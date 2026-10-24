import SwiftUI
import ArrowwordCore

/// The words for a result: the headline and score line on both level-end
/// cards (LevelCompleteView, LevelFailView).
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
        // Rounded down, like the daily's, so only a perfect board says 100%:
        // 99.6% rounded to nearest would read 100% next to "Great job".
        let percent = share.formatted(
            .percent.precision(.fractionLength(0)).rounded(rule: .down).locale(.appLanguage)
        )
        return String(localized: "\(percent) correct", bundle: .appLanguage, locale: .appLanguage)
    }
}
