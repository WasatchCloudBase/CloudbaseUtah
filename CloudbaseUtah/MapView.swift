import SwiftUI
import MapKit
import Combine
import UIKit
import CoreGraphics
import Foundation

// Annotation data model
struct mapAnnotationList: Identifiable {
    let id = UUID()
    let annotationType: String              // e.g., "site" or "station"
    let annotationID: String                // an identifier based on the type
    let annotationName: String
    let coordinates: CLLocationCoordinate2D
    let altitude: String
    let readingsNote: String
    let forecastNote: String
    let siteType: String
    let readingsStation: String             // For site annotations
    let readingsSource: String
    let windSpeed: Double?                  // For station annotations
    let windDirection: Double?
    let windGust: Double?
    let inEmergency: Bool?                  // For pilot track annotations
    let trackdateTime: Date?
}

// Custom MKPointAnnotation subclass for attaching clustering identifiers and station rendered wind speed/direction image
class CustomMKPointAnnotation: MKPointAnnotation {
    var annotationType: String = ""         // Track annotation type (site/station)
    var windSpeed: Double? = 0.0            // For station annotations
    var windDirection: Double? = 0.0
    var windGust: Double? = 0.0
    var clusteringIdentifier: String?       // Ensure clustering is explicitly supported
    var pilotName: String?                  // For pilot live tracking annotations
    var trackDateTime: Date?
    var altitude: String?
    var inEmergency: Bool?
}

// Map wrapper to improve performance through enabling clustering of annotations and lazy loading
struct MKMapViewWrapper: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var annotations: [mapAnnotationList]
    var mapType: MKMapType
    @Binding var selectedSite: Sites?
    @Binding var selectedPilotTrack: PilotTracks?
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
        
        // Remove annotations for layers that are no longer active.
        if !mapSettingsViewModel.activeLayers.contains(.sites) {
            let sitesToRemove = uiView.annotations.compactMap { $0 as? CustomMKPointAnnotation }
                .filter { $0.annotationType == "site" }
            uiView.removeAnnotations(sitesToRemove)
        }
        
        if !mapSettingsViewModel.activeLayers.contains(.stations) {
            let stationsToRemove = uiView.annotations.compactMap { $0 as? CustomMKPointAnnotation }
                .filter { $0.annotationType == "station" }
            uiView.removeAnnotations(stationsToRemove)
        }
        
        let visibleMapRect = uiView.visibleMapRect

        let newAnnotations = annotations.compactMap { ann -> CustomMKPointAnnotation? in
            // For both sites and stations, only add if within visible bounds.
            let point = MKMapPoint(ann.coordinates)
            guard visibleMapRect.contains(point) else { return nil }
            
            // Check for duplicates with a looser tolerance if needed.
            let alreadyExists = uiView.annotations.compactMap({ $0 as? CustomMKPointAnnotation }).contains {
                $0.title == ann.annotationID &&
                $0.annotationType == ann.annotationType &&
                abs($0.coordinate.latitude - ann.coordinates.latitude) < 0.00005 &&
                abs($0.coordinate.longitude - ann.coordinates.longitude) < 0.00005
            }
            if alreadyExists { return nil }
            
            let customAnnotation = CustomMKPointAnnotation(__coordinate: ann.coordinates)
            customAnnotation.title = ann.annotationID
            customAnnotation.subtitle = ann.annotationType
            customAnnotation.windSpeed = ann.windSpeed
            customAnnotation.windDirection = ann.windDirection
            customAnnotation.windGust = ann.windGust
            customAnnotation.annotationType = ann.annotationType

            // For station annotations, set clustering.
            if ann.annotationType == "station" {
                customAnnotation.clusteringIdentifier = "stationCluster"
            }
            
            return customAnnotation
        }
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
            
            if annotation is MKClusterAnnotation {
                let clusterView = mapView.dequeueReusableAnnotationView(withIdentifier: "ClusterView") as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "ClusterView")
                clusterView.annotation = annotation
                clusterView.canShowCallout = false
                clusterView.markerTintColor = clusterAnnotationColor
                return clusterView
            }

            let identifier = "CustomAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView!.canShowCallout = false
            } else {
                annotationView!.annotation = annotation
                // Remove any leftover labels to prevent stacking.
                annotationView!.subviews.forEach { if $0 is UILabel { $0.removeFromSuperview() } }
            }
            
            if let customAnnotation = annotation as? CustomMKPointAnnotation {
                // For station annotations, use our custom station view.
                if let customAnnotation = annotation as? CustomMKPointAnnotation,
                   customAnnotation.annotationType == "station" {
                    let stationView = mapView.dequeueReusableAnnotationView(withIdentifier: "StationAnnotationView") as? StationAnnotationView
                        ?? StationAnnotationView(annotation: annotation, reuseIdentifier: "StationAnnotationView")
                    stationView.annotation = annotation
                    stationView.clusteringIdentifier = "stationCluster"
                    // Optionally adjust displayPriority based on importance.
                    stationView.displayPriority = .defaultLow
                    return stationView
                }
                
                // For non‑station annotations, configure as before.
                var annotationImage: UIImage?
                var annotationTextColor: UIColor?
                
                switch customAnnotation.annotationType {
                case "site":
                    annotationImage = siteAnnotationUIImage
                    annotationTextColor = siteAnnotationTextColor
                case "pilot":
                    annotationImage = pilotAnnotationUIImage
                    annotationTextColor = pilotAnnotationTextColor
                default:
                    annotationImage = UIImage(systemName: defaultAnnotationImage)
                    annotationTextColor = defaultAnnotationTextColor
                }
                annotationView!.image = annotationImage
                
                // Add a label below the image as a subview.
                let label = UILabel()
                label.text = customAnnotation.title
                label.textAlignment = .center
                label.font = UIFont.systemFont(ofSize: 11)
                label.textColor = annotationTextColor
                label.layer.masksToBounds = true

                let labelXPosition = -((annotationImage?.size.width ?? 20) / 3)
                let labelYPosition = ((annotationImage?.size.height ?? 20) / 1.3)
                label.frame = CGRect(x: labelXPosition, y: labelYPosition, width: 100, height: 20)
                annotationView!.addSubview(label)
                
                return annotationView
            }
            return nil
        }
        
        // Station custom annotation marker
        struct StationAnnotationMarker: View {
            var customAnnotation: CustomMKPointAnnotation
            
            var body: some View {
                HStack (spacing: 1) {
                    Text(String(Int(customAnnotation.windSpeed?.rounded() ?? 0)))
                        .font(.caption)
                        .foregroundStyle(windSpeedColor(windSpeed: Int(customAnnotation.windSpeed?.rounded() ?? 0), siteType: ""))
                        .bold()
                    /* Not displaying gusts
                    Text("g")
                        .font(.caption2)
                    Text(String(Int(customAnnotation.windGust?.rounded() ?? 0)))
                        .font(.caption)
                        .foregroundStyle(windSpeedColor(windSpeed: Int(customAnnotation.windGust?.rounded() ?? 0), siteType: ""))
                        .bold()
                     */
                    Image(systemName: windArrow)
                        .rotationEffect(.degrees((Double(customAnnotation.windDirection ?? 180)) - 180))
                        .font(.footnote)
                }
                .padding (4)
                .frame(width: stationAnnotationWidth, height: stationAnnotationHeight)
                .background(stationAnnotationColor)
                .cornerRadius(5)
                
            }
        }

        class StationAnnotationView: MKAnnotationView {
            private var hostingController: UIHostingController<StationAnnotationMarker>?

            override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
                super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
                clusteringIdentifier = "stationCluster"
                setupHostingController()
            }

            required init?(coder aDecoder: NSCoder) {
                super.init(coder: aDecoder)
                clusteringIdentifier = "stationCluster"
                setupHostingController()
            }

            private func setupHostingController() {
                guard let annotation = annotation as? CustomMKPointAnnotation else { return }
                let markerView = StationAnnotationMarker(customAnnotation: annotation)
                let hostingController = UIHostingController(rootView: markerView)
                hostingController.view.backgroundColor = .clear
                hostingController.view.translatesAutoresizingMaskIntoConstraints = false
                addSubview(hostingController.view)
                
                NSLayoutConstraint.activate([
                    hostingController.view.widthAnchor.constraint(equalToConstant: 30),
                    hostingController.view.heightAnchor.constraint(equalToConstant: 30),
                    hostingController.view.centerXAnchor.constraint(equalTo: centerXAnchor),
                    hostingController.view.centerYAnchor.constraint(equalTo: centerYAnchor)
                ])
                self.hostingController = hostingController
            }

            override func prepareForReuse() {
                super.prepareForReuse()
                hostingController?.view.removeFromSuperview()
                hostingController = nil
            }
        }
        
        // Update region
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Compute the zoom scale based on the width of the visible map rect
            let zoomScale = mapView.visibleMapRect.size.width / mapView.frame.size.width
            let threshold: Double = 1200 // This threshold is adjustable
            
            // Loop through station annotations to adjust clustering dynamically
            for annotation in mapView.annotations.compactMap({ $0 as? CustomMKPointAnnotation }) {
                if annotation.annotationType == "station" {
                    // Disable clustering when zooming in (low zoomScale value)
                    annotation.clusteringIdentifier = zoomScale < threshold ? nil : "stationCluster"
                }
            }
            
            // Batch requests to prevent high volume of requests as user navigates map
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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
print("selected site: \(String(describing: customAnnotation.title))")
                guard let selectedSite = parent.annotations.first(where: { $0.annotationID == customAnnotation.title }) else {
                    print("Could not find site/station annotation for: \(String(describing: customAnnotation.title))")
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
                        sheetRow: 0
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
                        readingsAlt: selectedSite.altitude,
                        readingsSource: selectedSite.readingsSource,
                        readingsStation: selectedSite.annotationID,
                        pressureZoneReadingTime: "",
                        siteLat: "\(selectedSite.coordinates.latitude)",
                        siteLon: "\(selectedSite.coordinates.longitude)",
                        sheetRow: 0
                    )
                }

            case "pilot":
                // Return selectedSite for stations as well as sites to pass to siteDetail view for readings and forecast
                guard let selectedPilotTrack = parent.annotations.first(where: { $0.annotationID == customAnnotation.title }) else {
                    print("Could not find pilot annotation")
                    return
                }
                DispatchQueue.main.async {
                    self.parent.selectedPilotTrack = PilotTracks(
                        pilotName: customAnnotation.pilotName ?? "Unknown",
                        oldestDateTime: Date(), // Assuming you have logic to determine this
                        oldestCoordinates: (latitude: 0.0, longitude: 0.0), // Assuming you have logic to determine this
                        flightDuration: 0.0, // Assuming you have logic to determine this
                        dateTime: customAnnotation.trackDateTime ?? Date(),
                        coordinates: (customAnnotation.coordinate.latitude, customAnnotation.coordinate.longitude),
                        speed: customAnnotation.windSpeed ?? 0.0,
                        altitude: Double(customAnnotation.altitude ?? "") ?? 0.0,
                        heading: customAnnotation.windDirection ?? 0.0,
                        inEmergency: customAnnotation.inEmergency ?? false
                    )
                }
                
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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var stationLatestReadingsViewModel: StationLatestReadingsViewModel
    @StateObject private var pilotTracksViewModel: PilotTracksViewModel
    @State private var selectedSite: Sites?
    @State private var selectedPilotTrack: PilotTracks?
    @State private var isLayerSheetPresented = false
    @State private var isPlaying = false
    @State private var animationProgress: Double = 0.0
    @State private var currentTime: String = "00:00"
    @State private var mapAnnotations: [mapAnnotationList] = []
    @State private var isActive = false
    private var cancellables = Set<AnyCancellable>()

    init(sitesViewModel: SitesViewModel) {
        _stationLatestReadingsViewModel = StateObject(wrappedValue: StationLatestReadingsViewModel(viewModel: sitesViewModel));
        _pilotTracksViewModel = StateObject(wrappedValue: PilotTracksViewModel())
    }

    var body: some View {
        ZStack {
            MKMapViewWrapper(
                region: $mapSettingsViewModel.region,
                annotations: $mapAnnotations,
                mapType: mapSettingsViewModel.selectedMapType.toMapKitType(),
                selectedSite: $selectedSite,
                selectedPilotTrack: $selectedPilotTrack,
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
/*
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
*/
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
        .sheet(item: $selectedPilotTrack) { pilotTrack in
            PilotDetailView(pilotTrack: pilotTrack)
        }

        // Monitor for changes to live tracks and update annotations
        .onReceive(pilotTracksViewModel.$pilotTracks) { pilotTracks in
            // Append new pilot track annotations to the existing annotation list
            let newPilotAnnotations = pilotTracks.map { trackNode in
                mapAnnotationList(
                    annotationType: "pilot",
                    annotationID: String(trackNode.pilotName.prefix(6)),
                    annotationName: trackNode.pilotName,
                    coordinates: CLLocationCoordinate2D(latitude: trackNode.coordinates.latitude, longitude: trackNode.coordinates.longitude),
                    altitude: String(trackNode.altitude),
                    readingsNote: "",
                    forecastNote: "",
                    siteType: "",
                    readingsStation: "",
                    readingsSource: "",
                    windSpeed: trackNode.speed,
                    windDirection: trackNode.heading,
                    windGust: 0.0,
                    inEmergency: trackNode.inEmergency,
                    trackdateTime: trackNode.dateTime
                )
            }
            mapAnnotations.append(contentsOf: newPilotAnnotations)
        }
    }
    
    // Timer to reload readings and live tracks if page stays active
    private func startTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + pageRefreshInterval) {
            if isActive {
                if mapSettingsViewModel.activeLayers.contains(.stations) {
                    stationLatestReadingsViewModel.reloadLatestReadingsData()
                }
                if mapSettingsViewModel.activeLayers.contains(.pilots) {
                    for pilot in pilotsViewModel.pilots {
                        pilotTracksViewModel.fetchTrackingData(trackingURL: pilot.trackingFeedURL)
                    }
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
                        windSpeed: 0.0,
                        windDirection: 0.0,
                        windGust: 0.0,
                        inEmergency: false,
                        trackdateTime: nil
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
                                windSpeed: reading.windSpeed,
                                windDirection: reading.windDirection,
                                windGust: reading.windGust,
                                inEmergency: false,
                                trackdateTime: nil
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
                            altitude: String(Int(Double(reading.stationElevation) ?? 0.0)),
                            readingsNote: "",
                            forecastNote: "",
                            siteType: "",
                            readingsStation: reading.stationID,
                            readingsSource: "Mesonet",
                            windSpeed: reading.windSpeed,
                            windDirection: reading.windDirection,
                            windGust: reading.windGust,
                            inEmergency: false,
                            trackdateTime: nil
                        )
                        mapAnnotations.append(annotation)
                    }
                }
            }
        }
        if mapSettingsViewModel.activeLayers.contains(.pilots) {
            for pilot in pilotsViewModel.pilots {
                pilotTracksViewModel.fetchTrackingData(trackingURL: pilot.trackingFeedURL)
            }
        }
    }
}
