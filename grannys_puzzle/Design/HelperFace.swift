import SwiftUI

/// The two helpers' faces: the cat (reveals a letter) and grandma (solves a
/// word). Used wherever a helper appears, so the player learns one picture
/// per helper: the level's buttons, the home counts, the jar's treats and
/// the lesson.
///
/// These are still images for now. When the heads are animated, this view
/// is the one place that changes.
enum HelperFace {
    case cat
    case grandma

    var imageName: String {
        switch self {
        case .cat: "cat-head"
        case .grandma: "granny-head"
        }
    }
}

struct HelperFaceImage: View {
    let face: HelperFace
    let size: CGFloat
    /// Greyed out when the helper can't be used (none left).
    var isEnabled = true

    var body: some View {
        // Decorative: every place that shows a face already has a label
        // ("Cat: reveal a letter"), so VoiceOver shouldn't read the image too.
        Image(decorative: face.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .saturation(isEnabled ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.55)
    }
}
