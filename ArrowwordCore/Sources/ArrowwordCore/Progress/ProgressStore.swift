import Foundation

/// Why saved progress couldn't be loaded.
public enum ProgressStoreError: Error, Equatable {
    /// The file was written by a newer version of the app (the player
    /// downgraded, or restored an old backup of the app).
    case unsupportedVersion(Int)
}

/// Saves and loads `PlayerProgress` as a small JSON file.
///
/// Why a JSON file and not `UserDefaults`: both would work for data this
/// small, but a file is easy to inspect in tests, is written in one atomic
/// step, and is the same shape we'll later sync to the cloud when accounts
/// arrive.
public struct ProgressStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The store the app uses: `progress.json` in Application Support, which
    /// iOS keeps across launches and includes in device backups, and which
    /// (unlike Documents) isn't shown to the player in the Files app.
    public static func standard() throws -> ProgressStore {
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return ProgressStore(fileURL: folder.appendingPathComponent("progress.json"))
    }

    /// The saved progress, or a new player's if nothing has been saved yet.
    ///
    /// Throws if a file exists but can't be read. That's deliberately not
    /// turned into "new player" here: silently wiping someone's progress is
    /// the worst outcome, so the caller decides what to do and can keep the
    /// damaged file (see `setAsideDamagedFile`).
    public func load() throws -> PlayerProgress {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .newPlayer
        }
        let data = try Data(contentsOf: fileURL)
        // Read the version on its own first. A newer app may have changed the
        // format, and then decoding the whole thing would fail with a vague
        // decoding error instead of saying what actually happened.
        let version = try JSONDecoder().decode(SavedVersion.self, from: data).version
        guard version <= PlayerProgress.currentVersion else {
            throw ProgressStoreError.unsupportedVersion(version)
        }
        return try JSONDecoder().decode(PlayerProgress.self, from: data)
    }

    /// Just the `version` field of a save file.
    private struct SavedVersion: Decodable {
        let version: Int
    }

    /// Writes the progress. `.atomic` writes to a temporary file and then
    /// swaps it in, so a crash mid-save leaves the old file intact rather
    /// than half a file.
    public func save(_ progress: PlayerProgress) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(progress).write(to: fileURL, options: .atomic)
    }

    /// Renames an unreadable progress file instead of overwriting it, so it
    /// can still be recovered (by support, or a future app version).
    ///
    /// - Returns: where the file was moved.
    @discardableResult
    public func setAsideDamagedFile(now: Date = Date()) throws -> URL {
        let stamp = Int(now.timeIntervalSince1970)
        let backup = fileURL.deletingLastPathComponent()
            .appendingPathComponent("progress-damaged-\(stamp).json")
        try FileManager.default.moveItem(at: fileURL, to: backup)
        return backup
    }
}
