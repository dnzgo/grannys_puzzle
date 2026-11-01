#if DEBUG
import Foundation
import ArrowwordCore

/// Shortcuts for testing, set as Xcode launch arguments (Product → Scheme →
/// Edit Scheme… → Run → Arguments → "Arguments Passed On Launch"). Debug
/// builds only: none of this exists in a TestFlight or App Store build.
///
/// - `-GPStartLevel 91`: act as if the player had reached level 91. At 91 the
///   next pack (en-002) downloads at launch, as it does 10 levels before the
///   end of a pack; at 101 the first downloaded level is the one to play.
///   Only ever moves forward, so it can stay set across launches.
/// - `-GPDailyFirstDay 20260801`: count the dailies from 1 August 2026, so
///   today is a later daily and the next daily pack downloads (today must be
///   at least 91 days after it). Overrides Remote Config's `daily_first_day`.
///
/// Launch arguments are read through UserDefaults (its argument domain), so
/// they last only while they're set in the scheme; untick them to stop.
enum DebugLaunchOptions {
    static var startLevel: Int? { number("GPStartLevel") }

    static var dailyFirstDay: Int? { number("GPDailyFirstDay").flatMap(DailyDay.number(fromDate:)) }

    private static func number(_ key: String) -> Int? {
        UserDefaults.standard.string(forKey: key).flatMap { Int($0) }
    }
}
#endif
