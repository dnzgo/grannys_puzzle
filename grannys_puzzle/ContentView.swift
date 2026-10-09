import SwiftUI
import ArrowwordCore

/// The app's root. For now it opens straight into Level 100; the home screen
/// with grandma and the level list will sit here later.
struct ContentView: View {
    @State private var screen = Screen.loadFirstLevel()

    var body: some View {
        switch screen {
        case .level(let model):
            LevelScreen(model: model)
        case .failed(let message):
            // A bundled level failing to load is a bug in the build, but the
            // app should say so instead of crashing.
            ContentUnavailableView(
                "This level couldn't be loaded",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        }
    }
}

private enum Screen {
    case level(LevelViewModel)
    case failed(String)

    static func loadFirstLevel() -> Screen {
        do {
            let level = try LevelLoader.bundledLevel(named: "level-100")
            return .level(LevelViewModel(level: level, levelNumber: 100))
        } catch {
            return .failed(String(describing: error))
        }
    }
}

#Preview {
    ContentView()
}
