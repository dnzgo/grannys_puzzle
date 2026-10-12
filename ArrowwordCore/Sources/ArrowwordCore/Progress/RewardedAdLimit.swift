/// The daily cap on rewarded ads, shared by both helpers: however the
/// player splits them between cats and grandmas, they get this many a day.
///
/// Why a cap at all: unlimited videos would make helpers free, and then
/// the daily jar, careful play and the helpers themselves stop meaning
/// anything. It also keeps ad networks happy, which distrust players who
/// watch dozens a day.
extension PlayerProgress {
    /// The default; the game uses `GameTuning.rewardedAdsPerDay`, which
    /// the server can change. Tune it with data: many players hitting it
    /// means it's too low, or helpers are too scarce.
    public static let rewardedAdsPerDay = 3

    /// Videos the player may still watch today (`today` is a `JarDay`
    /// number), out of `perDay`. A new day starts the count again.
    public func rewardedAdsLeft(today: Int, perDay: Int = PlayerProgress.rewardedAdsPerDay) -> Int {
        let watched = rewardedAdDay == today ? rewardedAdsThatDay : 0
        return max(0, perDay - watched)
    }

    /// Counts a video that earned its reward. Called only for completed
    /// ones: closing a video early gives nothing, so it shouldn't cost one
    /// of the day's videos either.
    public mutating func recordRewardedAd(today: Int) {
        if rewardedAdDay == today {
            rewardedAdsThatDay += 1
        } else {
            rewardedAdDay = today
            rewardedAdsThatDay = 1
        }
    }
}
