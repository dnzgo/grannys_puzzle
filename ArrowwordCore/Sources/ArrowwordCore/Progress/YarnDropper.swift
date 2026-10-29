/// Picks the colours of the yarn balls a level awards.
///
/// Purely random colours would sometimes starve a player of one colour for a
/// long time, the classic collection-game frustration of waiting for the one
/// piece you're missing. So the draw is weighted: each colour's chance is
/// proportional to `1 / (1 + balls already owned)`, which makes the colour you
/// have least of the most likely. It still feels random, but nobody gets stuck.
///
/// The colours are the current wardrobe's (KnittingCatalog.yarnColors), so
/// a player is never given yarn nobody in the family needs yet.
public struct YarnDropper: Sendable {
    /// The colours that can drop.
    public var colors: [YarnColor]

    public init(colors: [YarnColor] = YarnColor.allCases) {
        precondition(!colors.isEmpty, "A dropper needs at least one colour")
        self.colors = colors
    }

    /// Draws `count` balls for a player whose bag currently holds `bag`.
    ///
    /// The generator is passed in rather than created here so tests can use a
    /// seeded one and get the same "random" colours every run.
    public func draw<Generator: RandomNumberGenerator>(
        _ count: Int,
        given bag: [YarnColor: Int],
        using generator: inout Generator
    ) -> [YarnColor] {
        // Counts include the balls drawn so far, so a 3-ball reward tends to
        // spread across colours instead of repeating one.
        var counts = bag
        var drawn: [YarnColor] = []
        for _ in 0..<max(0, count) {
            let color = pick(given: counts, using: &generator)
            drawn.append(color)
            counts[color, default: 0] += 1
        }
        return drawn
    }

    /// The chance weight of each colour, in `colors` order. Exposed for tests
    /// and for tuning: it shows the rule without any randomness involved.
    public func weights(given bag: [YarnColor: Int]) -> [Double] {
        colors.map { 1 / Double(1 + max(0, bag[$0, default: 0])) }
    }

    private func pick<Generator: RandomNumberGenerator>(
        given counts: [YarnColor: Int],
        using generator: inout Generator
    ) -> YarnColor {
        let weights = self.weights(given: counts)
        // Roll a point on a line made of one segment per colour, each as long
        // as its weight; the segment the point lands in is the colour.
        var roll = Double.random(in: 0..<weights.reduce(0, +), using: &generator)
        for (color, weight) in zip(colors, weights) {
            if roll < weight { return color }
            roll -= weight
        }
        // Floating-point rounding can leave the roll a hair past the end.
        return colors[colors.count - 1]
    }
}
