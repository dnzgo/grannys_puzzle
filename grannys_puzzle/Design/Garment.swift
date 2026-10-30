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
        case .beret: String(localized: "Beret", bundle: .appLanguage, locale: .appLanguage)
        case .handwarmers: String(localized: "Hand warmers", bundle: .appLanguage, locale: .appLanguage)
        case .legwarmers: String(localized: "Leg warmers", bundle: .appLanguage, locale: .appLanguage)
        case .shawl: String(localized: "Shawl", bundle: .appLanguage, locale: .appLanguage)
        case .cardigan: String(localized: "Cardigan", bundle: .appLanguage, locale: .appLanguage)
        case .beanie: String(localized: "Beanie", bundle: .appLanguage, locale: .appLanguage)
        case .gloves: String(localized: "Gloves", bundle: .appLanguage, locale: .appLanguage)
        case .socks: String(localized: "Socks", bundle: .appLanguage, locale: .appLanguage)
        case .vest: String(localized: "Sweater vest", bundle: .appLanguage, locale: .appLanguage)
        case .headband: String(localized: "Ear warmer", bundle: .appLanguage, locale: .appLanguage)
        case .mittens: String(localized: "Mittens", bundle: .appLanguage, locale: .appLanguage)
        case .earflaphat: String(localized: "Earflap hat", bundle: .appLanguage, locale: .appLanguage)
        case .bunny: String(localized: "Bunny", bundle: .appLanguage, locale: .appLanguage)
        case .pinafore: String(localized: "Pinafore dress", bundle: .appLanguage, locale: .appLanguage)
        case .slippers: String(localized: "Slippers", bundle: .appLanguage, locale: .appLanguage)
        case .dinohat: String(localized: "Dino hat", bundle: .appLanguage, locale: .appLanguage)
        case .teddy: String(localized: "Teddy bear", bundle: .appLanguage, locale: .appLanguage)
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

extension KnitItem {
    /// The garment's art in the asset catalog, e.g. "garment-son-scarf":
    /// per member, because the same kind looks different on each (the
    /// cat's scarf and the son's aren't the same piece).
    fileprivate var imageName: String { "garment-\(member.rawValue)-\(kind.rawValue)" }
}

/// A knitted item: the garment on a soft white tile, in the yarn's colour.
///
/// Like the yarn ball, each garment is drawn once in undyed greys (white
/// where the light falls, darker in the stitches), and `colorMultiply`
/// turns it into any yarn colour: a new colour needs no new art. (The art
/// must stay neutral grey: a warm cast would tint every colour with it.)
struct GarmentView: View {
    let item: KnitItem
    let size: CGFloat
    /// False draws it pale and undyed on a grey tile: not knitted yet.
    var isOwned = true
    /// False draws the garment alone, with no tile: where it appears in
    /// the room itself (knitting on the home screen) rather than in a list.
    var showsTile = true

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24)
            .fill(showsTile ? (isOwned ? Theme.surface : Theme.disabledFill) : .clear)
            .overlay {
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.07)
                    .colorMultiply(isOwned ? item.color.tint : .white)
                    .opacity(isOwned ? 1 : 0.45)
            }
            .frame(width: size, height: size)
            // Not hidden from VoiceOver here: callers decide. Where it's
            // decoration they hide it; where it's the content (the wardrobe)
            // they label it.
    }
}

#Preview {
    ScrollView {
        ForEach(KnittingCatalog.standard.members, id: \.self) { member in
            ForEach(KnittingCatalog.standard.sets(for: member), id: \.first?.id) { set in
                HStack {
                    ForEach(set) { GarmentView(item: $0, size: 56) }
                    if let first = set.first { GarmentView(item: first, size: 56, isOwned: false) }
                }
            }
        }
    }
    .padding()
    .background(Theme.background)
}
