/// Who grandma is knitting for. Each member has a wardrobe of their own,
/// knitted one member at a time, in this order: the next one's wardrobe
/// opens when the previous one is complete (KnittingCatalog.currentMember).
///
/// Raw values are saved inside item ids, so they must never change. New
/// members go at the end, so existing players keep their place.
public enum FamilyMember: String, Codable, CaseIterable, Sendable {
    case cat
    case daughter
    case son
    case granddaughter
    case grandson
}

/// A kind of knitted piece.
///
/// Raw values are saved inside item ids, so they must never change.
/// Kinds are shared between members where the garment is the same idea
/// (the cat's scarf and the son's scarf are both `scarf`); the art differs
/// per member (GarmentView looks it up by member and kind).
public enum GarmentKind: String, Codable, CaseIterable, Sendable {
    // The cat's
    case scarf
    case hat
    case sweater
    /// The cat's: a set of four, one per paw. (Mittens before release;
    /// renamed while no save could hold the old ids yet.)
    case booties
    case blanket
    // The daughter's
    case beret
    case handwarmers
    case legwarmers
    case shawl
    case cardigan
    // The son's (and his scarf)
    case beanie
    case gloves
    case socks
    case vest
    // The granddaughter's
    case headband
    case mittens
    case earflaphat
    case bunny
    case pinafore
    // The grandson's (and his mittens and sweater)
    case slippers
    case dinohat
    case teddy
}

/// One item grandma can knit: a garment, for a family member, in one colour.
///
/// Items are data, not code: a new colour or member adds rows to the
/// catalogue, and the same item art is tinted per colour.
public struct KnitItem: Hashable, Identifiable, Sendable {
    public let member: FamilyMember
    public let kind: GarmentKind
    public let color: YarnColor
    /// Yarn balls of `color` it takes to knit.
    public let cost: Int

    public init(member: FamilyMember, kind: GarmentKind, color: YarnColor, cost: Int) {
        self.member = member
        self.kind = kind
        self.color = color
        self.cost = cost
    }

    /// A stable id such as "cat.scarf.red". It's what the wardrobe saves, so
    /// re-pricing an item later never affects who already owns it.
    public var id: String {
        "\(member.rawValue).\(kind.rawValue).\(color.rawValue)"
    }

    /// The set it belongs to, such as "cat.scarf": the same garment for the
    /// same member in every colour. Saved when a set's jar is collected.
    public var setID: String {
        "\(member.rawValue).\(kind.rawValue)"
    }
}
