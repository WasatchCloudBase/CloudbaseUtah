import SwiftUI
import MapKit
import Combine
import UIKit

// Custom Map Style Enum
enum CustomMapStyle: String, CaseIterable {
    case standard, hybrid
    func toMapKitType() -> MKMapType {
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

    init(region: MKCoordinateRegion,
         activeLayers: Set<MapLayer>,
         selectedMapType: CustomMapStyle = .standard)
    {
        self.region = region
        self.activeLayers = activeLayers
        self.selectedMapType = selectedMapType
    }
}

// Define map layers
enum MapLayer: String, CaseIterable {
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

struct LayerSelectionView: View {
    @Binding var activeLayers: Set<MapLayer>
    @Binding var selectedMapType: CustomMapStyle
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .padding()
                Spacer()
            }
            .background(Color.blue.opacity(0.2))

            List {
                Section(header: Text("Map Type")) {
                    Picker("Map Type", selection: $selectedMapType) {
                        ForEach(CustomMapStyle.allCases, id: \.self) { style in
                            Text(style.rawValue.capitalized)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section(header: Text("Map Layers")) {
                    ForEach(MapLayer.allCases, id: \.self) { layer in
                        Toggle(isOn: Binding(
                            get: { activeLayers.contains(layer) },
                            set: { isActive in
                                if isActive {
                                    activeLayers.insert(layer)
                                } else {
                                    activeLayers.remove(layer)
                                }
                            }
                        )) {
                            VStack(alignment: .leading) {
                                Text(layer.name)
                                Text(layer.description)
                                    .font(.subheadline)
                                    .foregroundColor(infoFontColor)
                            }
                        }
                    }
                }
            }
        }
    }
}
