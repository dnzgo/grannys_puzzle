import SwiftUI
import ArrowwordCore

/// One compact row: back, the clue pill, settings. The level number is
/// small meta text and progress a thin bar; the clue keeps full size
/// because it's what the player reads most.
struct TopBar: View {
    let model: LevelViewModel
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            CircleIconButton(systemName: "chevron.left", label: "Home") {
                withAnimation(.easeInOut(duration: 0.25)) { model.goHome() }
            }
            CluePill(model: model)
                // The lesson keeps it lit with the word it's talking about.
                .spotlight(.clueBar)
            CircleIconButton(assetName: "icon-settings", iconSize: SettingsIcon.size, label: "Settings", action: onSettings)
        }
        .frame(height: BoardMetrics.topBarHeight)
    }
}

/// The clue being answered, in the colour of its word: the same tint as
/// its clue cell, so the bar and the grid read as one, and a change of
/// word shows at the top as a change of colour.
private struct CluePill: View {
    let model: LevelViewModel

    /// The active word's palette index; nil once the level is judged.
    private var colorIndex: Int? {
        model.activeAnswer.map { model.colorIndex(ofAnswer: $0.id) }
    }

    private var fill: Color {
        guard let colorIndex else { return Theme.surface }
        return ClueColors.fill(colorIndex, strength: ClueColors.clueBarTint)
    }

    /// Dark or white, whichever reads on the tint. Used at full strength
    /// for all of the bar's text and icons: the quieter greys, or any
    /// transparency, drop below the contrast they need on the tints.
    private var textColor: Color {
        guard let colorIndex else { return Theme.ink }
        return ClueColors.text(on: colorIndex, strength: ClueColors.clueBarTint)
    }

    /// Clue text sizes, largest first: the clue takes the first one at which
    /// all of it fits the bar.
    private static let clueFontSizes: [CGFloat] = [15, 14, 13, 12, 11, 10]

    var body: some View {
        VStack(spacing: 2) {
            header
                .font(.system(size: 10.5, weight: .semibold))
                .kerning(0.5)
                .monospacedDigit()
                .foregroundStyle(textColor)
            clueLine
        }
        // Clear of the progress line along the bottom edge.
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(RoundedRectangle(cornerRadius: 14).fill(fill))
        // A quick fade between colours, so the change of word is noticed.
        .animation(.easeOut(duration: 0.2), value: colorIndex)
        // Progress is the pill's bottom edge rather than a row of its own.
        .overlay(alignment: .bottom) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.progressTrack)
                    Rectangle().fill(Theme.primary)
                        .frame(width: geometry.size.width * model.progressFraction)
                }
            }
            .frame(height: 3)
            .animation(.easeOut(duration: 0.24), value: model.progressFraction)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    }

    /// Only which level this is. A filled count ("4/48") sat beside it but
    /// read like a second level number; the bar along the pill's bottom
    /// edge already shows how full the board is.
    @ViewBuilder
    private var header: some View {
        if model.isTutorial {
            Text("HOW TO PLAY")
        } else if let start = model.dailyStartedAt {
            HStack(spacing: 6) {
                Text("DAILY CHALLENGE")
                DailyStopwatch(start: start, finalSeconds: model.dailyResult?.seconds)
            }
        } else {
            Text("LEVEL \(model.levelNumber)")
        }
    }

    @ViewBuilder
    private var clueLine: some View {
        if let answer = model.activeAnswer {
            HStack(spacing: 5) {
                Image(systemName: answer.direction == .across ? "arrow.right" : "arrow.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(textColor)
                    .accessibilityLabel(answer.direction == .across ? Text("Across") : Text("Down"))
                // Never cut off with "…": a clue missing its end can't be
                // solved. ViewThatFits tries each size, largest first, and
                // keeps the first whose wrapped text fits the bar's height.
                // (minimumScaleFactor alone, tried before, gave up and cut
                // long clues: it shrinks text within a fixed line count.)
                // No letter count: the word's cells in the grid already show it.
                ViewThatFits(in: .vertical) {
                    ForEach(Self.clueFontSizes, id: \.self) { size in
                        clueText(answer.clueText, size: size)
                    }
                    // Longer than any clue should be: shrinks further rather
                    // than losing its end.
                    clueText(answer.clueText, size: Self.clueFontSizes.last ?? 10)
                        .lineLimit(3)
                        .minimumScaleFactor(0.5)
                }
            }
            .padding(.horizontal, 2)
        } else {
            Text("Level complete")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
    }

    private func clueText(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(textColor)
            .multilineTextAlignment(.center)
    }
}

/// The settings gear's drawn size, shared by home and levels so it's the
/// same everywhere. Bigger than the default 24: its image is centred on
/// the gear, with room for the yarn curl on one side.
enum SettingsIcon {
    static let size: CGFloat = 29
}

/// A round white 44pt button with an SF Symbol or one of the game's own icons.
struct CircleIconButton: View {
    private let icon: Icon
    let label: LocalizedStringKey
    let action: () -> Void

    /// A system symbol, or one of the game's own icons from the asset
    /// catalog (drawn as a template: the shape only, coloured here).
    private enum Icon {
        case system(String)
        /// With the size it's drawn at: an icon with something sticking
        /// out (the gear's yarn curl) is centred on its main shape, so it
        /// fills less of its image and needs drawing a little bigger.
        case asset(String, size: CGFloat)
    }

    init(systemName: String, label: LocalizedStringKey, action: @escaping () -> Void) {
        icon = .system(systemName)
        self.label = label
        self.action = action
    }

    init(assetName: String, iconSize: CGFloat = 24, label: LocalizedStringKey, action: @escaping () -> Void) {
        icon = .asset(assetName, size: iconSize)
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            iconImage
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.surface).shadow(color: .black.opacity(0.06), radius: 1, y: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var iconImage: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 18, weight: .semibold))
        case .asset(let name, let size):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                // 24 is about the size an 18 pt symbol looks: the drawn
                // icons fill their image, symbols leave room around themselves.
                .frame(width: size, height: size)
        }
    }
}

/// The daily puzzle's running time, ticking once a second, and fixed at the
/// final time once the board is submitted. Takes its font from the header.
private struct DailyStopwatch: View {
    let start: Date
    let finalSeconds: Int?

    var body: some View {
        if let finalSeconds {
            reading(finalSeconds)
        } else {
            // TimelineView redraws only this text each second, not the bar.
            TimelineView(.periodic(from: start, by: 1)) { context in
                reading(max(0, Int(context.date.timeIntervalSince(start))))
            }
        }
    }

    private func reading(_ seconds: Int) -> some View {
        Text(verbatim: "· " + DailyFormat.clock(seconds: seconds))
            .accessibilityLabel(Text("Time"))
            .accessibilityValue(Text(verbatim: DailyFormat.clock(seconds: seconds)))
    }
}
