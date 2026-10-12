import SwiftUI
import PhotosUI

private enum ConvertInputMode: String, CaseIterable, Hashable {
    case photo = "사진"
    case sketch = "직접 그리기"
}

/// Image → formula. "내가 그린 그림이나 촬영된 사진은 어떤 수식들의 조합으로 이루어졌을까?" —
/// both a photo and a finger-drawn sketch feed the same Fourier-series pipeline.
struct ConvertView: View {
    @Environment(AppModel.self) private var appModel
    @State private var model = ConvertModel()
    @State private var inputMode: ConvertInputMode = .photo
    @State private var photoItem: PhotosPickerItem?
    @State private var sketchPoints: [CGPoint] = []
    @State private var canvasRect: CGRect = .zero

    private var hasResult: Bool { model.series != nil || model.isProcessing || model.errorMessage != nil }

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
                Divider()
                controlSection
            }
            .navigationTitle("변환")
            .toolbar {
                if hasResult {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("다시 하기") { startOver() }
                    }
                }
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
        .onChange(of: inputMode) { _, _ in sketchPoints = [] }
    }

    private func startOver() {
        model.reset()
        sketchPoints = []
        photoItem = nil
    }

    // MARK: - Canvas

    private var canvasSection: some View {
        GeometryReader { proxy in
            ZStack {
                appModel.renderSettings.backgroundColor

                if model.series != nil || model.isProcessing {
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
            context.stroke(
                model.reconstructionPath,
                with: .color(appModel.renderSettings.strokeColor),
                lineWidth: appModel.renderSettings.strokeWidth
            )
        }
    }

    private var photoPrompt: some View {
        ContentUnavailableView {
            Label("사진을 선택하세요", systemImage: "photo.on.rectangle")
        } description: {
            Text("사진 속 윤곽을 삼각함수 급수(푸리에 급수)로 근사합니다.")
        } actions: {
            PhotosPicker("사진 선택", selection: $photoItem, matching: .images)
        }
    }

    private var sketchPad: some View {
        ZStack {
            Canvas { context, _ in
                var path = Path()
                if let first = sketchPoints.first {
                    path.move(to: first)
                    for point in sketchPoints.dropFirst() { path.addLine(to: point) }
                }
                context.stroke(
                    path,
                    with: .color(appModel.renderSettings.strokeColor),
                    lineWidth: appModel.renderSettings.strokeWidth
                )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0.5)
                    .onChanged { value in sketchPoints.append(value.location) }
            )

            VStack {
                Spacer()
                HStack {
                    Text("손가락으로 윤곽을 그려보세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("지우기") { sketchPoints.removeAll() }
                        .buttonStyle(.bordered)
                    Button("분석하기") { model.loadSketch(sketchPoints) }
                        .buttonStyle(.borderedProminent)
                        .disabled(sketchPoints.count < 5)
                }
                .padding(12)
            }
        }
    }

    // MARK: - Controls

    private var controlSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let series = model.series {
                    @Bindable var bindableModel = model
                    Stepper(
                        "항 개수 K: \(model.termCount)",
                        value: $bindableModel.termCount,
                        in: 1...max(series.terms.count, 1)
                    )
                    .font(.footnote)

                    notationPanel(series: series)
                } else {
                    Text("사진을 선택하거나 직접 그리면 분석 결과가 여기 표시됩니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
        }
        .frame(maxHeight: 220)
        .background(.thinMaterial)
    }

    private func notationPanel(series: FourierSeries) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("수식 표기", systemImage: "function")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(FourierFormatter.notation(for: series, termCount: model.termCount))
                .font(.system(size: 13, design: .serif))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ConvertView()
        .environment(AppModel())
}
