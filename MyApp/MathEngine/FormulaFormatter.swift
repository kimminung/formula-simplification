import Foundation

/// Turns a raw expression string (and a LayeredFormula) into reader-friendly math notation.
nonisolated enum FormulaFormatter {
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

    /// Several components mixed into one picture get numbered sections, so it's clear which
    /// formula draws which part of the combined image.
    static func notation(for components: [LayeredFormula]) -> String {
        guard components.count > 1 else {
            guard let only = components.first else { return "" }
            return notation(for: only)
        }
        return components.enumerated().map { index, component in
            "— 구성요소 \(index + 1) —\n" + notation(for: component)
        }.joined(separator: "\n\n")
    }
}
