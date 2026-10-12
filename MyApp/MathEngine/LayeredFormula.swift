import CoreGraphics

/// One "artwork": x(t,k) and y(t,k) over t, repeated for k = 0..<kCount and overlaid —
/// the Naderi Yeganeh technique of building an image out of many overlapping curves.
nonisolated struct LayeredFormula: Equatable, Sendable {
    var xExpression: String
    var yExpression: String
    var tStart: Double = 0
    var tEnd: Double = 2 * Double.pi
    var samplesPerLayer: Int = 200
    var kCount: Int = 1
    var title: String = ""
    var summary: String = ""

    static let maxLayers = 4000
    static let maxSamplesPerLayer = 400

    /// Evaluates the formula into one polyline per layer. Throws on the first parse/evaluation error.
    func evaluate() throws -> [[CGPoint]] {
        let xExpr = try MathParser.parse(xExpression)
        let yExpr = try MathParser.parse(yExpression)
        let clampedK = min(max(kCount, 1), Self.maxLayers)
        let clampedSamples = min(max(samplesPerLayer, 2), Self.maxSamplesPerLayer)

        var layers: [[CGPoint]] = []
        layers.reserveCapacity(clampedK)
        for layerIndex in 0..<clampedK {
            let k = Double(layerIndex)
            var points: [CGPoint] = []
            points.reserveCapacity(clampedSamples)
            for sampleIndex in 0..<clampedSamples {
                let fraction = Double(sampleIndex) / Double(clampedSamples - 1)
                let t = tStart + fraction * (tEnd - tStart)
                let variables: [String: Double] = ["t": t, "k": k, "n": Double(clampedK)]
                let x = try MathEvaluator.evaluate(xExpr, variables: variables)
                let y = try MathEvaluator.evaluate(yExpr, variables: variables)
                points.append(CGPoint(x: x, y: y))
            }
            layers.append(points)
        }
        return layers
    }
}
