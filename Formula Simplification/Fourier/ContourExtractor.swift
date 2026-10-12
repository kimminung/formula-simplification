import Vision
import UIKit

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
nonisolated enum ContourExtractor {
    static let maximumImageDimension = 768

    private struct Candidate: Sendable {
        let area: Double
        let key: String
        let points: [CGPoint]
    }

    static func extractContours(from image: UIImage, detail: PhotoDetailLevel) async throws -> [[CGPoint]] {
        guard let cgImage = uprightCGImage(from: image) else { throw ContourExtractionError.noImage }

        // One Vision pass per brightness level; they're independent, so run them concurrently.
        let candidates = try await withThrowingTaskGroup(of: [Candidate].self) { group in
            for pivot in detail.pivots {
                group.addTask { try await candidates(in: cgImage, pivot: pivot, detail: detail) }
            }
            var all: [Candidate] = []
            for try await batch in group { all.append(contentsOf: batch) }
            return all
        }

        // The same edge shows up at neighboring pivots; keep one copy per bounding box.
        var seenKeys = Set<String>()
        var unique: [Candidate] = []
        for candidate in candidates.sorted(by: { $0.area > $1.area }) where seenKeys.insert(candidate.key).inserted {
            unique.append(candidate)
        }

        guard !unique.isEmpty else { throw ContourExtractionError.noContourFound }

        return unique.prefix(detail.maxShapes).map { candidate in
            PolylineResampler.resample(candidate.points, to: sampleCount(for: candidate.points))
        }
    }

    private static func candidates(in cgImage: CGImage, pivot: Float, detail: PhotoDetailLevel) async throws -> [Candidate] {
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
            guard area >= detail.minimumArea, area < 0.85, contour.pointCount >= 8 else { continue }
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
