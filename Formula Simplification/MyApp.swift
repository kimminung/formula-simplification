import SwiftUI
import SwiftData

@main
struct MyApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
        .modelContainer(for: SavedArtwork.self)
    }
}
