import GameKit
import UIKit
import os
import ArrowwordCore

/// Game Center for the game: signing the player in, reporting achievement
/// progress, and opening Apple's achievements screen.
///
/// The game only talks to it through `Game` (reporting) and Settings (the
/// Achievements row, which shows only while signed in). Without Game
/// Center (no sign-in, a build signed without the entitlement, previews)
/// everything here quietly does nothing: achievements are a bonus, never
/// something that can stop the game.
///
/// Kept in the app rather than a package: it's a thin layer over GameKit
/// with one game's needs, and there's no second game to share it with yet.
@MainActor
@Observable
final class GameCenter {
    /// Signed in, so progress can be reported and the screen opened.
    private(set) var isSignedIn = false

    /// The highest progress Game Center already has for each achievement:
    /// loaded at sign-in, then kept up to date with what's reported. Only
    /// what goes past it is sent, which keeps the reports small and, more
    /// importantly, never re-sends a finished one: Apple would show its
    /// "achievement earned" banner again on every launch.
    @ObservationIgnored private var known: [String: Double] = [:]
    @ObservationIgnored private var hasLoadedKnown = false
    /// Progress handed over before sign-in finished; sent once it has.
    @ObservationIgnored private var pending: [AchievementProgress] = []
    @ObservationIgnored private var hasStartedSignIn = false
    /// A daily score handed over before sign-in finished; sent once it has,
    /// if its day's leaderboard is still the current one.
    @ObservationIgnored private var pendingDailyScore: DailyScoreReport?
    @ObservationIgnored private let logger = Logger(subsystem: "grannys_puzzle", category: "gamecenter")

    /// Signs the player in, once per launch. Apple decides whether to show
    /// its sign-in screen: the first time, and not again if the player
    /// dismissed it (they can then sign in from the Settings app).
    ///
    /// Called after the lesson, not at first launch, so a new player meets
    /// grandma before a system screen.
    func signIn() {
        guard !hasStartedSignIn else { return }
        hasStartedSignIn = true
        // GameKit calls this again whenever the sign-in state changes (the
        // player signs in from Settings while the game is open, say).
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    Self.present(viewController)
                    return
                }
                if let error {
                    // Not signed in, no network, or no Game Center in this
                    // build: all fine, the game goes on without it.
                    self.logger.info("Game Center not available: \(error.localizedDescription, privacy: .public)")
                }
                self.isSignedIn = GKLocalPlayer.local.isAuthenticated
                if self.isSignedIn {
                    if let waiting = self.pendingDailyScore {
                        self.pendingDailyScore = nil
                        self.submitDailyScore(waiting)
                    }
                    await self.loadKnownProgress()
                }
            }
        }
    }

    /// Reports whatever moved forward. Safe to call often (`Game` calls it
    /// after every saved change): unchanged achievements send nothing.
    func report(_ progress: [AchievementProgress]) {
        guard isSignedIn, hasLoadedKnown else {
            pending = progress
            return
        }
        let moved = progress.filter { $0.percentComplete > known[$0.id, default: 0] }
        guard !moved.isEmpty else { return }
        for item in moved { known[item.id] = item.percentComplete }
        let achievements = moved.map { item in
            let achievement = GKAchievement(identifier: item.id)
            achievement.percentComplete = item.percentComplete
            achievement.showsCompletionBanner = true
            return achievement
        }
        GKAchievement.report(achievements) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in
                guard let self else { return }
                self.logger.error("Reporting achievements failed: \(error.localizedDescription, privacy: .public)")
                // Forget them, so the next change tries them again.
                for item in moved where self.known[item.id] == item.percentComplete {
                    self.known[item.id] = nil
                }
                self.hasLoadedKnown = false
                await self.loadKnownProgress()
            }
        }
    }

    /// Sends a daily score to its language's leaderboard.
    ///
    /// Safe to send again: Game Center keeps each player's best score per
    /// leaderboard period, so `Game` simply re-sends today's at every
    /// sign-in, which also retries one that failed (offline, say) without
    /// the game having to remember what got through.
    ///
    /// The day is checked because the leaderboards are recurring and reset
    /// at 00:00 UTC, with the daily puzzle: a score held past midnight
    /// would land on the next day's board, ranked against a puzzle the
    /// player never played.
    func submitDailyScore(_ report: DailyScoreReport) {
        guard report.day == DailyDay.number() else { return }
        guard isSignedIn else {
            pendingDailyScore = report
            return
        }
        GKLeaderboard.submitScore(
            report.score, context: 0, player: GKLocalPlayer.local,
            leaderboardIDs: [Self.dailyLeaderboardID(language: report.language)]
        ) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in
                // Not retried here: the next launch's sign-in sends it again.
                self?.logger.error("Submitting the daily score failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// One leaderboard per language (docs/Achievements.md): the English
    /// and Turkish dailies are different puzzles, so their scores can't be
    /// ranked together. Must match the IDs in App Store Connect.
    static func dailyLeaderboardID(language: String) -> String {
        "grannyspuzzle.daily.\(language)"
    }

    /// Apple's achievements screen (Settings → Achievements).
    func showAchievements() {
        guard isSignedIn else { return }
        GKAccessPoint.shared.trigger(state: .achievements) {}
    }

    /// Apple's leaderboards screen (the trophy in grandma's room). False
    /// when the player isn't signed in to Game Center, so the caller can
    /// say why nothing opened.
    func showLeaderboards() -> Bool {
        guard isSignedIn else { return false }
        GKAccessPoint.shared.trigger(state: .leaderboards) {}
        return true
    }

    // MARK: - Private

    private func loadKnownProgress() async {
        do {
            let achievements = try await GKAchievement.loadAchievements()
            for achievement in achievements {
                known[achievement.identifier] = max(known[achievement.identifier, default: 0], achievement.percentComplete)
            }
            hasLoadedKnown = true
            let waiting = pending
            pending = []
            report(waiting)
        } catch {
            // Without knowing what Game Center has, reporting could replay
            // banners; it waits for the next sign-in instead.
            logger.error("Loading achievements failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Apple's sign-in screen, over whatever is showing.
    private static func present(_ viewController: UIViewController) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        top?.present(viewController, animated: true)
    }
}

/// A daily score on its way to Game Center: which day it's for (a
/// `DailyDay` number), which language's leaderboard, and the points.
struct DailyScoreReport: Equatable {
    let day: Int
    let language: String
    let score: Int
}
