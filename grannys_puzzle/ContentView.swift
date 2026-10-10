import SwiftUI
import ArrowwordCore

/// The app's root. For now it opens straight into the first pack; the home
/// screen with grandma and the level list will sit here later.
struct ContentView: View {
    @State private var screen = Screen.loadFirstPack()

    var body: some View {
        switch screen {
        case .playing(let sequence):
            if let model = sequence.current {
                LevelScreen(model: model)
                    // A new identity per level, so SwiftUI starts the next
                    // level's views fresh instead of reusing the last one's.
                    .id(model.level.id)
            } else {
                ContentUnavailableView(
                    "You've solved every puzzle!",
                    systemImage: "star.fill",
                    description: Text("Grandma is knitting new ones. Check back soon, dear.")
                )
            }
        case .failed(let message):
            // A bundled pack failing to load is a bug in the build, but the
            // app should say so instead of crashing.
            ContentUnavailableView(
                "The puzzles couldn't be loaded",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        }
    }
}

private enum Screen {
    case playing(LevelSequence)
    case failed(String)

    static func loadFirstPack() -> Screen {
        do {
            let pack = try LevelLoader.bundledPack(named: LevelLoader.firstPackName)
            return .playing(LevelSequence(pack: pack))
        } catch {
            return .failed(String(describing: error))
        }
    }
}

#Preview {
    ContentView()
}
