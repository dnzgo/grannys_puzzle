import Foundation
import ArrowwordCore

/// Loads levels and level packs shipped inside the app bundle.
///
/// Downloaded packs will get their own loader later; everything ends in
/// `Level` / `LevelPack` validation, so a level is checked the same way
/// wherever it comes from.
enum LevelLoader {
    enum LoadError: Error, CustomStringConvertible {
        case missingFile(String)

        var description: String {
            switch self {
            case .missingFile(let name): return "No bundled file named \(name).json"
            }
        }
    }

    /// The first pack the game plays. Moves into a pack catalog once there's
    /// more than one.
    static let firstPackName = "en-001"

    static func bundledPack(named name: String, in bundle: Bundle = .main) throws -> LevelPack {
        try LevelPack.decode(from: Data(contentsOf: bundledURL(named: name, in: bundle)))
    }

    private static func bundledURL(named name: String, in bundle: Bundle) throws -> URL {
        // Xcode may copy the file to the bundle root or keep its folder,
        // depending on project settings, so look in both places.
        let foundURL = bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Levels")
        guard let url = foundURL else { throw LoadError.missingFile(name) }
        return url
    }
}
