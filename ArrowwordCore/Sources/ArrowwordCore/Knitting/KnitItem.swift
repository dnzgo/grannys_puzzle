/// Who grandma is knitting for. Each member has a wardrobe of their own,
/// knitted one member at a time. The grandson and granddaughter come later.
///
/// Raw values are saved inside item ids, so they must never change.
public enum FamilyMember: String, Codable, CaseIterable, Sendable {
    case cat
}

/// A kind of knitted piece.
///
/// Raw values are saved inside item ids, so they must never change.
public enum GarmentKind: String, Codable, CaseIterable, Sendable {
    case scarf
    case hat
    case sweater
    case mittens
    case blanket
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
