import SwiftUI
import SwiftData

/// Saved Draw/Convert results, backed by SwiftData.
struct GalleryView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedArtwork.createdAt, order: .reverse) private var artworks: [SavedArtwork]
    @State private var selectedArtwork: SavedArtwork?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if artworks.isEmpty {
                    ContentUnavailableView(
                        "아직 저장된 작품이 없습니다",
                        systemImage: "square.grid.2x2",
                        description: Text("그리기 또는 변환 결과를 저장하면 여기에 모아 볼 수 있습니다.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(artworks) { artwork in
                                Button { selectedArtwork = artwork } label: {
                                    thumbnail(for: artwork)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .navigationTitle("갤러리")
            .sheet(item: $selectedArtwork) { artwork in
                ArtworkDetailView(artwork: artwork, onDelete: { delete(artwork) })
                    .environment(appModel)
            }
        }
    }

    private func thumbnail(for artwork: SavedArtwork) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let data = artwork.thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Color.secondary.opacity(0.1)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 4) {
                Image(systemName: artwork.kind == .draw ? "pencil.and.outline" : "wand.and.stars")
                    .font(.caption2)
                Text(artwork.title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)

            Text(artwork.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(artwork.title), \(artwork.kind == .draw ? "그리기" : "변환") 작품")
    }

    private func delete(_ artwork: SavedArtwork) {
        modelContext.delete(artwork)
        selectedArtwork = nil
    }
}

#Preview {
    GalleryView()
        .environment(AppModel())
        .modelContainer(for: SavedArtwork.self, inMemory: true)
}
