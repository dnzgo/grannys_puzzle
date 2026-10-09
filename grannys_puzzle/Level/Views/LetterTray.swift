import SwiftUI

/// One key per distinct letter, with how many are left. Keys keep their place
/// (alphabet order) even when used up, so nothing moves under the thumb.
struct LetterTray: View {
    let model: LevelViewModel
    let keyHeight: CGFloat

    /// 8 columns × 2 rows: the reason a level allows at most 16 distinct letters.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)

    var body: some View {
        LazyVGrid(columns: columns, spacing: BoardMetrics.trayRowSpacing) {
            ForEach(model.trayKeys) { key in
                Button { model.type(key.letter) } label: {
                    keyLabel(key)
                }
                .buttonStyle(.plain)
                .disabled(key.isUsedUp)
                .accessibilityLabel(String(key.letter))
                .accessibilityValue("\(key.remaining) left")
            }
        }
    }

    private func keyLabel(_ key: TrayKey) -> some View {
        Text(String(key.letter))
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(key.isUsedUp ? Theme.usedUpKey : Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: keyHeight)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(key.isUsedUp ? Color.clear : Theme.surface)
                    .shadow(color: .black.opacity(key.isUsedUp ? 0 : 0.06), radius: 2, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(key.isUsedUp ? Theme.usedUpBorder : Theme.cellBorder, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Text("\(key.remaining)")
                    .font(.system(size: 9, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(key.isUsedUp ? Theme.usedUpKey : Theme.secondaryInk)
                    .padding(.top, 2)
                    .padding(.trailing, 4)
            }
            .contentShape(Rectangle())
    }
}
