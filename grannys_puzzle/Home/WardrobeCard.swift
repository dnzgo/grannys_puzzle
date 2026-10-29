import SwiftUI
import ArrowwordCore

/// The family's wardrobes, as one of the game's cards: a row of Polaroids
/// to choose whose wardrobe to see, then that wardrobe's garments, one
/// shown large with the colours it comes in, and every garment as a row of
/// squares underneath to switch between them.
///
/// Each garment is a set: knitting it in every colour fills the set, and
/// its jar of treats is collected here, once. Showing the colours still to
/// knit is deliberate: a set one colour short is a stronger pull to keep
/// playing than a list of what's already done. Earlier wardrobes stay
/// open to look at (and to collect a jar left behind); later ones show as
/// a question mark until it's their turn.
struct WardrobeCard: View {
    let progress: PlayerProgress
    let catalog: KnittingCatalog
    /// Called with any item of the set whose jar is being collected.
    let onCollectJar: (KnitItem) -> Void
    let onClose: () -> Void

    @State private var selectedMember: FamilyMember
    @State private var selectedKind: GarmentKind
    /// A locked Polaroid was tapped: says why it doesn't open.
    @State private var showsLockedNote = false

    /// - Parameter initialItem: any item of the set to show first (after
    ///   finishing a set, that set). Otherwise a set with its jar waiting,
    ///   else the current wardrobe's first garment.
    init(
        progress: PlayerProgress,
        catalog: KnittingCatalog,
        initialItem: KnitItem? = nil,
        onCollectJar: @escaping (KnitItem) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.progress = progress
        self.catalog = catalog
        self.onCollectJar = onCollectJar
        self.onClose = onClose
        let waiting = catalog.items.first { progress.hasSetJarWaiting(for: $0, in: catalog) }
        let member = initialItem?.member ?? waiting?.member
            ?? catalog.currentMember(for: progress) ?? catalog.members.last ?? .cat
        let kind = initialItem?.kind
            ?? (waiting?.member == member ? waiting?.kind : nil)
            ?? catalog.sets(for: member).first?.first?.kind ?? .scarf
        _selectedMember = State(initialValue: member)
        _selectedKind = State(initialValue: kind)
    }

    private var sets: [[KnitItem]] { catalog.sets(for: selectedMember) }
    private var selectedSet: [KnitItem] { sets.first { $0.first?.kind == selectedKind } ?? [] }

    var body: some View {
        GameCard(title: selectedMember.wardrobeTitle, onClose: onClose) {
            VStack(spacing: 18) {
                familyRow
                Rectangle().fill(Theme.clueDivider).frame(height: 1)
                featured(selectedSet)
                Rectangle().fill(Theme.clueDivider).frame(height: 1)
                garmentSquares
            }
        }
    }

    // MARK: The family

    /// Every member's Polaroid; tapping one shows their wardrobe. A red dot
    /// marks a wardrobe with a jar still to collect.
    private var familyRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(catalog.members, id: \.self) { member in
                    polaroid(for: member)
                }
            }
            Text("Opens when the wardrobe before it is complete.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.secondaryInk)
                .opacity(showsLockedNote ? 1 : 0)
                .accessibilityHidden(!showsLockedNote)
        }
    }

    private func polaroid(for member: FamilyMember) -> some View {
        let status = catalog.status(of: member, for: progress)
        let isSelected = member == selectedMember
        let jarWaiting = catalog.items(for: member).contains { progress.hasSetJarWaiting(for: $0, in: catalog) }
        return Button {
            select(member, status: status)
        } label: {
            FamilyPolaroid(member: member, status: status, width: 54)
                // The chosen one straightens up and comes forward a little.
                .rotationEffect(isSelected ? .zero : member.tilt)
                .scaleEffect(isSelected ? 1.12 : 1)
                .overlay(alignment: .topTrailing) {
                    if jarWaiting {
                        Circle()
                            .fill(Theme.alertDot)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2))
                            .offset(x: 4, y: -4)
                    }
                }
                .zIndex(isSelected ? 1 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(jarWaiting ? Text("Jar waiting") : Text(""))
    }

    private func select(_ member: FamilyMember, status: WardrobeStatus) {
        guard status != .locked else {
            withAnimation(.easeOut(duration: 0.2)) { showsLockedNote = true }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeIn(duration: 0.3)) { showsLockedNote = false }
            }
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedMember = member
            // Their set with a jar waiting, if any, else their first garment.
            let sets = catalog.sets(for: member)
            let waiting = sets.first { $0.first.map { progress.hasSetJarWaiting(for: $0, in: catalog) } ?? false }
            selectedKind = (waiting ?? sets.first)?.first?.kind ?? selectedKind
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
        .animation(.easeOut(duration: 0.2), value: selectedMember)
    }

    /// One colour of the garment: knitted in its colour with a tick, or
    /// still to knit as a pale tile ringed in the colour it needs, so the
    /// player can see which yarn to collect.
    private func colourSwatch(for item: KnitItem) -> some View {
        let isOwned = progress.owns(item)
        return GarmentView(item: item, size: 52, isOwned: isOwned)
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
        return Group {
            if let shown {
                GarmentView(item: shown, size: size, isOwned: set.contains(where: progress.owns))
            }
        }
    }
}

#Preview {
    WardrobeCard(
        progress: PlayerProgress(
            levelNumber: 120, hints: 0, grandmas: 0, yarn: [:],
            // The cat's wardrobe done, the daughter's under way.
            wardrobe: Set(KnittingCatalog.standard.items(for: .cat).map(\.id))
                .union(["daughter.beret.pink", "daughter.beret.yellow"])
        ),
        catalog: .standard,
        onCollectJar: { _ in },
        onClose: {}
    )
}
