import Foundation
import ArrowwordCore

/// Loads levels shipped inside the app bundle.
///
/// Downloaded level packs will get their own loader later; both end in
/// `Level.decode`, so validation is the same wherever a level comes from.
enum LevelLoader {
    enum LoadError: Error, CustomStringConvertible {
        case missingFile(String)

        var description: String {
            switch self {
            case .missingFile(let name): return "No bundled level named \(name).json"
            }
        }
    }

    static func bundledLevel(named name: String, in bundle: Bundle = .main) throws -> Level {
        // Xcode may copy the file to the bundle root or keep its folder,
        // depending on project settings, so look in both places.
        let foundURL = bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Levels")
        guard let url = foundURL else { throw LoadError.missingFile(name) }
        return try Level.decode(from: Data(contentsOf: url))
    }
}
