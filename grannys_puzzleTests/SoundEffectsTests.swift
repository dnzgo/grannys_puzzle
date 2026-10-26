import Foundation
import Testing
@testable import grannys_puzzle

/// The sound rules that are plain logic: which variation plays next, and
/// that every file the code asks for is really in the app. (What the sounds
/// sound like is checked by ear, on a phone.)
@MainActor  // the app's types live on the main actor
struct SoundEffectsTests {
    private let letterClick = SoundEffect("letter-placed", variations: 4)

    @Test func aVariationNeverPlaysTwiceInARow() {
        var picker = VariationPicker()
        var previous: String?
        var heard: Set<String> = []
        for _ in 0..<500 {
            let file = picker.next(for: letterClick)
            #expect(file != previous)
            previous = file
            heard.insert(file)
        }
        // And the rule doesn't freeze out any of them.
        #expect(heard == Set(letterClick.files))
    }

    @Test func stepsOverTheLastOneInsteadOfRedrawing() {
        // A "random" that always says 0: the first pick is file 1; after
        // that, 0 out of the other three means "the first one that isn't
        // the last", so it alternates instead of repeating.
        var picker = VariationPicker()
        let picks = (0..<4).map { _ in picker.next(for: letterClick) { _ in 0 } }
        #expect(picks == ["letter-placed-1", "letter-placed-2", "letter-placed-1", "letter-placed-2"])
    }

    @Test func eachSoundKeepsItsOwnHistory() {
        // A yarn landing between two clicks mustn't make the second click
        // forget which one played last.
        var picker = VariationPicker()
        let yarn = SoundEffect("yarn-landed", variations: 3)
        let first = picker.next(for: letterClick) { _ in 0 }
        _ = picker.next(for: yarn) { _ in 0 }
        let second = picker.next(for: letterClick) { _ in 0 }
        #expect(first != second)
    }

    @Test func aSingleFileAlwaysPlaysThatFile() {
        var picker = VariationPicker()
        let submit = SoundEffect("submit")
        #expect((0..<3).map { _ in picker.next(for: submit) } == ["submit", "submit", "submit"])
    }

    @Test func everySoundFileIsInTheApp() {
        for file in FeedbackEvent.allCases.flatMap(\.sound.files) {
            #expect(Self.isInBundle(file), "No file for \(file) in Audio/Sounds")
        }
    }

    @Test func everyMusicFileIsInTheApp() {
        for track in MusicTrack.allCases {
            #expect(Self.isInBundle(track.rawValue), "No file for \(track.rawValue) in Audio/Sounds")
        }
    }

    /// Hosted tests run inside the app, so Bundle.main is the app itself.
    private static func isInBundle(_ name: String) -> Bool {
        ["caf", "m4a", "wav"].contains { Bundle.main.url(forResource: name, withExtension: $0) != nil }
    }
}
