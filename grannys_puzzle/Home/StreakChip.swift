import SwiftUI
import ArrowwordCore

/// The play streak, centred in the home screen's top row: a flame
/// and the days in a row.
///
/// The flame is orange once today is solved and grey while it isn't yet,
/// so a glance says whether today still needs a puzzle to keep it going.
/// A tap has grandma say what it means.
struct StreakChip: View {
    let status: StreakStatus
    let action: () -> Void

    private var isLit: Bool {
        if case .active(_, solvedToday: true) = status { return true }
        return false
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isLit ? Theme.primary : Theme.quietInk)
                Text("\(status.days)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(value: Double(status.days)))
                    .animation(.snappy, value: status.days)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            // The same white as the helpers' card beside it.
            .background(Capsule().fill(Theme.surface).shadow(color: .black.opacity(0.06), radius: 1, y: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Day streak")
        .accessibilityValue("\(status.days)")
    }
}

#Preview {
    HStack {
        StreakChip(status: .active(days: 12, solvedToday: true), action: {})
        StreakChip(status: .active(days: 12, solvedToday: false), action: {})
        StreakChip(status: .none, action: {})
    }
    .padding()
    .background(Theme.background)
}
