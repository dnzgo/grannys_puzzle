import SwiftUI
import ArrowwordCore

/// Something on the level screen the lesson can light up: a tap target
/// outside the board, the clue bar (which shows the lit word's clue larger
/// than its clue cell can), or the board's window as a whole.
///
/// Things *on* the board (clues, squares) aren't here: the board zooms and
/// slides inside its window, in a UIKit scroll view SwiftUI can't measure
/// into, so their places are worked out from the board's camera instead
/// (`SpotlightFrames.boardRect`).
enum SpotlightID: Hashable {
    case target(TutorialTarget)
    case clueBar
    case board
}

/// Where each lit-up-able view sits on the level screen, so the lesson's
/// overlay can cut holes in its dimming exactly over them, and its hand can
/// point at them.
///
/// Views report their own frames (`.spotlight(_:)`) rather than the overlay
/// working them out, because only the views know their layout: the tray's
/// key widths and the action bar change with the screen and the level.
/// Frames are in the `spaceName` coordinate space, which the level screen
/// defines on its root.
@Observable
final class SpotlightFrames {
    var rects: [SpotlightID: CGRect] = [:]
    /// How the board sits in its window right now; nil until it's on screen.
    var boardCamera: BoardCamera?

    static let spaceName = "tutorialSpotlight"

    /// The smallest rectangle around all of these, or nil if none has been
    /// laid out yet.
    func union(of ids: [SpotlightID]) -> CGRect? {
        ids.compactMap { rects[$0] }.reduce(nil as CGRect?) { result, rect in
            result?.union(rect) ?? rect
        }
    }

    /// Where a rectangle of the drawn board is on screen, cut to the part
    /// the window shows; nil when it's all out of view (slid or zoomed away).
    func boardRect(_ rect: CGRect) -> CGRect? {
        guard let window = rects[.board], let camera = boardCamera, !rect.isNull else { return nil }
        let onScreen = camera.place(rect).offsetBy(dx: window.minX, dy: window.minY)
        let visible = onScreen.intersection(window)
        return visible.isNull || visible.isEmpty ? nil : visible
    }

    /// The squares, on screen; see `boardRect(_:)`.
    func boardRect(around cells: [Coordinate]) -> CGRect? {
        guard let camera = boardCamera else { return nil }
        return boardRect(camera.metrics.rect(around: cells))
    }

    /// One clue, on screen. A clue cell holding two clues shows them in two
    /// halves, top clue first (as ClueCellView draws them), and the lesson
    /// points at the right half.
    func boardRect(ofClue answerID: Int, in level: Level) -> CGRect? {
        guard let camera = boardCamera else { return nil }
        let clueCell = level.answers[answerID].clueCell
        let clues = level.answerIDs(atClueCell: clueCell)
        guard let index = clues.firstIndex(of: answerID) else { return nil }
        let cell = camera.metrics.rect(around: [clueCell])
        let height = cell.height / CGFloat(clues.count)
        return boardRect(CGRect(x: cell.minX, y: cell.minY + height * CGFloat(index), width: cell.width, height: height))
    }
}

/// The board's zoom and scroll position in its window, as the scroll view
/// reports them, with the sizes the board is drawn at.
struct BoardCamera: Equatable {
    let metrics: BoardMetrics
    /// 1 at the close-up the board is drawn at, less when zoomed out.
    let scale: CGFloat
    /// The scroll view's content offset: which point of the zoomed board
    /// is at the window's top-left (negative while a zoomed-out board is
    /// centred in it).
    let offset: CGPoint

    /// A rectangle of the drawn board, in the window's own coordinates.
    func place(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX * scale - offset.x,
            y: rect.minY * scale - offset.y,
            width: rect.width * scale,
            height: rect.height * scale
        )
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
