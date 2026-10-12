import Foundation
import CoreGraphics

nonisolated struct FourierTerm: Identifiable, Sendable, Codable, Equatable {
    let id: UUID
    /// Signed frequency — how many times this epicycle turns per period.
    let k: Int
    let amplitude: Double
    let phase: Double

    init(k: Int, amplitude: Double, phase: Double) {
        self.id = UUID()
        self.k = k
        self.amplitude = amplitude
        self.phase = phase
    }
}

/// A truncated discrete Fourier series fit to a closed contour — the classic "draw any shape
/// with epicycles" technique. `terms` is sorted by amplitude descending; `points(usingTermCount:)`
/// sums however many of the strongest terms the caller wants into one closed polyline.
nonisolated struct FourierSeries: Sendable, Codable, Equatable {
    let terms: [FourierTerm]
    let sampleCount: Int

    func points(usingTermCount termCount: Int) -> [CGPoint] {
        let used = terms.prefix(max(termCount, 1))
        guard !used.isEmpty else { return [] }
        var points: [CGPoint] = []
        points.reserveCapacity(sampleCount)
        for i in 0..<sampleCount {
            let t = Double(i) / Double(sampleCount - 1) * 2 * Double.pi
            var x = 0.0, y = 0.0
            for term in used {
                let angle = Double(term.k) * t + term.phase
                x += term.amplitude * cos(angle)
                y += term.amplitude * sin(angle)
            }
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }
}
