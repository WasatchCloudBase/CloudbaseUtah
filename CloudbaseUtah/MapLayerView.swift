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

// This view uses temporary variables while the sheet is open, then publishes when the sheet is closed.
// This is done to prevent lag on this sheet each time a view item is changed.
struct LayerSelectionView: View {
    @Binding var activeLayers: Set<MapLayer>
    @Binding var selectedMapType: CustomMapStyle
    @Binding var pilotTrackDays: Double
    @Environment(\.presentationMode) var presentationMode

    // Temporary state variables
    @State private var tempActiveLayers: Set<MapLayer>
    @State private var tempSelectedMapType: CustomMapStyle
    @State private var tempPilotTrackDays: Double

    init(activeLayers: Binding<Set<MapLayer>>, selectedMapType: Binding<CustomMapStyle>, pilotTrackDays: Binding<Double>) {
        _activeLayers = activeLayers
        _selectedMapType = selectedMapType
        _pilotTrackDays = pilotTrackDays

        // Initialize temporary states with current values
        _tempActiveLayers = State(initialValue: activeLayers.wrappedValue)
        _tempSelectedMapType = State(initialValue: selectedMapType.wrappedValue)
        _tempPilotTrackDays = State(initialValue: pilotTrackDays.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    // Update the main state variables when the sheet is dismissed
                    activeLayers = tempActiveLayers
                    selectedMapType = tempSelectedMapType
                    pilotTrackDays = tempPilotTrackDays
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
                    Picker("Map Type", selection: $tempSelectedMapType) {
                        ForEach(CustomMapStyle.allCases, id: \.self) { style in
                            Text(style.rawValue.capitalized)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Map Layers")) {
                    ForEach(MapLayer.allCases, id: \.self) { layer in
                        VStack {
                            Toggle(isOn: Binding(
                                get: { tempActiveLayers.contains(layer) },
                                set: { isActive in
                                    if isActive {
                                        tempActiveLayers.insert(layer)
                                    } else {
                                        tempActiveLayers.remove(layer)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading) {
                                    Text(layer.name)
                                    Text(layer.description)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            if tempActiveLayers.contains(.pilots) && layer == .pilots {
                                VStack(alignment: .trailing) {
                                    Slider(value: $tempPilotTrackDays, in: 1.0...3.0, step: 1.0)
                                    HStack {
                                        Text("Today")
                                            .font(.subheadline)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("+ Yesterday")
                                            .font(.subheadline)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                        Text("+ Prior Day")
                                            .font(.subheadline)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                }
                            }

                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
