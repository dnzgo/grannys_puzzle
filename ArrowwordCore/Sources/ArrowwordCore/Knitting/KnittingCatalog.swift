/// Every item grandma can knit, in display order.
///
/// Prices live here, in one table, so they can be tuned in one place (and
/// later come from remote config). Cheaper pieces come first so a new player
/// finishes something early. Players earn about 2 yarn balls per level, and
/// the dropper spreads them across colours, so 6 of one colour takes about
/// 21 balls: the first scarf arrives around level 10–12. The cat's whole
/// wardrobe (204 balls) takes roughly 100 levels.
public struct KnittingCatalog: Sendable {
    public let items: [KnitItem]

    public init(items: [KnitItem]) {
        self.items = items
    }

    /// The cat's wardrobe: 5 garments × 4 colours = 20 items.
    public static let standard = KnittingCatalog(items: catItems())

    /// Yarn per garment for the cat, cheapest first.
    static let catPrices: [(GarmentKind, Int)] = [
        (.scarf, 6),
        (.hat, 8),
        (.sweater, 10),
        (.mittens, 12),
        (.blanket, 15),
    ]

    private static func catItems() -> [KnitItem] {
        catPrices.flatMap { kind, cost in
            YarnColor.allCases.map { KnitItem(member: .cat, kind: kind, color: $0, cost: cost) }
        }
    }

    public func items(for member: FamilyMember) -> [KnitItem] {
        items.filter { $0.member == member }
    }

    public func item(withID id: String) -> KnitItem? {
        items.first { $0.id == id }
    }
}
