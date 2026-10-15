import SwiftUI

/// Colours and fixed sizes for the game screens, in one place so the look
/// can be tuned without hunting through views. Views never write colour
/// values themselves; they use these names.
///
/// The palette is warm: a cream background and brown text, with orange for
/// main actions and brown for secondary ones. Every text colour is checked
/// against the surface it sits on (contrast noted beside it).
///
/// The screens are light-only for now (`.preferredColorScheme(.light)` on the
/// level screen). Dark mode means giving each colour a dark variant here,
/// ideally as colour sets in the asset catalog.
enum Theme {
    // MARK: Actions

    /// Main buttons (Submit, Next level, the cat) and the progress bar.
    /// White on this orange is only 2.4:1, below the 3:1 guideline for large
    /// text, so button labels are set large and heavy to stay legible. If
    /// testers find them hard to read, 0xD27E1E (same hue, 3.1:1) passes.
    static let primary = Color(red: 0.894, green: 0.592, blue: 0.247)
    static let onPrimary = Color(red: 1.0, green: 1.0, blue: 1.0)
    /// Secondary buttons: border and label only (3.3:1 on the background).
    static let secondary = Color(red: 0.710, green: 0.471, blue: 0.294)

    // MARK: Surfaces

    /// Warm cream behind everything.
    static let background = Color(hex: 0xF8F2EC)
    /// Cards, buttons and letter cells.
    static let surface = Color.white
    static let clueCell = Color(hex: 0xF1E7DE)
    static let clueDivider = Color(hex: 0xE0D3C8)
    static let cellBorder = Color(hex: 0xE6D9CF)
    static let progressTrack = Color(hex: 0xEFE5DC)
    static let disabledFill = Color(hex: 0xEDE4DC)

    // MARK: Text

    /// Raw value of `ink`, for contrast calculations (see ClueColors).
    static let inkHex: UInt32 = 0x4A3034
    /// Main text and letters: dark warm brown (10.7:1 on the background).
    static let ink = Color(hex: inkHex)
    /// Smaller labels and meta text (5.0:1 on the background).
    static let secondaryInk = Color(hex: 0x7E6162)
    /// Quiet icons, such as the clue bar's arrows (3.3:1 on white).
    static let quietInk = Color(hex: 0xA08889)
    /// Clue text inside clue cells (7.5:1 on the clue cell).
    static let clueInk = Color(hex: 0x5A4245)

    // MARK: States

    /// Letters the player can't erase (starters, the cat's and grandma's):
    /// a dark amber that keeps 4.5:1 contrast on white. Their corner mark
    /// uses it too.
    static let lockedInk = Color(hex: 0xB4530A)
    static let wrongInk = Color(hex: 0xC62828)
    static let wrongFill = Color(hex: 0xFDECEC)
    static let wrongBorder = Color(hex: 0xF3B9B9)
    /// A right letter after Submit: the green counterpart of the wrong
    /// colours, at the same lightness so neither shouts louder. The letter
    /// itself stays in `ink`, which reads at 9:1 on this fill.
    static let correctFill = Color(hex: 0xE9F6EA)
    static let correctBorder = Color(hex: 0xA5D6A7)
    /// Judged cells get a slightly thicker border than plain ones, so the
    /// colour reads at a glance even on small cells.
    static let judgedBorderWidth: CGFloat = 1.5
    static let usedUpKey = Color(hex: 0xC4B5B0)
    static let usedUpBorder = Color(hex: 0xE3D6CC)
    /// An empty yarn slot on the result panel (a pale, colourless ball).
    static let emptyYarnSlot = Color(hex: 0xDCCFC5)

    // MARK: Ad placeholder

    static let adPlaceholderFill = Color(hex: 0xF2EAE2)
    static let adPlaceholderBorder = Color(hex: 0xD6C7BB)

    // MARK: Sizes

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
