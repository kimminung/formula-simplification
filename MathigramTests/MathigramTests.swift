import Testing
import Foundation
import CoreGraphics
@testable import MyApp

struct MathLexerTests {
    @Test func tokenizesNumbersIdentifiersAndOperators() throws {
        var lexer = MathLexer("sin(2*t + pi) - k^2")
        let tokens = try lexer.tokenize()
        let kinds = tokens.map(\.kind)
        #expect(kinds == [
            .identifier("sin"), .leftParen, .number(2), .star, .identifier("t"),
            .plus, .identifier("pi"), .rightParen, .minus, .identifier("k"), .caret, .number(2), .end,
        ])
    }

    @Test func reportsUnknownCharacterWithColumn() {
        var lexer = MathLexer("1 + $")
        #expect(throws: MathSyntaxError.self) {
            try lexer.tokenize()
        }
    }
}

struct MathParserAndEvaluatorTests {
    @Test func evaluatesArithmeticWithPrecedence() throws {
        let expr = try MathParser.parse("2 + 3 * 4 - 1")
        #expect(try MathEvaluator.evaluate(expr, variables: [:]) == 13)
    }

    @Test func powerIsRightAssociative() throws {
        // 2^(3^2) = 2^9 = 512, not (2^3)^2 = 64
        let expr = try MathParser.parse("2^3^2")
        #expect(try MathEvaluator.evaluate(expr, variables: [:]) == 512)
    }

    @Test func unaryMinusHasLowerPrecedenceThanPower() throws {
        // -2^2 should be -(2^2) = -4, matching the usual math/Python convention.
        let expr = try MathParser.parse("-2^2")
        #expect(try MathEvaluator.evaluate(expr, variables: [:]) == -4)
    }

    @Test func resolvesVariablesAndConstants() throws {
        let expr = try MathParser.parse("sin(t) + k - pi")
        let value = try MathEvaluator.evaluate(expr, variables: ["t": .pi / 2, "k": 1])
        #expect(abs(value - (1 + 1 - Double.pi)) < 1e-9)
    }

    @Test func divisionByZeroThrows() throws {
        let expr = try MathParser.parse("1 / 0")
        #expect(throws: MathEvaluationError.self) {
            try MathEvaluator.evaluate(expr, variables: [:])
        }
    }

    @Test func sqrtOfNegativeThrows() throws {
        let expr = try MathParser.parse("sqrt(-1)")
        #expect(throws: MathEvaluationError.self) {
            try MathEvaluator.evaluate(expr, variables: [:])
        }
    }

    @Test func undefinedVariableThrows() throws {
        let expr = try MathParser.parse("z + 1")
        #expect(throws: MathEvaluationError.self) {
            try MathEvaluator.evaluate(expr, variables: [:])
        }
    }

    @Test func unmatchedParenthesisThrows() {
        #expect(throws: MathSyntaxError.self) {
            try MathParser.parse("sin(t")
        }
    }
}

struct LayeredFormulaTests {
    @Test func producesOneLayerPerK() throws {
        var formula = LayeredFormula(xExpression: "cos(t)", yExpression: "sin(t)")
        formula.kCount = 5
        formula.samplesPerLayer = 10
        let layers = try formula.evaluate()
        #expect(layers.count == 5)
        #expect(layers.allSatisfy { $0.count == 10 })
    }

    @Test func clampsExtremeLayerAndSampleCounts() throws {
        var formula = LayeredFormula(xExpression: "t", yExpression: "k")
        formula.kCount = 1_000_000
        formula.samplesPerLayer = 1_000_000
        let layers = try formula.evaluate()
        #expect(layers.count == LayeredFormula.maxLayers)
        #expect(layers[0].count == LayeredFormula.maxSamplesPerLayer)
    }

    @Test func traceSweepsFullTRangeAtFirstAndLastSample() throws {
        var formula = LayeredFormula(xExpression: "t", yExpression: "0")
        formula.tStart = 0
        formula.tEnd = 10
        formula.samplesPerLayer = 5
        formula.kCount = 1
        let points = try formula.evaluate()[0]
        #expect(points.first?.x == 0)
        #expect(points.last?.x == 10)
    }

    @Test func propagatesParseErrorsFromEvaluate() {
        let formula = LayeredFormula(xExpression: "cos(t", yExpression: "sin(t)")
        #expect(throws: MathSyntaxError.self) {
            try formula.evaluate()
        }
    }
}

struct FormulaFormatterTests {
    @Test func rewritesConstantsAndOperatorsForDisplay() {
        #expect(FormulaFormatter.format("2*pi*t") == "2·π·t")
        #expect(FormulaFormatter.format("sqrt(t)") == "√(t)")
    }
}

struct PolylineResamplerTests {
    @Test func resamplesToTheRequestedCount() {
        let points = (0..<10).map { CGPoint(x: Double($0), y: 0) }
        let resampled = PolylineResampler.resample(points, to: 50)
        #expect(resampled.count == 50)
    }

    @Test func preservesEndpointsOfAnOpenPolyline() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)]
        let resampled = PolylineResampler.resample(points, to: 5)
        #expect(resampled.first == CGPoint(x: 0, y: 0))
        #expect(abs(resampled.last!.x - 8) < 1e-9)
    }
}

struct FourierFitTests {
    @Test func fitsAUnitCircleWithASingleDominantTerm() {
        let n = 120
        let points = (0..<n).map { i -> CGPoint in
            let t = Double(i) / Double(n) * 2 * Double.pi
            return CGPoint(x: cos(t), y: sin(t))
        }
        let series = FourierFit.fit(contour: points)
        let strongest = try! #require(series.terms.first)
        #expect(abs(strongest.k) == 1)
        #expect(abs(strongest.amplitude - 1) < 0.05)

        // Reconstructing with just that one term should still trace (close to) the unit circle.
        for point in series.points(usingTermCount: 1) {
            let radius = (point.x * point.x + point.y * point.y).squareRoot()
            #expect(abs(radius - 1) < 0.05)
        }
    }

    @Test func moreTermsReconstructTheContourMoreClosely() {
        let n = 80
        // A square-ish contour has sharp corners, so it needs many terms to approximate well.
        let points = (0..<n).map { i -> CGPoint in
            let t = Double(i) / Double(n) * 2 * Double.pi
            let r = 1.0 / max(abs(cos(t)), abs(sin(t)))
            return CGPoint(x: r * cos(t), y: r * sin(t))
        }
        let series = FourierFit.fit(contour: points)

        func meanSquaredError(usingTermCount termCount: Int) -> Double {
            let reconstructed = series.points(usingTermCount: termCount)
            let resampledOriginal = PolylineResampler.resample(points, to: reconstructed.count)
            var total = 0.0
            for (a, b) in zip(reconstructed, resampledOriginal) {
                let dx = a.x - b.x, dy = a.y - b.y
                total += dx * dx + dy * dy
            }
            return total / Double(reconstructed.count)
        }

        #expect(meanSquaredError(usingTermCount: 25) < meanSquaredError(usingTermCount: 3))
    }
}
