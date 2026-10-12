import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var model = appModel
        TabView(selection: $model.selectedTab) {
            DrawView()
                .tabItem { Label("그리기", systemImage: "pencil.and.outline") }
                .tag(AppTab.draw)
            ConvertView()
                .tabItem { Label("변환", systemImage: "wand.and.stars") }
                .tag(AppTab.convert)
            GalleryView()
                .tabItem { Label("갤러리", systemImage: "square.grid.2x2") }
                .tag(AppTab.gallery)
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
