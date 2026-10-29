/// How the family's wardrobes follow one another: grandma knits for one
/// member at a time, and the next member's wardrobe opens when every item
/// in the current one is knitted.
///
/// Worked out from what the player owns rather than saved, so there is
/// nothing extra to keep in step: a save from before the family existed
/// simply has the cat as its current member.

/// Where a member's wardrobe stands for a player.
public enum WardrobeStatus: Equatable, Sendable {
    /// Every item knitted.
    case complete
    /// The wardrobe being knitted now.
    case current
    /// Not reached yet: an earlier wardrobe isn't complete.
    case locked
}

extension KnittingCatalog {
    /// The members who have a wardrobe, in knitting order.
    public var members: [FamilyMember] {
        FamilyMember.allCases.filter { member in items.contains { $0.member == member } }
    }

    public func isWardrobeComplete(_ member: FamilyMember, in progress: PlayerProgress) -> Bool {
        items(for: member).allSatisfy(progress.owns)
    }

    /// The member grandma is knitting for: the first whose wardrobe isn't
    /// complete. Nil once every wardrobe is.
    public func currentMember(for progress: PlayerProgress) -> FamilyMember? {
        members.first { !isWardrobeComplete($0, in: progress) }
    }

    public func status(of member: FamilyMember, for progress: PlayerProgress) -> WardrobeStatus {
        if isWardrobeComplete(member, in: progress) { return .complete }
        return member == currentMember(for: progress) ? .current : .locked
    }

    /// The items the player may knit towards: the current wardrobe's. (A
    /// complete wardrobe's items are all owned; a locked one's wait.)
    public func availableItems(for progress: PlayerProgress) -> [KnitItem] {
        guard let member = currentMember(for: progress) else { return [] }
        return items(for: member)
    }

    /// A member's yarn colours, in their wardrobe's order.
    public func colors(for member: FamilyMember) -> [YarnColor] {
        var colors: [YarnColor] = []
        for item in items(for: member) where !colors.contains(item.color) {
            colors.append(item.color)
        }
        return colors
    }

    /// The colours levels should drop: the current wardrobe's. Once every
    /// wardrobe is done, the last one's, so levels still give yarn.
    public func yarnColors(for progress: PlayerProgress) -> [YarnColor] {
        guard let member = currentMember(for: progress) ?? members.last else { return YarnColor.allCases }
        return colors(for: member)
    }
}
