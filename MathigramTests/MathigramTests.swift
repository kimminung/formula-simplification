import Testing
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
