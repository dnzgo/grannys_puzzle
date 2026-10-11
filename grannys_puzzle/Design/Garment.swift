import SwiftUI
import ArrowwordCore

extension GarmentKind {
    var name: String {
        switch self {
        case .scarf: String(localized: "Scarf", bundle: .appLanguage, locale: .appLanguage)
        case .hat: String(localized: "Hat", bundle: .appLanguage, locale: .appLanguage)
        case .sweater: String(localized: "Sweater", bundle: .appLanguage, locale: .appLanguage)
        case .mittens: String(localized: "Mittens", bundle: .appLanguage, locale: .appLanguage)
        case .blanket: String(localized: "Blanket", bundle: .appLanguage, locale: .appLanguage)
        }
    }

    /// Stand-in icons until the garment art exists. Only `GarmentView` uses
    /// them, so swapping in real images later is a one-place change.
    fileprivate var placeholderSymbol: String {
        switch self {
        case .scarf: "wind"
        case .hat: "graduationcap.fill"
        case .sweater: "tshirt.fill"
        case .mittens: "hand.raised.fill"
        case .blanket: "bed.double.fill"
        }
    }
}

extension KnitItem {
    /// "Red scarf", "Kırmızı atkı". A localized format, so a language
    /// that puts the colour after the garment can reorder it. Lowercased
    /// with the game's language: Turkish has its own rules (I → ı).
    var displayName: String {
        String(
            localized: "\(color.name) \(kind.name.lowercased(with: .appLanguage))",
            bundle: .appLanguage,
            locale: .appLanguage,
            comment: "A knitted item: colour, then garment, e.g. Red scarf"
        )
    }
}

/// A knitted item: a soft card in the yarn's colour with the garment on it.
struct GarmentView: View {
    let kind: GarmentKind
    let color: YarnColor
    let size: CGFloat
    /// False draws a pale outline: an item not knitted yet.
    var isOwned = true

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24)
            .fill(isOwned ? color.tint : Theme.disabledFill)
            .overlay {
                Image(systemName: kind.placeholderSymbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(isOwned ? Color.white : Theme.usedUpKey)
            }
            .frame(width: size, height: size)
            // Not hidden from VoiceOver here: callers decide. Where it's
            // decoration they hide it; where it's the content (the wardrobe)
            // they label it.
    }
}

#Preview {
    VStack {
        ForEach(GarmentKind.allCases, id: \.self) { kind in
            HStack {
                ForEach(YarnColor.allCases, id: \.self) { GarmentView(kind: kind, color: $0, size: 56) }
                GarmentView(kind: kind, color: .red, size: 56, isOwned: false)
            }
        }
    }
    .padding()
    .background(Theme.background)
}
