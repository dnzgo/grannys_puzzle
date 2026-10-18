import SwiftUI
import ArrowwordCore

/// The cat's wardrobe, as one of the game's cards: one garment shown large
/// with the colours it comes in, and every garment as a row of squares
/// underneath to switch between them.
///
/// Each garment is a set: knitting it in every colour fills the set, and
/// its jar of treats is collected here, once. Showing the colours still to
/// knit is deliberate: a set one colour short is a stronger pull to keep
/// playing than a list of what's already done.
struct WardrobeCard: View {
    let progress: PlayerProgress
    let catalog: KnittingCatalog
    /// Called with any item of the set whose jar is being collected.
    let onCollectJar: (KnitItem) -> Void
    let onClose: () -> Void

    @State private var selectedKind: GarmentKind

    /// - Parameter initialKind: the garment to show first (after finishing
    ///   a set, that set). Otherwise a set with its jar waiting, else the
    ///   first garment.
    init(
        progress: PlayerProgress,
        catalog: KnittingCatalog,
        initialKind: GarmentKind? = nil,
        onCollectJar: @escaping (KnitItem) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.progress = progress
        self.catalog = catalog
        self.onCollectJar = onCollectJar
        self.onClose = onClose
        let sets = catalog.sets(for: .cat)
        let waiting = sets.first { set in
            set.first.map { progress.hasSetJarWaiting(for: $0, in: catalog) } ?? false
        }
        let kind = initialKind ?? waiting?.first?.kind ?? sets.first?.first?.kind ?? .scarf
        _selectedKind = State(initialValue: kind)
    }

    private var sets: [[KnitItem]] { catalog.sets(for: .cat) }
    private var selectedSet: [KnitItem] { sets.first { $0.first?.kind == selectedKind } ?? [] }

    var body: some View {
        GameCard(title: "The cat's wardrobe", onClose: onClose) {
            VStack(spacing: 18) {
                featured(selectedSet)
                Rectangle().fill(Theme.clueDivider).frame(height: 1)
                garmentSquares
            }
        }
    }

    // MARK: The garment shown large

    private func featured(_ set: [KnitItem]) -> some View {
        let owned = set.filter(progress.owns)
        return VStack(spacing: 14) {
            garmentTile(for: set, size: 120)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text(selectedKind.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("\(owned.count) of \(set.count) knitted")
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryInk)
            }
            HStack(spacing: 10) {
                ForEach(set) { colourSwatch(for: $0) }
            }
            jarRow(for: set)
        }
        .animation(.easeOut(duration: 0.2), value: selectedKind)
    }

    /// One colour of the garment: knitted in its colour with a tick, or
    /// still to knit as a pale tile ringed in the colour it needs, so the
    /// player can see which yarn to collect.
    private func colourSwatch(for item: KnitItem) -> some View {
        let isOwned = progress.owns(item)
        return GarmentView(kind: item.kind, color: item.color, size: 52, isOwned: isOwned)
            .overlay {
                if !isOwned {
                    RoundedRectangle(cornerRadius: 52 * 0.24)
                        .strokeBorder(item.color.tint, lineWidth: 3)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isOwned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.onPrimary, Theme.switchOn)
                        .offset(x: 6, y: -6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.displayName)
            .accessibilityValue(isOwned ? Text("Knitted") : Text("Not knitted yet"))
    }

    /// The set's jar: to collect once every colour is knitted, collected,
    /// or the promise of one. The same height in every state, so the card
    /// doesn't jump when switching garments.
    private func jarRow(for set: [KnitItem]) -> some View {
        Group {
            if let item = set.first, progress.hasSetJarWaiting(for: item, in: catalog) {
                PrimaryButton(title: "Collect jar", height: 52) { onCollectJar(item) }
            } else if let item = set.first, progress.collectedSetJars.contains(item.setID) {
                Label("Jar collected", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
            } else {
                Text("Knit every colour for a jar of treats.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.secondaryInk)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 52)
    }

    // MARK: Every garment

    /// Every garment as a square; tapping one shows it large.
    private var garmentSquares: some View {
        HStack(spacing: 8) {
            ForEach(sets, id: \.first?.id) { set in
                if let kind = set.first?.kind {
                    square(for: set, kind: kind)
                }
            }
        }
    }

    private func square(for set: [KnitItem], kind: GarmentKind) -> some View {
        let isSelected = kind == selectedKind
        let jarWaiting = set.first.map { progress.hasSetJarWaiting(for: $0, in: catalog) } ?? false
        let owned = set.filter(progress.owns).count
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { selectedKind = kind }
        } label: {
            VStack(spacing: 4) {
                garmentTile(for: set, size: 50)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 50 * 0.24)
                                .strokeBorder(Theme.primary, lineWidth: 3)
                        }
                    }
                    // The same red dot as the daily treats button: something
                    // is waiting here.
                    .overlay(alignment: .topTrailing) {
                        if jarWaiting {
                            Circle()
                                .fill(Theme.alertDot)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2))
                                .offset(x: 4, y: -4)
                        }
                    }
                Text("\(owned)/\(set.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.name)
        .accessibilityValue(Text("\(owned) of \(set.count) knitted"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(jarWaiting ? Text("Jar waiting") : Text(""))
    }

    /// A garment as a whole: in the colour of its first knitted item, or a
    /// pale outline while none is knitted.
    private func garmentTile(for set: [KnitItem], size: CGFloat) -> some View {
        let shown = set.first(where: progress.owns) ?? set.first
        return GarmentView(
            kind: shown?.kind ?? selectedKind,
            color: shown?.color ?? .red,
            size: size,
            isOwned: set.contains(where: progress.owns)
        )
    }
}

#Preview {
    WardrobeCard(
        progress: PlayerProgress(
            levelNumber: 20, hints: 0, grandmas: 0, yarn: [:],
            wardrobe: ["cat.scarf.red", "cat.scarf.blue", "cat.scarf.yellow", "cat.scarf.green", "cat.hat.green"]
        ),
        catalog: .standard,
        onCollectJar: { _ in },
        onClose: {}
    )
}
