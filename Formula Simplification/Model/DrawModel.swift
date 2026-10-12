import SwiftUI

/// Owns the components of one artwork (one or more LayeredFormula pieces mixed together)
/// and its debounced, background-evaluated render.
@Observable
final class DrawModel {
    var components: [LayeredFormula]
    var selectedComponentIndex = 0
    private(set) var layerPaths: [Path] = []
    private(set) var errorMessage: String?

    private var debounceTask: Task<Void, Never>?

    init(components: [LayeredFormula]) {
        self.components = components
    }

    /// The component currently shown in the formula editor fields.
    var selectedComponent: LayeredFormula {
        get { components[clampedSelectedIndex] }
        set { components[clampedSelectedIndex] = newValue }
    }

    private var clampedSelectedIndex: Int {
        min(max(selectedComponentIndex, 0), components.count - 1)
    }

    func replaceAllComponents(_ newComponents: [LayeredFormula]) {
        components = newComponents
        selectedComponentIndex = 0
    }

    func addComponent() {
        components.append(LayeredFormula(xExpression: "cos(t)", yExpression: "sin(t)"))
        selectedComponentIndex = components.count - 1
    }

    func removeSelectedComponent() {
        guard components.count > 1 else { return }
        components.remove(at: clampedSelectedIndex)
        selectedComponentIndex = min(selectedComponentIndex, components.count - 1)
    }

    /// Cancels any pending render and schedules a new one 450ms out, matching the live-preview
    /// feel of the reference project's code editor without ever blocking the UI thread.
    func scheduleRender(in rect: CGRect) {
        guard rect.width > 0, rect.height > 0 else { return }
        debounceTask?.cancel()
        let snapshot = components
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await self?.render(snapshot, in: rect)
        }
    }

    @MainActor
    private func render(_ components: [LayeredFormula], in rect: CGRect) async {
        do {
            let layers = try await Task.detached(priority: .userInitiated) {
                try MathCanvasRenderer.fittedLayers(for: components, fitting: rect)
            }.value
            guard !Task.isCancelled else { return }
            layerPaths = MathCanvasRenderer.paths(from: layers)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
