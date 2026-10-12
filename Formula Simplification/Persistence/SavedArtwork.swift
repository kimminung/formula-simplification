import Foundation
import SwiftData

enum ArtworkKind: String, Codable, Sendable {
    case draw, convert
}

/// A saved Draw or Convert result. Draw stores its (possibly several, mixed-together) formula
/// components as JSON; Convert stores the fitted FourierSeries and the term count in use, also
/// as JSON — SwiftData models can't hold arbitrary struct arrays as typed properties.
@Model
final class SavedArtwork {
    var kind: ArtworkKind
    var title: String
    var createdAt: Date
    @Attribute(.externalStorage) var thumbnailData: Data?

    var drawComponentsJSON: Data?

    var fourierTermsJSON: Data?
    var fourierSampleCount: Int?
    var fourierTermCount: Int?

    init(kind: ArtworkKind, title: String, thumbnailData: Data?, createdAt: Date = .now) {
        self.kind = kind
        self.title = title
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
    }

    func apply(components: [LayeredFormula]) {
        drawComponentsJSON = try? JSONEncoder().encode(components)
    }

    var storedComponents: [LayeredFormula]? {
        guard let data = drawComponentsJSON,
              let components = try? JSONDecoder().decode([LayeredFormula].self, from: data),
              !components.isEmpty else {
            return nil
        }
        return components
    }

    func apply(shapes: [FourierSeries], termCount: Int) {
        fourierTermsJSON = try? JSONEncoder().encode(shapes)
        fourierSampleCount = shapes.first?.sampleCount
        fourierTermCount = termCount
    }

    var storedShapes: (shapes: [FourierSeries], termCount: Int)? {
        guard let data = fourierTermsJSON, let termCount = fourierTermCount else { return nil }
        let decoder = JSONDecoder()
        if let shapes = try? decoder.decode([FourierSeries].self, from: data), !shapes.isEmpty {
            return (shapes, termCount)
        }
        // Artworks saved before multi-shape support stored a single shape's bare term list.
        if let terms = try? decoder.decode([FourierTerm].self, from: data), let sampleCount = fourierSampleCount {
            return ([FourierSeries(terms: terms, sampleCount: sampleCount)], termCount)
        }
        return nil
    }
}
