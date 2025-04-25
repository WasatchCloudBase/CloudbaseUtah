import SwiftUI
import MapKit
import Combine


struct MapView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude),
        span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 6.0)
    )
    @State private var isLayerSheetPresented = false
    @State private var activeLayers: Set<MapLayer> = []
    @State private var selectedMapType: CustomMapStyle = .standard
    @State private var isPlaying = false
    @State private var animationProgress: Double = 0.0
    @State private var currentTime: String = "00:00"

    var body: some View {
        ZStack {
            // Map
            Map(coordinateRegion: $region)
                .mapStyle(selectedMapType.toMapKitStyle())
                .cornerRadius(10)
                .padding(.vertical, 10)


            // Floating Item Bar
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading) {
                        Button(action: { isLayerSheetPresented.toggle() }) {
                            VStack {
                                Image(systemName: layersImage)
                                    .imageScale(.large)
                                Text("Layers")
                                    .font(.caption)
                                    .foregroundColor(toolbarFontColor)
                            }
                        }
                        .sheet(isPresented: $isLayerSheetPresented) {
                            LayerSelectionView(activeLayers: $activeLayers, selectedMapType: $selectedMapType)
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    if activeLayers.contains(.precipitation) || activeLayers.contains(.cloudCover) {
                        VStack(alignment: .trailing) {
                            HStack(alignment: .center) {
                                Button(action: { isPlaying.toggle() }) {
                                    Image(systemName: isPlaying ? pauseImage : playImage)
                                        .imageScale(.large)
                                }
                                .padding(.horizontal, 8)
                                ProgressView(value: animationProgress)
                                    .frame(width: 100)
                                Text(currentTime)
                                    .font(.headline)
                                    .foregroundColor(toolbarFontColor)
                                    .padding(.horizontal, 8)
                            }
                        }
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.bottom, 24)
        }
    }
}

// Custom Map Style Enum
enum CustomMapStyle: String, CaseIterable {
    case standard, hybrid
    func toMapKitStyle() -> MapStyle {
        switch self {
        case .standard:
            return .standard
        case .hybrid:
            return .hybrid(elevation: .realistic)
        }
    }
}

// Layer and map type selection view
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
                            .foregroundColor(toolbarActiveImageColor)
                        Text("Back")
                            .foregroundColor(toolbarActiveFontColor)
                    }
                }
                .padding()
                Spacer()
            }
            .background(toolbarBackgroundColor)
            
            List {
                Section(header: Text("Map Type")) {
                    ForEach(CustomMapStyle.allCases, id: \.self) { style in
                        Button(action: { selectedMapType = style }) {
                            HStack {
                                Text(style.rawValue.capitalized)
                                if selectedMapType == style {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Select Layers")) {
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
                         //           .font(.headline)
                                    .foregroundColor(rowHeaderColor)
                                Text(layer.description)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
        }
    }
}

enum MapLayer: String, CaseIterable {
    case precipitation, cloudCover, tracks, thermalHeatMap, flySkyHyAirspace, windStations, paraglidingSites
    
    var name: String {
        switch self {
        case .precipitation: return "Precipitation"
        case .cloudCover: return "Cloud cover"
        case .tracks: return "Skyways"
        case .thermalHeatMap: return "Thermals"
        case .flySkyHyAirspace: return "FlySkyHy LZs and thermal hotspots"
        case .windStations: return "Wind stations"
        case .paraglidingSites: return "Paragliding sites"
        }
    }
    
    var description: String {
        switch self {
        case .precipitation: return "Past and forecasted precipitation"
        case .cloudCover: return "Past and forecasted cloud coverage"
        case .tracks: return "Tracks from thermal.kk7"
        case .thermalHeatMap: return "Heat map from thermal.kk7"
        case .flySkyHyAirspace: return "Can load into FlySkyHy from Links tab"
        case .windStations: return "Current and historial wind readings"
        case .paraglidingSites: return "Tap on sites for readings and forecast"
        }
    }
}
