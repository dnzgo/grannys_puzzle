import AVFoundation
import Observation
import os

/// Plays the short sounds (letter clicks, jingles). Views don't use it
/// directly: `.gameFeedback(_:)` plays an event's sound through it.
///
/// Observable only so SwiftUI can hand it down through the environment;
/// nothing about it changes on screen.
@Observable
final class SoundPlayer {
    /// Copies of each file kept ready, so a sound can start again while the
    /// last one is still ringing (a fast typist, the judging wave's ticks).
    /// With one copy each new click would cut the previous one off.
    private static let voicesPerFile = 3
    private static let fileExtensions = ["caf", "m4a", "wav"]

    @ObservationIgnored private var voices: [String: [AVAudioPlayer]] = [:]
    @ObservationIgnored private var nextVoice: [String: Int] = [:]
    @ObservationIgnored private var picker = VariationPicker()
    @ObservationIgnored private let bundle: Bundle
    @ObservationIgnored private let logger = Logger(subsystem: "grannys_puzzle", category: "audio")

    /// Loads every moment's sounds now, at launch. They're small (a few
    /// seconds each), and loading on first use would delay the first click.
    init(bundle: Bundle = .main) {
        self.bundle = bundle
        for file in FeedbackEvent.allCases.flatMap(\.sound.files) where voices[file] == nil {
            voices[file] = load(file)
        }
    }

    func play(_ effect: SoundEffect) {
        let file = picker.next(for: effect)
        guard let copies = voices[file], !copies.isEmpty else { return }
        // Round-robin over the copies: the oldest one is the most likely to
        // have finished, and restarting it cuts the least.
        let index = nextVoice[file, default: 0]
        nextVoice[file] = (index + 1) % copies.count
        let player = copies[index]
        player.volume = effect.volume
        player.currentTime = 0
        player.play()
    }

    /// The ready copies of one file, or none if it's missing or unreadable.
    /// A missing sound is logged and then silent rather than a crash: the
    /// game is fully playable without any one sound.
    private func load(_ file: String) -> [AVAudioPlayer] {
        guard let url = Self.fileExtensions.lazy.compactMap({ self.bundle.url(forResource: file, withExtension: $0) }).first else {
            logger.error("Sound file missing: \(file, privacy: .public)")
            return []
        }
        do {
            return try (0..<Self.voicesPerFile).map { _ in
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                return player
            }
        } catch {
            logger.error("Sound \(file, privacy: .public) unreadable: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
