/// The rules that tie levels to the knitting collection: noticing when a
/// level's yarn makes something new affordable, and rewarding a finished set.
///
/// A finished set's jar waits in the wardrobe until the player collects it,
/// rather than arriving with the knit: the wardrobe then has something to
/// come back for, and collecting it is a moment of its own.

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

    /// What the player can knit right now, in catalog order (cheapest first).
    public func knittableItems(for progress: PlayerProgress) -> [KnitItem] {
        items.filter(progress.canKnit)
    }

    /// A member's sets, one per garment, each in its colours' order, in
    /// catalog order (cheapest garment first).
    public func sets(for member: FamilyMember) -> [[KnitItem]] {
        var order: [String] = []
        var bySet: [String: [KnitItem]] = [:]
        for item in items(for: member) {
            if bySet[item.setID] == nil { order.append(item.setID) }
            bySet[item.setID, default: []].append(item)
        }
        return order.compactMap { bySet[$0] }
    }
}

extension PlayerProgress {
    /// Whether `item`'s set is finished and its jar not collected yet.
    public func hasSetJarWaiting(for item: KnitItem, in catalog: KnittingCatalog) -> Bool {
        !collectedSetJars.contains(item.setID) && catalog.isSetComplete(for: item, in: self)
    }

    /// Collects the jar for `item`'s finished set: it joins the unopened
    /// jars, and the set is marked so it can't be collected again. Nil when
    /// the set isn't finished or its jar was already collected.
    @discardableResult
    public mutating func collectSetJar(for item: KnitItem, in catalog: KnittingCatalog, reward: JarReward) -> Jar? {
        guard hasSetJarWaiting(for: item, in: catalog) else { return nil }
        collectedSetJars.insert(item.setID)
        let jar = Jar(reward: reward, source: .setComplete)
        jars.append(jar)
        return jar
    }

    /// Adds a jar's worth of helpers (the daily jar, or a set prize).
    public mutating func receive(_ reward: JarReward) {
        hints += reward.hints
        grandmas += reward.grandmas
    }
}
