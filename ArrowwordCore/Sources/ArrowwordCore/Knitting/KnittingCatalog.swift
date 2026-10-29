/// Every item grandma can knit, in display order: one wardrobe per family
/// member, in the order they're knitted for, cheapest garment first.
///
/// Prices live here, in one table, so they can be tuned in one place (and
/// later come from remote config). Cheaper pieces come first so a new player
/// finishes something early. Players earn about 2 yarn balls per level, and
/// the dropper spreads them across the current wardrobe's colours, so 6 of
/// one colour takes about 21 balls: the first scarf arrives around level
/// 10–12. The cat's whole wardrobe (204 balls) takes roughly 100 levels;
/// each later wardrobe costs 25% more than the one before (`priceStep`),
/// so the five together last roughly 840 levels.
public struct KnittingCatalog: Sendable {
    public let items: [KnitItem]

    public init(items: [KnitItem]) {
        self.items = items
    }

    public static let standard = KnittingCatalog(items: wardrobes.enumerated().flatMap { index, wardrobe in
        wardrobe.items(priceFactor: priceFactor(forWardrobeAt: index))
    })

    /// How much dearer each wardrobe is than the one before.
    static let priceStep = 1.25

    /// Compounding: the cat's is 1, the daughter's 1.25, the son's
    /// 1.25 × 1.25, and so on.
    static func priceFactor(forWardrobeAt index: Int) -> Double {
        (0..<index).reduce(1.0) { factor, _ in factor * priceStep }
    }

    /// The cat's prices, cheapest first. Every wardrobe has five garments,
    /// and its n-th garment costs the n-th of these times its price factor,
    /// so each wardrobe keeps the same gentle rise from first to last piece.
    static let basePrices = [6, 8, 10, 12, 15]

    /// One member's wardrobe: their garments (cheapest first) and colours.
    struct Wardrobe {
        let member: FamilyMember
        let garments: [GarmentKind]
        let colors: [YarnColor]

        func items(priceFactor: Double) -> [KnitItem] {
            zip(garments, KnittingCatalog.basePrices).flatMap { kind, base in
                let cost = Int((Double(base) * priceFactor).rounded())
                return colors.map { KnitItem(member: member, kind: kind, color: $0, cost: cost) }
            }
        }
    }

    /// The family in knitting order. Each wardrobe keeps two colours from
    /// the one before it, so leftover yarn still counts.
    static let wardrobes: [Wardrobe] = [
        Wardrobe(member: .cat, garments: [.scarf, .hat, .sweater, .booties, .blanket],
                 colors: [.red, .blue, .yellow, .green]),
        Wardrobe(member: .daughter, garments: [.beret, .handwarmers, .legwarmers, .shawl, .cardigan],
                 colors: [.yellow, .green, .pink, .purple]),
        Wardrobe(member: .son, garments: [.beanie, .gloves, .socks, .scarf, .vest],
                 colors: [.green, .purple, .navy, .orange]),
        Wardrobe(member: .granddaughter, garments: [.headband, .mittens, .earflaphat, .bunny, .pinafore],
                 colors: [.purple, .orange, .teal, .pink]),
        Wardrobe(member: .grandson, garments: [.mittens, .slippers, .dinohat, .teddy, .sweater],
                 colors: [.teal, .orange, .brown, .yellow]),
    ]

    public func items(for member: FamilyMember) -> [KnitItem] {
        items.filter { $0.member == member }
    }

    public func item(withID id: String) -> KnitItem? {
        items.first { $0.id == id }
    }
}
