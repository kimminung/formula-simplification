import SwiftUI
import SwiftData
import UIKit

/// Formula → image. Edits one or more LayeredFormula components — mixed together into a single
/// picture — and renders them live via MathCanvasRenderer.
struct DrawView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @State private var model = DrawModel(components: FormulaPresets.all[0].components)
    @State private var canvasRect: CGRect = .zero
    @State private var savedMessage: String?
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvasSection
                Divider()
                editorSection
            }
            .navigationTitle("그리기")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(FormulaPresets.all) { preset in
                            Button(preset.title) { model.replaceAllComponents(preset.components) }
                        }
                    } label: {
                        Label("프리셋", systemImage: "sparkles")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { saveSnapshot() } label: {
                        Label("사진 앱에 저장", systemImage: "square.and.arrow.down")
                    }
                    .disabled(model.layerPaths.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { saveToGallery() } label: {
                        Label("갤러리에 저장", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(model.layerPaths.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { isEditorFocused = false }
                        .fontWeight(.semibold)
                }
            }
            .alert(
                "저장됨",
                isPresented: Binding(get: { savedMessage != nil }, set: { if !$0 { savedMessage = nil } })
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(savedMessage ?? "")
            }
        }
        .onChange(of: model.components) { _, _ in
            model.scheduleRender(in: canvasRect)
        }
        .onChange(of: appModel.pendingDrawComponents) { _, newValue in
            guard let newValue else { return }
            model.replaceAllComponents(newValue)
            appModel.pendingDrawComponents = nil
        }
    }

    // MARK: - Canvas

    private var canvasSection: some View {
        GeometryReader { proxy in
            ZStack {
                appModel.renderSettings.backgroundColor
                canvasContent
                if let errorMessage = model.errorMessage {
                    VStack {
                        Spacer()
                        HStack {
                            errorBanner(errorMessage)
                            Spacer()
                        }
                    }
                    .padding(12)
                }
            }
            .onAppear {
                canvasRect = CGRect(origin: .zero, size: proxy.size)
                model.scheduleRender(in: canvasRect)
            }
            .onChange(of: proxy.size) { _, newSize in
                canvasRect = CGRect(origin: .zero, size: newSize)
                model.scheduleRender(in: canvasRect)
            }
        }
        .frame(minHeight: 260)
    }

    private var canvasContent: some View {
        Canvas { context, _ in
            let count = model.layerPaths.count
            for (index, path) in model.layerPaths.enumerated() {
                context.stroke(
                    path,
                    with: .color(MathCanvasRenderer.color(forLayer: index, of: count, settings: appModel.renderSettings)),
                    lineWidth: appModel.renderSettings.strokeWidth
                )
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.red.opacity(0.85), in: Capsule())
    }

    // MARK: - Editor

    private var editorSection: some View {
        @Bindable var drawModel = model
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                componentPicker

                formulaField(title: "x(t,k) =", text: $drawModel.selectedComponent.xExpression)
                formulaField(title: "y(t,k) =", text: $drawModel.selectedComponent.yExpression)

                Stepper(
                    "레이어 수 k: \(model.selectedComponent.kCount)",
                    value: $drawModel.selectedComponent.kCount,
                    in: 1...LayeredFormula.maxLayers,
                    step: layerStep
                )
                .font(.footnote)

                notationPanel
            }
            .padding(14)
        }
        .frame(maxHeight: 260)
        .background(.thinMaterial)
    }

    /// Lets the user mix several formula components into one picture: tap a chip to edit it,
    /// "+" to add another, trash to remove the selected one (when more than one exists).
    private var componentPicker: some View {
        HStack(spacing: 8) {
            Text("구성요소")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(model.components.enumerated()), id: \.element.id) { index, _ in
                        Button {
                            model.selectedComponentIndex = index
                        } label: {
                            Text("\(index + 1)")
                                .font(.caption.weight(.semibold))
                                .frame(width: 26, height: 26)
                                .background(
                                    index == model.selectedComponentIndex ? Color.accentColor : Color.secondary.opacity(0.15),
                                    in: Circle()
                                )
                                .foregroundStyle(index == model.selectedComponentIndex ? .white : .primary)
                        }
                        .accessibilityLabel("구성요소 \(index + 1)")
                    }
                }
            }
            Spacer()
            Button { model.addComponent() } label: {
                Image(systemName: "plus.circle.fill")
            }
            .accessibilityLabel("구성요소 추가")
            if model.components.count > 1 {
                Button(role: .destructive) { model.removeSelectedComponent() } label: {
                    Image(systemName: "trash.circle.fill")
                }
                .accessibilityLabel("선택한 구성요소 삭제")
            }
        }
    }

    private var layerStep: Int {
        model.selectedComponent.kCount < 50 ? 1 : max(model.selectedComponent.kCount / 20, 1)
    }

    private func formulaField(title: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("수식", text: text)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isEditorFocused)
        }
    }

    private var notationPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("수식 표기", systemImage: "function")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(FormulaFormatter.notation(for: model.components))
                .font(.system(.footnote, design: .serif))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Export

    @MainActor
    private func renderedImage() -> UIImage? {
        let exportView = ZStack {
            appModel.renderSettings.backgroundColor
            canvasContent
        }
        .frame(width: canvasRect.width, height: canvasRect.height)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 3
        return renderer.uiImage
    }

    @MainActor
    private func saveSnapshot() {
        guard let image = renderedImage() else {
            savedMessage = "이미지를 만들지 못했습니다."
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        savedMessage = "사진 앱에 저장했습니다."
    }

    @MainActor
    private func saveToGallery() {
        guard let image = renderedImage(), let thumbnailData = image.pngData() else {
            savedMessage = "이미지를 만들지 못했습니다."
            return
        }
        let title = model.components.first?.title.isEmpty == false ? model.components[0].title : "그리기 작품"
        let artwork = SavedArtwork(kind: .draw, title: title, thumbnailData: thumbnailData)
        artwork.apply(components: model.components)
        modelContext.insert(artwork)
        savedMessage = "갤러리에 저장했습니다."
    }
}

#Preview {
    DrawView()
        .environment(AppModel())
}
