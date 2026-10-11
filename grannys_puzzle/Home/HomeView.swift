import SwiftUI
import ArrowwordCore

/// The home screen: grandma in her armchair with the cat, the treat jar and
/// the yarn bag around her, and the Play button.
///
/// Each character is its own small view (`GrannyView`, `CatBedView`, …) so
/// that adding animation later only changes what's inside that view, not
/// this layout. Today they're still images.
struct HomeView: View {
    let game: Game

    @State private var speech = GrandmaSpeech()
    @State private var showsYarnBag = false
    @State private var showsWardrobe = false
    /// The item whose knitting moment is playing, if any.
    @State private var knittingItem: KnitItem?

    var body: some View {
        VStack(spacing: 0) {
            topRow
                .padding(.horizontal, Theme.sidePadding)
                .padding(.top, 4)

            HomeStage(
                progress: game.progress,
                canKnit: game.canKnitSomething,
                speechLine: speech.line,
                onGranny: { speech.say(GrandmaLines.greeting()) },
                onCat: { speech.say(GrandmaLines.catNapping) },
                onJar: { speech.say(GrandmaLines.jarComingSoon) },
                onYarnBag: { showsYarnBag = true }
            )
            .animation(.easeOut(duration: 0.2), value: speech.line)

            playButton
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.light)
        .sheet(isPresented: $showsYarnBag) {
            YarnBagSheet(progress: game.progress, catalog: game.catalog, onKnit: startKnitting)
        }
        .sheet(isPresented: $showsWardrobe) {
            WardrobeSheet(progress: game.progress, catalog: game.catalog)
        }
        .overlay {
            if let item = knittingItem {
                KnittingMoment(item: item) {
                    knittingItem = nil
                    speech.say(GrandmaLines.knitted)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: knittingItem)
        .onAppear {
            speech.say(game.nextLevelNumber == nil ? GrandmaLines.allLevelsDone : GrandmaLines.greeting())
        }
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            HelperCountChip(systemImage: "cat.fill", count: game.progress.hints, label: "Cat hints")
            HelperCountChip(systemImage: "eyeglasses", count: game.progress.grandmas, label: "Grandma helpers")
            Spacer()
            CircleIconButton(systemName: "hanger", label: "Wardrobe") { showsWardrobe = true }
            // Settings gets its action when the settings screen exists.
            CircleIconButton(systemName: "gearshape", label: "Settings") {}
        }
        .frame(height: BoardMetrics.topBarHeight)
    }

    /// Knitting is saved first; the moment on screen is only the reveal.
    private func startKnitting(_ item: KnitItem) {
        if game.knit(item) {
            knittingItem = item
        }
    }

    @ViewBuilder
    private var playButton: some View {
        if let number = game.nextLevelNumber {
            PrimaryButton(title: "Level \(number)", height: 60) {
                withAnimation(.easeInOut(duration: 0.25)) { game.play() }
            }
        } else {
            Text("More puzzles soon!")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .overlay(Capsule().strokeBorder(Theme.secondary, lineWidth: 2))
        }
    }
}

// MARK: - The stage

/// Grandma's corner, laid out on a square-ish "stage" that scales with the
/// screen. Positions are fractions of the stage size, so the scene keeps its
/// composition from an iPhone SE to a Pro Max.
private struct HomeStage: View {
    let progress: PlayerProgress
    let canKnit: Bool
    let speechLine: String?
    let onGranny: () -> Void
    let onCat: () -> Void
    let onJar: () -> Void
    let onYarnBag: () -> Void

    /// Stage height as a multiple of its width.
    private let aspect: CGFloat = 1.1

    var body: some View {
        GeometryReader { geometry in
            // The largest stage that fits, centred in the space available.
            let side = min(geometry.size.width, geometry.size.height / aspect)
            let origin = CGPoint(
                x: (geometry.size.width - side) / 2,
                y: (geometry.size.height - side * aspect) / 2
            )
            // A point on the stage, from fractions of its width.
            let at = { (x: CGFloat, y: CGFloat) in CGPoint(x: origin.x + x * side, y: origin.y + y * side) }

            ZStack {
                // Back to front, like layers of a painting.
                Ellipse()
                    .fill(Theme.clueCell)
                    .frame(width: side * 0.95, height: side * 0.24)
                    .position(at(0.5, 0.88))

                JarView(width: side * 0.2, action: onJar)
                    .position(at(0.86, 0.66))

                GrannyView(width: side * 0.6, action: onGranny)
                    .position(at(0.5, 0.52))

                CatBedView(width: side * 0.36, action: onCat)
                    .position(at(0.17, 0.83))

                YarnBagView(progress: progress, canKnit: canKnit, width: side * 0.26, action: onYarnBag)
                    .position(at(0.83, 0.9))

                if let speechLine {
                    SpeechBubble(text: speechLine)
                        .position(at(0.5, 0.12))
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                }
            }
        }
    }
}

// MARK: - Characters and props

/// Grandma in her armchair. Later: talking and knitting animations.
private struct GrannyView: View {
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("granny").resizable().scaledToFit().frame(width: width)
        }
        .buttonStyle(SceneButtonStyle())
        .accessibilityLabel("Grandma")
    }
}

/// The cat in its bed. Later: paw licking and tail waving.
private struct CatBedView: View {
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("cat-bed").resizable().scaledToFit().frame(width: width)
        }
        .buttonStyle(SceneButtonStyle())
        .accessibilityLabel("The cat")
    }
}

/// The daily treat jar. Later: shakes and opens for the daily reward.
private struct JarView: View {
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("jar").resizable().scaledToFit().frame(width: width)
        }
        .buttonStyle(SceneButtonStyle())
        .accessibilityLabel("Treat jar")
    }
}

/// Placeholder yarn bag until the artwork arrives: a wicker basket drawn in
/// code, with the player's three most plentiful colours on top and the
/// total count as a badge.
private struct YarnBagView: View {
    let progress: PlayerProgress
    /// Shows a "Knit!" tag when there's enough yarn for something new.
    let canKnit: Bool
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                HStack(spacing: -width * 0.1) {
                    ForEach(Array(topColors.enumerated()), id: \.offset) { _, color in
                        YarnBall(color: color, size: width * 0.42)
                    }
                }
                .offset(y: -width * 0.36)

                basket
            }
            .frame(width: width, height: width * 0.95, alignment: .bottom)
            .overlay(alignment: .topTrailing) { countBadge }
            .overlay(alignment: .top) {
                if canKnit { knitTag.offset(y: -width * 0.32) }
            }
        }
        .buttonStyle(SceneButtonStyle())
        .accessibilityLabel("Yarn bag")
        .accessibilityValue("\(progress.totalYarn) balls")
        .accessibilityHint(canKnit ? Text("Enough yarn to knit something") : Text(""))
    }

    private var knitTag: some View {
        Text("Knit!")
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.onPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.primary))
            .shadow(color: Theme.primary.opacity(0.4), radius: 4, y: 2)
    }

    private var basket: some View {
        RoundedRectangle(cornerRadius: width * 0.12)
            .fill(Color(hex: 0xC08A5B))
            .overlay {
                // Wicker bands.
                VStack(spacing: width * 0.07) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().fill(Color(hex: 0xA06E44)).frame(height: width * 0.04)
                    }
                }
                .padding(.horizontal, width * 0.08)
            }
            .frame(width: width, height: width * 0.5)
            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }

    /// The colours to show on top: most balls first; if the bag is empty,
    /// the starting colours as a hint of what's to come.
    private var topColors: [YarnColor] {
        let owned = YarnColor.allCases
            .filter { progress.yarnCount(of: $0) > 0 }
            .sorted { progress.yarnCount(of: $0) > progress.yarnCount(of: $1) }
        return Array((owned.isEmpty ? YarnColor.allCases : owned).prefix(3))
    }

    private var countBadge: some View {
        Text("\(progress.totalYarn)")
            .font(.system(size: 13, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 24, minHeight: 24)
            .background(Capsule().fill(Theme.ink))
            .overlay(Capsule().strokeBorder(Theme.background, lineWidth: 2))
    }
}

/// A small pill showing how many of a helper the player has.
private struct HelperCountChip: View {
    let systemImage: String
    let count: Int
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primary)
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Capsule().fill(Theme.surface).shadow(color: .black.opacity(0.06), radius: 1, y: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(count)")
    }
}

/// Scene objects shrink a little while pressed, so they feel touchable even
/// before they have real animations.
private struct SceneButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    if let game = Game.preview() {
        HomeView(game: game)
    }
}
