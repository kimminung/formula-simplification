import SwiftUI

/// Shared look-and-feel for both the Draw and Convert canvases.
struct RenderSettings {
    var strokeColor: Color = .black
    var strokeWidth: Double = 1.0
    var isColorCycleEnabled: Bool = false
    var isDarkBackground: Bool = false

    var backgroundColor: Color {
        isDarkBackground ? .black : .white
    }
}
