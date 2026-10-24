import Foundation
import ArrowwordCore

/// Fetches packs from the content server: plain JSON files on a CDN
/// (Firebase Hosting), at <baseURL>/packs/<name>.json.
///
/// Static files rather than a database or Remote Config: packs are
/// public, written once and read by everyone, which is exactly what a CDN
/// is for, and it needs no SDK, only URLSession. (Remote Config is made
/// for small settings; every player downloads all of it.)
struct PackDownloader {
    /// How a fetch ended. The difference between `offline` and
    /// `notPublished` decides what the home screen says when the player has
    /// no levels left: "connect to the internet" or "more coming soon".
    enum Outcome {
        case downloaded(LevelPack)
        /// The server answered, and has no such pack (yet).
        case notPublished
        /// No connection, or it dropped.
        case offline
        /// Anything else: a server error, or a file that failed the checks.
        /// Logged; treated like offline, since trying later may work.
        case failed(String)

        /// Short, for the analytics event.
        var label: String {
            switch self {
            case .downloaded: return "ok"
            case .notPublished: return "not_published"
            case .offline: return "offline"
            case .failed: return "failed"
            }
        }
    }

    /// Nil until the content server exists (see docs/LevelDelivery.md):
    /// then every fetch is `notPublished`, so a player out of levels sees
    /// "more soon", not a request to go online that couldn't help.
    static let contentBaseURL: URL? = nil

    /// A pack is about 200 KB (20 KB compressed in transit); this is
    /// generous for a slow connection while not leaving the home screen
    /// saying "loading" for minutes.
    private static let timeout: TimeInterval = 30

    var baseURL: URL? = Self.contentBaseURL
    var session: URLSession = .shared

    func fetch(_ kind: PackKind, language: String, number: Int) async -> Outcome {
        guard let baseURL else { return .notPublished }
        let name = kind.fileName(language: language, number: number)
        let url = baseURL.appending(path: "packs/\(name).json")
        // Straight to the server: a cached "not found" from before the pack
        // was published must not hide it.
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: Self.timeout)

        let reply: (Data, URLResponse)
        do {
            reply = try await session.data(for: request)
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            return .offline
        } catch {
            return .failed(String(describing: error))
        }
        let (data, response) = reply

        guard let http = response as? HTTPURLResponse else { return .failed("Not an HTTP response") }
        switch http.statusCode {
        case 200:
            break
        case 404:
            return .notPublished
        default:
            return .failed("HTTP \(http.statusCode)")
        }

        do {
            let pack = try PackValidation.validated(data, expectedName: name, language: language)
            try DownloadedPacks.save(data, name: name)
            return .downloaded(pack)
        } catch {
            return .failed(String(describing: error))
        }
    }

    /// The URLSession errors that mean "no usable connection" rather than
    /// a problem with the server or the file.
    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
        .dataNotAllowed, .internationalRoamingOff, .callIsActive,
    ]
}
