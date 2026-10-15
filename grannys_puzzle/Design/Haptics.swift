import SwiftUI

/// Moments in the game that get a haptic. View models report these; the
/// views turn them into vibrations with `.gameHaptics(_:)`.
///
/// Keeping "what happened" (here) apart from "how it feels" (below) means
/// the feel of the whole game is tuned in one place, and view models never
/// touch a haptics API, so they stay easy to test.
enum HapticEvent: Equatable {
    /// Tapping a cell or moving between clues.
    case select
    /// A letter placed from the tray: the keyboard click.
    case letterPlaced
    case letterErased
    /// The cat or grandma filling in letters.
    case reveal
    case levelPassed
    case levelFailed
    /// A finished knitted item revealed.
    case itemKnitted
    /// The jar's treat revealed.
    case jarOpened
    /// Helpers earned by watching a video.
    case helperEarned
    /// A yarn ball dropping into grandma's bag after a level. Soft: up to
    /// three come in quick succession.
    case yarnLanded
    /// One group of cells lighting green or red after Submit. The lightest
    /// tick of all: a wave can have fifteen of them in a second.
    case cellsJudged

    /// How each moment feels. Small and frequent actions get the lightest
    /// taps; only real outcomes get the stronger, patterned ones. If every
    /// tap buzzed hard, the big moments would stop standing out.
    var feedback: SensoryFeedback {
        switch self {
        case .select, .letterErased: .selection
        case .letterPlaced, .yarnLanded: .impact(flexibility: .soft, intensity: 0.6)
        case .cellsJudged: .impact(flexibility: .soft, intensity: 0.35)
        case .reveal: .impact(weight: .medium)
        case .levelPassed, .itemKnitted, .jarOpened, .helperEarned: .success
        case .levelFailed: .warning
        }
    }
}

/// One haptic to play. The id makes two identical events in a row (two
/// letters typed) count as two changes, so both of them buzz.
struct HapticSignal: Equatable {
    let event: HapticEvent
    let id: Int
}

private struct GameHaptics: ViewModifier {
    let signal: HapticSignal?
    // The Haptics switch in Settings writes this same key.
    @AppStorage(ToggleSetting.haptics.key) private var isEnabled = ToggleSetting.haptics.defaultValue

    func body(content: Content) -> some View {
        // Returning nil plays nothing: that's how the setting switches it off.
        content.sensoryFeedback(trigger: signal) { _, new in
            guard isEnabled, let new else { return nil }
            return new.event.feedback
        }
    }
}

extension View {
    /// Plays the haptic for each new signal, if the player has haptics on.
    func gameHaptics(_ signal: HapticSignal?) -> some View {
        modifier(GameHaptics(signal: signal))
    }
}
