import SwiftUI

/// Owns the Convert pipeline: either a photo or a hand-drawn sketch goes in, a FourierSeries
/// (and its live reconstruction path) comes out.
@Observable
final class ConvertModel {
    private(set) var series: FourierSeries?
    var termCount: Int = 40 {
        didSet { rebuildPath() }
    }
    private(set) var isProcessing = false
    private(set) var errorMessage: String?
    private(set) var reconstructionPath = Path()

    private var canvasRect: CGRect = .zero

    func reset() {
        series = nil
        errorMessage = nil
        reconstructionPath = Path()
    }

    func loadPhoto(_ image: UIImage) {
        reset()
        Task { await process { try await ContourExtractor.extractContour(from: image) } }
    }

    func loadSketch(_ points: [CGPoint]) {
        reset()
        guard points.count > 4 else {
            errorMessage = "조금 더 길게 그려주세요."
            return
        }
        Task { await process { PolylineResampler.resample(points, to: 160) } }
    }

    func updateCanvasRect(_ rect: CGRect) {
        canvasRect = rect
        rebuildPath()
    }

    @MainActor
    private func process(_ makeContour: @escaping () async throws -> [CGPoint]) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let contour = try await makeContour()
            let fitted = await Task.detached(priority: .userInitiated) {
                FourierFit.fit(contour: contour)
            }.value
            series = fitted
            termCount = min(40, max(fitted.terms.count, 1))
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func rebuildPath() {
        guard let series, canvasRect.width > 0, canvasRect.height > 0 else {
            reconstructionPath = Path()
            return
        }
        let rawPoints = series.points(usingTermCount: termCount)
        let fitted = MathCanvasRenderer.fit(layers: [rawPoints], in: canvasRect)
        reconstructionPath = MathCanvasRenderer.paths(from: fitted).first ?? Path()
    }
}
