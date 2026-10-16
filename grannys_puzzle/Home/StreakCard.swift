import SwiftUI

/// Grandma's daily treats: the week's streak as a row of days, and
/// today's jar to collect.
///
/// Collecting puts the jar beside grandma's chair on the home screen,
/// unopened: players can save jars up and open them when they want the
/// help. Opens by itself the first time the app is opened each day while
/// today's jar is waiting (see HomeView), and from the calendar button.
struct StreakCard: View {
    /// The day to show as today's: the one about to be collected, or the
    /// one already collected today. 1…`length`.
    let day: Int
    /// Today's jar is already collected.
    let isCollected: Bool
    /// Days in a cycle; the last one holds the big treat.
    let length: Int
    let onCollect: () -> Void
    let onClose: () -> Void

    var body: some View {
        GameCard(title: "Daily treats", onClose: onClose) {
            VStack(spacing: 16) {
                Text("Collect a jar every day and open it whenever you like. The last day holds a big treat!")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                days

                if isCollected {
                    Text("Come back tomorrow for day \(nextDay).")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .frame(height: 50)
                } else {
                    PrimaryButton(title: "Collect jar", height: 50, action: onCollect)
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: isCollected)
    }

    private var nextDay: Int { day >= length ? 1 : day + 1 }

    /// Four days to a row, the last day spanning what's left of its row,
    /// so the big one stands out (with 7 days: 1–4, then 5, 6 and a wide 7).
    private var days: some View {
        let perRow = 4
        let ordinary = Array(1..<max(length, 1))
        var rows = stride(from: 0, to: ordinary.count, by: perRow).map { Array(ordinary[$0..<min($0 + perRow, ordinary.count)]) }
        if rows.last.map({ $0.count == perRow }) ?? true { rows.append([]) }
        let lastSpan = perRow - (rows.last?.count ?? 0)

        return Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(rows.indices, id: \.self) { row in
                GridRow {
                    ForEach(rows[row], id: \.self) { tile(for: $0) }
                    if row == rows.count - 1 {
                        tile(for: length).gridCellColumns(lastSpan)
                    }
                }
            }
        }
    }

    private func tile(for index: Int) -> some View {
        DayTile(
            index: index,
            state: state(of: index),
            isBigTreat: index == length
        )
    }

    private func state(of index: Int) -> DayTile.State {
        if index < day || (index == day && isCollected) { return .collected }
        if index == day { return .today }
        return .later
    }
}

/// One day of the streak.
private struct DayTile: View {
    enum State {
        case collected
        case today
        case later
    }

    let index: Int
    let state: State
    /// The last day: wider, with the big treat's label.
    let isBigTreat: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("Day \(index)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(state == .later ? Theme.quietInk : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            ZStack {
                Image("jar")
                    .resizable()
                    .scaledToFit()
                    .frame(height: isBigTreat ? 34 : 28)
                    .saturation(state == .later ? 0.2 : 1)
                    .opacity(state == .later ? 0.5 : 1)
                if state == .collected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Theme.onPrimary, Theme.switchOn)
                        .offset(x: 12, y: 10)
                }
            }
            .frame(height: 34)
            if isBigTreat {
                Text("Big treat")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .background(RoundedRectangle(cornerRadius: 14).fill(state == .today ? Theme.surface : Theme.clueCell.opacity(0.6)))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(state == .today ? Theme.primary : Theme.cellBorder, lineWidth: state == .today ? 2 : 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Day \(index)"))
        .accessibilityValue(accessibilityState)
    }

    private var accessibilityState: Text {
        switch state {
        case .collected: Text("Collected")
        case .today: Text("Today")
        case .later: isBigTreat ? Text("Big treat") : Text("")
        }
    }
}

#Preview {
    StreakCard(day: 3, isCollected: false, length: 7, onCollect: {}, onClose: {})
}
