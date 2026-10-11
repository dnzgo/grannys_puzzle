import SwiftUI
import ArrowwordCore

/// The wardrobe: everything grandma has knitted, with empty outlines for
/// what's still to come. The second collection, next to the yarn bag.
///
/// Showing the empty slots is deliberate: a nearly full row is a stronger
/// pull to keep playing than a list of what you already have.
struct WardrobeSheet: View {
    let progress: PlayerProgress
    let catalog: KnittingCatalog

    @Environment(\.dismiss) private var dismiss

    private var catItems: [KnitItem] { catalog.items(for: .cat) }
    private var ownedCount: Int { catItems.filter(progress.owns).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("The cat's wardrobe")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("\(ownedCount) of \(catItems.count) knitted")
                            .font(.system(size: 14))
                            .monospacedDigit()
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    Spacer()
                    CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
                }

                ForEach(GarmentKind.allCases, id: \.self) { kind in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(kind.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        HStack(spacing: 10) {
                            ForEach(catItems.filter { $0.kind == kind }) { item in
                                GarmentView(kind: item.kind, color: item.color, size: 62, isOwned: progress.owns(item))
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(item.displayName)
                                    .accessibilityValue(progress.owns(item) ? Text("Knitted") : Text("Not knitted yet"))
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    WardrobeSheet(
        progress: PlayerProgress(levelNumber: 20, hints: 0, grandmas: 0, yarn: [:],
                                 wardrobe: ["cat.scarf.red", "cat.scarf.blue", "cat.hat.green"]),
        catalog: .standard
    )
}
