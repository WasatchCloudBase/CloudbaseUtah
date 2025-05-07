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

// Annotation data model
struct mapAnnotationList: Identifiable {
    let id = UUID()
    let annotationType: String      // e.g., "site" or "station"
    let annotationID: String        // an identifier based on the type
    let annotationName: String
    let coordinates: CLLocationCoordinate2D
    let altitude: String
    let readingsNote: String
    let forecastNote: String
    let siteType: String
    let readingsStation: String           // For site annotations
    let readingsSource: String
    let readingsImage: UIImage?
}

// Define map layers
enum MapLayer: String, CaseIterable {
    case sites,
         stations,
         pilots,
         precipitation,
         cloudCover,
         tracks,
         thermalHeatMap,
         flySkyHyAirspace

    var name: String {
        switch self {
        case .sites: return "Paragliding sites"
        case .stations: return "Wind stations"
        case .pilots: return "Live tracking"
        case .precipitation: return "Precipitation NOT AVAILABLE"
        case .cloudCover: return "Cloud cover NOT AVAILABLE"
        case .tracks: return "Skyways NOT AVAILABLE"
        case .thermalHeatMap: return "Thermals NOT AVAILABLE"
        case .flySkyHyAirspace: return "FlySkyHy LZs and thermal hotspots NOT AVAILABLE"
        }
    }
    
    var description: String {
        switch self {
        case .sites: return "Select site for readings and forecast"
        case .stations: return "Select station for readings and forecast"
        case .pilots: return "inReach GPS live tracking"
        case .precipitation: return "Past and forecasted precipitation \n(provided by www.rainviewer.com)"
        case .cloudCover: return "Past and forecasted cloud coverage \n(provided by www.rainviewer.com)"
        case .tracks: return "Tracks from thermal.kk7"
        case .thermalHeatMap: return "Heat map from thermal.kk7"
        case .flySkyHyAirspace: return "Preview of custom airspace \n(use Links tab to load into FlySkyHy)"
        }
    }
}

// Custom MKPointAnnotation subclass for attaching clustering identifiers and station rendered wind speed/direction image
class CustomMKPointAnnotation: MKPointAnnotation {
    var annotationType: String = "" // Track annotation type (site/station)
    var stationAnnotationImage: UIImage?
}

// View to define custom station annotion image format
struct windReadingImageView: View {
    var windSpeed: Double
    var gustSpeed: Double
    var windDirection: Double
    
    var body: some View {
        HStack(spacing: windArrowSpacing) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(Int(windSpeed.rounded())))
                    .font(.caption)
                    .foregroundStyle(windSpeedColor(windSpeed: Int(windSpeed), siteType: ""))
                HStack (spacing: 1) {
                    Text("g")
                        .font(.caption2)
                    Text(String(Int(gustSpeed.rounded())))
                        .font(.caption)
                        .foregroundStyle(windSpeedColor(windSpeed: Int(gustSpeed), siteType: ""))
                }
            }
            .padding(.vertical, 0)
            Image(systemName: windArrow)
                .rotationEffect(.degrees((Double(windDirection)) - 180))
                .font(.footnote)
        }
    }
}

// Extension to render custom station annotation image (based on view definition above)
extension View {
    func asUIImage() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view

        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

// Map wrapper to improve performance through enabling clustering of annotations and lazy loading
struct MKMapViewWrapper: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var annotations: [mapAnnotationList]
    var mapType: MKMapType
    @Binding var selectedSite: Sites?
    @Binding var selectedPilot: Pilots?
    @ObservedObject var mapSettingsViewModel: MapSettingsViewModel

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.isRotateEnabled = mapEnableRotation
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.mapType = mapType
        mapView.register(MKAnnotationView.self, forAnnotationViewWithReuseIdentifier: "CustomAnnotation")
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.mapType = mapType

        if uiView.region.center.latitude != region.center.latitude ||
            uiView.region.center.longitude != region.center.longitude {
            uiView.setRegion(region, animated: false)
        }

        let visibleMapRect = uiView.visibleMapRect
        let visibleAnnotations: [mapAnnotationList]

        if visibleMapRect.size.width == 0 || visibleMapRect.size.height == 0 {
            visibleAnnotations = annotations
        } else {
            visibleAnnotations = annotations.filter { annotation in
                let point = MKMapPoint(annotation.coordinates)
                return visibleMapRect.contains(point)
            }
        }

        // Remove site annotations if the sites layer is not active
        if !mapSettingsViewModel.activeLayers.contains(.sites) {
            uiView.removeAnnotations(uiView.annotations.filter {
                guard let customAnnotation = $0 as? CustomMKPointAnnotation else { return false }
                return customAnnotation.annotationType == "site"
            })
        }
    
        // Collect existing annotations in a set to prevent duplicates.
        let existingAnnotations = Set(uiView.annotations.compactMap { $0 as? CustomMKPointAnnotation })

        // Ensure site annotations remain untouched and avoid re-adding them.
        let newAnnotations = visibleAnnotations.filter { annotation in
            let isSite = annotation.annotationType == "site"
            let alreadyExists = existingAnnotations.contains { $0.title == annotation.annotationID && $0.annotationType == annotation.annotationType }
            return !isSite || !alreadyExists
        }.map { ann -> CustomMKPointAnnotation in
            let customAnnotation = CustomMKPointAnnotation()
            customAnnotation.coordinate = ann.coordinates
            customAnnotation.title = ann.annotationID
            customAnnotation.annotationType = ann.annotationType
            customAnnotation.subtitle = ann.annotationType
            return customAnnotation
        }

        uiView.removeAnnotations(uiView.annotations.filter { annotation in
            guard let customAnnotation = annotation as? CustomMKPointAnnotation else { return false }
            return customAnnotation.annotationType != "site"
        })

        uiView.addAnnotations(newAnnotations)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MKMapViewWrapper
        
        init(_ parent: MKMapViewWrapper) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            // Handle clustering only for station annotations
            if let clusterAnnotation = annotation as? MKClusterAnnotation {
                let clusterView = mapView.dequeueReusableAnnotationView(withIdentifier: "ClusterView") as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "ClusterView")
                clusterView.annotation = annotation
                clusterView.canShowCallout = false
                clusterView.markerTintColor = clusterAnnotationColor
                clusterView.clusteringIdentifier = "stationCluster"
                return clusterView
            }

            let identifier = "CustomAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView!.canShowCallout = false
            } else {
                annotationView!.annotation = annotation
                // Remove previously added labels to prevent stacking
                annotationView!.subviews.forEach { if $0 is UILabel { $0.removeFromSuperview() } }
            }

            if let customAnnotation = annotation as? CustomMKPointAnnotation {
                var annotationImage: UIImage?
                var annotationTextColor: UIColor?
                
                switch customAnnotation.annotationType {
                case "site":
                    annotationView!.clusteringIdentifier = nil // Keep sites fixed
                    annotationImage = siteAnnotationUIImage
                    annotationTextColor = siteAnnotationTextColor
                case "station":
                    annotationView!.clusteringIdentifier = "stationCluster"
                    annotationView!.displayPriority = .defaultHigh
                    // Set frame to reduce collisions by changing frame size
                    annotationView!.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                    annotationImage = customAnnotation.stationAnnotationImage
                    annotationTextColor = stationAnnotationTextColor
                case "pilot":
                    annotationView!.clusteringIdentifier = nil // Keep sites fixed
                    annotationImage = pilotAnnotationUIImage
                    annotationTextColor = pilotAnnotationTextColor
                default:
                    annotationView!.clusteringIdentifier = nil
                    annotationImage = UIImage(systemName: defaultAnnotationImage)
                    annotationTextColor = defaultAnnotationTextColor
                }

                annotationView!.image = annotationImage
                
                // Add label below annotation image
                let label = UILabel()
                label.text = customAnnotation.title
                label.textAlignment = .center
                label.font = UIFont.systemFont(ofSize: 11) //, weight: .bold)
                label.textColor = annotationTextColor
                label.layer.masksToBounds = true

                // Adjust label frame manually (positioning below annotation image)
                let labelXPosition = 0 - ( (annotationImage?.size.width ?? 20)/2 )
                let labelYPosition = ( (annotationImage?.size.height ?? 20)/1.4 )
                label.frame = CGRect(x: labelXPosition, y: labelYPosition, width: 100, height: 20)

                annotationView!.addSubview(label)
            }
            return annotationView
        }
        
        // Update region
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
        
        // Handle map annotation selections
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let customAnnotation = annotation as? CustomMKPointAnnotation else {
                // No matching annotation means that a cluster was selected
                return
            }

            switch customAnnotation.subtitle {
                
            case "site":
                guard let selectedSite = parent.annotations.first(where: { $0.annotationID == customAnnotation.title }) else {
                    print("Could not find site/station annotation")
                    return
                }
                DispatchQueue.main.async {
                    self.parent.selectedSite = Sites(
                        id: UUID(uuidString: selectedSite.annotationID) ?? UUID(),
                        area: "",
                        siteName: selectedSite.annotationName,
                        readingsNote: selectedSite.readingsNote,
                        forecastNote: selectedSite.forecastNote,
                        siteType: selectedSite.siteType,
                        readingsAlt: selectedSite.altitude,
                        readingsSource: selectedSite.readingsSource,
                        readingsStation: selectedSite.readingsStation,
                        pressureZoneReadingTime: "",
                        siteLat: "\(selectedSite.coordinates.latitude)",
                        siteLon: "\(selectedSite.coordinates.longitude)",
                    )
                }
                
            case "station":
                // Return selectedSite for stations as well as sites to pass to siteDetail view for readings and forecast
                guard let selectedSite = parent.annotations.first(where: { $0.annotationID == customAnnotation.title }) else {
                    print("Could not find station annotation")
                    return
                }
                DispatchQueue.main.async {
                    self.parent.selectedSite = Sites(
                        id: UUID(uuidString: selectedSite.annotationID) ?? UUID(),
                        area: "",
                        siteName: selectedSite.annotationName,
                        readingsNote: "",
                        forecastNote: "",
                        siteType: "",
                        readingsAlt: selectedSite.altitude,                       // Get from station details....
                        readingsSource: selectedSite.readingsSource,
                        readingsStation: selectedSite.annotationID,
                        pressureZoneReadingTime: "",
                        siteLat: "\(selectedSite.coordinates.latitude)",
                        siteLon: "\(selectedSite.coordinates.longitude)",
                        
                    )
                }
            case "pilot":
                // NEED TO COMPLETE PILOT SELECT SECTION
                print("temp")
                
            default:
                return
            }
        }
    }
}

struct MapView: View {
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodesViewModel
    @EnvironmentObject var sitesViewModel: SitesViewModel
    @EnvironmentObject var pilotsViewModel: PilotsViewModel
    @EnvironmentObject var mapSettingsViewModel: MapSettingsViewModel
    @StateObject var stationLatestReadingsViewModel: StationLatestReadingsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedSite: Sites?
    @State private var selectedPilot: Pilots?
    @State private var isLayerSheetPresented = false
    @State private var isPlaying = false
    @State private var animationProgress: Double = 0.0
    @State private var currentTime: String = "00:00"
    @State private var mapAnnotations: [mapAnnotationList] = []
    @State private var isActive = false

    init(sitesViewModel: SitesViewModel) {
        _stationLatestReadingsViewModel = StateObject(wrappedValue: StationLatestReadingsViewModel(viewModel: sitesViewModel))
    }

    var body: some View {
        ZStack {
            MKMapViewWrapper(
                region: $mapSettingsViewModel.region,
                annotations: $mapAnnotations,
                mapType: mapSettingsViewModel.selectedMapType.toMapKitType(),
                selectedSite: $selectedSite,
                selectedPilot: $selectedPilot,
                mapSettingsViewModel: mapSettingsViewModel
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
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                        .imageScale(.large)
                                }
                                .padding(.horizontal, 8)
                                ProgressView(value: animationProgress)
                                    .frame(width: 100)
                                Text(currentTime)
                                    .font(.headline)
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
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                if mapSettingsViewModel.activeLayers.contains(.stations) {
                    stationLatestReadingsViewModel.reloadLatestReadingsData()
                }
            } else {
                isActive = false
            }
        }
        .onAppear {
            updateMapAnnotations()
            isActive = true
            startTimer()
        }
        .onDisappear {
            isActive = false
        }
        .sheet(item: $selectedSite, onDismiss: {
            if mapSettingsViewModel.activeLayers.contains(.stations) {
                stationLatestReadingsViewModel.reloadLatestReadingsData()
            }
        }) { site in
            SiteDetailView(site: site)

        }
    }
    
    // Timer to reload readings if page stays active
    private func startTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + pageRefreshInterval) {
            if isActive {
                if mapSettingsViewModel.activeLayers.contains(.stations) {
                    stationLatestReadingsViewModel.reloadLatestReadingsData()
                }
            }
        }
    }
    
    // Update the annotations based on the active layers.
    private func updateMapAnnotations() {
        mapAnnotations.removeAll()

        if mapSettingsViewModel.activeLayers.contains(.sites) {
            let filteredSites = sitesViewModel.sites.filter { $0.siteType == "Mountain" || $0.siteType == "Soaring" }
            for site in filteredSites {
                if let lat = Double(site.siteLat), let lon = Double(site.siteLon) {
                    let annotation = mapAnnotationList(
                        annotationType: "site",
                        annotationID: site.siteName,
                        annotationName: site.siteName,
                        coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        altitude: site.readingsAlt,
                        readingsNote: site.readingsNote,
                        forecastNote: site.forecastNote,
                        siteType: site.siteType,
                        readingsStation: site.readingsStation,
                        readingsSource: site.readingsSource,
                        readingsImage: nil
                    )
                    mapAnnotations.append(annotation)
                }
            }
        }

        if mapSettingsViewModel.activeLayers.contains(.stations) {
            // Get latest Mesonet readings
            stationLatestReadingsViewModel.getLatestMesonetReadings(stationParameters: "") {
                DispatchQueue.main.async {
                    for reading in stationLatestReadingsViewModel.latestReadings {
                        if let lat = Double(reading.stationLatitude), let lon = Double(reading.stationLongitude) {
                            let annotation = mapAnnotationList(
                                annotationType: "station",
                                annotationID: reading.stationID,
                                annotationName: reading.stationName,
                                coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                altitude: String(Int(Double(reading.stationElevation) ?? 0.0)),
                                readingsNote: "",
                                forecastNote: "",
                                siteType: "",
                                readingsStation: reading.stationID,
                                readingsSource: "Mesonet",
                                readingsImage: UIImage(named: cameraAnnotationImage)
                                    
/*                                    windReadingImageView(
                                    windSpeed: reading.windSpeed ?? 0,
                                    gustSpeed: reading.windGust ?? 0,
                                    windDirection: reading.windDirection ?? 0
                                ).asUIImage()
 */
                            )
                            mapAnnotations.append(annotation)
                        }
                    }
                }
            }
            // Get latest CUASA readings
            self.stationLatestReadingsViewModel.getLatestCUASAReadings()
            DispatchQueue.main.async {
                for reading in stationLatestReadingsViewModel.latestReadings {
                    if let lat = Double(reading.stationLatitude), let lon = Double(reading.stationLongitude) {
                        let annotation = mapAnnotationList(
                            annotationType: "station",
                            annotationID: reading.stationID,
                            annotationName: reading.stationName,
                            coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            altitude: reading.stationElevation,
                            readingsNote: "",
                            forecastNote: "",
                            siteType: "",
                            readingsStation: reading.stationID,
                            readingsSource: "CUASA",
                            readingsImage: nil
                        )
                        mapAnnotations.append(annotation)
                    }
                }
            }
        }
        
        if mapSettingsViewModel.activeLayers.contains(.pilots) {
/*
            let filteredSites = sitesViewModel.sites.filter { $0.siteType == "Mountain" || $0.siteType == "Soaring" }
            for site in filteredSites {
                if let lat = Double(site.siteLat), let lon = Double(site.siteLon) {
                    let annotation = mapAnnotationList(
                        annotationType: "site",
                        annotationID: site.siteName,
                        annotationName: site.siteName,
                        coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        altitude: site.readingsAlt,
                        readingsNote: site.readingsNote,
                        forecastNote: site.forecastNote,
                        siteType: site.siteType,
                        stationID: site.readingsStation,
                        readingsSource: site.readingsSource
                    )
                    mapAnnotations.append(annotation)
                }
            }
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
                            }
                        }
                    }
                }
            }
        }
    }
}
