import SwiftUI
import ArrowwordCore

/// After the daily puzzle's board is judged: how correct it was and how long
/// it took, on the same panel as the level endings.
///
/// The leaderboard position goes under the stats once there is one (the
/// result already knows how to rank: DailyResult.ranks(above:)).
struct DailyResultCard: View {
    let result: DailyResult
    let onHome: () -> Void

    var body: some View {
        LevelEndPanel {
            Text("Daily puzzle")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 12) {
                stat(value: "\(result.percent)%", label: "correct")
                stat(value: DailyFormat.clock(seconds: result.seconds), label: "time")
            }

            Text("\(result.correctLetters) of \(result.judgedLetters) letters right")
                .font(.system(size: 15, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryInk)

            Text("Come back tomorrow for a new puzzle.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)

            PrimaryButton(title: "Home", height: 54, action: onHome)
        }
    }

    /// One big number with its label under it, on a white tile.
    private func stat(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        DailyResultCard(result: DailyResult(correctLetters: 46, judgedLetters: 50, seconds: 252), onHome: {})
    }
}
