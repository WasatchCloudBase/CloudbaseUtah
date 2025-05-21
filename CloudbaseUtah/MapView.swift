import SwiftUI
import MapKit
import Combine
import UIKit
import CoreGraphics
import CoreLocation
import Foundation

// Annotation data model
struct mapAnnotationList: Identifiable {
    let id = UUID()
    let annotationType: String              // e.g., "site" or "station"
    let annotationID: String                // an identifier based on the type
    let annotationName: String              // Pilot name for pilot track annotations
    let coordinates: CLLocationCoordinate2D
    let altitude: String
    let readingsNote: String                // For site annotations; track message for pilot track annotations
    let forecastNote: String
    let siteType: String
    let readingsStation: String             // For site annotations
    let readingsSource: String
    let windSpeed: Double?                  // For station annotations; track speed for pilot track annotations
    let windDirection: Double?              // Heading for pilot track annotations
    let windGust: Double?
    let inEmergency: Bool?                  // For pilot track annotations
    let message: String?
    let trackDateTime: Date?
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
    var message: String?
}

// Listing of pilot live tracks by pilot name and date
// used to determine track groupings for line rendering on track
struct PilotTrackKey: Hashable {
    let pilotName: String
    let date: Date
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
            customAnnotation.trackDateTime = ann.trackDateTime

            // For station annotations, set clustering.
            if ann.annotationType == "station" {
                customAnnotation.clusteringIdentifier = "stationCluster"
            }
            
            return customAnnotation
        }
        uiView.addAnnotations(newAnnotations)
        
        //Create lines between pilot track nodes
        // with a delay to ensure annotations have been added
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            context.coordinator.updatePolylines(on: uiView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MKMapViewWrapper
        
        init(_ parent: MKMapViewWrapper) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .white // Customize the color
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func updatePolylines(on mapView: MKMapView) {
            // Remove previous overlays
            mapView.overlays.forEach { mapView.removeOverlay($0) }
            
            // Ensure pilot track annotations exist
            let groupedTracks = Dictionary(grouping: parent.annotations.filter { $0.annotationType == "pilot" }) { ann in
                PilotTrackKey(pilotName: ann.annotationName, date: Calendar.current.startOfDay(for: ann.trackDateTime ?? Date()))
            }

            for (_, trackNodes) in groupedTracks {
                let sortedTrackNodes = trackNodes.sorted { $0.trackDateTime ?? Date() < $1.trackDateTime ?? Date() }
                let coordinates = sortedTrackNodes.map { $0.coordinates }
                
                guard coordinates.count > 1 else { continue } // Ensure at least two points

                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                mapView.addOverlay(polyline)
            }

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
                    // Override image if the track point has a text message
                    if customAnnotation.message != nil {
                        annotationImage = pilotMessageAnnotationUIImage
                    }
                    annotationTextColor = pilotAnnotationTextColor
                    if customAnnotation.inEmergency ?? false {
                        annotationTextColor = pilotEmergencyAnnotationTextColor
                    }
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
                guard let selectedPilotTrack = parent.annotations.first(where: { $0.annotationID == customAnnotation.title &&
                        $0.trackDateTime == customAnnotation.trackDateTime}) else {
                    print("Could not find pilot annotation for: \(String(describing: customAnnotation.title)) and \(String(describing: customAnnotation.trackDateTime))")
                    return
                }
                DispatchQueue.main.async {
                    self.parent.selectedPilotTrack = PilotTracks(
                        pilotName: selectedPilotTrack.annotationName,
                        dateTime: selectedPilotTrack.trackDateTime ?? Date(),
                        coordinates: (latitude: selectedPilotTrack.coordinates.latitude,
                                      longitude: selectedPilotTrack.coordinates.longitude),
                        speed: selectedPilotTrack.windSpeed ?? 0.0,
                        altitude: Double(selectedPilotTrack.altitude) ?? 0.0,
                        heading: selectedPilotTrack.windDirection ?? 0.0,
                        inEmergency: selectedPilotTrack.inEmergency ?? false,
                        message: selectedPilotTrack.readingsNote
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
    @State private var pilotTrackDays: Double = defaultPilotTrackDays
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
                    
                    VStack(alignment: .trailing) {
                        if mapSettingsViewModel.activeLayers.contains(.pilots) {
                            // Slider for selecting number of days
                            VStack (alignment: .trailing) {
                                HStack {
                                    VStack {
                                        Text("Track")
                                            .font(.caption)
                                            .foregroundColor(layersFontColor)
                                        
                                        Text("Days")
                                            .font(.caption)
                                            .foregroundColor(layersFontColor)
                                    }
                                    .padding(.horizontal)
                                    VStack {
                                        Slider(value: $pilotTrackDays, in: 1...3, step: 1)
                                            .tint(layersIconColor)
                                            .onChange(of: pilotTrackDays) { newValue, oldValue in
                                                // Remove previous pilot annotations
                                                mapAnnotations.removeAll { $0.annotationType == "pilot" }
                                                // Reload tracking data
                                                for pilot in pilotsViewModel.pilots {
                                                    pilotTracksViewModel.fetchTrackingData(trackingURL: pilot.trackingFeedURL, days: newValue)
                                                }
                                            }
                                        HStack {
                                            Text("1")
                                                .font(.caption)
                                                .foregroundColor(layersFontColor)
                                                .padding(.leading, 10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            Text("2")
                                                .font(.caption)
                                                .foregroundColor(layersFontColor)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                            Text("3")
                                                .font(.caption)
                                                .foregroundColor(layersFontColor)
                                                .padding(.trailing, 10)
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                        .font(.caption)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
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
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .onChange(of: mapSettingsViewModel.activeLayers) {
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
            PilotTrackNodeView(pilotTrack: pilotTrack)
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
                    readingsNote: trackNode.message ?? "",
                    forecastNote: "",
                    siteType: "",
                    readingsStation: "",
                    readingsSource: "",
                    windSpeed: trackNode.speed,
                    windDirection: trackNode.heading,
                    windGust: 0.0,
                    inEmergency: trackNode.inEmergency,
                    message: trackNode.message,
                    trackDateTime: trackNode.dateTime
                )
            }
            mapAnnotations.append(contentsOf: newPilotAnnotations)
        }
        // Make sure pilot live track view model is published
        .environmentObject(pilotTracksViewModel)
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
                        pilotTracksViewModel.fetchTrackingData(trackingURL: pilot.trackingFeedURL, days: pilotTrackDays)
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
                        message: "",
                        trackDateTime: nil
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
                                message: "",
                                trackDateTime: nil
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
                            message: "",
                            trackDateTime: nil
                        )
                        mapAnnotations.append(annotation)
                    }
                }
            }
        }
        if mapSettingsViewModel.activeLayers.contains(.pilots) {
            for pilot in pilotsViewModel.pilots {
                pilotTracksViewModel.fetchTrackingData(trackingURL: pilot.trackingFeedURL, days: pilotTrackDays)
            }
        }
    }
}






// Pilot live tracking structure
struct PilotTracks: Identifiable {
    let id: UUID = UUID()
    let pilotName: String
    let dateTime: Date
    let coordinates: (latitude: Double, longitude: Double)
    let speed: Double
    let altitude: Double
    let heading: Double
    let inEmergency: Bool
    let message: String?
}

class PilotTracksViewModel: ObservableObject {
    @Published var pilotTracks: [PilotTracks] = []
    
    func fetchTrackingData(trackingURL: String, days: Double) {
        guard let url = constructURL(trackingURL: trackingURL, days: days) else { return }
        var request = URLRequest(url: url)

        // Set headers to handle InReach requirements and redirect to data file location
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("1", forHTTPHeaderField: "DNT")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("none", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        request.setValue("\"Chromium\";v=\"136\", \"Google Chrome\";v=\"136\", \"Not.A/Brand\";v=\"99\"", forHTTPHeaderField: "sec-ch-ua")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")

        // Query InReach KML feed
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else { return }
            DispatchQueue.main.async {
                let newTracks = self.parseKML(data: data)
                // Check if track node already exists for pilot and time stamp; if so, don't append
                let existingKeys: Set<PilotTrackKey> = Set(self.pilotTracks.map { PilotTrackKey(pilotName: $0.pilotName, date: $0.dateTime) })
                let uniqueNewTracks = newTracks.filter { !existingKeys.contains(PilotTrackKey(pilotName: $0.pilotName, date: $0.dateTime)) }
                self.pilotTracks.append(contentsOf: uniqueNewTracks)
            }
        }
        task.resume()
    }

    private func constructURL(trackingURL: String, days: Double) -> URL? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        let dateSelectedDaysAgo = Date().addingTimeInterval(TimeInterval(-24 * days * 60 * 60))
        let dateString = dateFormatter.string(from: dateSelectedDaysAgo)
        let finalURLString = "\(trackingURL)?d1=\(dateString)"
        return URL(string: finalURLString)
    }

    private func parseKML(data: Data) -> [PilotTracks] {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            print("Invalid XML coding for track log")
            return []
        }

        let placemarkStrings = extractAllValues(from: xmlString, using: "<Placemark>", endTag: "</Placemark>")
        guard !placemarkStrings.isEmpty else {
            return []
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy h:mm:ss a"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var pilotTracks: [PilotTracks] = []
        for placemarkString in placemarkStrings {
            guard let pilotName = extractValue(from: placemarkString, using: "<Data name=\"Name\">", endTag: "</Data>"),
                  let dateTimeString = extractValue(from: placemarkString, using: "<Data name=\"Time\">", endTag: "</Data>"),
                  let latitudeString = extractValue(from: placemarkString, using: "<Data name=\"Latitude\">", endTag: "</Data>"),
                  let longitudeString = extractValue(from: placemarkString, using: "<Data name=\"Longitude\">", endTag: "</Data>")
            else {
                // ignore placemark entries that failed parsing (likely did not have a valid dateTime)
                continue
            }

            // Format data for track point
            let dateTime = formatter.date(from: dateTimeString) ?? Date()
            let speedString = extractValue(from: placemarkString, using: "<Data name=\"Velocity\">", endTag: "</Data>") ?? ""
            let speed = extractNumber(from: speedString) ?? 0.0
            let speedMph = convertKMToMiles(speed).rounded()
            let altitudeString = extractValue(from: placemarkString, using: "<Data name=\"Elevation\">", endTag: "</Data>") ?? ""
            let altitude = extractNumber(from: altitudeString) ?? 0.0
            let altitudeFeet = Double(convertMetersToFeet(altitude))
            let latitude = Double(latitudeString) ?? 0.0
            let longitude = Double(longitudeString) ?? 0.0
            let courseString = extractValue(from: placemarkString, using: "<Data name=\"Course\">", endTag: "</Data>") ?? ""
            let course = extractNumber(from: courseString) ?? 0.0
            let inEmergencyString = extractValue(from: placemarkString, using: "<Data name=\"In Emergency\">", endTag: "</Data>")?.lowercased()
            let inEmergency = Bool(inEmergencyString ?? "false") ?? false
            let message = extractValue(from: placemarkString, using: "<Data name=\"Text\">", endTag: "</Data>") ?? ""

            let trackPoint = PilotTracks(
                pilotName: pilotName,
                dateTime: dateTime,
                coordinates: (latitude, longitude),
                speed: speedMph,
                altitude: altitudeFeet,
                heading: course,
                inEmergency: inEmergency,
                message: message
            )
            pilotTracks.append(trackPoint)
        }
        return pilotTracks
    }
    
    private func extractAllValues(from text: String, using startTag: String, endTag: String) -> [String] {
        var values: [String] = []
        var searchRange: Range<String.Index>?
        while let startRange = text.range(of: startTag, options: [], range: searchRange),
              let endRange = text.range(of: endTag, options: [], range: startRange.upperBound..<text.endIndex) {
            let value = String(text[startRange.upperBound..<endRange.lowerBound])
            values.append(value)
            searchRange = endRange.upperBound..<text.endIndex
        }
        return values
    }
    
    private func extractValue(from text: String, using startTag: String, endTag: String) -> String? {
        
        // Get string within tag
        guard let startRange = text.range(of: startTag),
              let endRange = text.range(of: endTag, options: [], range: startRange.upperBound..<text.endIndex) else {
            //print("range lookup failed for startTag: \(startTag), endTag: \(endTag)")
            return nil
        }
        let tagString = String(text[startRange.upperBound..<endRange.lowerBound])

        // The string is in the format <value>xxx</value>
        // Only return the section between the value tags
        guard let startRange = tagString.range(of: "<value>"),
              let endRange = tagString.range(of: "</value>", options: [], range: startRange.upperBound..<tagString.endIndex) else {
            //print("value range lookup failed for startTag: \(startTag), endTag: \(endTag)")
            return nil
        }
        let valueString = String(tagString[startRange.upperBound..<endRange.lowerBound])
        
        return valueString
    }
}
