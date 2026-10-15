import SwiftUI
import ArrowwordCore

/// Grandma's lesson on top of the level screen: everything dimmed except
/// what she's talking about, a pulsing ring on what to tap, her card with
/// the words, and a Skip button.
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
            let target = model.tutorialTarget.flatMap { frames.union(of: [.target($0)]) }
            let lit = frames.union(of: litIDs)
            // While a word is lit, so is the clue bar: it shows the same
            // clue, larger and easier to read than its clue cell. Only when
            // the bar does show that word's clue (a step can point at a word
            // before the player has selected it). Its arrows can be tapped
            // through the hole but do nothing in the lesson.
            let barShowsLitWord = model.activeAnswer.map { model.tutorialLitClue == .clue(answerID: $0.id) } ?? false
            let clueBar = barShowsLitWord ? frames.rects[.clueBar] : nil
            let holes = [target?.insetBy(dx: -6, dy: -6), lit?.insetBy(dx: -4, dy: -4), clueBar?.insetBy(dx: -4, dy: -4)]
                .compactMap { $0 }

            ZStack {
                DimmingLayer(holes: holes)
                    .ignoresSafeArea()
                GuideLayer(
                    text: line.text,
                    showsNext: model.tutorialWaitsForNext,
                    target: target,
                    lit: lit,
                    clueBar: clueBar,
                    onNext: model.tutorialNext,
                    onSkip: model.skipTutorial
                )
            }
            .transition(.opacity)
        }
    }

    /// The lit word's clue and cells, as one hole.
    private var litIDs: [SpotlightID] {
        let clue = model.tutorialLitClue.map { [SpotlightID.target($0)] } ?? []
        return clue + model.tutorialLitCells.map(SpotlightID.cell)
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

/// The ring, grandma's card and Skip, laid out inside the safe area.
private struct GuideLayer: View {
    let text: String
    let showsNext: Bool
    /// What to tap, in the level screen's coordinate space.
    let target: CGRect?
    /// The word she's talking about, in the same space.
    let lit: CGRect?
    /// The clue bar, when it's lit with the word.
    let clueBar: CGRect?
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
                if let localTarget {
                    PulsingRing(rect: localTarget.insetBy(dx: -6, dy: -6))
                }
                card
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
                    .position(x: proxy.size.width / 2, y: cardTop + cardHeight / 2)
                    .animation(.easeInOut(duration: 0.25), value: cardTop)
                skipButton
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
    /// What grandma says at each step. Two lines name the lesson board's
    /// words (CAT and its T in English; ÇAY and its Y in Turkish), so each
    /// language's translation goes with its own tutorial-<lang>.json.
    var text: String {
        switch self {
        case .welcome:
            String(localized: "Hello, dear! Let me show you how my puzzles work.", bundle: .appLanguage, locale: .appLanguage)
        case .clueBox:
            String(localized: "Each clue sits in a little box. The arrow shows where its answer goes.", bundle: .appLanguage, locale: .appLanguage)
        case .typeWord:
            String(localized: "A purring pet… that's CAT! Tap the glowing letters to write it in.", bundle: .appLanguage, locale: .appLanguage)
        case .tapClue:
            String(localized: "Lovely! Now tap this clue to start the next word.", bundle: .appLanguage, locale: .appLanguage)
        case .catHelps:
            String(localized: "The T is already there: words share letters. Stuck on the next one? Tap my cat!", bundle: .appLanguage, locale: .appLanguage)
        case .finishWord:
            String(localized: "Clever cat! Now put in the last letter yourself.", bundle: .appLanguage, locale: .appLanguage)
        case .askGrandma:
            String(localized: "For a whole word, just ask me. Tap me!", bundle: .appLanguage, locale: .appLanguage)
        case .submit:
            String(localized: "All filled in! Tap Submit to see how you did.", bundle: .appLanguage, locale: .appLanguage)
        }
    }
}
