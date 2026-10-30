import Foundation
import Observation
import ArrowwordCore

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

    /// After a level that didn't pass, on the level-end card. Warm and
    /// forward-looking: the player should want to try again, not feel told off.
    static func encouragement() -> String {
        switch Int.random(in: 0..<5) {
        case 0: String(localized: "So close, dear! Every puzzle makes you a little sharper.", bundle: .appLanguage, locale: .appLanguage)
        case 1: String(localized: "Even my best scarves took a few tries. You'll get it this time!", bundle: .appLanguage, locale: .appLanguage)
        case 2: String(localized: "Don't you worry, sweetheart. A sip of tea, a fresh look, and it's yours.", bundle: .appLanguage, locale: .appLanguage)
        case 3: String(localized: "A wrong stitch is just one to unpick. Let's knit it again!", bundle: .appLanguage, locale: .appLanguage)
        default: String(localized: "You're doing wonderfully. One more go, I believe in you!", bundle: .appLanguage, locale: .appLanguage)
        }
    }

    /// The streak chip tapped, with today solved.
    static func streakKept(_ days: Int) -> String {
        String(localized: "That's \(days) days in a row, dear! See you tomorrow.", bundle: .appLanguage, locale: .appLanguage)
    }

    /// The streak chip tapped, with today still to solve.
    static func streakAtRisk(_ days: Int) -> String {
        String(localized: "Solve a puzzle today to keep your \(days)-day streak!", bundle: .appLanguage, locale: .appLanguage)
    }

    /// The streak chip tapped, with no streak going.
    static var streakStart: String { String(localized: "Solve a puzzle every day to build a streak!", bundle: .appLanguage, locale: .appLanguage) }
    static var streakSaved: String { String(localized: "Your streak is safe, dear! Let's keep it going.", bundle: .appLanguage, locale: .appLanguage) }

    /// After Restart from the level's settings.
    static var freshStart: String { String(localized: "A fresh start, dear! Take your time.", bundle: .appLanguage, locale: .appLanguage) }
    static var jarReady: String { String(localized: "My jar has a treat for you today, dear!", bundle: .appLanguage, locale: .appLanguage) }
    /// After a jar is collected: it's kept, not opened.
    static var jarKept: String { String(localized: "I've put your jar by my chair, dear. Open it whenever you like!", bundle: .appLanguage, locale: .appLanguage) }
    /// The trophy was tapped, but Game Center isn't signed in.
    static var leaderboardsNeedGameCenter: String { String(localized: "The leaderboards need Game Center, dear. You can sign in from your phone's Settings app.", bundle: .appLanguage, locale: .appLanguage) }
    static var catNapping: String { String(localized: "Shh, the cat's having a little nap.", bundle: .appLanguage, locale: .appLanguage) }
    /// After knitting something, for whoever it's for.
    static func knitted(for member: FamilyMember) -> String {
        switch member {
        case .cat: String(localized: "Doesn't the cat look smart?", bundle: .appLanguage, locale: .appLanguage)
        case .daughter: String(localized: "My daughter is going to love this.", bundle: .appLanguage, locale: .appLanguage)
        case .son: String(localized: "That'll keep my son nice and warm.", bundle: .appLanguage, locale: .appLanguage)
        case .granddaughter: String(localized: "My granddaughter will be thrilled!", bundle: .appLanguage, locale: .appLanguage)
        case .grandson: String(localized: "My grandson will look so smart in this!", bundle: .appLanguage, locale: .appLanguage)
        }
    }

    /// After a whole wardrobe is finished, as the next one comes in.
    static func wardrobeStarted(for member: FamilyMember?) -> String {
        switch member {
        case .daughter: String(localized: "All done for the cat! Now, something for my daughter.", bundle: .appLanguage, locale: .appLanguage)
        case .son: String(localized: "Now my son gets his turn, dear.", bundle: .appLanguage, locale: .appLanguage)
        case .granddaughter: String(localized: "Next, something lovely for my granddaughter!", bundle: .appLanguage, locale: .appLanguage)
        case .grandson: String(localized: "And now my little grandson's wardrobe!", bundle: .appLanguage, locale: .appLanguage)
        // The cat is never next; nil is after the last wardrobe.
        case .cat, nil: String(localized: "The whole family is wrapped up warm. Thank you, dear!", bundle: .appLanguage, locale: .appLanguage)
        }
    }
    static var allLevelsDone: String { String(localized: "You've solved them all! I'm writing more.", bundle: .appLanguage, locale: .appLanguage) }
    /// Out of a helper and today's videos are used up. Points at the jar,
    /// where tomorrow's help comes from.
    static var noMoreVideosToday: String { String(localized: "That's all the videos for today, dear. Come back tomorrow, and don't forget my jar!", bundle: .appLanguage, locale: .appLanguage) }
    /// Out of a helper and no video happened to be ready (offline, say).
    static var noVideoReady: String { String(localized: "No video ready just now, dear. Try again in a moment.", bundle: .appLanguage, locale: .appLanguage) }

    static func adReward(_ reward: HelperAdReward, amount: Int) -> String {
        switch reward {
        case .catHints: String(localized: "\(amount) cat hints, just for you, dear!", bundle: .appLanguage, locale: .appLanguage)
        case .grandma: String(localized: "Here I am! Tap me when a word's too tricky.", bundle: .appLanguage, locale: .appLanguage)
        }
    }
}
