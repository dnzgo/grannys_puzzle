import Foundation
import Observation

/// Grandma's speech bubble: the line on screen and its timer.
///
/// Shared by the level screen and the home screen, so the "show for a moment,
/// then fade" behaviour lives in one place.
@Observable
final class GrandmaSpeech {
    /// The line being shown, or nil when she's quiet.
    private(set) var line: String?

    /// How long a line stays up. Long enough to read about ten words.
    @ObservationIgnored private let duration: Duration
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    init(duration: Duration = .seconds(2.6)) {
        self.duration = duration
    }

    func say(_ newLine: String) {
        // A new line replaces the old one and restarts the timer.
        hideTask?.cancel()
        line = newLine
        hideTask = Task { [weak self, duration = self.duration] in
            // Sleep throws only when cancelled; a newer line then owns
            // `line`, so this timer must not clear it.
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.line = nil
        }
    }
}

/// Grandma's lines, translated through the String Catalog like the rest of
/// the app's text. Computed on each use rather than stored, so they always
/// come out in the app's current language.
enum GrandmaLines {
    static func solved(_ word: String) -> String {
        // The word goes in the middle of the sentence, and its place differs
        // between languages, so each line is a whole localized sentence.
        switch Int.random(in: 0..<4) {
        case 0: String(localized: "Ah, that one's \(word), dear.", bundle: .appLanguage, locale: .appLanguage)
        case 1: String(localized: "\(word)! I knew it before my tea went cold.", bundle: .appLanguage, locale: .appLanguage)
        case 2: String(localized: "Let me see… \(word). Easy as purl.", bundle: .appLanguage, locale: .appLanguage)
        default: String(localized: "It's \(word), sweetheart. Keep going!", bundle: .appLanguage, locale: .appLanguage)
        }
    }

    static func greeting() -> String {
        switch Int.random(in: 0..<4) {
        case 0: String(localized: "Hello, dear! Fancy a puzzle?", bundle: .appLanguage, locale: .appLanguage)
        case 1: String(localized: "Every puzzle you solve brings me yarn.", bundle: .appLanguage, locale: .appLanguage)
        case 2: String(localized: "My needles are waiting for some colour!", bundle: .appLanguage, locale: .appLanguage)
        default: String(localized: "Come sit with me, sweetheart.", bundle: .appLanguage, locale: .appLanguage)
        }
    }

    static var jarReady: String { String(localized: "My jar has a treat for you today, dear!", bundle: .appLanguage, locale: .appLanguage) }
    static var jarTomorrow: String { String(localized: "That's all for today. Come back tomorrow for another treat!", bundle: .appLanguage, locale: .appLanguage) }
    static var catNapping: String { String(localized: "Shh, the cat's having a little nap.", bundle: .appLanguage, locale: .appLanguage) }
    static var knitted: String { String(localized: "Doesn't the cat look smart?", bundle: .appLanguage, locale: .appLanguage) }
    static var allLevelsDone: String { String(localized: "You've solved them all! I'm writing more.", bundle: .appLanguage, locale: .appLanguage) }

    static func adReward(_ reward: HelperAdReward, amount: Int) -> String {
        switch reward {
        case .catHints: String(localized: "\(amount) cat hints, just for you, dear!", bundle: .appLanguage, locale: .appLanguage)
        case .grandma: String(localized: "Here I am! Tap me when a word's too tricky.", bundle: .appLanguage, locale: .appLanguage)
        }
    }
}
