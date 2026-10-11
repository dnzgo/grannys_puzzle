import SwiftUI
import ArrowwordCore

extension YarnColor {
    /// The tint applied to the grey yarn-ball image. Chosen to sit with the
    /// warm palette and to stay distinct from each other for colour-blind
    /// players: they differ in lightness as well as hue (yellow is light,
    /// blue and red mid, green darker), and the bag always shows names too.
    var tint: Color {
        switch self {
        case .red: Color(hex: 0xE0504A)
        case .blue: Color(hex: 0x4F86C6)
        case .yellow: Color(hex: 0xF2C14E)
        case .green: Color(hex: 0x5E9E50)
        }
    }

    /// The colour's name for labels and VoiceOver.
    var displayName: LocalizedStringKey {
        switch self {
        case .red: "Red"
        case .blue: "Blue"
        case .yellow: "Yellow"
        case .green: "Green"
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
