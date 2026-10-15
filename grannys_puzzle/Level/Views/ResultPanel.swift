import SwiftUI
import ArrowwordCore

/// Shown in place of the letter tray after submitting: the yarn earned, a
/// title and the score. Wrong letters are marked red on the grid above it.
/// The level-end card (LevelCompleteView or LevelFailView) sits on top,
/// with this under the dimming, so the board doesn't jump as the card goes.
struct ResultPanel: View {
    let result: LevelResult
    /// The balls awarded, in draw order; empty for a fail.
    let earnedYarn: [YarnColor]

    /// Always three slots, so the player sees what a perfect board would earn.
    private let slots = 3

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<slots, id: \.self) { index in
                    YarnBall(color: earnedYarn.indices.contains(index) ? earnedYarn[index] : nil, size: 40)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(yarnLabel)

            Text(result.headline)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text(result.scoreLine)
                .font(.system(size: 14))
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
    }

    private var yarnLabel: Text {
        guard !earnedYarn.isEmpty else { return Text("No yarn this time") }
        // "2 yarn balls: red, blue" for VoiceOver.
        let names = earnedYarn.map(\.name).joined(separator: ", ")
        return Text("\(earnedYarn.count) yarn balls: \(names)")
    }
}

/// The words for a result, shared by the result panel and the celebration.
extension LevelResult {
    var headline: LocalizedStringKey {
        guard passed else { return "Not quite" }
        switch yarnBalls {
        case 3: return "Perfect!"
        case 2: return "Great job"
        default: return "Well done"
        }
    }

    var scoreLine: String {
        // The percentage is formatted for the game's language, which puts
        // the sign in that language's place (Turkish writes it first: %90).
        let percent = share.formatted(.percent.precision(.fractionLength(0)).locale(.appLanguage))
        return String(localized: "\(percent) correct · \(correctLetters) of \(judgedLetters) letters", bundle: .appLanguage, locale: .appLanguage)
    }
}
