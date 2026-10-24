import SwiftUI
import ArrowwordCore

/// After the daily puzzle's board is judged: how correct it was, how long it
/// took, and the leaderboard score, on the same panel as the level endings.
///
/// The score is shown being added up: first the correctness points count
/// up, then the speed bonus, then the total lands. A bare "12,350" would
/// mean nothing to a player; watching it built from the two things they
/// did makes it clear how to beat it tomorrow.
struct DailyResultCard: View {
    let result: DailyResult
    let onHome: () -> Void

    /// How far the adding-up has got. Each step animates its own number.
    private enum Step: Int, Comparable {
        case start, correctness, speed, total
        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    @State private var step = Step.start
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let countDuration = 0.8
    private static let pauseBetween = 0.25

    private var score: DailyScore { result.score }

    var body: some View {
        LevelEndPanel {
            Text("Daily challenge")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 12) {
                stat(value: "\(result.percent)%", label: "correct")
                stat(value: DailyFormat.clock(seconds: result.seconds), label: "time")
            }

            scoreBreakdown

            Text("New challenge tomorrow!")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)

            PrimaryButton(title: "Home", height: 54, action: onHome)
        }
        .task { await countUp() }
    }

    // MARK: - The score

    private var scoreBreakdown: some View {
        VStack(spacing: 8) {
            scoreRow("Correct letters", value: step >= .correctness ? score.correctness : 0)
            scoreRow("Speed bonus", value: step >= .speed ? score.speedBonus : 0, sign: "+")
            Divider().overlay(Theme.clueDivider)
            HStack {
                Text("Score")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                CountingNumber(value: Double(step >= .total ? score.total : 0))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    // A small bounce as the total lands.
                    .scaleEffect(step == .total ? 1 : 0.9)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.5), value: step)
            }
            .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
        // Read as one sentence with the final numbers, not the counting.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Score \(score.total): \(score.correctness) for correct letters, \(score.speedBonus) speed bonus"))
    }

    private func scoreRow(_ label: LocalizedStringKey, value: Int, sign: String = "") -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.secondaryInk)
            Spacer()
            CountingNumber(value: Double(value), prefix: sign)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
        }
    }

    /// Correctness, then speed, then the total, each counting up. With
    /// Reduce Motion everything is simply there.
    private func countUp() async {
        guard !reduceMotion else {
            step = .total
            return
        }
        for next in [Step.correctness, .speed, .total] {
            try? await Task.sleep(for: .seconds(Self.pauseBetween))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: Self.countDuration)) { step = next }
            try? await Task.sleep(for: .seconds(Self.countDuration))
        }
    }

    // MARK: - Stats

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

/// A whole number that counts up (or down) to its value when it changes
/// inside an animation, rather than switching at once.
///
/// It works because the view is `Animatable`: SwiftUI hands it every
/// in-between value of `value` during the animation, and it redraws each
/// one as a whole number. Formatted in the app's language, so thousands
/// get "12,350" in English and "12.350" in Turkish.
private struct CountingNumber: View, Animatable {
    var value: Double
    var prefix = ""

    @Environment(\.locale) private var locale

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(verbatim: prefix + Int(value.rounded()).formatted(.number.locale(locale)))
            .monospacedDigit()
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        DailyResultCard(result: DailyResult(correctLetters: 46, judgedLetters: 50, seconds: 252), onHome: {})
    }
}
