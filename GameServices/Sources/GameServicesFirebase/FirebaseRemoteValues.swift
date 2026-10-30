#if os(iOS)
import FirebaseRemoteConfig
import Foundation
import GameServices
import os

/// Firebase Remote Config as a `RemoteValueSource`. Only valid after
/// `FirebaseServices.start` returned true.
@MainActor
public final class FirebaseRemoteValues: RemoteValueSource {
    private let config: RemoteConfig
    private let logger = Logger(subsystem: "GameServices", category: "remote-config")
    /// Set when the first launch's download (`fetchAndActivateNow`) ends.
    private var firstFetchDone = false

    /// - Parameter minimumFetchInterval: least time between downloads.
    ///   Firebase throttles apps that fetch too often; its default is 12
    ///   hours. Use 0 while developing to see console changes at once.
    public init(minimumFetchInterval: TimeInterval = 12 * 60 * 60) {
        config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = minimumFetchInterval
        config.configSettings = settings
    }

    public func activateFetched() async {
        do {
            // False just means nothing new was fetched; not an error.
            _ = try await config.activate()
        } catch {
            logger.notice("Activating fetched values failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func fetchForNextLaunch() async {
        do {
            _ = try await config.fetch()
        } catch {
            // Offline or throttled: the values from last time stay, and the
            // next launch tries again. Nothing for the player to see.
            logger.notice("Fetching values failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public var hasFetchedBefore: Bool {
        config.lastFetchStatus != .noFetchYet
    }

    public func fetchAndActivateNow(timeout: Duration) async {
        firstFetchDone = false
        // The download runs on its own; this waits for whichever comes
        // first, it finishing or the time limit. (Checked every tenth of a
        // second: simple, and a few checks are nothing next to a download.)
        // If it finishes after the limit, the values are there next time.
        Task {
            do {
                _ = try await config.fetchAndActivate()
            } catch {
                logger.notice("First fetch failed: \(error.localizedDescription, privacy: .public)")
            }
            firstFetchDone = true
        }
        let deadline = ContinuousClock.now + timeout
        while !firstFetchDone, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    public func number(forKey key: String) -> Double? {
        let value = config.configValue(forKey: key)
        // Only values the console actually sets. A key it doesn't set reads
        // as 0, which must not be mistaken for a real 0.
        guard value.source == .remote else { return nil }
        // `numberValue` also turns text it can't read into 0, so parse the
        // text instead: a typo in the console becomes nil (the default).
        return Double(value.stringValue.trimmingCharacters(in: .whitespaces))
    }
}
#endif
