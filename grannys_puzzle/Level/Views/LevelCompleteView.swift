import SwiftUI
import ArrowwordCore

/// The celebration after a passed level, in short beats:
/// 1. the score, with the cat celebrating and the new yarn at his paws;
/// 2. the balls fly one by one into grandma's yarn bag;
/// 3. if this yarn made a new item affordable, grandma says so;
/// 4. Next level and Home.
///
/// The card itself is shared with a fail (LevelEndCard); this view adds the
/// celebration on it.
///
/// About two and a half seconds in all, and a tap anywhere jumps straight
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
        case playing
        case flying
        case done
    }

    @State private var beat = Beat.playing
    /// How many balls have left the cat for the bag, and how many are in.
    @State private var flown = 0
    @State private var landed = 0
    @State private var rolling = false
    @State private var bagBounce = false
    @State private var feedback: FeedbackSignal?
    /// Picked once, so the line doesn't change while it's on screen.
    @State private var nudgeLine: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The stage is drawn on a fixed grid so the balls can travel exactly
    // from the cat's paws to the bag's mouth.
    private let stageSize = CGSize(width: 280, height: 230)
    private let catSize: CGFloat = 110
    private let ballSize: CGFloat = 34
    private let bagHeight: CGFloat = 86
    private var pawsY: CGFloat { 128 }
    private var bagMouthY: CGFloat { stageSize.height - bagHeight + 18 }

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
        ZStack {
            CatCelebration(size: catSize)
                .position(x: stageSize.width / 2, y: catSize / 2 + 8)

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
                .position(x: stageSize.width / 2, y: stageSize.height - bagHeight / 2)

            ForEach(Array(yarn.enumerated()), id: \.offset) { index, color in
                ball(index: index, color: color)
            }
        }
        .frame(width: stageSize.width, height: stageSize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(yarn.count) yarn balls for grandma's bag"))
    }

    /// One ball: at the cat's paws, rolling, until its turn to fly; then in
    /// the bag's mouth, shrinking as it drops in.
    private func ball(index: Int, color: YarnColor) -> some View {
        let hasFlown = index < flown
        let hasLanded = index < landed
        // Side by side at the paws; bunched together at the bag's mouth.
        let spread = CGFloat(index) - CGFloat(yarn.count - 1) / 2
        let x = stageSize.width / 2 + spread * (hasFlown ? 10 : ballSize + 8)
        let y = hasFlown ? bagMouthY : pawsY
        let roll = rolling && !hasFlown ? (index.isMultiple(of: 2) ? 7.0 : -7.0) : 0

        return YarnBall(color: color, size: ballSize)
            .rotationEffect(.degrees(roll * 6))
            .scaleEffect(hasLanded ? 0.4 : 1)
            .opacity(hasLanded ? 0 : 1)
            .position(x: x + roll, y: y)
    }

    // MARK: - The sequence

    private func play() async {
        nudgeLine = newlyKnittable.map(KnitNudgeLines.random(for:))
        if reduceMotion {
            skipToEnd()
            return
        }
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) { rolling = true }

        // Beat 1: the score and the cat with his yarn.
        guard await pause(0.9) else { return }

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
            String(localized: "Look at all that yarn! I could knit the cat a \(name). Pop by my yarn bag when you like.", bundle: .appLanguage, locale: .appLanguage),
            String(localized: "That's enough for a \(name), sweetheart. I'll have my needles ready!", bundle: .appLanguage, locale: .appLanguage),
        ]
        return lines.randomElement() ?? lines[0]
    }
}
