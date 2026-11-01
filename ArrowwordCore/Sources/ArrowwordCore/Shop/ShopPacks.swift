/// What each helper item in the shop gives. Kept in tuning, not in the
/// shop's list of items, so the amounts can change from the server
/// (Remote Config) without an app update; prices change in App Store
/// Connect. Together they let a pack be re-balanced entirely after launch.
///
/// The amounts are read when a purchase is delivered, so the shop must show
/// the same tuning it delivers with (the app passes `GameTuning.shop` to
/// both). The App Store's own product names shouldn't contain the numbers
/// ("Small cat hint pack", not "15 cat hints"), or they'd go stale here.
public struct ShopPacks: Equatable, Sendable {
    /// A small and a big pack of each helper. The big one is a little
    /// cheaper per helper, so it's the natural choice without making the
    /// small one feel like a rip-off (docs/Monetization.md has the prices).
    public var catHintsSmall = JarReward(hints: 15, grandmas: 0)
    public var catHintsBig = JarReward(hints: 50, grandmas: 0)
    public var grandmasSmall = JarReward(hints: 0, grandmas: 5)
    public var grandmasBig = JarReward(hints: 0, grandmas: 15)
    /// The helpers in the welcome bundle, besides removing ads. Given once
    /// per purchase (see `PlayerProgress.grantPurchase`).
    public var welcomeBundle = JarReward(hints: 30, grandmas: 5)

    public init() {}

    public static let standard = ShopPacks()
}
