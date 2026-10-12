import Foundation
import SwiftData

enum ArtworkKind: String, Codable, Sendable {
    case draw, convert
}

/// A saved Draw or Convert result. Draw stores the LayeredFormula's fields directly; Convert
/// stores the fitted FourierSeries (and the term count in use) as JSON, since SwiftData models
/// can't hold arbitrary struct arrays as typed properties.
@Model
final class SavedArtwork {
    var kind: ArtworkKind
    var title: String
    var createdAt: Date
    @Attribute(.externalStorage) var thumbnailData: Data?

    var drawXExpression: String?
    var drawYExpression: String?
    var drawTStart: Double?
    var drawTEnd: Double?
    var drawSamplesPerLayer: Int?
    var drawKCount: Int?

    var fourierTermsJSON: Data?
    var fourierSampleCount: Int?
    var fourierTermCount: Int?

    init(kind: ArtworkKind, title: String, thumbnailData: Data?, createdAt: Date = .now) {
        self.kind = kind
        self.title = title
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
    }

    func apply(formula: LayeredFormula) {
        drawXExpression = formula.xExpression
        drawYExpression = formula.yExpression
        drawTStart = formula.tStart
        drawTEnd = formula.tEnd
        drawSamplesPerLayer = formula.samplesPerLayer
        drawKCount = formula.kCount
    }

    var storedFormula: LayeredFormula? {
        guard let x = drawXExpression, let y = drawYExpression,
              let tStart = drawTStart, let tEnd = drawTEnd,
              let samples = drawSamplesPerLayer, let kCount = drawKCount else { return nil }
        return LayeredFormula(
            xExpression: x, yExpression: y,
            tStart: tStart, tEnd: tEnd,
            samplesPerLayer: samples, kCount: kCount,
            title: title
        )
    }

    func apply(series: FourierSeries, termCount: Int) {
        fourierTermsJSON = try? JSONEncoder().encode(series.terms)
        fourierSampleCount = series.sampleCount
        fourierTermCount = termCount
    }

    var storedSeries: (series: FourierSeries, termCount: Int)? {
        guard let data = fourierTermsJSON,
              let sampleCount = fourierSampleCount,
              let termCount = fourierTermCount,
              let terms = try? JSONDecoder().decode([FourierTerm].self, from: data) else {
            return nil
        }
        return (FourierSeries(terms: terms, sampleCount: sampleCount), termCount)
    }
}
