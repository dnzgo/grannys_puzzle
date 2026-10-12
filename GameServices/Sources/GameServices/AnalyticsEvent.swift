/// One thing that happened in the game, worth counting: a level finished,
/// a reward chosen. Names and limits follow Google Analytics, the backend
/// we use, but nothing here depends on it.
///
/// Why check names at all: Analytics silently drops an event whose name or
/// parameters break its rules. A typo'd or reserved name would mean weeks
/// of missing data before anyone noticed, so `problems` lists them and
/// `EventLogger` stops on them in debug builds, the first time they're sent.
public struct AnalyticsEvent: Equatable, Sendable {
    /// Parameter values Analytics accepts. Booleans go in as `.int(0 / 1)`:
    /// Analytics has no boolean type, and 0/1 can be summed and averaged.
    public enum Value: Equatable, Sendable {
        case int(Int)
        case double(Double)
        case string(String)

        public static func bool(_ value: Bool) -> Value { .int(value ? 1 : 0) }
    }

    public let name: String
    public let parameters: [String: Value]

    public init(_ name: String, _ parameters: [String: Value] = [:]) {
        self.name = name
        self.parameters = parameters
    }

    // MARK: - Google Analytics' rules

    /// From Google's "Event naming rules" and "collection limits" pages.
    public enum Limits {
        public static let nameLength = 40
        public static let parameterCount = 25
        public static let stringValueLength = 100

        /// Event names the system uses for its own events (mobile list).
        public static let reservedEventNames: Set<String> = [
            "ad_activeview", "ad_click", "ad_exposure", "ad_query", "ad_reward", "adunit_exposure",
            "app_clear_data", "app_exception", "app_install", "app_remove", "app_store_refund",
            "app_update", "app_upgrade", "dynamic_link_app_open", "dynamic_link_app_update",
            "dynamic_link_first_open", "error", "firebase_campaign", "firebase_in_app_message_action",
            "firebase_in_app_message_dismiss", "firebase_in_app_message_impression", "first_open",
            "first_visit", "notification_dismiss", "notification_foreground", "notification_open",
            "notification_receive", "notification_send", "os_update", "session_start", "user_engagement",
        ]
        /// Prefixes reserved for Google's own events and parameters.
        public static let reservedPrefixes = ["_", "firebase_", "ga_", "google_", "gtag."]
    }

    /// What's wrong with this event under those rules; empty when it's fine.
    public var problems: [String] {
        var problems: [String] = []
        if let issue = Self.nameIssue(name) {
            problems.append("event name \"\(name)\": \(issue)")
        } else if Limits.reservedEventNames.contains(name) {
            problems.append("event name \"\(name)\" is reserved")
        }
        if parameters.count > Limits.parameterCount {
            problems.append("\(parameters.count) parameters, at most \(Limits.parameterCount) allowed")
        }
        // Sorted so the list reads the same every time.
        for (key, value) in parameters.sorted(by: { $0.key < $1.key }) {
            if let issue = Self.nameIssue(key) {
                problems.append("parameter \"\(key)\": \(issue)")
            }
            if case .string(let text) = value, text.count > Limits.stringValueLength {
                problems.append("parameter \"\(key)\": value longer than \(Limits.stringValueLength) characters")
            }
        }
        return problems
    }

    /// Rules shared by event and parameter names: 1–40 characters, ASCII
    /// letters, digits and underscores, starting with a letter, no reserved
    /// prefix.
    private static func nameIssue(_ name: String) -> String? {
        if name.isEmpty || name.count > Limits.nameLength {
            return "must be 1–\(Limits.nameLength) characters"
        }
        if let prefix = Limits.reservedPrefixes.first(where: name.hasPrefix) {
            return "starts with the reserved \"\(prefix)\""
        }
        guard let first = name.unicodeScalars.first, isASCIILetter(first) else {
            return "must start with a letter"
        }
        let allowed = name.unicodeScalars.allSatisfy { isASCIILetter($0) || ("0"..."9").contains($0) || $0 == "_" }
        return allowed ? nil : "only letters, digits and underscores are allowed"
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }
}
