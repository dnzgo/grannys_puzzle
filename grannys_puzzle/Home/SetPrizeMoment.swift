import SwiftUI
import ArrowwordCore

/// Shown after the knitting moment that finishes a set (one garment in
/// every colour): the whole set together, and a jar of treats.
///
/// The jar is already saved with the player's unopened jars when this
/// shows (see Game.knit); collecting it here sends the player home, where
/// it waits beside grandma's chair like the daily ones. What's inside
/// stays a surprise until it's opened. Placeholder styling until the
/// reward scenes are redesigned with the new art.
struct SetPrizeMoment: View {
    /// Every item in the finished set, in catalog order.
    let items: [KnitItem]
    let onDone: () -> Void

    @State private var shown = false
    @State private var haptic: HapticSignal?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {}
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text("Set complete!")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)

                HStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        GarmentView(kind: item.kind, color: item.color, size: 56)
                            .scaleEffect(shown ? 1 : 0.4)
                            .opacity(shown ? 1 : 0)
                            .animation(
                                reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.1),
                                value: shown
                            )
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(items.map(\.displayName).joined(separator: ", ")))

                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Image("jar")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 76)
                    .scaleEffect(shown ? 1 : 0.4)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.55).delay(0.45), value: shown)
                    .accessibilityLabel("Treat jar")

                PrimaryButton(title: "Collect jar", height: 52, action: onDone)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.background))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .padding(.horizontal, 24)
        }
        .onAppear {
            shown = true
            haptic = HapticSignal(event: .itemKnitted, id: 1)
        }
        .gameHaptics(haptic)
        .accessibilityAddTraits(.isModal)
    }

    /// "The scarf set is complete! …", named after the garment.
    private var message: String {
        let garment = items.first?.kind.name.lowercased(with: .appLanguage) ?? ""
        return String(localized: "The \(garment) set is complete! Here's a jar of treats from me.", bundle: .appLanguage, locale: .appLanguage)
    }
}

#Preview {
    SetPrizeMoment(
        items: KnittingCatalog.standard.items.filter { $0.kind == .scarf },
        onDone: {}
    )
}
