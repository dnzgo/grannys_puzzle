import SwiftUI
import ArrowwordCore

/// Shown in place of the letter tray after submitting: the yarn earned, a
/// title and the score. Wrong letters are marked red on the grid above it.
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

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text(detail)
                .font(.system(size: 14))
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
    }

    private var title: LocalizedStringKey {
        guard result.passed else { return "Not quite" }
        switch result.yarnBalls {
        case 3: return "Perfect!"
        case 2: return "Great job"
        default: return "Well done"
        }
    }

    private var detail: String {
        let percent = Int((result.share * 100).rounded())
        return "\(percent)% correct · \(result.correctLetters) of \(result.judgedLetters) letters"
    }

    private var yarnLabel: Text {
        guard !earnedYarn.isEmpty else { return Text("No yarn this time") }
        // "2 yarn balls: red, blue" for VoiceOver.
        let names = earnedYarn.map(\.name).joined(separator: ", ")
        return Text("\(earnedYarn.count) yarn balls: \(names)")
    }
}
