import SwiftUI
import ArrowwordCore

/// Shown in place of the letter tray after submitting: stars, a title and
/// the score. Wrong letters are marked red on the grid above it.
struct ResultPanel: View {
    let result: LevelResult

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    let earned = index < result.stars
                    Image(systemName: earned ? "star.fill" : "star")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(earned ? Theme.star : Theme.starOutline)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(result.stars) of 3 stars")

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
        switch result.stars {
        case 3: return "Perfect!"
        case 2: return "Great job"
        default: return "Well done"
        }
    }

    private var detail: String {
        let percent = Int((result.share * 100).rounded())
        return "\(percent)% correct · \(result.correctLetters) of \(result.judgedLetters) letters"
    }
}
