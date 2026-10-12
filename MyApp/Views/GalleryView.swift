import SwiftUI

/// Saved draw/convert results. SwiftData persistence lands in a later phase.
struct GalleryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "아직 저장된 작품이 없습니다",
                systemImage: "square.grid.2x2",
                description: Text("그리기 또는 변환 결과를 저장하면 여기에 모아 볼 수 있습니다.")
            )
            .navigationTitle("갤러리")
        }
    }
}

#Preview {
    GalleryView()
        .environment(AppModel())
}
