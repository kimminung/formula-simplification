import Foundation

/// Turns a raw expression string (and a LayeredFormula) into reader-friendly math notation.
enum FormulaFormatter {
    static func format(_ expression: String) -> String {
        var result = expression
        for (from, to) in [("pi", "π"), ("sqrt", "√"), ("*", "·")] {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result
    }

    static func notation(for formula: LayeredFormula) -> String {
        """
        x(t,k) = \(format(formula.xExpression))
        y(t,k) = \(format(formula.yExpression))
        t ∈ [\(formula.tStart.formatted(.number.precision(.fractionLength(2)))), \(formula.tEnd.formatted(.number.precision(.fractionLength(2))))],  k = 0 … \(max(formula.kCount - 1, 0))
        """
    }
}
