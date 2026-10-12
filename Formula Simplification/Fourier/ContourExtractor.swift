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
            return "사진에서 윤곽을 찾지 못했습니다. 배경이 단순하고 대비가 뚜렷한 사진을 사용해보세요."
        }
    }
}

/// Finds the most prominent contour in a photo using Vision's contour detector, then resamples
/// it to evenly spaced points so FourierFit can treat it as one closed curve.
nonisolated enum ContourExtractor {
    static func extractContour(from image: UIImage, sampleCount: Int = 160) async throws -> [CGPoint] {
        guard let cgImage = image.cgImage else { throw ContourExtractionError.noImage }

        var request = DetectContoursRequest()
        request.contrastAdjustment = 2.0
        request.detectsDarkOnLight = true
        request.maximumImageDimension = 512

        let observation = try await request.perform(on: cgImage)

        // Busy real-world photos produce many small, jagged texture contours with lots of
        // points; picking by point count favors that noise. The bounding-box area instead
        // favors the single largest shape in the frame — except the frame itself, which also
        // has a trivially large bounding box, so it's excluded first.
        let candidates = observation.topLevelContours.filter { areaOf($0) < 0.85 }
        let pool = candidates.isEmpty ? observation.topLevelContours : candidates
        guard let bestContour = pool.max(by: { areaOf($0) < areaOf($1) }),
              bestContour.pointCount > 4 else {
            throw ContourExtractionError.noContourFound
        }

        // Vision's normalized space has its origin at the bottom-left; flip y to match the
        // top-left, y-down space the rest of the app (and MathCanvasRenderer) uses.
        let rawPoints = bestContour.points.map { point in
            CGPoint(x: point.cgPoint.x, y: 1 - point.cgPoint.y)
        }

        return PolylineResampler.resample(rawPoints, to: sampleCount)
    }

    private static func areaOf(_ contour: ContoursObservation.Contour) -> Double {
        let box = contour.boundingBox
        return Double(box.width) * Double(box.height)
    }
}
