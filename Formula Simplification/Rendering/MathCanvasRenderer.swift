import SwiftUI

/// Pure data pipeline from math-space polylines to screen-space paths, kept free of view state
/// so the (potentially expensive) evaluate-and-fit step can run on a background task.
enum MathCanvasRenderer {
    /// Evaluates the formula, then fits every point into `rect`.
    /// `nonisolated` so this can run on a background Task.detached despite the project's
    /// default main-actor isolation.
    /// Evaluates every component and concatenates their layers before fitting, so components with
    /// very different scales (e.g. a heart plus a wide ring of small circles) still share one
    /// consistent frame — mixing several formulas into a single picture.
    nonisolated static func fittedLayers(for components: [LayeredFormula], fitting rect: CGRect) throws -> [[CGPoint]] {
        var all: [[CGPoint]] = []
        for component in components {
            all.append(contentsOf: try component.evaluate())
        }
        return fit(layers: all, in: rect)
    }

    /// Scales/translates an arbitrary set of polylines to fit within `rect`, preserving aspect
    /// ratio and flipping the y-axis (math-space is y-up; SwiftUI views are y-down).
    nonisolated static func fit(layers: [[CGPoint]], in rect: CGRect) -> [[CGPoint]] {
        guard rect.width > 0, rect.height > 0, layers.contains(where: { !$0.isEmpty }) else {
            return layers
        }

        var minX = Double.greatestFiniteMagnitude, maxX = -Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
        for layer in layers {
            for point in layer {
                minX = min(minX, point.x); maxX = max(maxX, point.x)
                minY = min(minY, point.y); maxY = max(maxY, point.y)
            }
        }
        let width = max(maxX - minX, 1e-6)
        let height = max(maxY - minY, 1e-6)
        let scale = min(Double(rect.width) / width, Double(rect.height) / height) * 0.92
        let midX = (minX + maxX) / 2
        let midY = (minY + maxY) / 2
        let originX = Double(rect.midX)
        let originY = Double(rect.midY)

        return layers.map { layer in
            layer.map { point in
                CGPoint(
                    x: originX + (point.x - midX) * scale,
                    y: originY - (point.y - midY) * scale
                )
            }
        }
    }

    nonisolated static func paths(from layers: [[CGPoint]]) -> [Path] {
        layers.map { layer in
            var path = Path()
            guard let first = layer.first else { return path }
            path.move(to: first)
            for point in layer.dropFirst() {
                path.addLine(to: point)
            }
            return path
        }
    }

    static func color(forLayer index: Int, of count: Int, settings: RenderSettings) -> Color {
        guard settings.isColorCycleEnabled, count > 1 else { return settings.strokeColor }
        return Color(hue: Double(index) / Double(count), saturation: 0.75, brightness: 0.9)
    }
}
