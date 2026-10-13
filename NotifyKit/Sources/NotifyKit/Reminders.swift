import Foundation
import Observation

/// A game's reminders: whether they may be sent, asking for permission at a
/// good moment, and scheduling them under `ReminderRules`.
///
/// Permission takes two answers, and the order matters. The game asks first,
/// in its own words ("Shall I let you know when your jar is ready?"), and
/// only a yes leads to the system's prompt. iOS shows its prompt once per
/// install, ever; spent at launch, before the player cares, it's usually a
/// no that can only be undone in the iOS Settings app. The game's own
/// question can be asked again later, so a "not now" costs nothing.
@MainActor
@Observable
public final class Reminders {
    /// What the system allows. Refresh it when the app becomes active: the
    /// player may have changed it in iOS Settings meanwhile.
    public private(set) var permission: NotificationPermission = .notAsked

    /// The player's own switch in the game's settings. Separate from the
    /// system's permission so a player can pause reminders without a trip
    /// to iOS Settings, and turn them back on just as easily.
    public var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: key("enabled")) }
    }

    /// Whether the game may ask its own "shall I remind you?" question now:
    /// the system hasn't been asked yet, and the player hasn't recently
    /// said "not now" (or said it too often).
    public func canOfferSoftAsk(now: Date = .now) -> Bool {
        guard permission == .notAsked else { return false }
        let declines = defaults.integer(forKey: key("softAskDeclines"))
        guard declines < softAskLimit else { return false }
        guard let lastDecline = defaults.object(forKey: key("softAskDeclinedAt")) as? Date else { return true }
        let wait = calendar.date(byAdding: .day, value: softAskRetryDays, to: lastDecline) ?? lastDecline
        return now >= wait
    }

    /// "Not now" may be said this many times before the game stops asking.
    public let softAskLimit = 2
    /// Days to wait after a "not now" before asking again.
    public let softAskRetryDays = 14

    private let scheduler: any ReminderScheduler
    private let rules: ReminderRules
    private let calendar: Calendar
    private let defaults: UserDefaults
    private let keyPrefix: String
    @ObservationIgnored private var bags: [String: ShuffleBag]
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()
    /// The last schedule or cancel, so the next one waits for it.
    @ObservationIgnored private var lastChange: Task<Void, Never>?

    /// - Parameters:
    ///   - defaults: where the switch, the soft-ask answers and the line
    ///     order are kept. A device preference like the sound switch, so
    ///     not part of a game's progress.
    ///   - keyPrefix: keeps these keys apart from the app's own.
    public init(
        scheduler: any ReminderScheduler,
        rules: ReminderRules = .standard,
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard,
        keyPrefix: String = "notifykit"
    ) {
        self.scheduler = scheduler
        self.rules = rules
        self.calendar = calendar
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        // On until the player turns it off; nothing is sent without the
        // system's permission anyway.
        isEnabled = defaults.object(forKey: "\(keyPrefix).enabled") as? Bool ?? true
        bags = (defaults.data(forKey: "\(keyPrefix).lineBags"))
            .flatMap { try? JSONDecoder().decode([String: ShuffleBag].self, from: $0) } ?? [:]
    }

    // MARK: - Permission

    public func refreshPermission() async {
        permission = await scheduler.permission()
    }

    /// The player said yes to the game's own question: now the system's
    /// prompt. Returns whether notifications are allowed.
    @discardableResult
    public func requestPermission() async -> Bool {
        let allowed = await scheduler.requestPermission()
        permission = allowed ? .allowed : .denied
        if allowed { isEnabled = true }
        return allowed
    }

    /// The player said "not now" to the game's own question.
    public func declineSoftAsk(now: Date = .now) {
        defaults.set(defaults.integer(forKey: key("softAskDeclines")) + 1, forKey: key("softAskDeclines"))
        defaults.set(now, forKey: key("softAskDeclinedAt"))
    }

    // MARK: - Scheduling

    /// Replaces what's scheduled with these candidates, after the rules
    /// (delivery hours, one a day, quiet after a long absence). Call it when
    /// the player leaves the app: everything is relative to `now`.
    /// Schedules nothing while reminders are off or not allowed.
    public func schedule(_ candidates: [Reminder], now: Date = .now) async {
        let plan = permission == .allowed && isEnabled
            ? ReminderPlanner.plan(candidates, now: now, rules: rules, calendar: calendar)
            : []
        await replaceInOrder(with: plan)
    }

    /// Clears everything scheduled, e.g. when the player comes back: they're
    /// here, so the reminders have done their job.
    public func cancelAll() async {
        await replaceInOrder(with: [])
    }

    /// Replacing takes several steps with waits between them (read what's
    /// pending, remove it, add each new one). A player who leaves and comes
    /// straight back would start a cancel while the schedule is still
    /// adding, and reminders could end up scheduled while they're playing.
    /// So each change waits for the previous one to finish: the last call
    /// always decides what's left scheduled.
    private func replaceInOrder(with plan: [Reminder]) async {
        let previous = lastChange
        let change = Task { [scheduler] in
            await previous?.value
            await scheduler.replaceScheduled(with: plan)
        }
        lastChange = change
        await change.value
    }

    // MARK: - Varied lines

    /// The next of several lines for one kind of reminder, never the same
    /// twice in a row and each used before any repeats (see `ShuffleBag`).
    /// The order is remembered across launches, per `kind`.
    public func line(from lines: [String], kind: String) -> String? {
        var bag = (bags[kind] ?? ShuffleBag(count: lines.count)).resized(to: lines.count)
        guard let index = bag.next(using: &generator) else { return nil }
        bags[kind] = bag
        if let data = try? JSONEncoder().encode(bags) {
            defaults.set(data, forKey: key("lineBags"))
        }
        return lines[index]
    }

    private func key(_ name: String) -> String {
        "\(keyPrefix).\(name)"
    }
}
