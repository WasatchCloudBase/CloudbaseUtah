import SwiftUI
import MapKit
import Combine

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

// Set up model to retain map settings (center, zoom, layers) when navigating between views)
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

// Annotation data model (used in our view model)
struct mapAnnotationList: Identifiable {
    let id = UUID()
    let annotationType: String      // e.g., "site" or "station"
    let annotationID: String        // an identifier based on the type
    let annotationName: String
    let coordinates: CLLocationCoordinate2D
}

// Define your map layers
enum MapLayer: String, CaseIterable {
    case paraglidingSites,
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
        case .paraglidingSites: return "Select site for readings and forecast"
        case .windStations: return "Current wind readings \n(visible when zoomed in)"
        case .precipitation: return "Past and forecasted precipitation \n(provided by www.rainviewer.com)"
        case .cloudCover: return "Past and forecasted cloud coverage \n(provided by www.rainviewer.com)"
        case .tracks: return "Tracks from thermal.kk7"
        case .thermalHeatMap: return "Heat map from thermal.kk7"
        case .flySkyHyAirspace: return "Preview of custom airspace \n(use Links tab to load into FlySkyHy)"
        }
    }
}

// A custom MKPointAnnotation subclass for attaching clustering identifiers.
class CustomMKPointAnnotation: MKPointAnnotation {}

// Map wrapper to improve performance through enabling clustering of annotations and lazy loading
struct MKMapViewWrapper: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var annotations: [mapAnnotationList]
    var mapType: MKMapType
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.isRotateEnabled = mapEnableRotation
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.mapType = mapType
        // Register a marker view.
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "CustomAnnotation")
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update the map type if needed
        uiView.mapType = mapType
        
        // Update the region if it has changed
        if uiView.region.center.latitude != region.center.latitude ||
            uiView.region.center.longitude != region.center.longitude {
            uiView.setRegion(region, animated: true)
        }
        
        // --- Lazy Load Annotations ---
        // Only add annotations that fall within the current visible map rect
        let visibleMapRect = uiView.visibleMapRect
        let visibleAnnotations = annotations.filter { annotation in
            let point = MKMapPoint(annotation.coordinates)
            return visibleMapRect.contains(point)
        }
        
        // Remove existing annotations
        uiView.removeAnnotations(uiView.annotations)
        
        // Convert to CustomMKPointAnnotation so we can set clustering identifiers
        let customAnnotations = visibleAnnotations.map { ann -> CustomMKPointAnnotation in
            let customAnnotation = CustomMKPointAnnotation()
            customAnnotation.coordinate = ann.coordinates
            customAnnotation.title = ann.annotationName
            // Save the annotation type (e.g., "site", "station") in subtitle
            customAnnotation.subtitle = ann.annotationType
            return customAnnotation
        }
        uiView.addAnnotations(customAnnotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MKMapViewWrapper
        
        init(_ parent: MKMapViewWrapper) {
            self.parent = parent
        }
        
        // Provide an annotation view with clustering enabled
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Skip user location
            if annotation is MKUserLocation {
                return nil
            }
            
            let identifier = "CustomAnnotation"
            
            // Handle cluster annotations separately.
            if let clusterAnnotation = annotation as? MKClusterAnnotation {
                let clusterView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                clusterView.canShowCallout = true
                
                // Inspect one of the member annotations to determine the type.
                if let member = clusterAnnotation.memberAnnotations.first as? CustomMKPointAnnotation {
                    if member.subtitle == "station" {
                        clusterView.glyphImage = UIImage(systemName: stationAnnotationImage)
                        clusterView.markerTintColor = stationAnnotationColor
                        clusterView.displayPriority = .defaultHigh
                    } else if member.subtitle == "site" {
                        clusterView.glyphImage = UIImage(systemName: siteAnnotationImage)
                        clusterView.markerTintColor = siteAnnotationColor
                        clusterView.displayPriority = .required
                    } else {
                        clusterView.glyphImage = nil
                        clusterView.markerTintColor = UIColor.gray
                    }
                }
                return clusterView
            }
            
            // Individual annotation view for non-cluster annotations.
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView.canShowCallout = true
            
            if let customAnnotation = annotation as? CustomMKPointAnnotation {
                switch customAnnotation.subtitle {
                case "station":
                    annotationView.clusteringIdentifier = "stationCluster" // Only station annotations cluster.
                    annotationView.glyphImage = UIImage(systemName: stationAnnotationImage)
                    annotationView.markerTintColor = stationAnnotationColor
                    annotationView.displayPriority = .defaultHigh
                case "site":
                    annotationView.clusteringIdentifier = nil // Sites do not cluster.
                    annotationView.glyphImage = UIImage(systemName: siteAnnotationImage)
                    annotationView.markerTintColor = siteAnnotationColor
                    annotationView.displayPriority = .required
                default:
                    annotationView.clusteringIdentifier = nil
                    annotationView.glyphImage = nil
                    annotationView.markerTintColor = UIColor.gray
                }
            }
            return annotationView
        }
        
        // Update the region and adjust the annotation marker sizes based on the map's span.
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region

                // Calculate a scale factor based on latitudeDelta.
                let scale = self.scaleFactor(for: mapView.region.span.latitudeDelta)
                
                // Loop through each annotation and update its view's transform.
                for annotation in mapView.annotations {
                    if let annotationView = mapView.view(for: annotation) {
                        annotationView.transform = CGAffineTransform(scaleX: scale, y: scale)
                    }
                }
            }
        }
        
        // Helper method to determine a scale factor based on the current latitudeDelta.
        private func scaleFactor(for latitudeDelta: CLLocationDegrees) -> CGFloat {
            // Adjust these thresholds to suit your design.
            if latitudeDelta > 1.0 {
                return 0.5  // When zoomed out (large delta), markers shrink.
            } else if latitudeDelta > 0.5 {
                return 0.75
            } else if latitudeDelta > 0.2 {
                return 1.25
            } else {
                return 2  // When zoomed in (small delta), markers enlarge.
            }
        }
    }
}

struct MapView: View {
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodesViewModel
    @EnvironmentObject var sitesViewModel: SitesViewModel
    @EnvironmentObject var mapSettingsViewModel: MapSettingsViewModel
    @StateObject var siteLatestReadingsViewModel: SiteLatestReadingsViewModel
    @State private var selectedSite: Sites?
    @State private var isLayerSheetPresented = false
    @State private var isPlaying = false
    @State private var animationProgress: Double = 0.0
    @State private var currentTime: String = "00:00"
    @State private var mapAnnotations: [mapAnnotationList] = []
    
    init(sitesViewModel: SitesViewModel) {
        _siteLatestReadingsViewModel = StateObject(wrappedValue: SiteLatestReadingsViewModel(viewModel: sitesViewModel))
    }
    
    var body: some View {
        ZStack {
            // Use custom MKMapViewWrapper to allow separate markers and clustering based on annotation type
            MKMapViewWrapper(
                region: $mapSettingsViewModel.region,
                annotations: mapAnnotations,
                mapType: mapSettingsViewModel.selectedMapType.toMapKitType()
            )
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
                                    .foregroundStyle(layersIconColor)
                                Text("Layers")
                                    .font(.caption)
                                    .foregroundColor(layersFontColor)
                            }
                        }
                        .sheet(isPresented: $isLayerSheetPresented) {
                            LayerSelectionView(
                                activeLayers: $mapSettingsViewModel.activeLayers,
                                selectedMapType: $mapSettingsViewModel.selectedMapType
                            )
                        }
                    }
                    .padding()
                    .background(layersIconBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    if mapSettingsViewModel.activeLayers.contains(.precipitation) ||
                        mapSettingsViewModel.activeLayers.contains(.cloudCover) {
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
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .onChange(of: mapSettingsViewModel.activeLayers) { _ in
            updateMapAnnotations()
        }
        .onAppear {
            updateMapAnnotations()
        }
        .sheet(item: $selectedSite, onDismiss: {
            siteLatestReadingsViewModel.reloadLatestReadingsData()
        }) { site in
            SiteDetailView(site: site)
        }
    }
    
    // Update the annotations based on the active layers
    private func updateMapAnnotations() {
        mapAnnotations.removeAll()
        
        if mapSettingsViewModel.activeLayers.contains(.paraglidingSites) {
            let filteredSites = sitesViewModel.sites.filter { $0.siteType == "Mountain" || $0.siteType == "Soaring" }
            for site in filteredSites {
                if let lat = Double(site.siteLat), let lon = Double(site.siteLon) {
                    let annotation = mapAnnotationList(
                        annotationType: "site",
                        annotationID: site.id.uuidString,
                        annotationName: site.siteName,
                        coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    )
                    mapAnnotations.append(annotation)
                }
            }
        }
        
        if mapSettingsViewModel.activeLayers.contains(.windStations) {
            siteLatestReadingsViewModel.getLatestMesonetReadings(stationParameters: "") {
                DispatchQueue.main.async {
                    for reading in siteLatestReadingsViewModel.latestReadings {
                        if let lat = Double(reading.stationLatitude), let lon = Double(reading.stationLongitude) {
                            let annotation = mapAnnotationList(
                                annotationType: "station",
                                annotationID: reading.stationID,
                                annotationName: reading.stationName,
                                coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            )
                            mapAnnotations.append(annotation)
                        }
                    }
                }
            }
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
