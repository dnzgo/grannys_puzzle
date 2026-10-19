import SwiftUI
import ArrowwordCore

/// Grandma's lesson on top of the level screen: everything dimmed except
/// what she's talking about, a pulsing ring on what to tap, her hand
/// showing how, her card with the words, and a Skip button.
///
/// The dimming also swallows taps everywhere outside the holes, so the
/// back and settings buttons can't be hit mid-lesson. Which taps *count*
/// is still decided by the coach (through the view model); the holes are
/// how the player sees where to tap, not the rule itself.
struct TutorialOverlay: View {
    let model: LevelViewModel
    let frames: SpotlightFrames

    var body: some View {
        if let line = model.tutorialLine {
            let targetRect = model.tutorialTarget.flatMap(rect(of:))
            let lit = litRect
            // While a word is lit, so is the clue bar: it shows the same
            // clue, larger and easier to read than its clue cell. Only when
            // the bar does show that word's clue (a step can point at a word
            // before the player has selected it).
            let barShowsLitWord = model.activeAnswer.map { $0.id == model.tutorialLitAnswerID } ?? false
            let clueBar = barShowsLitWord ? frames.rects[.clueBar] : nil
            let holes = [targetRect?.insetBy(dx: -6, dy: -6), lit?.insetBy(dx: -4, dy: -4), clueBar?.insetBy(dx: -4, dy: -4)]
                .compactMap { $0 }

            ZStack {
                DimmingLayer(holes: holes)
                    .ignoresSafeArea()
                GuideLayer(
                    text: line.text,
                    showsNext: model.tutorialWaitsForNext,
                    target: targetRect,
                    // The board is pinched, not tapped: the hand shows how,
                    // and a ring round the whole board would only frame it.
                    ringsTarget: !isZoomStep,
                    lit: lit,
                    clueBar: clueBar,
                    hand: hand(target: targetRect, line: line),
                    handKey: HandKey(step: model.tutorialStep, target: model.tutorialTarget, visitsClueBar: visitsClueBar(line)),
                    onNext: model.tutorialNext,
                    onSkip: model.skipTutorial
                )
            }
            .transition(.opacity)
        }
    }

    private var isZoomStep: Bool {
        model.tutorialTarget == .zoomOut || model.tutorialTarget == .zoomIn
    }

    /// Where the thing to act on is, in the level screen's space. Things on
    /// the board are found through its camera, since it zooms and slides.
    private func rect(of target: TutorialTarget) -> CGRect? {
        switch target {
        case .zoomOut, .zoomIn: frames.rects[.board]
        case .clue(let id): frames.boardRect(ofClue: id, in: model.level)
        case .cell(let cell): frames.boardRect(around: [cell])
        case .key, .cat, .grandma, .submit: frames.rects[.target(target)]
        }
    }

    /// The lit word's clue and cells, as one hole.
    private var litRect: CGRect? {
        guard let id = model.tutorialLitAnswerID else { return nil }
        let rects = [frames.boardRect(ofClue: id, in: model.level), frames.boardRect(around: model.tutorialLitCells)]
        return rects.compactMap { $0 }.reduce(nil as CGRect?) { $0?.union($1) ?? $1 }
    }

    /// On the first letter of the word to type, the hand first points up
    /// at the clue bar, which the card says shows the clue too. After that
    /// it only taps the keys, which change with every letter.
    private func visitsClueBar(_ line: TutorialLine) -> Bool {
        line == .typeWord && model.tutorialLitCells.allSatisfy { model.puzzle.entries[$0]?.source != .placed }
    }

    /// What grandma's hand does for this step; nil when what it would
    /// point at isn't on screen (slid out of the board's window).
    private func hand(target: CGRect?, line: TutorialLine) -> HandMotion? {
        guard let target, let kind = model.tutorialTarget else { return nil }
        let centre = CGPoint(x: target.midX, y: target.midY)
        switch kind {
        case .zoomOut:
            return .pinchClosing(at: centre)
        case .zoomIn:
            // Then a slide across the middle, the other thing the card says.
            let slide = min(60, target.width / 4)
            return .pinchOpeningThenSlide(
                at: centre,
                from: CGPoint(x: centre.x + slide, y: centre.y + slide / 2),
                to: CGPoint(x: centre.x - slide, y: centre.y + slide / 2)
            )
        case .cell:
            return .doubleTap(at: centre)
        case .key where visitsClueBar(line):
            guard let bar = frames.rects[.clueBar] else { return .tap(at: centre) }
            return .point(at: CGPoint(x: bar.midX, y: bar.midY), thenTap: centre)
        case .key, .clue, .cat, .grandma, .submit:
            return .tap(at: centre)
        }
    }
}

/// The dark layer with holes cut out. Its own geometry reader converts the
/// holes from the level screen's coordinate space to its own, because it
/// reaches into the safe areas and so doesn't start at the same point.
private struct DimmingLayer: View {
    let holes: [CGRect]

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .named(SpotlightFrames.spaceName)).origin
            let shape = Self.path(size: proxy.size, holes: holes.map { $0.offsetBy(dx: -origin.x, dy: -origin.y) })
            // The holes are cut out of the shape itself, so they're both
            // undrawn and untappable: taps there fall through to the button
            // underneath.
            shape
                .fill(Color.black.opacity(0.45))
                .contentShape(shape)
                .onTapGesture {}
                .accessibilityHidden(true)
        }
    }

    /// The screen minus the holes. The holes are joined first: cut one by
    /// one with an even-odd fill, two that overlap (the clue bar and the
    /// word just below it, on a small screen) would dim their overlap again.
    private static func path(size: CGSize, holes: [CGRect]) -> Path {
        let joinedHoles = holes.reduce(Path()) { joined, hole in
            joined.union(Path(roundedRect: hole, cornerSize: CGSize(width: 12, height: 12)))
        }
        return Path(CGRect(origin: .zero, size: size)).subtracting(joinedHoles)
    }
}

/// The ring, grandma's card, Skip and her hand, laid out inside the safe area.
private struct GuideLayer: View {
    let text: String
    let showsNext: Bool
    /// What to act on, in the level screen's coordinate space.
    let target: CGRect?
    let ringsTarget: Bool
    /// The word she's talking about, in the same space.
    let lit: CGRect?
    /// The clue bar, when it's lit with the word.
    let clueBar: CGRect?
    /// Grandma's hand showing what to do, in the same space.
    let hand: HandMotion?
    /// Changes when the hand should start its motion over.
    let handKey: HandKey
    let onNext: () -> Void
    let onSkip: () -> Void

    /// The card's measured height, needed to find a spot it fits in. The
    /// starting guess only matters for the first frame.
    @State private var cardHeight: CGFloat = 120

    private let gap: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .named(SpotlightFrames.spaceName)).origin
            let toLocal = { (rect: CGRect) in rect.offsetBy(dx: -origin.x, dy: -origin.y) }
            let localTarget = target.map(toLocal)
            let cardTop = Self.cardTop(
                cardHeight: cardHeight,
                in: proxy.size,
                target: localTarget,
                lit: lit.map(toLocal),
                clueBar: clueBar.map(toLocal),
                gap: gap
            )

            ZStack(alignment: .topTrailing) {
                if let localTarget, ringsTarget {
                    PulsingRing(rect: localTarget.insetBy(dx: -6, dy: -6))
                }
                card
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
                    .position(x: proxy.size.width / 2, y: cardTop + cardHeight / 2)
                    .animation(.easeInOut(duration: 0.25), value: cardTop)
                skipButton
                // On top of the card: on its way between two places the
                // hand can pass over it, and shouldn't vanish behind it.
                if let hand {
                    TutorialHand(motion: hand.offsetBy(dx: -origin.x, dy: -origin.y), restartKey: handKey)
                }
            }
        }
        .onAppear { announce() }
        .onChange(of: text) { announce() }
    }

    /// Where the card's top edge goes: the first of a few natural spots
    /// that covers neither the thing to tap nor the word being filled, so
    /// the player always sees both the button and the letters landing.
    ///
    /// - A target low on the screen (tray, helpers, Submit): just above it,
    ///   else at the very top, over the top bar (unless the bar is lit).
    /// - A target high up (a clue): at the bottom, else just below it.
    /// - Nothing to tap: at the bottom, else the top, else the middle.
    ///
    /// The middle is the last resort for every case, which matters once the
    /// lit clue bar takes the top. If no spot is clear (a very small
    /// screen), the first one is used.
    static func cardTop(cardHeight: CGFloat, in size: CGSize, target: CGRect?, lit: CGRect?, clueBar: CGRect?, gap: CGFloat) -> CGFloat {
        let top = gap / 2
        let bottom = size.height - gap - cardHeight
        let middle = (size.height - cardHeight) / 2

        let candidates: [CGFloat]
        if let target, target.midY > size.height / 2 {
            candidates = [target.minY - gap - cardHeight, top]
        } else if let target {
            candidates = [bottom, target.maxY + gap]
        } else if lit != nil {
            candidates = [bottom, top]
        } else {
            candidates = [middle]
        }

        let keepClear = [target, lit, clueBar].compactMap { $0 }
        let maxTop = max(0, size.height - cardHeight)
        let clamped = (candidates + [middle]).map { min(max($0, 0), maxTop) }
        let isClear = { (cardTop: CGFloat) in
            let card = CGRect(x: 0, y: cardTop, width: size.width, height: cardHeight)
            return !keepClear.contains { $0.intersects(card) }
        }
        return clamped.first(where: isClear) ?? clamped[0]
    }

    private var card: some View {
        HStack(alignment: .top, spacing: 12) {
            HelperFaceImage(face: .grandma, size: 56)

            VStack(alignment: .leading, spacing: 10) {
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if showsNext {
                    Button(action: onNext) {
                        Text("Next")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.onPrimary)
                            .padding(.horizontal, 22)
                            .frame(height: 40)
                            .background(Capsule().fill(Theme.primary))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        )
        .padding(.horizontal, Theme.sidePadding)
        .accessibilityElement(children: .contain)
    }

    private var skipButton: some View {
        Button(action: onSkip) {
            Text("Skip")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(Capsule().fill(Theme.surface))
        }
        .buttonStyle(.plain)
        .padding(.trailing, Theme.sidePadding)
        .padding(.top, 8)
        .accessibilityHint("Leaves the lesson")
    }

    /// VoiceOver users can't see the spotlight, so each new line is read out.
    private func announce() {
        AccessibilityNotification.Announcement(text).post()
    }
}

/// The ring around what to tap. It breathes gently, or holds still with
/// Reduce Motion on.
private struct PulsingRing: View {
    let rect: CGRect

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Theme.primary, lineWidth: 3)
            .frame(width: rect.width, height: rect.height)
            .scaleEffect(isExpanded ? 1.08 : 1)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    isExpanded = true
                }
            }
    }
}

// MARK: - Grandma's words

extension TutorialLine {
    /// What grandma says at each step. The typing line names the lesson
    /// board's word (TEA in English, OYA in Turkish), so each language's
    /// translation goes with its own tutorial-<lang>.json.
    var text: String {
        switch self {
        case .zoomOut:
            String(localized: "Hello, dear! This puzzle is bigger than your screen. Pinch your fingers together to see all of it.", bundle: .appLanguage, locale: .appLanguage)
        case .zoomIn:
            String(localized: "Now spread them apart to look closer. You can slide the board around, too.", bundle: .appLanguage, locale: .appLanguage)
        case .clueBox:
            String(localized: "Each box with words is a clue, and its arrow shows where the answer goes. Tap this one!", bundle: .appLanguage, locale: .appLanguage)
        case .typeWord:
            String(localized: "Its clue shows up top too, nice and big. A hot drink… that's TEA! Tap the glowing letters.", bundle: .appLanguage, locale: .appLanguage)
        case .switchDirection:
            String(localized: "Some letters belong to two words. Tap this square twice to turn to the word going down.", bundle: .appLanguage, locale: .appLanguage)
        case .catHelps:
            String(localized: "Stuck on a letter? Tap my cat, she'll show you one!", bundle: .appLanguage, locale: .appLanguage)
        case .askGrandma:
            String(localized: "For a whole word, just ask me. Tap me!", bundle: .appLanguage, locale: .appLanguage)
        case .submit:
            String(localized: "All filled in! Tap Submit to see how you did.", bundle: .appLanguage, locale: .appLanguage)
        }
    }
}
