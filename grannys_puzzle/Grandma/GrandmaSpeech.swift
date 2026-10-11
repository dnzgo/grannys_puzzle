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

/// Grandma's lines. They move into a data file (with Turkish versions and
/// triggers) when the mascot's full behaviour is built.
enum GrandmaLines {
    private static let solvedTemplates = [
        "Ah, that one's %@, dear.",
        "%@! I knew it before my tea went cold.",
        "Let me see… %@. Easy as purl.",
        "It's %@, sweetheart. Keep going!",
    ]

    private static let greetings = [
        "Hello, dear! Fancy a puzzle?",
        "Every puzzle you solve brings me yarn.",
        "My needles are waiting for some colour!",
        "Come sit with me, sweetheart.",
    ]

    static func solved(_ word: String) -> String {
        let template = solvedTemplates.randomElement() ?? "%@"
        return String(format: template, word)
    }

    static func greeting() -> String {
        greetings.randomElement() ?? greetings[0]
    }

    static let jarReady = "My jar has a treat for you today, dear!"
    static let jarTomorrow = "That's all for today. Come back tomorrow for another treat!"
    static let catNapping = "Shh, the cat's having a little nap."
    static let knitted = "Doesn't the cat look smart?"
    static let allLevelsDone = "You've solved them all! I'm writing more."

    static func adReward(_ reward: HelperAdReward) -> String {
        switch reward {
        case .catHints: "Three cat hints, just for you, dear!"
        case .grandma: "Here I am! Tap me when a word's too tricky."
        }
    }
}
