/// Picks which of several lines to use next, so they feel varied.
///
/// Plain random picking repeats itself more than people expect: with four
/// lines, the same one comes up twice in a row a quarter of the time, and
/// that's exactly what makes a reminder feel robotic. A shuffle bag works
/// like a deck of cards: every line is dealt once, in random order, before
/// the deck is reshuffled. It also never deals the last card of one deck
/// first in the next, so the same line can't appear back to back even
/// across a reshuffle.
///
/// A value type that saves as JSON, so the order survives app restarts:
/// otherwise every launch would start a fresh deck and the first lines
/// would come up far more often than the rest.
public struct ShuffleBag: Codable, Equatable, Sendable {
    /// How many lines the bag deals from.
    public private(set) var count: Int
    /// Indices still to deal in this round, next one last.
    private var remaining: [Int]
    /// The index dealt most recently.
    private var last: Int?

    public init(count: Int) {
        self.count = max(0, count)
        remaining = []
        last = nil
    }

    /// The next index, from 0 up to `count - 1`. With 0 lines there's
    /// nothing to deal, so it returns nil.
    public mutating func next<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Int? {
        guard count > 0 else { return nil }
        if remaining.isEmpty {
            refill(using: &generator)
        }
        let index = remaining.removeLast()
        last = index
        return index
    }

    /// A bag for a list whose length may have changed since this one was
    /// saved (a line added in an update): a fresh deck for the new length.
    public func resized(to newCount: Int) -> ShuffleBag {
        newCount == count ? self : ShuffleBag(count: newCount)
    }

    private mutating func refill<Generator: RandomNumberGenerator>(using generator: inout Generator) {
        remaining = Array(0..<count).shuffled(using: &generator)
        // Dealt from the end: if the new deck would open with the line just
        // used, swap it to the bottom.
        if count > 1, remaining.last == last {
            remaining.swapAt(0, remaining.count - 1)
        }
    }
}
