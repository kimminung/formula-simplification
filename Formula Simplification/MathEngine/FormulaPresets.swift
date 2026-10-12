import Foundation

struct FormulaPreset: Identifiable {
    let id = UUID()
    let title: String
    /// One or more LayeredFormula components overlaid into a single picture — mixing several
    /// different formulas into one image is exactly the Naderi Yeganeh technique.
    let components: [LayeredFormula]
}

/// Starting points spanning single classic curves, Naderi-Yeganeh-style layered bundles (many
/// overlapping curves from one formula), and composites that mix several *different* formulas
/// into one picture.
enum FormulaPresets {
    static let all: [FormulaPreset] = [
        FormulaPreset(title: "하트 곡선", components: [LayeredFormula(
            xExpression: "16*sin(t)^3",
            yExpression: "13*cos(t) - 5*cos(2*t) - 2*cos(3*t) - cos(4*t)",
            tStart: 0, tEnd: 2 * .pi, samplesPerLayer: 300, kCount: 1,
            title: "하트 곡선",
            summary: "x=16sin³t, y=13cos t−5cos2t−2cos3t−cos4t"
        )]),
        FormulaPreset(title: "장미 곡선 (5개 꽃잎)", components: [LayeredFormula(
            xExpression: "cos(5*t) * cos(t)",
            yExpression: "cos(5*t) * sin(t)",
            tStart: 0, tEnd: 2 * .pi, samplesPerLayer: 300, kCount: 1,
            title: "장미 곡선",
            summary: "극좌표 장미 곡선 r=cos(5θ)"
        )]),
        FormulaPreset(title: "리사주 곡선 (3:4)", components: [LayeredFormula(
            xExpression: "sin(3*t)",
            yExpression: "sin(4*t + pi/2)",
            tStart: 0, tEnd: 2 * .pi, samplesPerLayer: 300, kCount: 1,
            title: "리사주 곡선",
            summary: "x=sin3t, y=sin(4t+π/2)"
        )]),
        FormulaPreset(title: "나비 곡선", components: [LayeredFormula(
            xExpression: "sin(t) * (exp(cos(t)) - 2*cos(4*t) - sin(t/12)^5)",
            yExpression: "cos(t) * (exp(cos(t)) - 2*cos(4*t) - sin(t/12)^5)",
            tStart: 0, tEnd: 12 * .pi, samplesPerLayer: 400, kCount: 1,
            title: "나비 곡선",
            summary: "Temple Fay의 나비 곡선"
        )]),
        FormulaPreset(title: "스피로그래프 다발", components: [LayeredFormula(
            xExpression: "(5 - (1 + k*0.08)) * cos(t) + 3*cos((5 - (1 + k*0.08)) / (1 + k*0.08) * t)",
            yExpression: "(5 - (1 + k*0.08)) * sin(t) - 3*sin((5 - (1 + k*0.08)) / (1 + k*0.08) * t)",
            tStart: 0, tEnd: 2 * .pi, samplesPerLayer: 240, kCount: 24,
            title: "스피로그래프 다발",
            summary: "내접원 반지름을 k마다 조금씩 바꾼 하이포트로코이드 24겹"
        )]),
        FormulaPreset(title: "나선 다발 (은하)", components: [LayeredFormula(
            xExpression: "t * cos(t + k * 2*pi/n)",
            yExpression: "t * sin(t + k * 2*pi/n)",
            tStart: 0, tEnd: 6 * .pi, samplesPerLayer: 220, kCount: 36,
            title: "나선 다발",
            summary: "같은 나선을 k번 회전시켜 겹친 은하 모양"
        )]),
        FormulaPreset(title: "원형 체인", components: [LayeredFormula(
            xExpression: "2*cos(k * 2*pi/n) + cos(t)",
            yExpression: "2*sin(k * 2*pi/n) + sin(t)",
            tStart: 0, tEnd: 2 * .pi, samplesPerLayer: 120, kCount: 18,
            title: "원형 체인",
            summary: "중심이 고리 모양으로 배치된 단위원 18개"
        )]),
        FormulaPreset(title: "카디오이드 실 그림", components: [LayeredFormula(
            xExpression: "(1-t)*cos(k * 2*pi/n) + t*cos(k * 4*pi/n)",
            yExpression: "(1-t)*sin(k * 2*pi/n) + t*sin(k * 4*pi/n)",
            tStart: 0, tEnd: 1, samplesPerLayer: 2, kCount: 200,
            title: "카디오이드 실 그림",
            summary: "원 위의 점 k와 2k를 잇는 직선 200개의 포락선 — 전통 실 그림(string art) 기법"
        )]),
        FormulaPreset(title: "아스트로이드", components: [LayeredFormula(
            xExpression: "cos(t)^3",
            yExpression: "sin(t)^3",
            tStart: 0, tEnd: 2 * .pi, samplesPerLayer: 240, kCount: 1,
            title: "아스트로이드",
            summary: "x=cos³t, y=sin³t"
        )]),
        FormulaPreset(title: "파동 격자", components: [LayeredFormula(
            xExpression: "t",
            yExpression: "k*0.18 + 0.12*sin(t*3 + k*0.4)",
            tStart: -1.6, tEnd: 1.6, samplesPerLayer: 120, kCount: 28,
            title: "파동 격자",
            summary: "같은 위상이 밀린 사인파 28줄을 겹친 격자"
        )]),

        // Composites: two genuinely different formulas mixed into one picture.
        FormulaPreset(title: "혼합: 하트 + 별자리 고리", components: [
            LayeredFormula(
                xExpression: "16*sin(t)^3",
                yExpression: "13*cos(t) - 5*cos(2*t) - 2*cos(3*t) - cos(4*t)",
                tStart: 0, tEnd: 2 * .pi, samplesPerLayer: 300, kCount: 1,
                title: "하트", summary: "x=16sin³t, y=13cos t−5cos2t−2cos3t−cos4t"
            ),
            LayeredFormula(
                xExpression: "22*cos(k*2*pi/n) + 2*cos(t)",
                yExpression: "22*sin(k*2*pi/n) + 2*sin(t)",
                tStart: 0, tEnd: 2 * .pi, samplesPerLayer: 40, kCount: 40,
                title: "별자리 고리", summary: "작은 원 40개를 큰 고리 모양으로 배치"
            ),
        ]),
        FormulaPreset(title: "혼합: 은하 + 중심핵", components: [
            LayeredFormula(
                xExpression: "t * cos(t + k * 2*pi/n)",
                yExpression: "t * sin(t + k * 2*pi/n)",
                tStart: 0, tEnd: 6 * .pi, samplesPerLayer: 220, kCount: 36,
                title: "나선 팔", summary: "같은 나선을 k번 회전시켜 겹친 모양"
            ),
            LayeredFormula(
                xExpression: "(0.3 + k*0.05) * cos(t)",
                yExpression: "(0.3 + k*0.05) * sin(t)",
                tStart: 0, tEnd: 2 * .pi, samplesPerLayer: 60, kCount: 14,
                title: "중심핵", summary: "반지름이 커지는 동심원 14겹으로 만든 은하 중심"
            ),
        ]),
    ]
}
