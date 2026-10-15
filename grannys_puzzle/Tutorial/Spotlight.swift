import SwiftUI
import ArrowwordCore

/// Something on the level screen the lesson can light up: a tap target,
/// one letter cell of the word being talked about, or the clue bar, which
/// shows that word's clue larger than its clue cell can.
enum SpotlightID: Hashable {
    case target(TutorialTarget)
    case cell(Coordinate)
    case clueBar
}

/// Where each lit-up-able view sits on the level screen, so the lesson's
/// overlay can cut holes in its dimming exactly over them.
///
/// Views report their own frames (`.spotlight(_:)`) rather than the overlay
/// working them out, because only the views know their layout: the grid's
/// cell size, the tray's key widths and the action bar all change with the
/// screen and the level. Frames are in the `spaceName` coordinate space,
/// which the level screen defines on its root.
@Observable
final class SpotlightFrames {
    var rects: [SpotlightID: CGRect] = [:]

    static let spaceName = "tutorialSpotlight"

    /// The smallest rectangle around all of these, or nil if none has been
    /// laid out yet.
    func union(of ids: [SpotlightID]) -> CGRect? {
        ids.compactMap { rects[$0] }.reduce(nil as CGRect?) { result, rect in
            result?.union(rect) ?? rect
        }
    }
}

extension View {
    /// Reports this view's frame for the lesson's spotlight. Does nothing on
    /// real levels, where no `SpotlightFrames` is in the environment.
    func spotlight(_ id: SpotlightID) -> some View {
        modifier(SpotlightAnchor(id: id))
    }
}

private struct SpotlightAnchor: ViewModifier {
    let id: SpotlightID
    @Environment(SpotlightFrames.self) private var frames: SpotlightFrames?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let frames {
            // Copied into a local so the geometry closure, which SwiftUI may
            // run off the main actor, captures a plain string.
            let space = SpotlightFrames.spaceName
            content.onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(space))
            } action: { frame in
                frames.rects[id] = frame
            }
        } else {
            content
        }
    }
}
