import SwiftUI

/// Owns one LayeredFormula draft and its debounced, background-evaluated render.
@Observable
final class DrawModel {
    var formula: LayeredFormula
    private(set) var layerPaths: [Path] = []
    private(set) var errorMessage: String?

    private var debounceTask: Task<Void, Never>?

    init(formula: LayeredFormula) {
        self.formula = formula
    }

    /// Cancels any pending render and schedules a new one 450ms out, matching the live-preview
    /// feel of the reference project's code editor without ever blocking the UI thread.
    func scheduleRender(in rect: CGRect) {
        guard rect.width > 0, rect.height > 0 else { return }
        debounceTask?.cancel()
        let snapshot = formula
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await self?.render(snapshot, in: rect)
        }
    }

    @MainActor
    private func render(_ formula: LayeredFormula, in rect: CGRect) async {
        do {
            let layers = try await Task.detached(priority: .userInitiated) {
                try MathCanvasRenderer.fittedLayers(for: formula, fitting: rect)
            }.value
            guard !Task.isCancelled else { return }
            layerPaths = MathCanvasRenderer.paths(from: layers)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
