import SwiftUI
import MapKit
import Combine

struct MapView: View {
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodesViewModel
    @EnvironmentObject var sitesViewModel: SitesViewModel
    @StateObject var siteLatestReadingsViewModel: SiteLatestReadingsViewModel
    @State private var selectedSite: Sites?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: mapInitLongitude, longitude: mapInitLatitude),
        span: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan)
    )
    
    @State private var isLayerSheetPresented = false
    @State private var isPlaying = false
    @State private var animationProgress: Double = 0.0
    @State private var currentTime: String = "00:00"
    
    // Set default map type and layer settings
    @State private var activeLayers: Set<MapLayer> = [.windStations, .paraglidingSites]
    @State private var selectedMapType: CustomMapStyle = .standard
    
    init(sitesViewModel: SitesViewModel) {
        _siteLatestReadingsViewModel = StateObject(wrappedValue: SiteLatestReadingsViewModel(viewModel: sitesViewModel))
    }
    
    var body: some View {
        
        Map(coordinateRegion: $region, annotationItems: sitesViewModel.sites.filter {
            activeLayers.contains(.paraglidingSites) && ($0.siteType == "Mountain" || $0.siteType == "Soaring")
        }) { site in
            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: Double(site.siteLat) ?? 0.0,
                                                             longitude: Double(site.siteLon) ?? 0.0)) {
                Button(action: {
                    openSiteDetail(site)
                }) {
                    VStack {
                        Image(systemName: region.span.latitudeDelta < 0.5 ? siteAnnotationImage : siteAnnotationImage)
                            .foregroundColor(siteAnnotationColor)
                            .imageScale(region.span.latitudeDelta < 0.5 ? .medium : .small)
                            .shadow(color: siteAnnotationShadowColor, radius: 2)
                        
                        if region.span.latitudeDelta < 0.5 {
                            Text(site.siteName)
                                .font(.caption)
                                .foregroundColor(siteAnnotationTextColor)
                        }
                    }
                }
            }
        }
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
        .sheet(item: $selectedSite, onDismiss: {
            siteLatestReadingsViewModel.reloadLatestReadingsData()
        }) { site in
            SiteDetailView(site: site)
        }
    }
    func openSiteDetail(_ site: Sites) {
        selectedSite = site
    }
    
}

// Custom Map Style Enum
enum CustomMapStyle: String, CaseIterable {
    case standard, hybrid
    func toMapKitStyle() -> MapStyle {
        switch self {
        case .standard:
            return .standard(emphasis: .muted)
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
    case
        paraglidingSites,
        windStations,
        precipitation,
        cloudCover,
        tracks,
        thermalHeatMap,
        flySkyHyAirspace
    
    var name: String {
        switch self {
        case .paraglidingSites: return "Paragliding sites"
        case .windStations: return "Wind stations"
        case .precipitation: return "Precipitation"
        case .cloudCover: return "Cloud cover"
        case .tracks: return "Skyways"
        case .thermalHeatMap: return "Thermals"
        case .flySkyHyAirspace: return "FlySkyHy LZs and thermal hotspots"
        }
    }
    
    var description: String {
        switch self {
        case .paraglidingSites: return "Tap on sites for readings and forecast"
        case .windStations: return "Current and historial wind readings"
        case .precipitation: return "Past and forecasted precipitation (provided by www.rainviewer.com)"
        case .cloudCover: return "Past and forecasted cloud coverage (provided by www.rainviewer.com)"
        case .tracks: return "Tracks from thermal.kk7"
        case .thermalHeatMap: return "Heat map from thermal.kk7"
        case .flySkyHyAirspace: return "Can load into FlySkyHy from Links tab"
        }
    }
}
