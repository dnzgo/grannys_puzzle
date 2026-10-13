import Foundation
import UserNotifications
import os

/// Whether the system lets the app show notifications.
public enum NotificationPermission: Equatable, Sendable {
    /// The system prompt hasn't been shown yet. It can only be shown once.
    case notAsked
    case allowed
    /// Declined, now or in iOS Settings; only the player can change it there.
    case denied
}

/// What NotifyKit needs from the system. The real one wraps Apple's
/// notification centre; tests use a fake that records what was scheduled.
@MainActor
public protocol ReminderScheduler: AnyObject {
    func permission() async -> NotificationPermission
    /// Shows the system's "Allow notifications?" prompt. Returns whether
    /// the player allowed them.
    func requestPermission() async -> Bool
    /// Replaces every reminder this app scheduled with these.
    func replaceScheduled(with reminders: [Reminder]) async
}

/// Apple's notification centre as a `ReminderScheduler`.
@MainActor
public final class SystemReminderScheduler: ReminderScheduler {
    /// Every request NotifyKit adds has this prefix, so replacing them never
    /// touches notifications something else in the app may schedule.
    static let identifierPrefix = "notifykit."
    /// Where the kind travels inside a notification, for `ReminderTapRelay`.
    static let kindKey = "notifykitKind"

    private let center = UNUserNotificationCenter.current()
    private let calendar: Calendar
    private let logger = Logger(subsystem: "NotifyKit", category: "scheduler")

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func permission() async -> NotificationPermission {
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .notDetermined: return .notAsked
        // Provisional notifications deliver too, just quietly.
        case .authorized, .provisional: return .allowed
        case .denied: return .denied
        default:
            // `.ephemeral` (App Clips) only exists on iOS, and this package
            // also builds on macOS for its tests; it delivers, so allowed.
            #if os(iOS)
            if status == .ephemeral { return .allowed }
            #endif
            return .denied
        }
    }

    public func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Permission request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    public func replaceScheduled(with reminders: [Reminder]) async {
        let ours = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        for (index, reminder) in reminders.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.userInfo = [Self.kindKey: reminder.kind]

            // A calendar trigger (not "in N seconds") so the reminder keeps
            // its local time if the player changes time zone meanwhile.
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(Self.identifierPrefix)\(index).\(reminder.kind)",
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                logger.error("Scheduling \(reminder.kind, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

/// Hears when the player taps one of the app's reminders, and keeps
/// reminders from showing while the app is open.
///
/// iOS hands a tap that launches the app to the notification centre's
/// delegate early in launch, so set this up in the app's `init`, before the
/// first screen; set later, the tap that opened the app is missed.
@MainActor
public final class ReminderTapRelay: NSObject, UNUserNotificationCenterDelegate {
    /// Called with the tapped reminder's kind.
    public var onTap: ((String) -> Void)? {
        didSet { deliverPendingTap() }
    }
    /// A tap that arrived before `onTap` was set (the launch case).
    private var pendingKind: String?

    public override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    private func deliverPendingTap() {
        guard let kind = pendingKind, let onTap else { return }
        pendingKind = nil
        onTap(kind)
    }

    // MARK: - UNUserNotificationCenterDelegate

    // The system calls these off the main actor's knowledge, so they're
    // nonisolated and hop over.

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let kind = response.notification.request.content.userInfo[SystemReminderScheduler.kindKey] as? String
        guard let kind else { return }
        await MainActor.run {
            pendingKind = kind
            deliverPendingTap()
        }
    }

    /// While the game is open the player is already here, so a reminder
    /// arriving now isn't shown.
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }
}
