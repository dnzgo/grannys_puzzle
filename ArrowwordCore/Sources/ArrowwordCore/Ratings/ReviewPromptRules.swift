import Foundation

/// When the game may show Apple's "Enjoying the game?" rating prompt.
///
/// The game only *asks*; iOS decides whether the prompt actually appears
/// (at most three times a year per app). So these rules are about choosing
/// good moments, not about counting: a happy moment (the caller's job, e.g.
/// a perfect board), from a player who knows the game, not too often.
///
/// Never in exchange for anything: Apple's rules forbid rewarding ratings.
public struct ReviewPromptRules: Equatable, Sendable {
    /// Levels passed before the first ask. A player who has finished this
    /// many has an opinion; asking a brand-new one invites a hasty rating.
    public var minLevelsPassed = 10
    /// Days between asks, on top of iOS's own yearly limit, so the prompt
    /// never feels like the price of a good moment.
    public var daysBetweenAsks = 120

    public init() {}

    public static let standard = ReviewPromptRules()

    /// Whether this happy moment may be used to ask.
    /// - Parameter lastAsked: when the game last asked, nil if never.
    public func mayAsk(levelsPassed: Int, lastAsked: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard levelsPassed >= minLevelsPassed else { return false }
        guard let lastAsked else { return true }
        guard let nextAllowed = calendar.date(byAdding: .day, value: daysBetweenAsks, to: lastAsked) else { return false }
        return now >= nextAllowed
    }
}
