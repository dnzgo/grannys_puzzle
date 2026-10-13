/// When Apple's rating prompt appears after a happy moment.
enum ReviewTiming {
    /// Long enough to see the result (or grandma's comment) first, short
    /// enough that the good feeling is still there when the prompt asks.
    static let delayAfterHappyMoment: Duration = .seconds(1.5)
}
