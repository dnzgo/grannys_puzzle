import SwiftUI

/// The cat celebrating a solved level.
///
/// A placeholder until the Rive animation (the cat dancing and batting the
/// yarn about) exists: for now his head bobs and sways. Kept as one
/// self-contained view on purpose, so the animation replaces only what's
/// inside it. The yarn balls belong to the celebration around it
/// (LevelCompleteView), because they have to travel from his paws to
/// grandma's bag in one continuous movement.
struct CatCelebration: View {
    let size: CGFloat

    @State private var bouncing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("cat-head")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .rotationEffect(.degrees(bouncing ? 7 : -7), anchor: .bottom)
            .offset(y: bouncing ? -size * 0.08 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.32).repeatForever(autoreverses: true)) {
                    bouncing = true
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    CatCelebration(size: 120)
        .padding()
        .background(Theme.background)
}
