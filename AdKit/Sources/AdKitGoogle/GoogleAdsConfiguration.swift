#if os(iOS)
/// An app's AdMob ad units, plus consent-testing settings.
///
/// Ad unit IDs aren't secrets (they ship inside every copy of the app), so
/// they can live in source. The AdMob *app* ID goes in the app's Info.plist
/// as `GADApplicationIdentifier`, where the SDK reads it.
public struct GoogleAdsConfiguration: Sendable {
    public var rewardedAdUnitID: String
    public var bannerAdUnitID: String

    /// Devices that see consent forms in test mode (IDs are printed in the
    /// Xcode console on first run). Simulators always do.
    public var consentTestDeviceIDs: [String]
    /// Pretend the device is in the EU/UK, so the consent form shows while
    /// testing from anywhere. Debug builds only; never ship it on.
    public var simulatesEEAForConsent: Bool

    public init(
        rewardedAdUnitID: String,
        bannerAdUnitID: String,
        consentTestDeviceIDs: [String] = [],
        simulatesEEAForConsent: Bool = false
    ) {
        self.rewardedAdUnitID = rewardedAdUnitID
        self.bannerAdUnitID = bannerAdUnitID
        self.consentTestDeviceIDs = consentTestDeviceIDs
        self.simulatesEEAForConsent = simulatesEEAForConsent
    }

    /// Google's public test ad units: always fill, never earn, safe to tap.
    /// Use them for development; showing real ads to yourself can get an
    /// AdMob account suspended for invalid traffic.
    public static let googleTestUnits = GoogleAdsConfiguration(
        rewardedAdUnitID: "ca-app-pub-3940256099942544/1712485313",
        bannerAdUnitID: "ca-app-pub-3940256099942544/2934735716"
    )
}
#endif
