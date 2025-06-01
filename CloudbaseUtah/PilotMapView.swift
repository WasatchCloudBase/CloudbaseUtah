import SwiftUI
import MapKit
import Combine
import UIKit
import CoreGraphics
import CoreLocation
import Foundation

struct pilotMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var zoomLevel: Double
    let pilotTracks: [PilotTracks]
    let onPilotSelected: (PilotTracks) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, onPilotSelected: onPilotSelected)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.showsUserLocation = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        let calendar = Calendar.current
        let groupedTracks = Dictionary(grouping: pilotTracks) { track in
            PilotTrackKey(pilotName: track.pilotName, date: calendar.startOfDay(for: track.dateTime))
        }

        let showAllMarkers = zoomLevel > mapShowAllMarkersZoomLevel
        var addedTrackIDs = Set<UUID>() // Make sure PilotTracks has a UUID or unique identifier

        for (_, tracks) in groupedTracks {
            let sorted = tracks.sorted { $0.dateTime < $1.dateTime }
            let coords = sorted.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

            // Draw polyline if multiple coordinates
            if coords.count > 1 {
                let polyline = MKPolyline(coordinates: coords, count: coords.count)
                mapView.addOverlay(polyline)
            }

            for (index, track) in sorted.enumerated() {
                // Skip already-processed tracks
                guard addedTrackIDs.insert(track.id).inserted else { continue }

                let isFirst = index == 0
                let isLast = index == sorted.count - 1
                let isEmergency = track.inEmergency == true
                let hasMessage = !(track.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

                let isNormalNode = !isFirst && !isLast && !isEmergency && !hasMessage
                if !showAllMarkers && isNormalNode {
                    continue
                }

                let annotation = PilotTrackAnnotation(
                    coordinate: CLLocationCoordinate2D(latitude: track.latitude, longitude: track.longitude),
                    title: track.pilotName,
                    subtitle: DateFormatter.localizedString(from: track.dateTime, dateStyle: .none, timeStyle: .short),
                    annotationType: "pilot",
                    pilotTrack: track,
                    pilotName: track.pilotName,
                    isFirst: isFirst,
                    isLast: isLast,
                    isEmergency: isEmergency,
                    hasMessage: hasMessage
                )

                mapView.addAnnotation(annotation)
            }
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: pilotMapView
        let onPilotSelected: (PilotTracks) -> Void

        init(parent: pilotMapView, onPilotSelected: @escaping (PilotTracks) -> Void) {
            self.parent = parent
            self.onPilotSelected = onPilotSelected
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let newZoom = log2(360 * (Double(mapView.frame.size.width) / 256) / mapView.region.span.longitudeDelta)
            DispatchQueue.main.async {
                self.parent.zoomLevel = newZoom
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue.withAlphaComponent(0.7)
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer()
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pilotAnnotation = annotation as? PilotTrackAnnotation else { return nil }

            if pilotAnnotation.isFirst || pilotAnnotation.isLast || pilotAnnotation.isEmergency || pilotAnnotation.hasMessage {
                let identifier = "PilotMarkerAnnotation"
                
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

                view.annotation = nil  // Ensure no stale annotation
                view.annotation = annotation
                view.canShowCallout = false
                view.clusteringIdentifier = nil  // <--- this disables clustering

                // Style
                if pilotAnnotation.isEmergency {
                    view.markerTintColor = .systemRed
                    view.glyphImage = UIImage(systemName: "exclamationmark.triangle.fill")
                } else if pilotAnnotation.hasMessage {
                    view.markerTintColor = .systemOrange
                    view.glyphImage = UIImage(systemName: "envelope.fill")
                } else if pilotAnnotation.isFirst {
                    view.markerTintColor = .systemGreen
                    view.glyphImage = UIImage(systemName: "arrow.up.circle.fill")
                } else if pilotAnnotation.isLast {
                    view.markerTintColor = .systemBlue
                    view.glyphImage = UIImage(systemName: "flag.checkered")
                }

                return view
            } else {
                // Regular node — use small dot view
                let identifier = "DotAnnotation"
                

                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                    ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

                view.annotation = annotation
                view.canShowCallout = false
                view.clusteringIdentifier = nil
                view.frame = CGRect(x: 0, y: 0, width: 6, height: 6)
                view.layer.cornerRadius = 3
                view.backgroundColor = .gray
                return view
            }
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard
                let annotation = view.annotation as? PilotTrackAnnotation,
                let track = annotation.pilotTrack
            else { return }

            // Defer the state update to avoid conflict with MKMapView animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.onPilotSelected(track)
            }
        }
    }
}

struct PilotMapContainerView: View {
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodesViewModel
    @EnvironmentObject var sitesViewModel: SitesViewModel
    @EnvironmentObject var pilotsViewModel: PilotsViewModel
    @EnvironmentObject var mapSettingsViewModel: MapSettingsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var stationLatestReadingsViewModel: StationLatestReadingsViewModel
    @StateObject private var pilotTracksViewModel: PilotTracksViewModel
    @StateObject private var annotationSourceItemsViewModel: AnnotationSourceItemsViewModel
    @State private var selectedSite: Sites?
    @State private var selectedPilotTrack: PilotTracks?
    @State private var isLayerSheetPresented = false
    @State private var isPlaying = false
    @State private var animationProgress: Double = 0.0
    @State private var currentTime: String = "00:00"
    @State private var annotationSourceItems: [AnnotationSourceItem] = []
    @State private var isActive = false                         // Whether view is active for time refreshes
    @State private var refreshWorkItem: DispatchWorkItem?       // Used to cancel and restart timer when another event occurs
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: mapInitLatitude, longitude: mapInitLongitude),
        span: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan))
    @State private var position = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: mapInitLatitude, longitude: mapInitLongitude),
        span: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan)))
    @State private var lastRegionSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0, longitudeDelta: 0)
    @State private var currentZoomLevel: Double = defaultMapZoomLevel
    private var cancellables = Set<AnyCancellable>()
    
    init(sitesViewModel: SitesViewModel) {
        _stationLatestReadingsViewModel = StateObject(wrappedValue: StationLatestReadingsViewModel(viewModel: sitesViewModel));
        _pilotTracksViewModel = StateObject(wrappedValue: PilotTracksViewModel())
        _annotationSourceItemsViewModel = StateObject(wrappedValue: AnnotationSourceItemsViewModel(
            mapSettingsViewModel: MapSettingsViewModel(
                region: MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: mapInitLatitude, longitude: mapInitLongitude),
                    span: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan)
                ),
                activeLayers: defaultActiveLayers,
                selectedMapType: .standard,
                pilotTrackDays: defaultPilotTrackDays),
            sitesViewModel: SitesViewModel(),
            stationLatestReadingsViewModel: StationLatestReadingsViewModel(viewModel: SitesViewModel()),
            pilotsViewModel: PilotsViewModel(), pilotTracksViewModel: PilotTracksViewModel()))
    }
    
    var body: some View {
        ZStack {
            
            // Validate annotation coordinates
            let _ = annotationSourceItemsViewModel.clusteredAnnotationSourceItems.forEach { annotation in
                assert(annotation.coordinates.latitude >= -90 && annotation.coordinates.latitude <= 90, "Invalid latitude: \(annotation.coordinates.latitude)")
                assert(annotation.coordinates.longitude >= -180 && annotation.coordinates.longitude <= 180, "Invalid longitude: \(annotation.coordinates.longitude)")
            }
            
            pilotMapView(
                region: $region,
                zoomLevel: $currentZoomLevel,
                pilotTracks: pilotTracksViewModel.pilotTracks,
                onPilotSelected: { track in
                    selectedPilotTrack = track
                }
            )
            .mapStyle(mapSettingsViewModel.selectedMapType.toMapStyle())
            .cornerRadius(10)
            .padding(.vertical, 8)

            if let track = selectedPilotTrack {
                PilotTrackNodeView(pilotTrack: track)
            }

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
                                Text("Settings")
                                    .font(.caption)
                                    .foregroundColor(layersFontColor)
                            }
                        }
                        .sheet(isPresented: $isLayerSheetPresented) {
                            MapSettingsView(
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
                annotationSourceItemsViewModel.mapSettingsViewModel = mapSettingsViewModel
                annotationSourceItemsViewModel.sitesViewModel = sitesViewModel
                annotationSourceItemsViewModel.stationLatestReadingsViewModel = stationLatestReadingsViewModel
                annotationSourceItemsViewModel.pilotsViewModel = pilotsViewModel
                annotationSourceItemsViewModel.pilotTracksViewModel = pilotTracksViewModel
                annotationSourceItemsViewModel.updateAnnotationSourceItems {
                    annotationSourceItemsViewModel.clusterAnnotationSourceItems(regionSpan: region.span)
                    startTimer() // Cancels existing timer and restarts
                    isActive = true
                }
            } else {
                isActive = false
            }
        }
       .onAppear {
           annotationSourceItemsViewModel.mapSettingsViewModel = mapSettingsViewModel
           annotationSourceItemsViewModel.sitesViewModel = sitesViewModel
           annotationSourceItemsViewModel.stationLatestReadingsViewModel = stationLatestReadingsViewModel
           annotationSourceItemsViewModel.pilotsViewModel = pilotsViewModel
           annotationSourceItemsViewModel.pilotTracksViewModel = pilotTracksViewModel
           annotationSourceItemsViewModel.updateAnnotationSourceItems {
               annotationSourceItemsViewModel.clusterAnnotationSourceItems(regionSpan: region.span)
               isActive = true
               startTimer()
               startMonitoringRegion()
           }
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
    
    private func getPilotLabelHeightFromMapSpan(span: MKCoordinateSpan) -> CGFloat {
        if span.latitudeDelta < pilotNodeLabelThreeRowSpan {
            return pilotNodeAnnotationTextThreeRowHeight
        }
        else {
            return pilotNodeAnnotationTextOneRowHeight
        }
    }
    
    private func getPilotAnnotationImage(inEmergency: Bool, message: String) -> String {
        if inEmergency {
            return pilotInEmergencyAnnotationImage
        } else if message != "" {
            return pilotMessageAnnotationImage
        } else {
            return pilotNodeAnnotationImage
        }
    }
    
    // Timer to reload annotations if page stays active
    private func startTimer() {
        // Cancel any existing timer
        refreshWorkItem?.cancel()
        
        // Create a new work item
        let workItem = DispatchWorkItem {
            if isActive {
                annotationSourceItemsViewModel.mapSettingsViewModel = mapSettingsViewModel
                annotationSourceItemsViewModel.sitesViewModel = sitesViewModel
                annotationSourceItemsViewModel.stationLatestReadingsViewModel = stationLatestReadingsViewModel
                annotationSourceItemsViewModel.pilotsViewModel = pilotsViewModel
                annotationSourceItemsViewModel.pilotTracksViewModel = pilotTracksViewModel
                annotationSourceItemsViewModel.updateAnnotationSourceItems {
                    annotationSourceItemsViewModel.clusterAnnotationSourceItems(regionSpan: region.span)
                }
            }
        }
        refreshWorkItem = workItem
        
        // Schedule the new timer
        DispatchQueue.main.asyncAfter(deadline: .now() + pageRefreshInterval, execute: workItem)
    }
    
    private func startMonitoringRegion() {
        Timer.scheduledTimer(withTimeInterval: mapBatchProcessingInterval, repeats: true) { _ in
            let currentSpan = region.span
            if hasRegionSpanChanged(from: lastRegionSpan, to: currentSpan) {
                lastRegionSpan = currentSpan
                annotationSourceItemsViewModel.clusterAnnotationSourceItems(regionSpan: currentSpan)
            }
        }
    }
    
    private func hasRegionSpanChanged(from oldSpan: MKCoordinateSpan, to newSpan: MKCoordinateSpan) -> Bool {
        return abs(oldSpan.latitudeDelta - newSpan.latitudeDelta) > mapScaleChangeTolerance ||
        abs(oldSpan.longitudeDelta - newSpan.longitudeDelta) > mapScaleChangeTolerance
    }
    
}
