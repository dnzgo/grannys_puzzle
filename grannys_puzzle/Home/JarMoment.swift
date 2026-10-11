import SwiftUI
import ArrowwordCore

/// The daily jar opening: the jar shakes for a moment, then the treat comes
/// out, with the streak shown as a row of days.
///
/// The reward is already added and saved before this shows; it's only the
/// reveal. Placeholder motion until the Rive "jar shakes and opens"
/// animation exists. With Reduce Motion on, the jar doesn't shake.
struct JarMoment: View {
    let opening: JarOpening
    let streakLength: Int
    let onDone: () -> Void

    private enum Phase {
        case shaking
        case opened
    }

    @State private var phase = Phase.shaking
    @State private var tilt = false
    @State private var haptic: HapticSignal?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let shakeTime: Duration = .seconds(1.2)

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack(spacing: 18) {
                switch phase {
                case .shaking:
                    Image(decorative: "jar")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 170)
                        .rotationEffect(.degrees(reduceMotion ? 0 : (tilt ? 7 : -7)), anchor: .bottom)
                    Text("Let's see what's inside…")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                case .opened:
                    opened
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.background))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .padding(.horizontal, 32)
        }
        .task {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) { tilt = true }
            }
            try? await Task.sleep(for: shakeTime)
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.45, dampingFraction: 0.6)) {
                phase = .opened
            }
            haptic = HapticSignal(event: .jarOpened, id: 1)
        }
        .gameHaptics(haptic)
        .accessibilityAddTraits(.isModal)
    }

    private var opened: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                ForEach(0..<opening.reward.hints, id: \.self) { _ in
                    RewardToken(face: .cat)
                }
                ForEach(0..<opening.reward.grandmas, id: \.self) { _ in
                    RewardToken(face: .grandma)
                }
            }
            .accessibilityHidden(true)

            Text(rewardTitle)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            StreakRow(day: opening.streakDay, length: streakLength)

            Text(streakCaption)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Thank you, Granny!", height: 52, action: onDone)
        }
    }

    private var rewardTitle: String {
        let reward = opening.reward
        let cats = reward.hints == 1
            ? String(localized: "1 cat hint")
            : String(localized: "\(reward.hints) cat hints")
        switch (reward.hints > 0, reward.grandmas > 0) {
        case (true, true): return String(localized: "\(cats) and a grandma!")
        case (false, true): return String(localized: "A grandma helper!")
        default: return "\(cats)!"
        }
    }

    private var streakCaption: String {
        if opening.streakDay >= streakLength {
            return String(localized: "A full week! Tomorrow a new week begins.")
        }
        return String(localized: "Day \(opening.streakDay) of \(streakLength). Come back tomorrow to keep it going!")
    }
}

/// One cat or grandma coming out of the jar, styled like the level's
/// helper buttons so the player recognises what they got.
private struct RewardToken: View {
    let face: HelperFace

    var body: some View {
        HelperFaceImage(face: face, size: 50)
            .frame(width: 54, height: 54)
            // The same soft orange glow as the level's helper buttons.
            .background(Circle().fill(Theme.surface).shadow(color: Theme.primary.opacity(0.45), radius: 6, y: 2))
    }
}

/// The week as a row of dots: days done filled, today ringed, the last day
/// shown as a gift because it's the big one.
private struct StreakRow: View {
    let day: Int
    let length: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...length, id: \.self) { index in
                ZStack {
                    Circle()
                        .fill(index <= day ? Theme.primary : Theme.disabledFill)
                        .frame(width: 26, height: 26)
                    if index == length {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(index <= day ? Theme.onPrimary : Theme.usedUpKey)
                    }
                }
                .overlay(Circle().strokeBorder(index == day ? Theme.ink : .clear, lineWidth: 2))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak")
        .accessibilityValue("Day \(day) of \(length)")
    }
}

#Preview {
    JarMoment(
        opening: JarOpening(reward: JarReward(hints: 3, grandmas: 1), streakDay: 7),
        streakLength: 7,
        onDone: {}
    )
}
