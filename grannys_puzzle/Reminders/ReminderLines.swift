import Foundation

/// What grandma says in her reminders, several lines per kind so they don't
/// repeat (NotifyKit rotates them).
///
/// Each line is about the player's own game (their jar, their streak, the
/// yarn for their next piece) rather than "come back and play". That's what
/// makes them feel like a note from her instead of an advert, and it keeps
/// them on the right side of Apple's rules on promotional notifications.
///
/// Built when the reminders are scheduled, in the game's language at that
/// moment, so they arrive in the language the player last used.
enum ReminderLines {
    /// Shown above every reminder, as the sender.
    static var title: String {
        String(localized: "Granny", bundle: .appLanguage, locale: .appLanguage, comment: "Sender name on reminder notifications")
    }

    /// Tomorrow's jar is ready.
    static var jar: [String] {
        [
            String(localized: "Your treat jar is ready, dear. Come see what's inside!", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "I've filled your jar with something nice. Come and have a peek!", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "Psst… there's a little surprise waiting in your jar.", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "The kettle's on and your jar is full. Pop in for a puzzle?", bundle: .appLanguage, locale: .appLanguage),
        ]
    }

    /// The play streak breaks unless they solve something today.
    static func streak(days: Int) -> [String] {
        [
            String(localized: "Your \(days)-day streak needs one puzzle today, sweetheart. Don't let it slip!", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "\(days) days in a row! One puzzle today keeps it going.", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "Don't forget me today, dear, or your \(days)-day streak starts over.", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "\(days) days in a row, how proud I am! Shall we make it one more?", bundle: .appLanguage, locale: .appLanguage),
        ]
    }

    /// Yesterday was missed: a video can still save the streak today.
    static func streakSave(days: Int) -> [String] {
        [
            String(localized: "Oh dear, you missed a day! You can still save your \(days)-day streak today.", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "Your \(days)-day streak is hanging by a thread, sweetheart. Come save it today!", bundle: .appLanguage, locale: .appLanguage),
        ]
    }

    /// A level was left halfway.
    static var unfinished: [String] {
        [
            String(localized: "You left a puzzle half done, dear. I kept your place!", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "Your puzzle is waiting right where you left it. Shall we finish it?", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "I peeked at your puzzle, dear. You're doing so well, come finish it!", bundle: .appLanguage, locale: .appLanguage),
        ]
    }

    /// There's enough yarn for something. `item` is its name in lowercase,
    /// as it reads inside a sentence ("red scarf"). The same lines grandma
    /// says on the level-end card (KnitNudgeLines), so they're translated once.
    static func knit(item: String) -> [String] {
        [
            String(localized: "Ooh, there's enough yarn for a \(item) now, dear! Come and knit it with me.", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "Look at all that yarn! I could knit a \(item). Pop by my yarn bag when you like.", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "That's enough for a \(item), sweetheart. I'll have my needles ready!", bundle: .appLanguage, locale: .appLanguage),
        ]
    }

    /// A new daily challenge is out.
    static var daily: [String] {
        [
            String(localized: "A new daily challenge is waiting, dear. How quick can you be today?", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "Today's daily challenge is ready. Fancy a race against the clock?", bundle: .appLanguage, locale: .appLanguage),
        ]
    }

    /// Grandma is short of yarn for her next piece. `color` is the colour's
    /// name in lowercase, as it reads inside a sentence ("yellow").
    static func yarn(color: String) -> [String] {
        [
            String(localized: "I've run out of \(color) yarn, sweetheart. Could you fetch me some?", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "My needles are waiting, dear. A little more \(color) yarn and the next piece is done!", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "Kitty's been eyeing my basket. Shall we knit him something \(color)?", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "Just a few more balls of \(color) yarn and I can start knitting. Will you help me?", bundle: .appLanguage, locale: .appLanguage),
        ]
    }

    /// They've been away a few days.
    static var missYou: [String] {
        [
            String(localized: "The house is so quiet without you, dear. Shall we do a puzzle together?", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "I saved you a cup of tea and a tricky puzzle. Whenever you're ready!", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "Kitty and I were just talking about you. Come say hello!", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "I'm stuck on a word, dear. Could you lend me your clever head?", bundle: .appLanguage, locale: .appLanguage),
        ]
    }
}
