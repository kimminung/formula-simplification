import Vision
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

nonisolated enum ContourExtractionError: Error, CustomStringConvertible, Sendable {
    case noImage
    case noContourFound

    var description: String {
        switch self {
        case .noImage:
            return "이미지를 읽을 수 없습니다."
        case .noContourFound:
            return "사진에서 윤곽을 찾지 못했습니다. 세밀도를 높이거나 대비가 뚜렷한 사진을 사용해보세요."
        }
    }
}

/// How aggressively a photo is broken into shapes. Each level scans the image at several
/// brightness thresholds (like contour lines on a map) and keeps the N largest regions.
nonisolated enum PhotoDetailLevel: String, CaseIterable, Identifiable, Sendable {
    case simple, balanced, detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simple: "단순"
        case .balanced: "보통"
        case .detailed: "세밀"
        }
    }

    /// Brightness pivots (0 = black, 1 = white) at which region boundaries are traced.
    var pivots: [Float] {
        switch self {
        case .simple: [0.5]
        case .balanced: [0.25, 0.4, 0.55, 0.7]
        case .detailed: [0.15, 0.27, 0.39, 0.5, 0.62, 0.74, 0.86]
        }
    }

    var maxShapes: Int {
        switch self {
        case .simple: 8
        case .balanced: 40
        case .detailed: 80
        }
    }

    /// Smallest bounding-box area (fraction of the frame) worth keeping; drops speckle noise.
    var minimumArea: Double {
        switch self {
        case .simple: 0.01
        case .balanced: 0.002
        case .detailed: 0.0008
        }
    }
}

/// Finds every meaningful region boundary in a photo and resamples each to evenly spaced
/// points so FourierFit can treat it as one closed curve. Returns many shapes, largest first,
/// all in the same top-left-origin normalized space.
///
/// With `isolateSubject`, Vision's foreground segmentation runs first: the subject's silhouette
/// becomes the first shape(s), and the brightness scan only looks inside the subject (the
/// background is painted white), so busy backgrounds stop flooding the result with noise.
nonisolated enum ContourExtractor {
    static let maximumImageDimension = 768

    private struct Candidate: Sendable {
        let area: Double
        let key: String
        let points: [CGPoint]
    }

    struct Extraction: Sendable {
        let shapes: [[CGPoint]]
        /// True when a foreground subject was found and the scan was limited to it.
        let subjectIsolated: Bool
        /// Why isolation was skipped (no subject, or segmentation unavailable), if it was requested.
        let isolationNote: String?
    }

    static func extractContours(
        from image: UIImage,
        detail: PhotoDetailLevel,
        isolateSubject: Bool
    ) async throws -> Extraction {
        guard let cgImage = uprightCGImage(from: image) else { throw ContourExtractionError.noImage }

        var silhouettes: [Candidate] = []
        var scanTarget = cgImage
        var subjectIsolated = false
        var isolationNote: String?
        if isolateSubject {
            do {
                if let subject = try await isolate(cgImage) {
                    // A subject that fills most of the frame is still a real silhouette, unlike
                    // the image border, so allow it to be much larger than interior regions.
                    silhouettes = try await candidates(in: subject.mask, pivot: 0.5, detail: detail, maxArea: 0.97)
                    scanTarget = subject.onWhite
                    subjectIsolated = true
                } else {
                    isolationNote = "피사체를 찾지 못해 사진 전체를 분석했습니다."
                }
            } catch {
                // Segmentation isn't available everywhere (e.g. some simulators); degrade gracefully.
                isolationNote = "피사체 분리를 사용할 수 없어 사진 전체를 분석했습니다. (\(error.localizedDescription))"
            }
        }

        // One Vision pass per brightness level; they're independent, so run them concurrently.
        let interior = try await withThrowingTaskGroup(of: [Candidate].self) { group in
            for pivot in detail.pivots {
                group.addTask { try await candidates(in: scanTarget, pivot: pivot, detail: detail) }
            }
            var all: [Candidate] = []
            for try await batch in group { all.append(contentsOf: batch) }
            return all
        }

        // Silhouettes come first so they always survive the cap; the same edge also shows up at
        // neighboring pivots, so keep one copy per bounding box.
        var seenKeys = Set<String>()
        var unique: [Candidate] = []
        let ordered = silhouettes.sorted { $0.area > $1.area } + interior.sorted { $0.area > $1.area }
        for candidate in ordered where seenKeys.insert(candidate.key).inserted {
            unique.append(candidate)
        }

        guard !unique.isEmpty else { throw ContourExtractionError.noContourFound }

        let shapes = unique.prefix(detail.maxShapes).map { candidate in
            PolylineResampler.resample(candidate.points, to: sampleCount(for: candidate.points))
        }
        return Extraction(shapes: shapes, subjectIsolated: subjectIsolated, isolationNote: isolationNote)
    }

    // MARK: - Subject isolation

    private struct IsolatedSubject: @unchecked Sendable {
        /// Binary mask: white where the subject is. Its contours are the subject's silhouette.
        let mask: CGImage
        /// The original pixels inside the subject, pure white everywhere else.
        let onWhite: CGImage
    }

    private static func isolate(_ cgImage: CGImage) async throws -> IsolatedSubject? {
        let request = GenerateForegroundInstanceMaskRequest()
        let observation: InstanceMaskObservation? = try await request.perform(on: cgImage)
        guard let observation, !observation.allInstances.isEmpty else { return nil }

        let handler = ImageRequestHandler(cgImage)
        let maskBuffer = try observation.generateScaledMask(for: observation.allInstances, scaledToImageFrom: handler)

        let context = CIContext()
        let original = CIImage(cgImage: cgImage)
        let mask = CIImage(cvPixelBuffer: maskBuffer)
            .transformed(by: CGAffineTransform(
                scaleX: original.extent.width / CGFloat(CVPixelBufferGetWidth(maskBuffer)),
                y: original.extent.height / CGFloat(CVPixelBufferGetHeight(maskBuffer))
            ))

        let blend = CIFilter.blendWithMask()
        blend.inputImage = original
        blend.backgroundImage = CIImage(color: .white).cropped(to: original.extent)
        blend.maskImage = mask

        guard let onWhite = blend.outputImage.flatMap({ context.createCGImage($0, from: original.extent) }),
              let maskImage = context.createCGImage(mask, from: original.extent) else {
            return nil
        }
        return IsolatedSubject(mask: maskImage, onWhite: onWhite)
    }

    // MARK: - Contour scanning

    private static func candidates(
        in cgImage: CGImage,
        pivot: Float,
        detail: PhotoDetailLevel,
        maxArea: Double = 0.85
    ) async throws -> [Candidate] {
        var request = DetectContoursRequest()
        request.contrastAdjustment = 2.0
        request.contrastPivot = pivot
        request.detectsDarkOnLight = true
        request.maximumImageDimension = maximumImageDimension

        let observation = try await request.perform(on: cgImage)
        var found: [Candidate] = []
        for index in 0..<observation.contourCount {
            guard let contour = observation.contourAtIndex(index) else { continue }
            let box = contour.boundingBox
            let area = Double(box.width) * Double(box.height)
            // Skip speckle noise and the image frame itself (which trivially has the biggest box).
            guard area >= detail.minimumArea, area < maxArea, contour.pointCount >= 8 else { continue }
            // Vision's normalized space has its origin at the bottom-left (measured: the top apex
            // of an upright star comes back with y ≈ 0.87); flip to the canvas's y-down space.
            let points = contour.points.map { CGPoint(x: $0.cgPoint.x, y: 1 - $0.cgPoint.y) }
            found.append(Candidate(area: area, key: dedupeKey(for: box.cgRect), points: points))
        }
        return found
    }

    /// Longer outlines get more samples so fine detail survives; tiny ones stay cheap.
    static func sampleCount(for points: [CGPoint]) -> Int {
        var perimeter = 0.0
        for i in 1..<max(points.count, 1) {
            perimeter += hypot(Double(points[i].x - points[i - 1].x), Double(points[i].y - points[i - 1].y))
        }
        return min(max(Int(perimeter * 320), 48), 192)
    }

    private static func dedupeKey(for box: CGRect) -> String {
        func bucket(_ value: CGFloat) -> Int { Int((value * 60).rounded()) }
        return "\(bucket(box.minX)),\(bucket(box.minY)),\(bucket(box.width)),\(bucket(box.height))"
    }

    /// Photos taken on a device carry an EXIF orientation that `cgImage` ignores, which would
    /// hand Vision a sideways image. Redraw upright (and no larger than needed) first.
    private static func uprightCGImage(from image: UIImage) -> CGImage? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, CGFloat(maximumImageDimension) / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        guard image.imageOrientation != .up || scale < 1 else { return image.cgImage }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }
}
