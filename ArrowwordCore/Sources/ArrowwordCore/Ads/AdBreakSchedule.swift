/// When the game offers an ad break between levels: never early on, and
/// only after a few levels passed since the last one.
///
/// This is the game's half of the interstitial rules. The ads package adds
/// the half every app shares (time since the last ad, no ad right after a
/// rewarded video) and may still say no; that's why a break only counts as
/// taken once `breakTaken()` is called.
///
/// Kept for the session only, not saved: a player who plays one level per
/// visit never sees a break. That leans toward the player, and it keeps the
/// save file free of ad bookkeeping. Revisit with real session data.
public struct AdBreakSchedule: Equatable, Sendable {
    /// Players learn the game ad-free; breaks start after this level.
    public var firstLevel = 10
    /// Levels passed between breaks.
    public var levelsBetween = 2

    /// Passes counted toward the next break.
    public private(set) var passesSinceBreak = 0

    public init() {}

    /// Counts a passed level. Levels before `firstLevel` don't count, so the
    /// first break comes `levelsBetween` passes after it, not straight away.
    public mutating func levelPassed(number: Int) {
        guard number >= firstLevel else { return }
        passesSinceBreak += 1
    }

    /// Whether the game should ask for a break now (before the next level).
    public var isBreakDue: Bool {
        passesSinceBreak >= levelsBetween
    }

    /// Whether interstitials are worth loading for a player about to play
    /// this level: from the first level that counts. The first break is
    /// still `levelsBetween` passes away, plenty of time for one to load,
    /// and nothing is requested for new players who won't see one.
    public func wantsAdsLoaded(forLevel number: Int) -> Bool {
        number >= firstLevel
    }

    /// An ad was shown; counting starts again. Not called when the ads
    /// package declined, so the break stays due and the next pass tries again.
    public mutating func breakTaken() {
        passesSinceBreak = 0
    }
}
