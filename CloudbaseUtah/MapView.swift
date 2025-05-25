/* Data flow for map annotations:
 
 App on appear:  List of sites and pilots loaded
 
 MapView:
    Site list and pilot list passed in as environment object
    Map built using MKMapViewWrapper
    On appear, timer is started to periodically update annotations
    updateMapAnnotations is called on appear, change of scene, or change of map parameters to manage mapAnnotation structure
    Publish any changes to pilotTracksViewModel
 
 updateMapAnnotations manages the mapAnnotation [MapAnnotation] structure:
    Removes all existing mapAnnotations
    Based on which map layers are active:
        Fetches source data (calls fetchTrackingData for pilot tracks, latest readings for station readings, etc.)
            Update pilot tracks to pilotTracksViewModel
        Appends mapAnnotations for active layers

 MKMapViewWrapper manages the map and annotation display and events:
    func makeUIView
    func updateUIView
    func makeCoordinator
    class Coordinator
        @objc func labelTapped
        struct StationAnnotationMarker: View
        class StationAnnotationView: MKAnnotationView
            private func setupHostingController()
        func updatePolylines
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay)
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation)
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool)
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation)
 
 
 *** Implement throttle functionality on async functions that are called when use pan/zooms map
 *** Determine when to use main or background async threads for various asynch processes
 
*/

import SwiftUI
import MapKit
import Combine
import UIKit
import CoreGraphics
import CoreLocation
import Foundation

// Annotation data model
struct MapAnnotation: Identifiable {
    let id = UUID()
    let annotationType: String              // e.g., "site" or "station"
    let annotationID: String                // an identifier based on the type
    var nodePosition: String? = nil         // Identifies first and last nodes in a track
    let annotationName: String              // Pilot name for pilot track annotations
    let coordinates: CLLocationCoordinate2D
    let altitude: String
    let readingsNote: String                // For site annotations; track message for pilot track annotations
    let forecastNote: String
    let siteType: String                    // For site annotations
    let readingsStation: String             // For site annotations
    let readingsSource: String
    let windSpeed: Double?                  // For station annotations; track speed for pilot track annotations
    let windDirection: Double?              // Heading for pilot track annotations
    let windGust: Double?
    let inEmergency: Bool?                  // For pilot track annotations
    let message: String?
    let trackDateTime: Date?
}

// Custom MKPointAnnotation subclass for attaching clustering identifiers, station rendered wind speed/direction image,
// and conditional pilot track annotation images
class CustomMKPointAnnotation: MKPointAnnotation {
    var annotationType: String = ""         // Track annotation type (site, station, pilot, etc.)
    var nodePosition: String? = nil         // Identifies first and last nodes in a track
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
    @Binding var annotations: [MapAnnotation]
    var mapType: MKMapType
    @Binding var selectedSite: Sites?
    @Binding var selectedPilotTrack: PilotTracks?
    @ObservedObject var mapSettingsViewModel: MapSettingsViewModel

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        // Configure the map view as needed, for example:
        mapView.isRotateEnabled = mapEnableRotation
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.mapType = mapType
        mapView.register(MKAnnotationView.self, forAnnotationViewWithReuseIdentifier: "CustomAnnotation")
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.mapType = mapType

        if uiView.region.center.latitude != region.center.latitude ||
            uiView.region.center.longitude != region.center.longitude {
            uiView.setRegion(region, animated: false)
        }
        
        // If annotations are cleared, remove all markers
        if annotations.isEmpty {
            uiView.removeAnnotations(uiView.annotations)
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
        
        if !mapSettingsViewModel.activeLayers.contains(.pilots) {
            let pilotsToRemove = uiView.annotations.compactMap { $0 as? CustomMKPointAnnotation }
                .filter { $0.annotationType == "pilot" }
            uiView.removeAnnotations(pilotsToRemove)
        } else {
            // Remove annotations that are older than days specified in pilotTrackDays
            let targetDate = getDateForDays(days: mapSettingsViewModel.pilotTrackDays)
            let pilotsToRemove = uiView.annotations.compactMap { $0 as? CustomMKPointAnnotation }
                .filter { $0.trackDateTime ?? Date() < targetDate }
            uiView.removeAnnotations(pilotsToRemove)
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
            customAnnotation.nodePosition = ann.nodePosition
            customAnnotation.altitude = ann.altitude
            
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
        weak var mapView: MKMapView?
        var parent: MKMapViewWrapper

        init(_ parent: MKMapViewWrapper) {
            self.parent = parent
        }
        
        // When annotation label is tapped, treat as if annotation marker is tapped
        @objc func labelTapped(_ sender: UITapGestureRecognizer) {
            guard let label = sender.view as? UILabel,
                  let annotationView = label.superview as? MKAnnotationView,
                  let annotation = annotationView.annotation,
                  let customAnnotation = annotation as? CustomMKPointAnnotation,
                  let mapView = self.mapView  // Use the stored mapView reference
            else { return }
            if let annotationView = label.superview as? MKAnnotationView {
                mapView.selectAnnotation(annotationView.annotation!, animated: true)
            }
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
        
        func updatePolylines(on mapView: MKMapView) {
            // Remove all previous overlays
            mapView.overlays.forEach { mapView.removeOverlay($0) }
            
            // Group pilot annotations by pilot name and the start of day of their timestamp
            var groupedAnnotations = [PilotTrackKey: [(index: Int, annotation: MapAnnotation)]]()
            
            // Loop through the parent's annotations with indices
            for (index, ann) in parent.annotations.enumerated() {
                if ann.annotationType == "pilot" {
                    let key = PilotTrackKey(
                        pilotName: ann.annotationName,
                        date: Calendar.current.startOfDay(for: ann.trackDateTime ?? Date())
                    )
                    groupedAnnotations[key, default: []].append((index, ann))
                }
            }
            
            // Now process each group
            for (_, group) in groupedAnnotations {
                // Sort group based on the timestamp
                let sortedGroup = group.sorted {
                    ($0.annotation.trackDateTime ?? Date()) < ($1.annotation.trackDateTime ?? Date())
                }
                
                guard sortedGroup.count > 1 else { continue }
                
                // Update the parent's annotations array directly using the index:
//                parent.annotations[sortedGroup.first!.index].nodePosition = "first"
//                parent.annotations[sortedGroup.last!.index].nodePosition = "last"
                
                // Create a polyline for the track
                let coordinates = sortedGroup.map { $0.annotation.coordinates }
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                mapView.addOverlay(polyline)
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = pilotTrackColor
                renderer.lineWidth = pilotTrackWidth
                return renderer
            }
            return MKOverlayRenderer()
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
                
                var annotationImage: UIImage?
                var annotationTextColor: UIColor?
                
                switch customAnnotation.annotationType {
                case "site":
                    annotationImage = siteAnnotationUIImage
                    annotationTextColor = siteAnnotationTextColor
                case "pilot":
                    
                    // Determine image based on position
                    switch customAnnotation.nodePosition {
                    case "first":
                        annotationImage = pilotLaunchAnnotationUIImage
                    case "last":
                        annotationImage = pilotLatestAnnotationUIImage
                    default:
                        annotationImage = pilotNodeAnnotationUIImage
                        annotationTextColor = pilotNodeAnnotationColor
                        // Override image if the track point has a text message
                        if customAnnotation.message != nil {
                            annotationImage = pilotMessageAnnotationUIImage
                        }
                    }
                    
                    annotationTextColor = pilotLabelNameTextColor
                    if customAnnotation.inEmergency ?? false {
                        annotationTextColor = pilotEmergencyAnnotationTextColor
                    }
                default:
                    annotationImage = defaultAnnotationUIImage
                    annotationTextColor = defaultAnnotationTextColor
                }
                annotationView!.image = annotationImage
                
                // Add a label below the image as a subview.
                let label = UILabel()
                let labelText = customAnnotation.title

                if customAnnotation.annotationType == "pilot" {
                    
                    let attributedText = NSMutableAttributedString()
                    
                    let pilotName = (labelText?.components(separatedBy: " ").first ?? labelText) ?? "Pilot"
                    let labelLine1 = NSMutableAttributedString(
                        string: pilotName + "\n",
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 11),
                            .foregroundColor: pilotLabelNameTextColor
                        ]
                    )
                    attributedText.append(labelLine1)

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "h:mm"
                    let labelLine2 = NSMutableAttributedString(
                        string: dateFormatter.string(from: customAnnotation.trackDateTime ?? Date()) + "\n",
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 10),
                            .foregroundColor: pilotLabelDateTextColor
                        ]
                    )
                    attributedText.append(labelLine2)
                    
                    let labelLine3 = NSMutableAttributedString(
                        string: "\(customAnnotation.altitude ?? "0")",
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 10),
                            .foregroundColor: pilotLabelAltTextColor
                        ]
                    )
                    attributedText.append(labelLine3)

                    label.attributedText = attributedText
                    label.numberOfLines = 0                 // Allow unlimited lines
                    label.lineBreakMode = .byWordWrapping   // Wrap at word boundaries
                    label.backgroundColor = pilotLabelBackgroundColor
                    label.layer.cornerRadius = 6
                    let labelXPosition = -((annotationImage?.size.width ?? 20) / 1.2)
                    let labelYPosition = ((annotationImage?.size.height ?? 20) / 1.3)
                    label.frame = CGRect(x: labelXPosition, y: labelYPosition, width: 60, height: 40)
                    
                } else {
                    
                    label.text = labelText
                    label.font = UIFont.systemFont(ofSize: 11)
                    label.textColor = annotationTextColor
                    let labelXPosition = -((annotationImage?.size.width ?? 20) / 2)
                    let labelYPosition = ((annotationImage?.size.height ?? 20) / 1.3)
                    label.frame = CGRect(x: labelXPosition, y: labelYPosition, width: 100, height: 20)
                    
                }
                
                label.textAlignment = .center
                label.layer.masksToBounds = true
                
                // Enable user interaction and add tap gesture
                label.isUserInteractionEnabled = true
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(labelTapped(_:)))
                label.addGestureRecognizer(tapGesture)
                        
                annotationView!.addSubview(label)
                
                return annotationView
            }
            return nil
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

// Composite structure to check for all map settings and view changes together
// and only rebuild annotations once if there are multiple changes
struct MapSettingsState: Equatable {
    let activeLayers: Set<MapLayer>
    let pilotTrackDays: Double
    let scenePhase: ScenePhase
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
    @State private var mapAnnotations: [MapAnnotation] = []
    @State private var isActive = false                         // Whether view is active for time refreshes
    @State private var refreshWorkItem: DispatchWorkItem?       // Used to cancel and restart timer when another event occurs
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
                                selectedMapType: $mapSettingsViewModel.selectedMapType,
                                pilotTrackDays: $mapSettingsViewModel.pilotTrackDays
                            )
                        }
                    }
                    .padding()
                    .background(layersIconBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer()
                    
                    VStack(alignment: .trailing) {
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
        .onChange(of: MapSettingsState(activeLayers: mapSettingsViewModel.activeLayers,
                                       pilotTrackDays: mapSettingsViewModel.pilotTrackDays,
                                       scenePhase: scenePhase)) {
            // Check all changes together to only execute updateMapAnnotations once
            if scenePhase == .active {
                updateMapAnnotations()
                startTimer() // Cancels existing timer and restarts
                isActive = true
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
        .sheet(item: $selectedSite) { site in
            SiteDetailView(site: site)

        }
        .sheet(item: $selectedPilotTrack) { pilotTrack in
            PilotTrackNodeView(pilotTrack: pilotTrack)
        }
        // Make sure pilot live track view model is published
        .environmentObject(pilotTracksViewModel)
    }
    
    // Timer to reload annotations if page stays active
    private func startTimer() {
        // Cancel any existing timer
        refreshWorkItem?.cancel()

        // Create a new work item
        let workItem = DispatchWorkItem {
            if isActive {
                updateMapAnnotations()
            }
        }
        refreshWorkItem = workItem

        // Schedule the new timer
        DispatchQueue.main.asyncAfter(deadline: .now() + pageRefreshInterval, execute: workItem)
    }

    // Update the annotations based on the active layers.
    private func updateMapAnnotations() {
        mapAnnotations.removeAll()

        if mapSettingsViewModel.activeLayers.contains(.sites) {
                let filteredSites = sitesViewModel.sites.filter { $0.siteType == "Mountain" || $0.siteType == "Soaring" }
            for site in filteredSites {
                if let lat = Double(site.siteLat), let lon = Double(site.siteLon) {
                    let annotation = MapAnnotation(
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
    
            // Set readings dispatch group to determine when all readings calls are completed before updating annotations
            let readingsGroup = DispatchGroup()
            readingsGroup.enter()

            stationLatestReadingsViewModel.getLatestMesonetReadings(stationParameters: "") {
                stationLatestReadingsViewModel.getLatestCUASAReadings() {
                    readingsGroup.leave()
                }
            }

            // When all CUASA readings are received, update annotations
            readingsGroup.notify(queue: .main) {
                // Create annotations for each latest reading
                for reading in stationLatestReadingsViewModel.latestReadings {
                    if let lat = Double(reading.stationLatitude), let lon = Double(reading.stationLongitude) {
                        let annotation = MapAnnotation(
                            annotationType: "station",
                            annotationID: reading.stationID,
                            annotationName: reading.stationName,
                            coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            altitude: reading.stationElevation,
                            readingsNote: "",
                            forecastNote: "",
                            siteType: "",
                            readingsStation: reading.stationID,
                            readingsSource: reading.readingsSource,
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
        
        if mapSettingsViewModel.activeLayers.contains(.pilots){
            // Set pilot dispatch group to determine when all pilot track calls are completed before updating annotations
            let pilotGroup = DispatchGroup()
            for pilot in pilotsViewModel.pilots {
                pilotGroup.enter()
                self.pilotTracksViewModel.getPilotTrackingData(pilotName: pilot.pilotName, trackingURL: pilot.trackingFeedURL, days: mapSettingsViewModel.pilotTrackDays) {
                    pilotGroup.leave()
                }
            }
            pilotGroup.notify(queue: .main) {
                for trackNode in pilotTracksViewModel.pilotTracks {
                    let annotation = MapAnnotation(
                        annotationType: "pilot",
                        annotationID: trackNode.pilotName,
                        annotationName: trackNode.pilotName,
                        coordinates: CLLocationCoordinate2D(latitude: trackNode.coordinates.latitude, longitude: trackNode.coordinates.longitude),
                        altitude: formatAltitude(String(Int(trackNode.altitude))),
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
                    mapAnnotations.append(annotation)
                }
            }
        }
    }
}
