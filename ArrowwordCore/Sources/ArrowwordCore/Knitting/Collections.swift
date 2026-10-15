/// The rules that tie levels to the knitting collection: noticing when a
/// level's yarn makes something new affordable, and rewarding a finished set.

extension KnittingCatalog {
    /// The first item (cheapest first, as the catalog is ordered) the player
    /// could not afford `before` but can `after`, e.g. before and after a
    /// level's yarn. Nil when nothing new became affordable.
    ///
    /// Only *newly* affordable, so grandma mentions each item once rather
    /// than after every level while it waits to be knitted.
    public func newlyKnittable(before: PlayerProgress, after: PlayerProgress) -> KnitItem? {
        items.first { after.canKnit($0) && !before.canKnit($0) }
    }

    /// The set an item belongs to: the same garment for the same family
    /// member, in every colour (e.g. the cat's four scarves).
    public func itemsInSet(of item: KnitItem) -> [KnitItem] {
        items.filter { $0.member == item.member && $0.kind == item.kind }
    }

    /// Whether the player owns every item in `item`'s set. Checked right
    /// after knitting `item`: a yes means this knit finished the set, which
    /// happens once, since each item is knitted only once.
    public func isSetComplete(for item: KnitItem, in progress: PlayerProgress) -> Bool {
        itemsInSet(of: item).allSatisfy(progress.owns)
    }
}

extension PlayerProgress {
    /// Adds a jar's worth of helpers (the daily jar, or a set prize).
    public mutating func receive(_ reward: JarReward) {
        hints += reward.hints
        grandmas += reward.grandmas
    }
}
