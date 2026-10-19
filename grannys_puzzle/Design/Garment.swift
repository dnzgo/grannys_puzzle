import SwiftUI
import ArrowwordCore

extension GarmentKind {
    var name: String {
        switch self {
        case .scarf: String(localized: "Scarf", bundle: .appLanguage, locale: .appLanguage)
        case .hat: String(localized: "Hat", bundle: .appLanguage, locale: .appLanguage)
        case .sweater: String(localized: "Sweater", bundle: .appLanguage, locale: .appLanguage)
        case .booties: String(localized: "Booties", bundle: .appLanguage, locale: .appLanguage)
        case .blanket: String(localized: "Blanket", bundle: .appLanguage, locale: .appLanguage)
        }
    }

    /// The garment's art in the asset catalog, e.g. "garment-scarf".
    fileprivate var imageName: String { "garment-\(rawValue)" }
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

/// A knitted item: the garment on a soft white tile, in the yarn's colour.
///
/// Like the yarn ball, each garment is drawn once in undyed greys (white
/// where the light falls, darker in the stitches), and `colorMultiply`
/// turns it into any yarn colour: a new colour needs no new art.
struct GarmentView: View {
    let kind: GarmentKind
    let color: YarnColor
    let size: CGFloat
    /// False draws it pale and undyed on a grey tile: not knitted yet.
    var isOwned = true

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24)
            .fill(isOwned ? Theme.surface : Theme.disabledFill)
            .overlay {
                Image(kind.imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.07)
                    .colorMultiply(isOwned ? color.tint : .white)
                    .opacity(isOwned ? 1 : 0.45)
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
