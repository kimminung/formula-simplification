import Foundation
import CoreGraphics

/// Fits a closed, evenly-resampled contour with a truncated discrete Fourier series — i.e.
/// finds the circles (epicycles) whose sum traces the contour. This is a real DFT, not a
/// visual approximation: more terms always reconstruct the original contour more closely.
nonisolated enum FourierFit {
    static let maxTerms = 200

    static func fit(contour points: [CGPoint]) -> FourierSeries {
        let n = points.count
        guard n > 1 else { return FourierSeries(terms: [], sampleCount: 360) }

        let half = n / 2
        var terms: [FourierTerm] = []
        terms.reserveCapacity(n)
        for k in -half...(n - half - 1) {
            var sumRe = 0.0, sumIm = 0.0
            for m in 0..<n {
                let angle = -2 * Double.pi * Double(k) * Double(m) / Double(n)
                let zx = Double(points[m].x), zy = Double(points[m].y)
                let cosA = cos(angle), sinA = sin(angle)
                // (zx + i·zy) * (cosA + i·sinA)
                sumRe += zx * cosA - zy * sinA
                sumIm += zx * sinA + zy * cosA
            }
            let re = sumRe / Double(n)
            let im = sumIm / Double(n)
            let amplitude = (re * re + im * im).squareRoot()
            guard amplitude > 1e-6 else { continue }
            terms.append(FourierTerm(k: k, amplitude: amplitude, phase: atan2(im, re)))
        }
        terms.sort { $0.amplitude > $1.amplitude }
        return FourierSeries(terms: Array(terms.prefix(maxTerms)), sampleCount: 360)
    }

    /// Fits every shape independently. All shapes must share one coordinate frame (e.g. the
    /// same normalized image space, or the same canvas) so their relative placement survives:
    /// each series' k=0 term stores that shape's own center.
    static func fit(shapes: [[CGPoint]]) -> [FourierSeries] {
        shapes.map { fit(contour: $0) }
    }

    /// A DFT assumes the signal is periodic, so an open stroke would otherwise get a straight
    /// "rubber-band" segment snapping its end back to its start. Walking the stroke forward and
    /// then backward makes it periodic while only ever tracing the line the user actually drew.
    static func closedLoop(from points: [CGPoint]) -> [CGPoint] {
        guard isOpen(points) else { return points }
        let interior = points.dropFirst().dropLast().reversed()
        return points + interior
    }

    static func isOpen(_ points: [CGPoint]) -> Bool {
        guard points.count > 2, let first = points.first, let last = points.last else { return false }
        var length = 0.0
        for i in 1..<points.count {
            length += hypot(Double(points[i].x - points[i - 1].x), Double(points[i].y - points[i - 1].y))
        }
        let gap = hypot(Double(last.x - first.x), Double(last.y - first.y))
        return length > 0 && gap > length * 0.12
    }
}
