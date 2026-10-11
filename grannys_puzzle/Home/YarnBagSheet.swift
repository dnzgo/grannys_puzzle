import SwiftUI
import ArrowwordCore

/// Grandma's yarn bag: the yarn the player owns, and what she can knit
/// with it. Tapping an item the player can afford starts knitting.
///
/// The first of the two collections; the second, the wardrobe, is its own
/// sheet.
struct YarnBagSheet: View {
    let progress: PlayerProgress
    let catalog: KnittingCatalog
    /// Called with the item to knit. The sheet closes first, so the
    /// knitting moment plays on the home screen behind it.
    let onKnit: (KnitItem) -> Void

    @Environment(\.dismiss) private var dismiss

    private let yarnColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Granny's yarn bag")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
                }

                LazyVGrid(columns: yarnColumns, spacing: 12) {
                    ForEach(YarnColor.allCases, id: \.self) { color in
                        YarnCountCard(color: color, count: progress.yarnCount(of: color))
                    }
                }

                Text("Knit for the cat")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 4)

                ForEach(GarmentKind.allCases, id: \.self) { kind in
                    GarmentRow(
                        kind: kind,
                        items: catalog.items(for: .cat).filter { $0.kind == kind },
                        progress: progress,
                        onKnit: knit
                    )
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func knit(_ item: KnitItem) {
        dismiss()
        onKnit(item)
    }
}

/// One colour in the bag: the ball, its name and the count.
private struct YarnCountCard: View {
    let color: YarnColor
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            YarnBall(color: count > 0 ? color : nil, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(color.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("× \(count)")
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryInk)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(color.name)
        .accessibilityValue("\(count)")
    }
}

/// A garment in its four colours, with the price.
private struct GarmentRow: View {
    let kind: GarmentKind
    let items: [KnitItem]
    let progress: PlayerProgress
    let onKnit: (KnitItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(kind.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if let cost = items.first?.cost {
                    Text("· \(cost) yarn each")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
            HStack(spacing: 10) {
                ForEach(items) { item in
                    KnitChoice(item: item, progress: progress) { onKnit(item) }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
    }
}

/// One item: knitted (with a tick), ready to knit (tappable, outlined), or
/// not affordable yet (pale, showing yarn owned of yarn needed).
private struct KnitChoice: View {
    let item: KnitItem
    let progress: PlayerProgress
    let action: () -> Void

    private var owned: Bool { progress.owns(item) }
    private var affordable: Bool { progress.canKnit(item) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                GarmentView(kind: item.kind, color: item.color, size: 54, isOwned: owned || affordable)
                    .opacity(owned || affordable ? 1 : 0.6)
                    .overlay {
                        if affordable {
                            RoundedRectangle(cornerRadius: 54 * 0.24)
                                .strokeBorder(Theme.primary, lineWidth: 3)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if owned {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.onPrimary, Theme.ink)
                                .offset(x: 6, y: -6)
                        }
                    }
                Text(caption)
                    .font(.system(size: 12, weight: affordable ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(affordable ? Theme.primary : Theme.secondaryInk)
            }
        }
        .buttonStyle(.plain)
        .disabled(!affordable)
        .accessibilityLabel(item.displayName)
        .accessibilityValue(accessibilityState)
        .accessibilityHint(affordable ? Text("Knits it") : Text(""))
    }

    private var caption: String {
        if owned { return String(localized: "Knitted") }
        if affordable { return String(localized: "Knit!") }
        return "\(progress.yarnCount(of: item.color))/\(item.cost)"
    }

    private var accessibilityState: Text {
        if owned { return Text("Knitted") }
        if affordable { return Text("Ready to knit") }
        return Text("\(progress.yarnCount(of: item.color)) of \(item.cost) yarn")
    }
}

#Preview {
    YarnBagSheet(
        progress: PlayerProgress(levelNumber: 9, hints: 2, grandmas: 1, yarn: [.red: 7, .blue: 3, .green: 9],
                                 wardrobe: ["cat.scarf.yellow"]),
        catalog: .standard,
        onKnit: { _ in }
    )
}
