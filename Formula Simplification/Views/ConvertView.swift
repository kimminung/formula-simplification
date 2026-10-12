import SwiftUI
import SwiftData
import PhotosUI
import UIKit

private enum ConvertInputMode: String, CaseIterable, Hashable {
    case photo = "사진"
    case sketch = "직접 그리기"
}

/// Image → formula. "내가 그린 그림이나 촬영된 사진은 어떤 수식들의 조합으로 이루어졌을까?" —
/// a photo is split into many region outlines and a sketch into its individual strokes; every
/// shape gets its own Fourier series, and they're drawn together in one shared frame.
struct ConvertView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @State private var model = ConvertModel()
    @State private var inputMode: ConvertInputMode = .photo
    @State private var photoItem: PhotosPickerItem?
    @State private var strokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var canvasRect: CGRect = .zero
    @State private var savedMessage: String?

    private var hasResult: Bool { model.shapes != nil || model.isProcessing || model.errorMessage != nil }
    private var sketchPointCount: Int { strokes.reduce(0) { $0 + $1.count } + currentStroke.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !hasResult {
                    Picker("입력 방식", selection: $inputMode) {
                        ForEach(ConvertInputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                canvasSection
                if let shapes = model.shapes {
                    // Kept outside the canvas so captions never cover the drawing.
                    VStack(alignment: .leading, spacing: 4) {
                        caption(
                            "도형 \(shapes.count)개 · 도형당 \(model.termCount)항"
                            + (model.subjectIsolated == true ? " · 피사체 분리" : "")
                        )
                        if let note = model.isolationNote {
                            caption(note)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                Divider()
                controlSection
            }
            .navigationTitle("변환")
            .toolbar {
                if model.shapes != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { saveToGallery() } label: {
                            Label("갤러리에 저장", systemImage: "tray.and.arrow.down")
                        }
                    }
                }
                if hasResult {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("다시 하기") { startOver() }
                    }
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
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    model.loadPhoto(image)
                }
            }
        }
        .onChange(of: inputMode) { _, _ in clearSketch() }
        .onChange(of: appModel.pendingConvertLoad) { _, newValue in
            guard let newValue else { return }
            model.loadStored(shapes: newValue.shapes, termCount: newValue.termCount)
            appModel.pendingConvertLoad = nil
        }
    }

    @MainActor
    private func saveToGallery() {
        guard let shapes = model.shapes else { return }
        let exportView = ZStack {
            appModel.renderSettings.backgroundColor
            reconstructionCanvas
        }
        .frame(width: canvasRect.width, height: canvasRect.height)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 3
        guard let image = renderer.uiImage, let thumbnailData = image.pngData() else {
            savedMessage = "이미지를 만들지 못했습니다."
            return
        }
        let artwork = SavedArtwork(kind: .convert, title: "변환 작품 (도형 \(shapes.count)개)", thumbnailData: thumbnailData)
        artwork.apply(shapes: shapes, termCount: model.termCount)
        modelContext.insert(artwork)
        savedMessage = "갤러리에 저장했습니다."
    }

    private func startOver() {
        model.reset()
        clearSketch()
        photoItem = nil
    }

    private func clearSketch() {
        strokes = []
        currentStroke = []
    }

    // MARK: - Canvas

    private var canvasSection: some View {
        GeometryReader { proxy in
            ZStack {
                appModel.renderSettings.backgroundColor

                if model.shapes != nil || model.isProcessing {
                    reconstructionCanvas
                } else if let errorMessage = model.errorMessage {
                    ContentUnavailableView {
                        Label("분석 실패", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("다시 시도") { startOver() }
                    }
                } else if inputMode == .photo {
                    photoPrompt
                } else {
                    sketchPad
                }

                if model.isProcessing {
                    ProgressView("분석 중…")
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .onAppear {
                canvasRect = CGRect(origin: .zero, size: proxy.size)
                model.updateCanvasRect(canvasRect)
            }
            .onChange(of: proxy.size) { _, newSize in
                canvasRect = CGRect(origin: .zero, size: newSize)
                model.updateCanvasRect(canvasRect)
            }
        }
        .frame(minHeight: 260)
    }

    private var reconstructionCanvas: some View {
        Canvas { context, _ in
            let count = model.reconstructionPaths.count
            for (index, path) in model.reconstructionPaths.enumerated() {
                context.stroke(
                    path,
                    with: .color(MathCanvasRenderer.color(forLayer: index, of: count, settings: appModel.renderSettings)),
                    lineWidth: appModel.renderSettings.strokeWidth
                )
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }

    private var photoPrompt: some View {
        ContentUnavailableView {
            Label("사진을 선택하세요", systemImage: "photo.on.rectangle")
        } description: {
            Text("사진을 여러 윤곽으로 나누고, 각 윤곽을 삼각함수 급수(푸리에 급수)로 근사합니다.")
        } actions: {
            PhotosPicker("사진 선택", selection: $photoItem, matching: .images)
        }
    }

    private var sketchPad: some View {
        ZStack {
            Canvas { context, _ in
                for stroke in strokes + [currentStroke] {
                    var path = Path()
                    if let first = stroke.first {
                        path.move(to: first)
                        for point in stroke.dropFirst() { path.addLine(to: point) }
                    }
                    context.stroke(
                        path,
                        with: .color(appModel.renderSettings.strokeColor),
                        lineWidth: appModel.renderSettings.strokeWidth
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0.5)
                    .onChanged { value in currentStroke.append(value.location) }
                    .onEnded { _ in
                        if currentStroke.count > 1 { strokes.append(currentStroke) }
                        currentStroke = []
                    }
            )

            VStack {
                Spacer()
                HStack {
                    Text(strokes.isEmpty ? "손가락으로 여러 획을 그려보세요" : "획 \(strokes.count)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        _ = strokes.popLast()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .disabled(strokes.isEmpty)
                    .accessibilityLabel("마지막 획 되돌리기")
                    Button("지우기") { clearSketch() }
                        .buttonStyle(.bordered)
                        .disabled(strokes.isEmpty)
                    Button("분석하기") { model.loadSketch(strokes: strokes) }
                        .buttonStyle(.borderedProminent)
                        .disabled(sketchPointCount < 5)
                }
                .padding(12)
            }
        }
    }

    // MARK: - Controls

    private var controlSection: some View {
        @Bindable var bindableModel = model
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let shapes = model.shapes {
                    if model.lastImage != nil {
                        detailPicker
                    }

                    Stepper(
                        "항 개수 K (도형당): \(model.termCount)",
                        value: $bindableModel.termCount,
                        in: 1...max(model.maxTermCount, 1)
                    )
                    .font(.footnote)

                    notationPanel(shapes: shapes)
                } else if inputMode == .photo {
                    detailPicker
                    Text(model.isProcessing
                         ? "밝기 단계별로 윤곽을 찾는 중입니다…"
                         : "사진을 선택하면 밝기 단계별 윤곽을 여러 개 추출해 각각 수식으로 바꿉니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("획을 여러 개 그린 뒤 분석하면 획마다 별도의 수식이 만들어집니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .padding(.bottom, 48)
        }
        .frame(maxHeight: 240)
        .background(.thinMaterial)
    }

    private var detailPicker: some View {
        @Bindable var bindableModel = model
        return VStack(alignment: .leading, spacing: 6) {
            Picker("세밀도", selection: $bindableModel.photoDetail) {
                ForEach(PhotoDetailLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)
            Text("세밀도가 높을수록 더 많은 밝기 단계에서 더 작은 윤곽까지 찾습니다 (최대 \(model.photoDetail.maxShapes)개).")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Toggle("피사체만 분석", isOn: $bindableModel.isolateSubject)
                .font(.footnote)
            Text("켜면 주된 피사체를 먼저 분리해 그 실루엣과 내부 윤곽만 수식으로 만들고, 배경은 무시합니다. 피사체를 못 찾으면 사진 전체를 분석합니다.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func notationPanel(shapes: [FourierSeries]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("수식 표기", systemImage: "function")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(FourierFormatter.notation(for: shapes, termCount: model.termCount))
                .font(.system(.footnote, design: .serif))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ConvertView()
        .environment(AppModel())
}
