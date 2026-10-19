import SwiftUI
import UIKit
import ArrowwordCore

/// The board inside its square frame, like a view through a window: a
/// white border round a tinted pane, which sets the board apart from the
/// screen's background and shows where the board ends when zoomed out.
struct BoardViewport: View {
    let model: LevelViewModel
    let metrics: BoardMetrics

    /// Only there in the lesson, which needs to know where the board is.
    @Environment(SpotlightFrames.self) private var spotlightFrames: SpotlightFrames?

    var body: some View {
        ZoomableBoard(
            model: model,
            metrics: metrics,
            focus: focusRect,
            focusID: focusID,
            showsWholeBoard: model.puzzle.isSubmitted,
            onCameraChange: spotlightFrames.map { frames in { (camera: BoardCamera) in frames.boardCamera = camera } }
        )
        .frame(width: metrics.viewportSide, height: metrics.viewportSide)
        .spotlight(.board)
        .background(Theme.boardWindow)
        .clipShape(RoundedRectangle(cornerRadius: Self.paneCornerRadius))
        .padding(BoardMetrics.windowBorder)
        .background(
            RoundedRectangle(cornerRadius: BoardMetrics.windowCornerRadius)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        )
    }

    /// Inner corners follow the outer ones at the border's distance.
    static let paneCornerRadius = BoardMetrics.windowCornerRadius - BoardMetrics.windowBorder

    /// What's kept in view: what the lesson points at on the board, else
    /// the active word with its clue cell.
    private var focusRect: CGRect? {
        if let cells = model.tutorialBoardFocus { return metrics.rect(around: cells) }
        guard let answer = model.activeAnswer else { return nil }
        return metrics.rect(around: answer.cells + [answer.clueCell])
    }

    private var focusID: BoardFocusID? {
        if model.tutorialBoardFocus != nil, let step = model.tutorialStep { return .lessonStep(step) }
        return model.activeAnswer.map { .word($0.id) }
    }
}

/// Which thing the board keeps in view. When it changes, the board moves
/// to show the new one.
enum BoardFocusID: Hashable {
    case word(Int)
    /// What a lesson step points at, so each step that points somewhere on
    /// the board brings it into view, even if the player slid it away.
    case lessonStep(Int)
}

/// A board larger than its frame, seen through it like a map: pinch to zoom
/// between the whole board and a close-up of 5×5 cells (see BoardMetrics),
/// drag to move around. It can't be dragged away, and when zoomed out
/// smaller than the frame it stays centred.
///
/// Built on UIScrollView rather than SwiftUI gestures: it already zooms
/// around the fingers and keeps the content in bounds with a natural
/// bounce, which would otherwise be hand-written and fiddly to get right.
///
/// Taps go through UIKit too. The board's own SwiftUI buttons are switched
/// off here and one tap recognizer on the scroll view finds the cell under
/// the finger. With the buttons live, a cell took the first finger of a
/// pinch before the scroll view saw the second, so pinches often ended as a
/// tap or a slide. Now tap, pan and pinch are three UIKit recognizers, and
/// UIKit picks exactly one: a tap fails as soon as the finger moves or a
/// second finger lands.
///
/// On top of that, three things a puzzle needs:
/// - **An intro**: a level that opens at reading size starts on the whole
///   board for a moment, then zooms in to the selected word, so the player sees there's more (under
///   half a second, and any touch ends it).
/// - **Following the word**: when a new word is selected (tapped, or
///   reached by typing), the board slides just enough to show all of it and
///   its clue, zooming out only if it's longer than the frame.
/// - **The whole board after Submit**, for the green and red wave.
///
/// The lesson also uses it to teach zooming: the board says when a pinch
/// ends at the whole board or plainly zoomed in, and where it sits in the
/// window as it moves, so the spotlight and grandma's hand can follow
/// things on it.
struct ZoomableBoard: UIViewRepresentable {
    let model: LevelViewModel
    let metrics: BoardMetrics
    /// What to keep in view, on the drawn board; nil when nothing is selected.
    let focus: CGRect?
    /// Changes when a different word is selected, which is when the board
    /// follows; not on every letter, so it never fights the player's own drags.
    let focusID: BoardFocusID?
    let showsWholeBoard: Bool
    /// Told where the board is in its window whenever it zooms or slides;
    /// only the lesson asks, to point at things on the board.
    var onCameraChange: ((BoardCamera) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The game's language, which a hosting controller doesn't pass on by
    /// itself (the board's VoiceOver texts use it).
    @Environment(\.locale) private var locale

    func makeCoordinator() -> Coordinator { Coordinator() }

    private var board: HostedBoard { HostedBoard(model: model, metrics: metrics, locale: locale) }

    func makeUIView(context: Context) -> FirstLayoutScrollView {
        let scrollView = FirstLayoutScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.contentInsetAdjustmentBehavior = .never
        // The frame's edge: what's past it is hidden.
        scrollView.layer.cornerRadius = BoardViewport.paneCornerRadius
        scrollView.clipsToBounds = true

        let host = UIHostingController(rootView: board)
        host.view.backgroundColor = .clear
        // The board is laid out at a fixed size; the screen's safe areas
        // mean nothing inside the frame.
        host.safeAreaRegions = []
        // Touches go to the scroll view's recognizers, not the cells (see
        // the type's comment). VoiceOver still reads the cells.
        host.view.isUserInteractionEnabled = false
        scrollView.addSubview(host.view)
        scrollView.hostedController = host
        let coordinator = context.coordinator
        coordinator.host = host
        coordinator.focus = focus
        coordinator.reduceMotion = reduceMotion
        coordinator.lastFocusID = focusID
        coordinator.showedWholeBoard = showsWholeBoard
        coordinator.onTap = tapHandler
        coordinator.onPinchEnded = pinchHandler
        coordinator.onCameraChange = onCameraChange

        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:)))
        scrollView.addGestureRecognizer(tap)

        apply(metrics, to: scrollView, coordinator: coordinator)
        // The coordinator reads the focus when the intro runs, not now: the
        // word can change before the board is first on screen.
        scrollView.onFirstShown = { [weak coordinator, weak scrollView] in
            guard let coordinator, let scrollView else { return }
            coordinator.playIntro(in: scrollView)
        }
        // The frame can change size after it's first shown (the screen
        // settling its layout), which would leave the board half-placed.
        scrollView.onResize = { [weak coordinator, weak scrollView] in
            guard let coordinator, let scrollView else { return }
            coordinator.settle(in: scrollView)
        }
        return scrollView
    }

    func updateUIView(_ scrollView: FirstLayoutScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.host?.rootView = board
        coordinator.focus = focus
        coordinator.reduceMotion = reduceMotion
        coordinator.onTap = tapHandler
        coordinator.onPinchEnded = pinchHandler
        coordinator.onCameraChange = onCameraChange
        apply(metrics, to: scrollView, coordinator: coordinator)
        coordinator.reportCamera(of: scrollView)
        // Before it's first on screen there's no frame to work in yet; the
        // intro takes care of where the board starts.
        guard scrollView.wasShown else { return }

        if showsWholeBoard != coordinator.showedWholeBoard {
            coordinator.showedWholeBoard = showsWholeBoard
            coordinator.lastFocusID = focusID
            if showsWholeBoard {
                coordinator.showWholeBoard(in: scrollView, animated: !reduceMotion)
            } else if let focus {
                // Try again: back to reading size, at the first word.
                coordinator.show(focus, in: scrollView, animated: !reduceMotion)
            }
            return
        }
        if focusID != coordinator.lastFocusID {
            coordinator.lastFocusID = focusID
            if let focus, !showsWholeBoard {
                coordinator.reveal(focus, in: scrollView, animated: !reduceMotion)
            }
        }
    }

    /// The level is closing: the board's controller leaves the screen's.
    static func dismantleUIView(_ scrollView: FirstLayoutScrollView, coordinator: Coordinator) {
        guard let host = coordinator.host, host.parent != nil else { return }
        host.willMove(toParent: nil)
        host.removeFromParent()
    }

    /// Sizes the board and the zoom range; cheap to repeat.
    private func apply(_ metrics: BoardMetrics, to scrollView: FirstLayoutScrollView, coordinator: Coordinator) {
        guard let hostView = coordinator.host?.view else { return }
        let boardResized = coordinator.boardSize != metrics.boardSize
        if boardResized {
            coordinator.boardSize = metrics.boardSize
            // A view's frame can only be set safely without a zoom transform.
            let zoom = scrollView.zoomScale
            scrollView.zoomScale = 1
            hostView.frame = CGRect(origin: .zero, size: metrics.boardSize)
            scrollView.contentSize = metrics.boardSize
            scrollView.zoomScale = zoom
        }
        scrollView.minimumZoomScale = metrics.minimumZoom
        scrollView.maximumZoomScale = 1
        coordinator.openingZoom = metrics.openingZoom
        coordinator.metrics = metrics
        if scrollView.zoomScale < metrics.minimumZoom { scrollView.zoomScale = metrics.minimumZoom }
        coordinator.centre(scrollView)
        // The cells changed size on screen already showing the board (the
        // screen's height crossing a cell-size step): place it again.
        if boardResized, scrollView.wasShown { coordinator.settle(in: scrollView) }
    }

    /// Turns a tap on the drawn board into the same action the cell's own
    /// button has in BoardGrid.
    private var tapHandler: (CGPoint) -> Void {
        { [model, metrics] point in
            guard let cell = metrics.cell(at: point, columns: model.level.columns, rows: model.level.rows) else { return }
            guard model.level.isClueCell(cell) else {
                model.tapCell(cell)
                return
            }
            let clues = model.clues(atClueCell: cell)
            guard !clues.isEmpty else { return }
            // ClueCellView stacks two clues in equal halves, top first.
            let share = (point.y - metrics.origin(of: cell).y) / metrics.cellSize
            let index = min(clues.count - 1, max(0, Int(share * CGFloat(clues.count))))
            model.tapClue(answerID: clues[index].answerID)
        }
    }

    /// A pinch the player finished: how far out or in it left the board.
    private var pinchHandler: (PinchResult) -> Void {
        { [model] result in
            switch result {
            case .wholeBoard: model.playerZoomedOut()
            case .closeUp: model.playerZoomedIn()
            case .between: break
            }
        }
    }

    /// Where a pinch left the board. Only the lesson, which teaches
    /// pinching, listens.
    enum PinchResult {
        /// All of the board in view.
        case wholeBoard
        /// At least halfway from the whole board to the close-up: plainly
        /// zoomed in, on any board, even one whose whole view is already
        /// near reading size (the tutorial's 7×7).
        case closeUp
        case between
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var host: UIHostingController<HostedBoard>?
        var boardSize: CGSize = .zero
        var lastFocusID: BoardFocusID?
        var showedWholeBoard = false
        /// The latest word to keep in view and motion setting, kept here so
        /// the intro uses them as they are when it runs.
        var focus: CGRect?
        var reduceMotion = false
        /// The zoom a level opens at (see BoardMetrics).
        var openingZoom: CGFloat = 1
        /// What a tap on the board does, given the point on the drawn board.
        var onTap: ((CGPoint) -> Void)?
        var onPinchEnded: ((PinchResult) -> Void)?
        var onCameraChange: ((BoardCamera) -> Void)?
        /// The board's sizes, for the camera reports.
        var metrics: BoardMetrics?
        /// The last camera reported, so a scroll that doesn't move (UIKit
        /// calls back on every layout) isn't reported again.
        private var reportedCamera: BoardCamera?
        /// The zoom in progress comes from the player's fingers, not from
        /// the board following a word.
        private var isPlayerPinching = false
        /// The player has dragged or pinched: from then on the board stays
        /// where they put it unless a new word needs bringing into view.
        private var playerMoved = false
        /// The intro is showing the whole board and about to zoom in.
        private var introPending = false

        /// How long the whole board shows once it's on screen before zooming
        /// in (the zoom itself takes about 0.3s), and the margin kept around
        /// a word brought into view.
        private let introPause: TimeInterval = 0.15
        private let margin: CGFloat = 6

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { host?.view }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centre(scrollView)
            reportCamera(of: scrollView)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) { reportCamera(of: scrollView) }

        // Only the player's own gestures call these, not zoom(to:).
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { playerMoved = true }
        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            playerMoved = true
            // Checked on the pinch itself as well, so the board's own
            // animated moves can never count as the player's pinch.
            let pinch = scrollView.pinchGestureRecognizer?.state
            isPlayerPinching = pinch == .began || pinch == .changed
        }

        /// UIKit calls this once the fingers are up and any bounce back
        /// into the zoom range is over.
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            guard isPlayerPinching else { return }
            isPlayerPinching = false
            let minimum = scrollView.minimumZoomScale
            let range = scrollView.maximumZoomScale - minimum
            // Within a tenth of the range of the whole board counts as all
            // of it: a pinch rarely stops on the exact limit.
            let share = range > 0 ? (min(max(scale, minimum), scrollView.maximumZoomScale) - minimum) / range : 0
            if share <= 0.1 {
                onPinchEnded?(.wholeBoard)
            } else if share >= 0.5 {
                onPinchEnded?(.closeUp)
            } else {
                onPinchEnded?(.between)
            }
        }

        /// Tells the lesson where the board is now. Sent on the next turn of
        /// the main loop: UIKit scrolls during SwiftUI's own updates (when
        /// the board is resized), and changing what SwiftUI watches in the
        /// middle of an update isn't allowed.
        func reportCamera(of scrollView: UIScrollView) {
            guard let onCameraChange, let metrics else { return }
            let camera = BoardCamera(metrics: metrics, scale: scrollView.zoomScale, offset: scrollView.contentOffset)
            guard camera != reportedCamera else { return }
            reportedCamera = camera
            DispatchQueue.main.async { onCameraChange(camera) }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let hostView = host?.view else { return }
            // In the board's own coordinates, so the zoom doesn't matter.
            onTap?(recognizer.location(in: hostView))
        }

        /// Keeps a board smaller than the frame (zoomed out) in the middle
        /// of it rather than in the top-left corner.
        func centre(_ scrollView: UIScrollView) {
            let size = scrollView.contentSize
            let bounds = scrollView.bounds.size
            let x = max(0, (bounds.width - size.width) / 2)
            let y = max(0, (bounds.height - size.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
        }

        /// The level opens on the whole board, then zooms in to the word.
        func playIntro(in scrollView: UIScrollView) {
            // Nothing to zoom in to when the level opens on the whole board.
            if reduceMotion || opensWhole(scrollView) {
                if let focus {
                    show(focus, in: scrollView, animated: false)
                } else {
                    showWholeBoard(in: scrollView, animated: false)
                }
                return
            }
            showWholeBoard(in: scrollView, animated: false)
            introPending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + introPause) { [weak self, weak scrollView] in
                guard let self, let scrollView else { return }
                self.introPending = false
                // Already moved by the player: they've found the board.
                // A flag rather than comparing the zoom with the minimum,
                // which can change in the meantime if the screen re-lays out.
                guard !self.playerMoved, !self.showedWholeBoard, let focus = self.focus else { return }
                self.show(focus, in: scrollView, animated: true)
            }
        }

        /// Puts the board back where it belongs after the frame or the
        /// cells changed size: the same view as before, at the new size.
        func settle(in scrollView: UIScrollView) {
            centre(scrollView)
            if showedWholeBoard || introPending {
                showWholeBoard(in: scrollView, animated: false)
            } else if !playerMoved, let focus {
                show(focus, in: scrollView, animated: false)
            }
            // Moved by the player: apply() has already kept the zoom in range.
        }

        /// The whole board, centred. Through zoom(to:) rather than setting
        /// the zoom scale, which can leave it in the top-left corner.
        func showWholeBoard(in scrollView: UIScrollView, animated: Bool) {
            // The centring insets for the zoomed-out size go in first: UIKit
            // keeps the scroll position within the insets in place when it
            // zooms, and at reading size those are still zero.
            let scale = scrollView.minimumZoomScale
            let bounds = scrollView.bounds.size
            let x = max(0, (bounds.width - boardSize.width * scale) / 2)
            let y = max(0, (bounds.height - boardSize.height * scale) / 2)
            scrollView.contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
            scrollView.zoom(to: CGRect(origin: .zero, size: boardSize), animated: animated)
        }

        /// Brings a word fully into view with the smallest move: no move
        /// if it's already all visible, a slide at the same zoom if it fits,
        /// and zooming out only if it's longer than the frame.
        func reveal(_ word: CGRect, in scrollView: UIScrollView, animated: Bool) {
            guard let hostView = host?.view else { return }
            // The margin stops at the board's edge, or a word along the edge
            // could never count as fully visible.
            let target = word.insetBy(dx: -margin, dy: -margin)
                .intersection(CGRect(origin: .zero, size: boardSize))
            let visible = scrollView.convert(scrollView.bounds, to: hostView)
            if visible.contains(target) { return }
            guard target.width <= visible.width, target.height <= visible.height else {
                scrollView.zoom(to: target, animated: animated)
                return
            }
            let dx = target.minX < visible.minX ? target.minX - visible.minX
                : target.maxX > visible.maxX ? target.maxX - visible.maxX : 0
            let dy = target.minY < visible.minY ? target.minY - visible.minY
                : target.maxY > visible.maxY ? target.maxY - visible.maxY : 0
            scrollView.zoom(to: visible.offsetBy(dx: dx, dy: dy), animated: animated)
        }

        private func opensWhole(_ scrollView: UIScrollView) -> Bool {
            openingZoom <= scrollView.minimumZoomScale + 0.001
        }

        /// Back to the opening view at a word: the whole board if the level
        /// opens on it; otherwise the word at reading size, as close to the
        /// frame's top-left as the board allows, so the rest of the board
        /// lies ahead of it. A word longer than the frame is zoomed out to fit.
        func show(_ word: CGRect, in scrollView: UIScrollView, animated: Bool) {
            guard !opensWhole(scrollView) else {
                showWholeBoard(in: scrollView, animated: animated)
                return
            }
            // How much of the drawn board the frame shows at reading size.
            let side = scrollView.bounds.width / openingZoom
            let padded = word.insetBy(dx: -margin, dy: -margin).intersection(CGRect(origin: .zero, size: boardSize))
            guard padded.width <= side, padded.height <= side else {
                scrollView.zoom(to: padded, animated: animated)
                return
            }
            let origin = CGPoint(
                x: min(max(0, word.minX - margin), max(0, boardSize.width - side)),
                y: min(max(0, word.minY - margin), max(0, boardSize.height - side))
            )
            scrollView.zoom(to: CGRect(origin: origin, size: CGSize(width: side, height: side)), animated: animated)
        }
    }
}

/// The board as the hosting controller shows it, with what it needs from
/// the SwiftUI environment outside, which doesn't reach inside by itself.
struct HostedBoard: View {
    let model: LevelViewModel
    let metrics: BoardMetrics
    let locale: Locale

    var body: some View {
        BoardGrid(model: model, metrics: metrics)
            .environment(\.locale, locale)
    }
}

/// A scroll view that says when it's first on screen with a size, which is
/// when the intro can start (before that there's nothing to see, and no
/// frame to fit the board to). It also attaches the board's hosting
/// controller to the screen's view controller, as UIKit expects of a view
/// controller whose view is shown.
final class FirstLayoutScrollView: UIScrollView {
    var onFirstShown: (() -> Void)?
    /// Called when the size changes after the board was first shown.
    var onResize: (() -> Void)?
    var hostedController: UIViewController?
    private(set) var wasShown = false
    private var shownSize: CGSize = .zero

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        attachHostedController()
        showIfReady()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Scrolling lays out too; only a real size change counts.
        if wasShown, bounds.size != shownSize {
            shownSize = bounds.size
            onResize?()
        }
        showIfReady()
    }

    private func showIfReady() {
        guard !wasShown, window != nil, bounds.width > 0 else { return }
        wasShown = true
        shownSize = bounds.size
        onFirstShown?()
        onFirstShown = nil
    }

    /// The nearest view controller up the responder chain becomes the
    /// hosting controller's parent.
    private func attachHostedController() {
        guard let child = hostedController, child.parent == nil else { return }
        var responder: UIResponder? = next
        while let current = responder, !(current is UIViewController) { responder = current.next }
        guard let parent = responder as? UIViewController else { return }
        parent.addChild(child)
        child.didMove(toParent: parent)
    }
}
