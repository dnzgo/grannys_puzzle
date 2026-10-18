import Foundation

/// How the daily puzzle's times are written.
enum DailyFormat {
    /// A stopwatch reading: "4:12", or "1:04:12" past an hour (also how
    /// the countdown to the next puzzle reads, "22:28:52"). Digits and
    /// colons read the same in every language, so it isn't localized.
    static func clock(seconds: Int) -> String {
        let seconds = max(0, seconds)
        let hours = seconds / 3600
        let minutes = seconds / 60 % 60
        let rest = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, rest)
        }
        return String(format: "%d:%02d", minutes, rest)
    }
}
