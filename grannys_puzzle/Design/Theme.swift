import SwiftUI

/// Colours and fixed sizes for the game screens, in one place so the look
/// can be tuned without hunting through views. Values match the design canvas.
///
/// The screens are light-only for now (`.preferredColorScheme(.light)` on the
/// level screen). Dark mode means giving each colour a dark variant here,
/// ideally as colour sets in the asset catalog.
enum Theme {
    static let accent = Color(hex: 0x3355FF)
    static let background = Color(hex: 0xF7F7F5)
    static let surface = Color.white
    static let ink = Color(hex: 0x1C1C1E)
    static let secondaryInk = Color(hex: 0x6B6B70)
    static let quietInk = Color(hex: 0x8A8A8F)

    static let clueCell = Color(hex: 0xEEEEEA)
    static let clueInk = Color(hex: 0x3F3F44)
    static let clueDivider = Color(hex: 0xD9D9D4)
    static let cellBorder = Color(hex: 0xE4E4E0)

    /// Revealed letters: a dark amber that keeps 4.5:1 contrast on white.
    static let revealedInk = Color(hex: 0xB4530A)
    static let wrongInk = Color(hex: 0xC62828)
    static let wrongFill = Color(hex: 0xFDECEC)
    static let wrongBorder = Color(hex: 0xF3B9B9)

    static let usedUpKey = Color(hex: 0xB8B8BD)
    static let usedUpBorder = Color(hex: 0xDCDCD7)
    static let star = Color(hex: 0xE8A317)
    static let starOutline = Color(hex: 0xCFCFCA)
    static let cat = Color(hex: 0xE8892B)

    static let sidePadding: CGFloat = 16
    static let cornerRadius: CGFloat = 6
}

extension Color {
    /// A colour from a 0xRRGGBB literal, so values can be copied from the design.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
