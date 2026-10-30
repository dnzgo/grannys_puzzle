import SwiftUI

/// The cat celebrating a solved level: standing up, front paws in the air,
/// hopping. The yarn balls belong to the celebration around it
/// (LevelCompleteView), because they circle him and then travel to
/// grandma's bag in one continuous movement.
///
/// Kept as one self-contained view, so a richer animation (Rive, say) can
/// later replace only what's inside.
struct CatCelebration: View {
    /// The picture's height (the cat is about as tall as wide, standing).
    let size: CGFloat

    @State private var hopping = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("cat-cheer")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            // A little hop with a squash on landing, and a slight sway, so
            // he looks like he's cheering rather than holding a pose.
            .scaleEffect(x: hopping ? 0.98 : 1.02, y: hopping ? 1.02 : 0.97, anchor: .bottom)
            .rotationEffect(.degrees(hopping ? 3 : -3), anchor: .bottom)
            .offset(y: hopping ? -size * 0.05 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                    hopping = true
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    CatCelebration(size: 150)
        .padding()
        .background(Theme.background)
}
