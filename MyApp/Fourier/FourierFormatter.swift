import Foundation

/// Turns a fitted FourierSeries into reader-friendly math notation, showing only the strongest
/// terms actually in use (the rest are summarized as a count).
nonisolated enum FourierFormatter {
    static func notation(for series: FourierSeries, termCount: Int) -> String {
        let used = Array(series.terms.prefix(max(termCount, 0)))
        guard !used.isEmpty else { return "아직 분석된 수식이 없습니다." }

        let shown = used.prefix(8)
        let lines = shown.map { term -> String in
            let r = term.amplitude.formatted(.number.precision(.fractionLength(3)))
            let phi = term.phase.formatted(.number.precision(.fractionLength(2)))
            return "k=\(term.k)\tr=\(r)\tφ=\(phi)"
        }

        var text = "x(t)=Σₖ rₖcos(kt+φₖ), y(t)=Σₖ rₖsin(kt+φₖ)\n\n" + lines.joined(separator: "\n")
        if used.count > shown.count {
            text += "\n⋯ 외 \(used.count - shown.count)개 항 (총 \(used.count)개 사용 중)"
        }
        return text
    }
}
