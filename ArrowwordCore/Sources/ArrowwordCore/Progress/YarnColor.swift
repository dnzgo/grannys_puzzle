/// A colour of yarn the player collects.
///
/// Each family member's wardrobe uses four of these (KnittingCatalog):
/// the cat's are the first four, and each later wardrobe keeps two colours
/// from the one before and brings new ones, so yarn left over from one
/// wardrobe is still useful in the next.
///
/// The raw value is what gets saved, so it must never change once shipped:
/// renaming `red` would make every saved red ball disappear. Adding a new
/// case is safe.
///
/// `CodingKeyRepresentable` lets `[YarnColor: Int]` save as a readable JSON
/// object (`{"red": 3}`) instead of Swift's default for enum-keyed
/// dictionaries, a flat array (`["red", 3]`).
public enum YarnColor: String, Codable, CaseIterable, Sendable, CodingKeyRepresentable {
    case red
    case blue
    case yellow
    case green
    case pink
    case purple
    case navy
    case orange
    case teal
    case brown
}
