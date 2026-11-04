import SwiftUI
import ArrowwordCore

/// The home screen's way into the daily puzzle, under the level button,
/// with a small tab hanging under it counting down to the next puzzle.
/// Once today's is submitted the button is dimmed and disabled, and the
/// tab says how long until it's back. Before the daily's first day it's
/// dimmed and disabled too, and says "soon".
///
/// It ticks once a second and works out the day on each tick, so at
/// midnight UTC it turns into the new day's button by itself, without the
/// home screen having to notice.
struct DailyPuzzleButton: View {
    /// Where the player stands with a day's puzzle (a DailyDay number).
    let status: (Int) -> DailyStatus
    /// Whether the daily challenge has begun on a day (a DailyDay number).
    let isOpen: (Int) -> Bool
    let height: CGFloat
    /// Held off while something else is happening (a jar opening).
    let isHeld: Bool
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let today = DailyDay.number(for: context.date)
            let secondsLeft = Int(DailyDay.end(of: today).timeIntervalSince(context.date).rounded(.up))
            content(state: Self.state(isOpen: isOpen(today), status: status(today)), secondsLeft: secondsLeft)
        }
    }

    /// What the button shows. Only `.playable` can be tapped.
    private enum ButtonState {
        /// Before the daily's first day.
        case soon
        case playable
        /// Today's is submitted.
        case done
    }

    private static func state(isOpen: Bool, status: DailyStatus) -> ButtonState {
        guard isOpen else { return .soon }
        if case .done = status { return .done }
        return .playable
    }

    private func content(state: ButtonState, secondsLeft: Int) -> some View {
        let isPlayable = state == .playable
        return VStack(spacing: 0) {
            HomeButton(title: Self.title(for: state), accent: Theme.daily, height: height) {
                guard isPlayable, !isHeld else { return }
                action()
            }
            // Not `.disabled`: a disabled button is dimmed again by iOS on top
            // of our fade, and it would no longer match the tab.
            // Taps are turned off instead, and the fade is ours alone.
            .allowsHitTesting(isPlayable && !isHeld)
            // Done for today, or not started yet: still there, so the player
            // knows it's coming, but plainly not to be tapped.
            .opacity(Self.opacity(isDimmed: !isPlayable))
            countdownTab(secondsLeft: secondsLeft, isDimmed: !isPlayable)
                // Before the first day the countdown to tonight's midnight
                // would mean nothing. Hidden, not removed, so the buttons
                // don't move up and then down again when it starts.
                .opacity(state == .soon ? 0 : 1)
                .accessibilityHidden(state == .soon)
        }
    }

    private static func title(for state: ButtonState) -> LocalizedStringKey {
        switch state {
        case .soon: "Daily challenge soon"
        case .playable: "Daily challenge"
        case .done: "Daily challenge done"
        }
    }

    /// Flat on top and tucked under the button, rounded below, like a tab.
    /// Its fill is the button's colour, faded by the same amount
    /// when done, so the two always match; its time stays solid bone, like the label:
    /// still worth reading, since it says when the next puzzle comes.
    private func countdownTab(secondsLeft: Int, isDimmed: Bool) -> some View {
        let clock = DailyFormat.clock(seconds: secondsLeft)
        return HStack(spacing: 5) {
            Image(systemName: "stopwatch.fill")
            Text(verbatim: clock)
        }
        .font(.system(size: 15, weight: .heavy, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(Theme.background)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            UnevenRoundedRectangle(bottomLeadingRadius: 12, bottomTrailingRadius: 12)
                .fill(Theme.daily.opacity(Self.opacity(isDimmed: isDimmed)))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Time left"))
        .accessibilityValue(Text(verbatim: clock))
    }

    private static func opacity(isDimmed: Bool) -> Double { isDimmed ? 0.5 : 1 }
}

#Preview {
    VStack(spacing: 30) {
        DailyPuzzleButton(status: { _ in .notStarted }, isOpen: { _ in false }, height: 54, isHeld: false, action: {})
        DailyPuzzleButton(status: { _ in .notStarted }, isOpen: { _ in true }, height: 54, isHeld: false, action: {})
        DailyPuzzleButton(
            status: { _ in .done(DailyResult(correctLetters: 46, judgedLetters: 50, seconds: 252)) },
            isOpen: { _ in true },
            height: 54,
            isHeld: false,
            action: {}
        )
    }
    .padding(60)
    .background(Theme.background)
}
