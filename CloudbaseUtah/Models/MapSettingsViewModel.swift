import SwiftUI
import Combine
import MapKit

// Custom Map Style Enum
enum CustomMapStyle: String, CaseIterable {
    case standard, hybrid
    func toMapStyle() -> MapStyle {
        switch self {
        case .standard:
            return .standard
        case .hybrid:
            return .hybrid
        }
    }
}

// Model to retain map settings (center, zoom, layers) when navigating between views
class MapSettingsViewModel: ObservableObject {
    @Published var region: MKCoordinateRegion
    @Published var activeLayers: Set<MapLayer>
    @Published var selectedMapType: CustomMapStyle
    @Published var pilotTrackDays: Double

    init(region: MKCoordinateRegion,
         activeLayers: Set<MapLayer>,
         selectedMapType: CustomMapStyle = .standard,
         pilotTrackDays: Double = defaultPilotTrackDays)
    {
        self.region = region
        self.activeLayers = activeLayers
        self.selectedMapType = selectedMapType
        self.pilotTrackDays = pilotTrackDays
    }
}

// Define map layers
enum MapLayer: String, Equatable, CaseIterable {
    case sites,
         stations,
         pilots
    /*,
         precipitation,
         cloudCover,
         tracks,
         thermalHeatMap,
         flySkyHyAirspace
     */

    var name: String {
        switch self {
        case .sites: return "Paragliding sites"
        case .stations: return "Wind stations"
        case .pilots: return "Live tracking"
    /*
        case .precipitation: return "Precipitation"
        case .cloudCover: return "Cloud cover"
        case .tracks: return "Skyways"
        case .thermalHeatMap: return "Thermals"
        case .flySkyHyAirspace: return "FlySkyHy LZs and thermal hotspots"
     */
        }
    }
    
    var description: String {
        switch self {
        case .sites: return "Select site for readings and forecast"
        case .stations: return "Select station for readings and forecast"
        case .pilots: return "inReach GPS live tracking"
    /*
        case .precipitation: return "Past and forecasted precipitation \n(provided by www.rainviewer.com)"
        case .cloudCover: return "Past and forecasted cloud coverage \n(provided by www.rainviewer.com)"
        case .tracks: return "Tracks from thermal.kk7"
        case .thermalHeatMap: return "Heat map from thermal.kk7"
        case .flySkyHyAirspace: return "Preview of custom airspace \n(use Links tab to load into FlySkyHy)"
     */
        }
    }
}
