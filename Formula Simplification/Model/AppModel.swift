import SwiftUI

enum AppTab: Hashable {
    case draw, convert, gallery, settings
}

/// A Convert result (series + the term count that was in use) requested from the Gallery.
struct PendingConvertLoad: Equatable {
    let series: FourierSeries
    let termCount: Int
}

/// Root app state shared across tabs.
@Observable
final class AppModel {
    var selectedTab: AppTab = .draw
    var renderSettings = RenderSettings()

    /// Set by GalleryView when the user reopens a saved Draw/Convert artwork; the respective
    /// tab's view consumes and clears it.
    var pendingDrawComponents: [LayeredFormula]?
    var pendingConvertLoad: PendingConvertLoad?
}
