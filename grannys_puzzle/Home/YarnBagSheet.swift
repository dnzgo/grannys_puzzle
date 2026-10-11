import SwiftUI
import ArrowwordCore

/// Grandma's yarn bag: how many balls of each colour the player has.
///
/// The first of the two collections; the wardrobe of knitted clothes comes
/// with the knitting screen.
struct YarnBagSheet: View {
    let progress: PlayerProgress

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Granny's yarn bag")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(YarnColor.allCases, id: \.self) { color in
                    YarnCountCard(color: color, count: progress.yarnCount(of: color))
                }
            }

            Text("Solve puzzles to collect yarn. Soon Granny will knit it into clothes!")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// One colour in the bag: the ball, its name and the count.
private struct YarnCountCard: View {
    let color: YarnColor
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            YarnBall(color: count > 0 ? color : nil, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(color.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("× \(count)")
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryInk)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(color.displayName)
        .accessibilityValue("\(count)")
    }
}

#Preview {
    YarnBagSheet(progress: PlayerProgress(levelNumber: 5, hints: 2, grandmas: 1, yarn: [.red: 4, .blue: 1]))
}
