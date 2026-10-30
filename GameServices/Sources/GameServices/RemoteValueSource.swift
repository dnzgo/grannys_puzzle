/// Numbers set from a server (Firebase Remote Config in the app), so a game
/// can be tuned without an App Store update.
///
/// The intended rhythm, which keeps rules steady while someone plays and
/// never makes launch wait for the network:
/// 1. At launch, `activateFetched()`: switch to the values fetched last
///    time. This only reads the device, so it's quick.
/// 2. Read values with `number(forKey:)`.
/// 3. `fetchForNextLaunch()` in the background: download new values,
///    which take effect at the next launch.
///
/// Except on the very first launch, when nothing was ever fetched: then
/// `fetchAndActivateNow(timeout:)` gets the server's values straight
/// away, so a new player isn't on the app's defaults for a whole session
/// (the daily's first day must match everyone else's from the start).
@MainActor
public protocol RemoteValueSource: AnyObject {
    func activateFetched() async
    func fetchForNextLaunch() async

    /// True once values have been downloaded at least once on this device.
    var hasFetchedBefore: Bool { get }
    /// Downloads and switches to the server's values now, waiting at most
    /// `timeout` (offline, it gives up and the defaults stay).
    func fetchAndActivateNow(timeout: Duration) async

    /// The server's value for a key, or nil if the server doesn't set it
    /// (or it isn't a number). Nil means "use the app's own default", so
    /// the game always has a value, even offline or on first launch.
    func number(forKey key: String) -> Double?
}
