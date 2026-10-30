import SwiftUI
import ArrowwordCore

/// After the daily puzzle's board is judged: the leaderboard score, big,
/// with how it was made (how correct, how quick) under it, on the same
/// panel as the level endings, with the cat peeking over the top.
///
/// The score is the biggest thing because it's what the leaderboard ranks;
/// the percentage and the time are its ingredients. It's shown being added
/// up: the correctness points count up, then the speed bonus joins them,
/// then the total lands. A bare "12,350" would mean nothing to a player;
/// watching it built from the two things they did makes it clear how to
/// beat it tomorrow.
struct DailyResultCard: View {
    let result: DailyResult
    let onHome: () -> Void

    /// How far the adding-up has got. Each step animates its own number.
    private enum Step: Int, Comparable {
        case start, correctness, speed, total
        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    @State private var step = Step.start
    /// The leaderboard button was tapped without Game Center: says why
    /// nothing opened.
    @State private var needsGameCenter = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Nil in previews.
    @Environment(GameCenter.self) private var gameCenter: GameCenter?

    private static let countDuration = 0.8
    private static let pauseBetween = 0.25

    private var score: DailyScore { result.score }

    /// The score so far in the adding-up: the correctness, then with the
    /// speed bonus on top.
    private var shownScore: Int {
        (step >= .correctness ? score.correctness : 0) + (step >= .speed ? score.speedBonus : 0)
    }

    var body: some View {
        LevelEndPanel(peek: "cat-peek") {
            Text("Daily challenge")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.secondaryInk)
                .accessibilityAddTraits(.isHeader)

            scoreHero

            // Smaller than the score: they're what it was made of.
            HStack(spacing: 10) {
                stat(
                    value: "\(result.percent)%",
                    label: "correct",
                    points: step >= .correctness ? score.correctness : 0
                )
                stat(
                    value: DailyFormat.clock(seconds: result.seconds),
                    label: "time",
                    points: step >= .speed ? score.speedBonus : 0
                )
            }

            NextChallengeCountdown()
                .padding(.top, 2)

            VStack(spacing: 10) {
                PrimaryButton(title: "Home", height: 54, action: onHome)
                SecondaryButton(title: "Leaderboard", height: 54, action: openLeaderboard)
                if needsGameCenter {
                    Text("Sign in to Game Center in your phone's Settings app to see the leaderboard.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: needsGameCenter)
        .task { await countUp() }
    }

    // MARK: - The score

    /// The total, big, counting up as it's added together, with a small
    /// bounce as it lands.
    private var scoreHero: some View {
        VStack(spacing: 0) {
            CountingNumber(value: Double(shownScore))
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .scaleEffect(step == .total ? 1 : 0.92)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.5), value: step)
            Text("points")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.secondaryInk)
        }
        // Read as one sentence with the final numbers, not the counting.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Score \(score.total): \(score.correctness) for correct letters, \(score.speedBonus) speed bonus"))
    }

    /// One ingredient of the score: what the player did (55%, 0:33) and
    /// the points it brought, which appear as their step of the adding-up
    /// comes.
    private func stat(value: String, label: LocalizedStringKey, points: Int) -> some View {
        VStack(spacing: 0) {
            Text(verbatim: value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.secondaryInk)
            CountingNumber(value: Double(points), prefix: "+")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primary)
                .opacity(points > 0 ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        // The card's total already says the points; these say what was done.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: value))
        .accessibilityValue(Text(label))
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

    private func openLeaderboard() {
        needsGameCenter = gameCenter?.showLeaderboards() != true
    }
}

/// "Next challenge in 9 h 22 min": the time until the daily changes, which
/// is midnight UTC for everyone (DailyDay), not the player's midnight. So
/// it's exact wherever they are, where "Tomorrow!" was often a few hours
/// off. Rechecked every half minute; minutes are all it shows.
private struct NextChallengeCountdown: View {
    @Environment(\.locale) private var locale

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let end = DailyDay.end(of: DailyDay.number(for: context.date))
            // Rounded up, so the last minute reads "1 min", never "0 min".
            let minutes = max(1, Int((end.timeIntervalSince(context.date) / 60).rounded(.up)))
            let remaining = Duration.seconds(minutes * 60)
                .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
            Text("Next challenge in \(remaining)")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
        }
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
