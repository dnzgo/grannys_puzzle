import SwiftUI

/// "Watch a short video and pick a treat": shown when the player taps a
/// helper they've run out of. They choose the reward first, then the video
/// plays, so they always know what they're watching it for.
///
/// Placeholder styling like the other reward moments; it gets redesigned
/// with them.
struct AdOfferCard: View {
    /// How many helpers each choice gives (tuned remotely, so not fixed here).
    let amount: (HelperAdReward) -> Int
    let onChoose: (HelperAdReward) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text("Need a little help?")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("Watch a short video and pick a treat.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondaryInk)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    ForEach(HelperAdReward.allCases, id: \.self) { reward in
                        option(reward)
                    }
                }

                Button("Not now", action: onCancel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.secondaryInk)
                    .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.background))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .padding(.horizontal, 24)
        }
        .accessibilityAddTraits(.isModal)
    }

    private func option(_ reward: HelperAdReward) -> some View {
        Button { onChoose(reward) } label: {
            VStack(spacing: 10) {
                // One face per helper given, overlapping like a little crowd.
                HStack(spacing: -14) {
                    ForEach(0..<amount(reward), id: \.self) { _ in
                        HelperFaceImage(face: reward.face, size: 44)
                    }
                }
                .frame(height: 48)

                Text(reward.title(amount: amount(reward)))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)

                Label("Watch", systemImage: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Capsule().fill(Theme.primary))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.surface)
                    .shadow(color: Theme.primary.opacity(0.35), radius: 6, y: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reward.title(amount: amount(reward)))
        .accessibilityHint("Plays a short video")
    }
}

private extension HelperAdReward {
    var face: HelperFace {
        switch self {
        case .catHints: .cat
        case .grandma: .grandma
        }
    }

    func title(amount: Int) -> LocalizedStringKey {
        switch self {
        case .catHints: "\(amount) cat hints"
        case .grandma: "\(amount) grandma"
        }
    }
}
