import SwiftUI
import Combine
import MapKit

enum MapDisplayMode {
    case weather
    case tracking
}

// Custom Map Style
enum CustomMapStyle: String, CaseIterable {
    case standard, hybrid
    
    // Conversion to MapStyle (for Map)
    func toMapStyle() -> MapStyle {
        switch self {
        case .standard:
            return .standard
        case .hybrid:
            return .hybrid
        }
    }

    // Conversion to Maptype (for MKMapView)
    func toMapType() -> MKMapType {
        switch self {
        case .standard:
            return .standard
        case .hybrid:
            return .hybrid
        }
    }
}

class MapSettingsViewModel: ObservableObject {
    @Published var region: MKCoordinateRegion
    @Published var selectedMapType: CustomMapStyle
    @Published var pilotTrackDays: Double
    @Published var mapDisplayMode: MapDisplayMode
    @Published var showSites: Bool
    @Published var showStations: Bool

    init(region: MKCoordinateRegion,
         selectedMapType: CustomMapStyle = defaultmapType,
         pilotTrackDays: Double = defaultPilotTrackDays,
         mapDisplayMode: MapDisplayMode = defaultmapDisplayMode,
         showSites: Bool = false,
         showStations: Bool = true
    ) {
        self.region = region
        self.selectedMapType = selectedMapType
        self.pilotTrackDays = pilotTrackDays
        self.mapDisplayMode = mapDisplayMode
        self.showSites = showSites
        self.showStations = showStations
    }
    
    var isMapWeatherMode: Bool { mapDisplayMode == .weather }
    var isMapTrackingMode: Bool { mapDisplayMode == .tracking }
    var isMapDisplayingSites: Bool { mapDisplayMode == .weather && showSites }
    var isMapDisplayingStations: Bool { mapDisplayMode == .weather && showStations }
}

// Composite structure to check for all map settings and view changes together
// and only rebuild annotations once if there are multiple changes
struct MapSettingsState: Equatable {
    let pilotTrackDays: Double
    let mapDisplayMode: MapDisplayMode
    let showSites: Bool
    let showStations: Bool
    let scenePhase: ScenePhase
}
