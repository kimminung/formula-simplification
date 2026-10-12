import SwiftUI

/// Owns the Convert pipeline: a photo or a multi-stroke sketch goes in, one FourierSeries per
/// shape (and their live reconstruction paths, all in one shared frame) comes out.
@Observable
final class ConvertModel {
    private(set) var shapes: [FourierSeries]?
    var termCount: Int = 40 {
        didSet { rebuildPaths() }
    }
    /// Re-analyzes the last photo when changed, so the user can dial detail up or down.
    var photoDetail: PhotoDetailLevel = .balanced {
        didSet {
            guard photoDetail != oldValue, let lastImage else { return }
            loadPhoto(lastImage)
        }
    }
    /// Segment the main subject first and ignore the background. Re-analyzes when toggled.
    var isolateSubject = true {
        didSet {
            guard isolateSubject != oldValue, let lastImage else { return }
            loadPhoto(lastImage)
        }
    }
    private(set) var isProcessing = false
    private(set) var errorMessage: String?
    private(set) var reconstructionPaths: [Path] = []
    private(set) var lastImage: UIImage?
    /// Photo results only: whether the scan was limited to a segmented subject.
    private(set) var subjectIsolated: Bool?
    /// Shown when isolation was requested but didn't happen, so a silent fallback is never silent.
    private(set) var isolationNote: String?

    private var canvasRect: CGRect = .zero

    var shapeCount: Int { shapes?.count ?? 0 }

    /// The longest term list across shapes bounds the K stepper; smaller shapes just clamp.
    var maxTermCount: Int { shapes?.map(\.terms.count).max() ?? 0 }

    func reset() {
        shapes = nil
        errorMessage = nil
        reconstructionPaths = []
        lastImage = nil
        subjectIsolated = nil
        isolationNote = nil
    }

    func loadPhoto(_ image: UIImage) {
        let detail = photoDetail
        let isolate = isolateSubject
        reset()
        lastImage = image
        Task {
            await process {
                try await ContourExtractor.extractContours(from: image, detail: detail, isolateSubject: isolate)
            }
        }
    }

    /// Each finger-down → finger-up stroke becomes its own shape. Open strokes are walked
    /// there-and-back so the DFT sees a periodic signal without a straight closing segment.
    func loadSketch(strokes: [[CGPoint]]) {
        reset()
        let usable = strokes.filter { $0.count > 4 }
        guard !usable.isEmpty else {
            errorMessage = "조금 더 길게 그려주세요."
            return
        }
        Task {
            await process {
                let shapes = usable.map { stroke in
                    let loop = FourierFit.closedLoop(from: stroke)
                    return PolylineResampler.resample(loop, to: ContourExtractor.sampleCount(for: loop) * 2)
                }
                return ContourExtractor.Extraction(shapes: shapes, subjectIsolated: false, isolationNote: nil)
            }
        }
    }

    /// Reopens a previously saved result (from the Gallery) without rerunning Vision/DFT.
    func loadStored(shapes: [FourierSeries], termCount: Int) {
        reset()
        self.shapes = shapes
        self.termCount = termCount
    }

    func updateCanvasRect(_ rect: CGRect) {
        canvasRect = rect
        rebuildPaths()
    }

    @MainActor
    private func process(_ makeShapes: @escaping () async throws -> ContourExtractor.Extraction) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let extraction = try await makeShapes()
            let fitted = await Task.detached(priority: .userInitiated) {
                FourierFit.fit(shapes: extraction.shapes)
            }.value
            shapes = fitted
            subjectIsolated = lastImage == nil ? nil : extraction.subjectIsolated
            isolationNote = extraction.isolationNote
            termCount = min(40, max(maxTermCount, 1))
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func rebuildPaths() {
        guard let shapes, canvasRect.width > 0, canvasRect.height > 0 else {
            reconstructionPaths = []
            return
        }
        // Fit all shapes together so they keep their relative positions and scale. Strokes and
        // image contours are already y-down, so no math-space flip.
        let layers = shapes.map { $0.points(usingTermCount: termCount) }
        reconstructionPaths = MathCanvasRenderer.paths(
            from: MathCanvasRenderer.fit(layers: layers, in: canvasRect, flipY: false)
        )
    }
}
