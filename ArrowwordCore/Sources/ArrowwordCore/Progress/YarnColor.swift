/// A colour of yarn the player collects.
///
/// The four starting colours match the cat's wardrobe (5 items × 4 colours).
/// More colours arrive with the next family members.
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
}
