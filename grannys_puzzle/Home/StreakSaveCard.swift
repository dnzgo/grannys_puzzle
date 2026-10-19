import SwiftUI

/// Offered when the player comes back after missing one day: a short video
/// keeps their streak (see PlayStreak.swift).
///
/// Watching is the big orange choice, since losing a long streak is when a
/// player is most likely to drift away. Letting it go is the outlined one,
/// and closing the card only puts the question off: it's asked again the
/// next time home opens, until they solve something today.
struct StreakSaveCard: View {
    let days: Int
    /// A video is on its way: both buttons wait.
    let isWatching: Bool
    /// The last try had no video to show (offline, none loaded yet).
    let noVideo: Bool
    let onWatch: () -> Void
    let onLetGo: () -> Void
    let onClose: () -> Void

    var body: some View {
        GameCard(title: "Save your streak?", onClose: onClose) {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                    Text("\(days)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Day streak")
                .accessibilityValue("\(days)")

                Text("You missed yesterday. Watch a short video to keep your \(days)-day streak.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if noVideo {
                    Text("No video ready just now. Try again in a moment.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.wrongInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    PrimaryButton(title: "Watch video", height: 52, action: onWatch)
                    SecondaryButton(title: "Let it go", height: 52, action: onLetGo)
                }
                .disabled(isWatching)
                .opacity(isWatching ? 0.6 : 1)
            }
        }
    }
}

#Preview {
    StreakSaveCard(days: 12, isWatching: false, noVideo: true, onWatch: {}, onLetGo: {}, onClose: {})
}
