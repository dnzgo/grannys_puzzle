import SwiftUI
import ArrowwordCore
import Foundation

/// The celebration after a passed level, in short beats:
/// 1. the score, with the cat cheering and the new yarn circling him once,
///    like electrons round an atom;
/// 2. the balls drop one by one into grandma's yarn bag;
/// 3. if this yarn made a new item affordable, grandma says so;
/// 4. Next level and Home.
///
/// The card itself is shared with a fail (LevelEndCard); this view adds the
/// celebration on it.
///
/// About three seconds in all, and a tap anywhere jumps straight
/// to the end: players see this after every level, potentially thousands
/// of times, and a ceremony that can't be hurried turns from a treat into a
/// wait. With Reduce Motion on, it opens at the end.
///
/// Grandma only *mentions* a newly affordable item; she never stops the
/// player from going on. Someone who only wants puzzles keeps playing, and
/// everyone else is reminded that the yarn is for something.
struct LevelCompleteView: View {
    let result: LevelResult
    let yarn: [YarnColor]
    /// An item this level's yarn made affordable for the first time.
    let newlyKnittable: KnitItem?
    /// The lesson ends with a single "Let's play!", which goes home.
    let isTutorial: Bool
    let onNext: () -> Void
    let onHome: () -> Void
    /// The celebration reached its end (played through or tapped past).
    let onFinished: () -> Void

    private enum Beat {
        case orbiting
        case flying
        case done
    }

    @State private var beat = Beat.orbiting
    /// When the balls started circling; their place follows the clock.
    @State private var orbitStart = Date.now
    /// How many balls have left their orbit for the bag, and how many are in.
    @State private var flown = 0
    @State private var landed = 0
    @State private var bagBounce = false
    @State private var feedback: FeedbackSignal?
    /// Picked once, so the line doesn't change while it's on screen.
    @State private var nudgeLine: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The stage is drawn on a fixed grid so the balls can travel exactly
    // from their orbits to the bag's mouth. The cat stands on the left,
    // the bag beside him on the right, both on the floor at `groundY`.
    private let stageSize = CGSize(width: 280, height: 210)
    private let catSize: CGFloat = 140
    private let ballSize: CGFloat = 30
    private let bagHeight: CGFloat = 72
    private var groundY: CGFloat { stageSize.height - StageFloor.height / 2 - 4 }
    /// The middle of his picture: his feet are on the floor.
    private var catCenter: CGPoint { CGPoint(x: 98, y: groundY - catSize / 2) }
    private var bagX: CGFloat { 222 }
    private var bagMouth: CGPoint { CGPoint(x: bagX, y: groundY - bagHeight + 14) }

    /// One full turn round the cat.
    private let orbitSeconds = 1.3
    /// Each orbit is a flat ellipse (wide, shallow: a circle seen from the
    /// side), tipped at its own angle, so the paths cross like an atom's.
    /// Narrow enough to clear the bag beside him.
    private let orbitWidth: CGFloat = 78
    private let orbitDepth: CGFloat = 28
    private let orbitTilts: [Double] = [-50, 0, 50]

    var body: some View {
        LevelEndCard(result: result) {
            stage
        } footer: {
            if beat == .done {
                if let nudgeLine {
                    LevelEndGrandmaLine(text: nudgeLine)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                LevelEndButtons(
                    primaryTitle: isTutorial ? "Let's play!" : "Next level",
                    onPrimary: onNext,
                    onHome: isTutorial ? nil : onHome
                )
                .transition(.opacity)
            }
        }
        // A tap anywhere skips ahead; once the buttons are up it does
        // nothing, and the buttons take their own taps.
        .contentShape(Rectangle())
        .onTapGesture { skipToEnd() }
        .animation(.easeOut(duration: 0.25), value: beat)
        .gameFeedback(feedback)
        .task { await play() }
    }

    // MARK: - Pieces

    private var stage: some View {
        // Redrawn every frame while the balls circle (their place depends on
        // the time), and still afterwards, when ordinary animations take
        // them to the bag.
        TimelineView(.animation(paused: beat != .orbiting)) { context in
            let turn = beat == .orbiting
                ? min(max(context.date.timeIntervalSince(orbitStart) / orbitSeconds, 0), 1)
                : 1
            ZStack {
                StageFloor(width: stageSize.width - 16)
                    .position(x: stageSize.width / 2, y: groundY)
                ContactShadow(width: catSize * 0.55)
                    .position(x: catCenter.x, y: groundY)
                ContactShadow(width: bagHeight * 0.9)
                    .position(x: bagX, y: groundY)

                // He cheers while the yarn circles and drops into the bag,
                // then stands still with the buttons (or straight away
                // when the show is skipped).
                CatCelebration(size: catSize, isCheering: beat != .done)
                    .position(catCenter)
                    .zIndex(1)

                bag
                    .position(x: bagX, y: groundY - bagHeight / 2)
                    .zIndex(1)

                ForEach(Array(yarn.enumerated()), id: \.offset) { index, color in
                    ball(index: index, color: color, turn: turn)
                }
            }
        }
        .frame(width: stageSize.width, height: stageSize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(yarn.count) yarn balls for grandma's bag"))
    }

    private var bag: some View {
        Image("yarn-bag")
            .resizable()
            .scaledToFit()
            .frame(height: bagHeight)
            .scaleEffect(bagBounce ? 1.08 : 1, anchor: .bottom)
            .overlay(alignment: .topTrailing) {
                if landed > 0 {
                    Text(verbatim: "+\(landed)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.onPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.primary))
                        .offset(x: 10, y: -6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
    }

    /// One ball: on its orbit until its turn to go; then in the bag's
    /// mouth, shrinking as it drops in. On the far side of its orbit it's
    /// behind the cat and a little smaller, which is what makes the circle
    /// read as going round him rather than across him.
    private func ball(index: Int, color: YarnColor, turn: Double) -> some View {
        let hasFlown = index < flown
        let hasLanded = index < landed
        let orbit = orbitPlace(of: index, turn: turn)
        // Bunched together at the bag's mouth.
        let spread = CGFloat(index) - CGFloat(yarn.count - 1) / 2
        let point = hasFlown ? CGPoint(x: bagMouth.x + spread * 10, y: bagMouth.y) : orbit.point
        let isBehind = !hasFlown && orbit.depth < 0

        return YarnBall(color: color, size: ballSize)
            .scaleEffect(hasLanded ? 0.4 : (hasFlown ? 1 : 0.88 + 0.12 * orbit.depth))
            .opacity(hasLanded ? 0 : 1)
            .position(point)
            .zIndex(isBehind ? 0 : 2)
    }

    /// Where a ball is on its orbit after `turn` (0 to 1) of a full circle,
    /// and how near the viewer it is (-1 far side, 1 near side).
    ///
    /// The ball goes round a flat ellipse, which is then tipped by the
    /// orbit's angle (a rotation of the point about the cat's middle).
    /// The balls start spread evenly round the circle, so they never bunch.
    private func orbitPlace(of index: Int, turn: Double) -> (point: CGPoint, depth: Double) {
        let count = max(yarn.count, 1)
        let angle = 2 * Double.pi * (Double(index) / Double(count) + turn)
        let flat = CGPoint(x: orbitWidth * cos(angle), y: orbitDepth * sin(angle))
        // One ball: tipped a little, so it still sweeps behind and in front.
        let tilt = (count == 1 ? -25 : orbitTilts[index % orbitTilts.count]) * Double.pi / 180
        let tipped = CGPoint(
            x: flat.x * cos(tilt) - flat.y * sin(tilt),
            y: flat.x * sin(tilt) + flat.y * cos(tilt)
        )
        // The lower half of the ellipse is the near side.
        return (CGPoint(x: catCenter.x + tipped.x, y: catCenter.y + tipped.y), sin(angle))
    }

    // MARK: - The sequence

    private func play() async {
        nudgeLine = newlyKnittable.map(KnitNudgeLines.random(for:))
        if reduceMotion {
            skipToEnd()
            return
        }
        // Beat 1: the score, and the yarn circling the cat once.
        orbitStart = .now
        guard await pause(orbitSeconds) else { return }

        // Beat 2: one ball at a time into the bag.
        beat = .flying
        for _ in yarn.indices {
            withAnimation(.easeIn(duration: 0.35)) { flown += 1 }
            guard await pause(0.35) else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                landed += 1
                bagBounce = true
            }
            feedback = FeedbackSignal(event: .yarnLanded, id: landed)
            guard await pause(0.12) else { return }
            withAnimation(.easeOut(duration: 0.15)) { bagBounce = false }
        }

        // Beats 3 and 4: grandma's word, and the buttons.
        guard await pause(0.2) else { return }
        finish()
    }

    /// Waits, and says whether to carry on: false if the player skipped
    /// ahead meanwhile (or the view went away).
    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled && beat != .done
    }

    private func skipToEnd() {
        guard beat != .done else { return }
        flown = yarn.count
        landed = yarn.count
        bagBounce = false
        finish()
    }

    private func finish() {
        beat = .done
        onFinished()
    }
}

/// What grandma says when a level's yarn makes a new item affordable. A
/// few ways of saying it, so it doesn't sound like a notification.
enum KnitNudgeLines {
    static func random(for item: KnitItem) -> String {
        // "red scarf", in the game's language, inside a sentence.
        let name = item.displayName.lowercased(with: .appLanguage)
        let lines = [
            String(localized: "Ooh, there's enough yarn for a \(name) now, dear! Come and knit it with me.", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "Look at all that yarn! I could knit a \(name). Pop by my yarn bag when you like.", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "That's enough for a \(name), sweetheart. I'll have my needles ready!", bundle: .appLanguage, locale: .appLanguage),
        ]
        return lines.randomElement() ?? lines[0]
    }
}
