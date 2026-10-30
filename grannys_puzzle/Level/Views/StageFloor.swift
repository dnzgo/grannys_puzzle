import SwiftUI

/// The floor of the level-end card's little stage: a soft oval the cat and
/// the yarn bag stand on. Without it they float in the card; with it, and
/// a shadow under each (ContactShadow), they're standing somewhere.
struct StageFloor: View {
    let width: CGFloat
    static let height: CGFloat = 30

    var body: some View {
        Ellipse()
            .fill(Theme.disabledFill)
            .frame(width: width, height: Self.height)
            .accessibilityHidden(true)
    }
}

/// The dark, blurred patch right under something standing on the floor:
/// the small detail that makes it read as touching the ground.
struct ContactShadow: View {
    let width: CGFloat

    var body: some View {
        Ellipse()
            .fill(Color.black.opacity(0.16))
            .frame(width: width, height: width * 0.2)
            .blur(radius: 3)
            .accessibilityHidden(true)
    }
}
