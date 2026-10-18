import SwiftUI
import ArrowwordCore

/// The home screen's way into the daily puzzle, under the level button,
/// with a small tab hanging under it counting down to the next puzzle.
/// Once today's is submitted the button is dimmed and disabled, and the
/// tab says how long until it's back.
///
/// It ticks once a second and works out the day on each tick, so at
/// midnight UTC it turns into the new day's button by itself, without the
/// home screen having to notice.
struct DailyPuzzleButton: View {
    /// Where the player stands with a day's puzzle (a DailyDay number).
    let status: (Int) -> DailyStatus
    let height: CGFloat
    /// Held off while something else is happening (a jar opening).
    let isHeld: Bool
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let today = DailyDay.number(for: context.date)
            let secondsLeft = Int(DailyDay.end(of: today).timeIntervalSince(context.date).rounded(.up))
            content(isDone: Self.isDone(status(today)), secondsLeft: secondsLeft)
        }
    }

    private func content(isDone: Bool, secondsLeft: Int) -> some View {
        VStack(spacing: 0) {
            SecondaryButton(title: isDone ? "Daily puzzle done" : "Daily puzzle", height: height, action: action)
                .disabled(isDone || isHeld)
                // Done for today: still there, so the player knows it'll be
                // back, but plainly not to be tapped.
                .opacity(isDone ? 0.5 : 1)
            countdownTab(secondsLeft: secondsLeft)
        }
    }

    /// Flat on top and tucked under the button, rounded below, like a tab.
    private func countdownTab(secondsLeft: Int) -> some View {
        let clock = DailyFormat.clock(seconds: secondsLeft)
        return HStack(spacing: 5) {
            Image(systemName: "stopwatch.fill")
            Text(verbatim: clock)
        }
        .font(.system(size: 15, weight: .heavy, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(Theme.onPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            UnevenRoundedRectangle(bottomLeadingRadius: 12, bottomTrailingRadius: 12)
                .fill(Theme.secondary)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Time left"))
        .accessibilityValue(Text(verbatim: clock))
    }

    private static func isDone(_ status: DailyStatus) -> Bool {
        if case .done = status { return true }
        return false
    }
}

#Preview {
    VStack(spacing: 30) {
        DailyPuzzleButton(status: { _ in .notStarted }, height: 54, isHeld: false, action: {})
        DailyPuzzleButton(
            status: { _ in .done(DailyResult(correctLetters: 46, judgedLetters: 50, seconds: 252)) },
            height: 54,
            isHeld: false,
            action: {}
        )
    }
    .padding(60)
    .background(Theme.background)
}
