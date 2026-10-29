import SwiftUI
import ArrowwordCore

/// Shown when the last item of a family member's wardrobe is knitted: their
/// Polaroid, black and white while it was being knitted, slowly fills with
/// colour, and the next member's photo appears as "Up next". After it, the
/// home screen swaps the wardrobe (HomeStage).
///
/// The colour photo is the reward for a finished wardrobe; this is where
/// the player sees it earned. Placeholder styling, like SetPrizeMoment,
/// until the reward scenes are redesigned.
struct WardrobeDoneMoment: View {
    let member: FamilyMember
    /// Whose wardrobe opens now; nil after the last one.
    let next: FamilyMember?
    let onDone: () -> Void

    /// 0 (black and white) to 1 (colour), animated in on appear.
    @State private var colour = 0.0
    @State private var showsNext = false
    @State private var feedback: FeedbackSignal?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {}
                .accessibilityHidden(true)

            VStack(spacing: 18) {
                Text(member.wardrobeTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryInk)
                Text("Complete!")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, -12)

                FamilyPolaroid(member: member, status: .complete, width: 170, colour: colour)
                    .rotationEffect(member.tilt)

                if let next {
                    HStack(spacing: 12) {
                        Text("Up next")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.secondaryInk)
                        FamilyPolaroid(member: next, status: .current, width: 64)
                            .rotationEffect(next.tilt)
                    }
                    .opacity(showsNext ? 1 : 0)
                    .scaleEffect(showsNext ? 1 : 0.8)
                }

                PrimaryButton(title: next == nil ? "Wonderful!" : "Next wardrobe", height: 52, action: onDone)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.background))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .padding(.horizontal, 24)
        }
        .onAppear {
            feedback = FeedbackSignal(event: .itemKnitted, id: 1)
            // The colour comes in like a photo developing: slowly, after a
            // beat, so the black-and-white picture is seen first.
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.6).delay(0.5)) { colour = 1 }
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7).delay(2.2)) { showsNext = true }
        }
        .gameFeedback(feedback)
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    WardrobeDoneMoment(member: .cat, next: .daughter, onDone: {})
}
