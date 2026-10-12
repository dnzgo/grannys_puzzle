#if os(iOS)
import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import Foundation
import GameServices
import os

/// Starting Firebase, and the app's access to it.
public enum FirebaseServices {
    /// Starts Firebase from the app's `GoogleService-Info.plist`. Returns
    /// false, and starts nothing, when the file isn't in the app.
    ///
    /// Call it first thing at launch, and in particular before Google's ad
    /// consent check (AdKit's `start()`): the consent tool passes the
    /// player's choice to Analytics only if Firebase is already running.
    ///
    /// - Parameter collectsAnalytics: whether Analytics sends events. Set
    ///   on every launch because Firebase remembers the last setting.
    @MainActor
    public static func start(collectsAnalytics: Bool) -> Bool {
        if FirebaseApp.app() == nil {
            // Without the file, `configure()` stops the app. Missing it is
            // normal in a fresh checkout (it's downloaded from the console),
            // so the game runs without these services instead.
            guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
                Logger(subsystem: "GameServices", category: "firebase")
                    .notice("No GoogleService-Info.plist; running without Firebase")
                return false
            }
            FirebaseApp.configure()
        }
        Analytics.setAnalyticsCollectionEnabled(collectsAnalytics)
        // Crashlytics reports crashes by itself once Firebase is configured.
        // It's touched here so the linker keeps it: nothing else in the app
        // refers to it, and unreferenced code can be stripped.
        _ = Crashlytics.crashlytics()
        return true
    }
}

/// Sends events to Google Analytics for Firebase.
@MainActor
public final class FirebaseAnalyticsBackend: AnalyticsBackend {
    public init() {}

    public func send(_ event: AnalyticsEvent) {
        let parameters = event.parameters.mapValues { value -> Any in
            switch value {
            case .int(let number): number
            case .double(let number): number
            case .string(let text): text
            }
        }
        Analytics.logEvent(event.name, parameters: parameters.isEmpty ? nil : parameters)
    }
}
#endif
