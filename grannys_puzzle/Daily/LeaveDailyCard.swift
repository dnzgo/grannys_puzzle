import SwiftUI

/// Asked when the player taps back mid-way through the daily challenge,
/// which throws the go away (see DailyAttempt): one tap shouldn't cost them
/// the board and the time by accident.
///
/// Keep playing is the big, orange choice and closing the card does the
/// same, so the easy way out is the safe one; leaving takes a deliberate
/// tap on the outlined button.
struct LeaveDailyCard: View {
    let onKeepPlaying: () -> Void
    let onLeave: () -> Void

    var body: some View {
        GameCard(title: "Leave?", onClose: onKeepPlaying) {
            VStack(spacing: 16) {
                Text("Your time and board will reset.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    PrimaryButton(title: "Keep playing", height: 52, action: onKeepPlaying)
                    SecondaryButton(title: "Leave", height: 52, action: onLeave)
                }
            }
        }
    }
}

#Preview {
    LeaveDailyCard(onKeepPlaying: {}, onLeave: {})
}
