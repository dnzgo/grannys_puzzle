import SwiftUI
import ArrowwordCore

extension YarnColor {
    /// The tint applied to the grey yarn-ball and garment images. Chosen to
    /// sit with the warm palette and to stay distinct for colour-blind
    /// players within each wardrobe's four (the only ones shown together):
    /// they differ in lightness as well as hue, and the bag shows names too.
    var tint: Color {
        switch self {
        case .red: Color(hex: 0xE0504A)
        case .blue: Color(hex: 0x4F86C6)
        case .yellow: Color(hex: 0xF2C14E)
        case .green: Color(hex: 0x5E9E50)
        case .pink: Color(hex: 0xE88FB4)
        case .purple: Color(hex: 0x8A60B8)
        case .navy: Color(hex: 0x34497A)
        case .orange: Color(hex: 0xEE8A3C)
        case .teal: Color(hex: 0x37A39B)
        case .brown: Color(hex: 0x98694A)
        }
    }

    /// The colour's name for labels and VoiceOver.
    var name: String {
        switch self {
        case .red: String(localized: "Red", bundle: .appLanguage, locale: .appLanguage)
        case .blue: String(localized: "Blue", bundle: .appLanguage, locale: .appLanguage)
        case .yellow: String(localized: "Yellow", bundle: .appLanguage, locale: .appLanguage)
        case .green: String(localized: "Green", bundle: .appLanguage, locale: .appLanguage)
        case .pink: String(localized: "Pink", bundle: .appLanguage, locale: .appLanguage)
        case .purple: String(localized: "Purple", bundle: .appLanguage, locale: .appLanguage)
        case .navy: String(localized: "Navy", bundle: .appLanguage, locale: .appLanguage)
        case .orange: String(localized: "Orange", bundle: .appLanguage, locale: .appLanguage)
        case .teal: String(localized: "Teal", bundle: .appLanguage, locale: .appLanguage)
        case .brown: String(localized: "Brown", bundle: .appLanguage, locale: .appLanguage)
        }
    }
}

/// A yarn ball in any colour.
///
/// There's one image, `yarn-ball`: a grey ball that's white where the yarn
/// catches the light and darker in the grooves. `colorMultiply` multiplies
/// every pixel by the tint, so white becomes the full colour and the grooves
/// a darker shade of it. New colours need no new artwork.
struct YarnBall: View {
    /// Nil draws an empty slot (a pale, colourless ball).
    let color: YarnColor?
    let size: CGFloat

    var body: some View {
        Image("yarn-ball")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .colorMultiply(color?.tint ?? Theme.emptyYarnSlot)
            .opacity(color == nil ? 0.55 : 1)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ForEach(YarnColor.allCases, id: \.self) { YarnBall(color: $0, size: 60) }
        YarnBall(color: nil, size: 60)
    }
    .padding()
    .background(Theme.background)
}
