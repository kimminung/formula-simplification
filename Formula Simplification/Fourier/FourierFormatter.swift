import Foundation

/// Turns fitted Fourier series into reader-friendly math notation, showing only the strongest
/// terms actually in use (the rest are summarized as a count).
nonisolated enum FourierFormatter {
    static func notation(for series: FourierSeries, termCount: Int) -> String {
        let used = Array(series.terms.prefix(max(termCount, 0)))
        guard !used.isEmpty else { return "아직 분석된 수식이 없습니다." }

        var text = "x(t)=Σₖ rₖcos(kt+φₖ), y(t)=Σₖ rₖsin(kt+φₖ)\n\n" + termLines(used, limit: 8)
        if used.count > 8 {
            text += "\n⋯ 외 \(used.count - 8)개 항 (총 \(used.count)개 사용 중)"
        }
        return text
    }

    /// A picture decomposed into several shapes: one series per shape, each with its own
    /// `k, r, φ` terms. The first few shapes are listed; the rest are summarized.
    static func notation(for shapes: [FourierSeries], termCount: Int) -> String {
        guard !shapes.isEmpty else { return "아직 분석된 수식이 없습니다." }
        if shapes.count == 1 { return notation(for: shapes[0], termCount: termCount) }

        let usedCounts = shapes.map { min($0.terms.count, max(termCount, 0)) }
        let totalTerms = usedCounts.reduce(0, +)
        var text = "도형 \(shapes.count)개 · 도형당 최대 \(termCount)항 · 총 \(totalTerms)항\n"
        text += "각 도형 j:  xⱼ(t)=Σₖ rₖcos(kt+φₖ), yⱼ(t)=Σₖ rₖsin(kt+φₖ)\n"

        let shownShapes = shapes.prefix(3)
        for (index, series) in shownShapes.enumerated() {
            let used = Array(series.terms.prefix(max(termCount, 0)))
            text += "\n— 도형 \(index + 1) (\(used.count)항) —\n" + termLines(used, limit: 4)
            if used.count > 4 { text += "\n⋯ 외 \(used.count - 4)개 항" }
        }
        if shapes.count > shownShapes.count {
            text += "\n\n⋯ 외 도형 \(shapes.count - shownShapes.count)개"
        }
        return text
    }

    private static func termLines(_ terms: [FourierTerm], limit: Int) -> String {
        terms.prefix(limit).map { term in
            let r = term.amplitude.formatted(.number.precision(.fractionLength(3)))
            let phi = term.phase.formatted(.number.precision(.fractionLength(2)))
            return "k=\(term.k)\tr=\(r)\tφ=\(phi)"
        }.joined(separator: "\n")
    }
}
