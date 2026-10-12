import SwiftUI

/// Full-size preview of a saved artwork, with the option to reopen it in its original tab.
struct ArtworkDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    let artwork: SavedArtwork
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let data = artwork.thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }

                Text(artwork.createdAt.formatted(date: .long, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    load()
                } label: {
                    Label(
                        artwork.kind == .draw ? "그리기에서 다시 열기" : "변환에서 다시 열기",
                        systemImage: "arrow.uturn.backward"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canReload)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle(artwork.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var canReload: Bool {
        switch artwork.kind {
        case .draw: artwork.storedComponents != nil
        case .convert: artwork.storedShapes != nil
        }
    }

    private func load() {
        switch artwork.kind {
        case .draw:
            if let components = artwork.storedComponents {
                appModel.pendingDrawComponents = components
                appModel.selectedTab = .draw
            }
        case .convert:
            if let stored = artwork.storedShapes {
                appModel.pendingConvertLoad = PendingConvertLoad(shapes: stored.shapes, termCount: stored.termCount)
                appModel.selectedTab = .convert
            }
        }
        dismiss()
    }
}
