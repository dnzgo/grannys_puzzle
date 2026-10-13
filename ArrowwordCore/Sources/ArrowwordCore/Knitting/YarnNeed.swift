/// The yarn a player is closest to needing: the colour of the item they're
/// nearest to affording, and how many balls short they are.
public struct YarnNeed: Equatable, Sendable {
    public let item: KnitItem
    public let missing: Int

    public var color: YarnColor { item.color }
}

extension PlayerProgress {
    /// What grandma is short of for her next piece: among items not knitted
    /// yet that the player can't afford, the one missing the fewest balls
    /// (the cheaper one when two are equally close).
    ///
    /// Nearest, not simply the next in the list, so a reminder that asks
    /// for yarn points at something the player could finish soon. Nil when
    /// they can already afford something (that's a different, happier
    /// reminder) or the wardrobe is complete.
    public func closestYarnNeed(in catalog: KnittingCatalog) -> YarnNeed? {
        let notOwned = catalog.items.filter { !owns($0) }
        guard !notOwned.isEmpty, !notOwned.contains(where: canKnit) else { return nil }
        return notOwned
            .map { YarnNeed(item: $0, missing: $0.cost - yarnCount(of: $0.color)) }
            // Catalog order breaks ties: it's cheapest first.
            .min { $0.missing < $1.missing }
    }
}
