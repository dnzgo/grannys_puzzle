import SwiftUI

/// Grandma asks whether she may send reminders, in her own words, before
/// iOS asks its "Allow notifications?" question.
///
/// Only a yes here leads to the system's prompt, which iOS shows once per
/// install, ever. Asked at a moment the player cares about (they've just
/// collected her jar), a yes is far more likely than at launch, and a "not
/// now" here costs nothing: she can ask again in a couple of weeks.
///
/// Placeholder styling like the other cards; redesigned with them.
struct ReminderAskCard: View {
    let onYes: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onNotNow)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                HelperFaceImage(face: .grandma, size: 72)

                Text("Shall I send you a little note when your treat jar is ready, dear?")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("At most one a day, and never at night.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryInk)
                    .multilineTextAlignment(.center)

                Button(action: onYes) {
                    Text("Yes, please")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Capsule().fill(Theme.primary))
                }
                .buttonStyle(.plain)

                Button("Not now", action: onNotNow)
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
}

#Preview {
    ReminderAskCard(onYes: {}, onNotNow: {})
}
