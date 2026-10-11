import SwiftUI
import ArrowwordCore

extension GarmentKind {
    var name: String {
        switch self {
        case .scarf: String(localized: "Scarf")
        case .hat: String(localized: "Hat")
        case .sweater: String(localized: "Sweater")
        case .mittens: String(localized: "Mittens")
        case .blanket: String(localized: "Blanket")
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
    /// "Red scarf". English word order for now; Turkish puts it the same way
    /// round ("Kırmızı atkı"), but this moves into the String Catalog with a
    /// proper format when localization starts.
    var displayName: String {
        "\(color.name) \(kind.name.lowercased())"
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
