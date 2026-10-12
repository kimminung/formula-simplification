import SwiftUI

enum AppTab: Hashable {
    case draw, convert, gallery, settings
}

/// Root app state shared across tabs.
@Observable
final class AppModel {
    var selectedTab: AppTab = .draw
    var renderSettings = RenderSettings()
}
