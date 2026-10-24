import Foundation

/// The two kinds of pack, which are numbered and fetched the same way but
/// are separate lists: the levels the Play button walks through, and the
/// daily puzzles, one per day.
enum PackKind: String {
    case levels
    case daily

    /// A pack's file name without ".json", the same in the app bundle, on
    /// the content server and on the phone: "en-002" (levels 101–200) or
    /// "daily-en-002" (dailies 101–200). Three digits, padded, so files
    /// sort in play order wherever they're listed.
    func fileName(language: String, number: Int) -> String {
        let padded = String(format: "%03d", number)
        switch self {
        case .levels: return "\(language)-\(padded)"
        case .daily: return "daily-\(language)-\(padded)"
        }
    }
}
