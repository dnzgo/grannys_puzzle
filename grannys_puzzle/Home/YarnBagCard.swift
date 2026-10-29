import SwiftUI
import ArrowwordCore

/// Grandma's yarn bag, as one of the game's cards: the yarn the player has,
/// and the one thing to do with it, knitting.
///
/// The card shows only what can be knitted now, one item at a time, rather
/// than the whole catalogue: the bag answers "what can I make?", and the
/// wardrobe is where the whole collection lives. With nothing affordable it
/// shows the item the player is closest to, greyed out, so there's always a
/// goal in view.
struct YarnBagCard: View {
    let progress: PlayerProgress
    let catalog: KnittingCatalog
    /// Called with the item to knit; the home screen closes the card and
    /// plays the knitting moment.
    let onKnit: (KnitItem) -> Void
    let onClose: () -> Void

    /// Which of the knittable items is showing.
    @State private var index = 0

    private var knittable: [KnitItem] { catalog.knittableItems(for: progress) }

    var body: some View {
        GameCard(title: "Granny's yarn bag", onClose: onClose) {
            VStack(spacing: 18) {
                yarnRow
                Rectangle().fill(Theme.clueDivider).frame(height: 1)
                itemSection
            }
        }
    }

    // MARK: Yarn

    /// The current wardrobe's four colours: grey with no count until the
    /// player has some. Only these, not every colour there is: they're the
    /// ones levels drop and the bag can use now. Yarn kept from an earlier
    /// wardrobe stays saved and shows again when a later one uses it.
    private var yarnRow: some View {
        HStack(spacing: 0) {
            ForEach(catalog.yarnColors(for: progress), id: \.self) { color in
                let count = progress.yarnCount(of: color)
                VStack(spacing: 4) {
                    YarnBall(color: count > 0 ? color : nil, size: 50)
                    // Kept in the layout when hidden, so every ball sits at
                    // the same height whether it has a count or not.
                    Text("× \(count)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .opacity(count > 0 ? 1 : 0)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(color.name)
                .accessibilityValue("\(count)")
            }
        }
    }

    // MARK: Item

    @ViewBuilder
    private var itemSection: some View {
        if !knittable.isEmpty {
            knittableItem(knittable[min(index, knittable.count - 1)])
        } else if let need = progress.closestYarnNeed(in: catalog) {
            nearestItem(need.item)
        } else {
            Text("Everything is knitted!")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .frame(height: 120)
        }
    }

    /// An item the player can afford, with arrows to the others and Knit.
    private func knittableItem(_ item: KnitItem) -> some View {
        VStack(spacing: 14) {
            HStack {
                arrow(systemName: "chevron.left", label: "Previous item", step: -1)
                Spacer(minLength: 0)
                GarmentView(item: item, size: 120)
                    // A new item fades in rather than snapping, so the arrows
                    // feel like turning a page.
                    .id(item.id)
                    .transition(.opacity)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                arrow(systemName: "chevron.right", label: "Next item", step: 1)
            }
            itemCaption(item)
            PrimaryButton(title: "Knit!", height: 52) { onKnit(item) }
        }
    }

    /// Nothing affordable: the closest item, greyed out, and how far off it is.
    private func nearestItem(_ item: KnitItem) -> some View {
        VStack(spacing: 14) {
            GarmentView(item: item, size: 120)
                .grayscale(1)
                .opacity(0.6)
                .accessibilityHidden(true)
            itemCaption(item)
            Text("Solve puzzles to collect more yarn.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
                .frame(height: 52)
        }
    }

    /// The item's name, and the yarn it takes against the yarn there is.
    private func itemCaption(_ item: KnitItem) -> some View {
        VStack(spacing: 4) {
            Text(item.displayName)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 6) {
                YarnBall(color: item.color, size: 18)
                Text("\(progress.yarnCount(of: item.color)) of \(item.cost) yarn")
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Steps through the knittable items, wrapping round, so neither arrow
    /// is ever a dead end. Hidden (but keeping its space) with only one.
    private func arrow(systemName: String, label: LocalizedStringKey, step: Int) -> some View {
        let count = knittable.count
        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                index = (min(index, count - 1) + step + count) % count
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(count > 1 ? 1 : 0)
        .disabled(count < 2)
        .accessibilityLabel(label)
        .accessibilityHidden(count < 2)
    }
}

#Preview("Two to knit") {
    YarnBagCard(
        progress: PlayerProgress(levelNumber: 9, hints: 2, grandmas: 1, yarn: [.red: 8, .blue: 3, .green: 6],
                                 wardrobe: ["cat.scarf.yellow"]),
        catalog: .standard,
        onKnit: { _ in },
        onClose: {}
    )
}

#Preview("Nearly there") {
    YarnBagCard(
        progress: PlayerProgress(levelNumber: 9, hints: 2, grandmas: 1, yarn: [.red: 5, .blue: 2]),
        catalog: .standard,
        onKnit: { _ in },
        onClose: {}
    )
}
