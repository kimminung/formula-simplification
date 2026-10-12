import SwiftUI
import UIKit

/// Formula → image. Edits a LayeredFormula and renders it live via MathCanvasRenderer.
struct DrawView: View {
    @Environment(AppModel.self) private var appModel
    @State private var model = DrawModel(formula: FormulaPresets.all[0].formula)
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
                            Button(preset.title) { model.formula = preset.formula }
                        }
                    } label: {
                        Label("프리셋", systemImage: "sparkles")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { saveSnapshot() } label: {
                        Label("저장", systemImage: "square.and.arrow.down")
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
        .onChange(of: model.formula) { _, _ in
            model.scheduleRender(in: canvasRect)
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
                formulaField(title: "x(t,k) =", text: $drawModel.formula.xExpression)
                formulaField(title: "y(t,k) =", text: $drawModel.formula.yExpression)

                Stepper(
                    "레이어 수 k: \(model.formula.kCount)",
                    value: $drawModel.formula.kCount,
                    in: 1...LayeredFormula.maxLayers,
                    step: layerStep
                )
                .font(.footnote)

                notationPanel
            }
            .padding(14)
        }
        .frame(maxHeight: 220)
        .background(.thinMaterial)
    }

    private var layerStep: Int {
        model.formula.kCount < 50 ? 1 : max(model.formula.kCount / 20, 1)
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
            Text(FormulaFormatter.notation(for: model.formula))
                .font(.system(size: 13, design: .serif))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Export

    @MainActor
    private func saveSnapshot() {
        let exportView = ZStack {
            appModel.renderSettings.backgroundColor
            canvasContent
        }
        .frame(width: canvasRect.width, height: canvasRect.height)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 3
        guard let image = renderer.uiImage else {
            savedMessage = "이미지를 만들지 못했습니다."
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        savedMessage = "사진 앱에 저장했습니다."
    }
}

#Preview {
    DrawView()
        .environment(AppModel())
}
