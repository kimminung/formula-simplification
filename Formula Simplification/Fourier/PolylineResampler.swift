import CoreGraphics

/// Shared by both Convert inputs (Vision contours and hand-drawn sketches): re-samples an
/// arbitrary polyline to `count` points evenly spaced along its arc length, so FourierFit always
/// works with a uniform parameterization regardless of how dense the source points were.
nonisolated enum PolylineResampler {
    static func resample(_ points: [CGPoint], to count: Int) -> [CGPoint] {
        guard points.count > 1, count > 1 else { return points }

        var distances: [Double] = [0]
        distances.reserveCapacity(points.count)
        for i in 1..<points.count {
            let dx = Double(points[i].x - points[i - 1].x)
            let dy = Double(points[i].y - points[i - 1].y)
            distances.append(distances[i - 1] + (dx * dx + dy * dy).squareRoot())
        }
        let total = distances.last ?? 0
        guard total > 0 else { return points }

        var result: [CGPoint] = []
        result.reserveCapacity(count)
        var segmentIndex = 0
        for sampleIndex in 0..<count {
            let targetDistance = total * Double(sampleIndex) / Double(count)
            while segmentIndex < distances.count - 2, distances[segmentIndex + 1] < targetDistance {
                segmentIndex += 1
            }
            let segmentStart = distances[segmentIndex]
            let segmentEnd = distances[segmentIndex + 1]
            let segmentLength = segmentEnd - segmentStart
            let fraction = segmentLength > 0 ? (targetDistance - segmentStart) / segmentLength : 0
            let p0 = points[segmentIndex]
            let p1 = points[segmentIndex + 1]
            result.append(CGPoint(
                x: p0.x + (p1.x - p0.x) * fraction,
                y: p0.y + (p1.y - p0.y) * fraction
            ))
        }
        return result
    }
}
