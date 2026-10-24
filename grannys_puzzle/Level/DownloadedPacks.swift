import Foundation
import os
import ArrowwordCore

/// The packs downloaded after pack 1, kept on the phone so each is fetched
/// once: Application Support/LevelPacks/<name>.json.
///
/// Application Support rather than Caches because iOS may empty Caches
/// when space runs low, and a player with no connection would then lose
/// levels they had. They're marked as excluded from iCloud backup though:
/// they can always be downloaded again, and Apple asks apps not to back up
/// what can be.
enum DownloadedPacks {
    private static let logger = Logger(subsystem: "grannys_puzzle", category: "packs")

    static var folder: URL {
        URL.applicationSupportDirectory.appending(path: "LevelPacks", directoryHint: .isDirectory)
    }

    static func url(for name: String) -> URL {
        folder.appending(path: "\(name).json")
    }

    /// The stored packs that follow `library`'s last one, appended in
    /// order until one is missing. A stored file that no longer loads
    /// (damaged, or from an older format the app has moved on from) is
    /// deleted, so it's downloaded again, and the packs after it wait.
    static func appendStored(_ kind: PackKind, to library: inout LevelLibrary) {
        while true {
            let name = kind.fileName(language: library.language, number: library.nextPackNumber)
            let url = url(for: name)
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            do {
                try library.append(PackValidation.validated(Data(contentsOf: url), expectedName: name, language: library.language))
            } catch {
                logger.error("Stored pack \(name, privacy: .public) is unusable, deleting it: \(String(describing: error), privacy: .public)")
                try? FileManager.default.removeItem(at: url)
                return
            }
        }
    }

    /// Writes a downloaded pack's file (already validated). Atomic, so a
    /// crash mid-write leaves no half file to trip over at the next launch.
    static func save(_ data: Data, name: String) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var url = url(for: name)
        try data.write(to: url, options: .atomic)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
}

/// The checks every pack from outside the bundle passes before it's used:
/// it loads as a `LevelPack` (every level valid) and is the pack it was
/// asked for. A server file under the wrong name would otherwise slot
/// another pack's levels into the wrong numbers.
enum PackValidation {
    enum Mismatch: Error, CustomStringConvertible {
        case wrongPack(expected: String, found: String)
        case wrongLanguage(expected: String, found: String)

        var description: String {
            switch self {
            case .wrongPack(let expected, let found): return "Expected pack \(expected), the file is \(found)"
            case .wrongLanguage(let expected, let found): return "Expected language \(expected), the pack is \(found)"
            }
        }
    }

    static func validated(_ data: Data, expectedName: String, language: String) throws -> LevelPack {
        let pack = try LevelPack.decode(from: data)
        guard pack.id == expectedName else { throw Mismatch.wrongPack(expected: expectedName, found: pack.id) }
        guard pack.language == language else { throw Mismatch.wrongLanguage(expected: language, found: pack.language) }
        return pack
    }
}
