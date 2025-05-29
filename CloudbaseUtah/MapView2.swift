import SwiftUI
import MapKit
import Combine
import SDWebImage
import SDWebImageSwiftUI
/*
struct MapView2: View {
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
    @State private var annotationSourceItems: [AnnotationSourceItem] = []
    @State private var isActive = false                         // Whether view is active for time refreshes
    @State private var refreshWorkItem: DispatchWorkItem?       // Used to cancel and restart timer when another event occurs
    private var cancellables = Set<AnyCancellable>()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: mapInitLatitude, longitude: mapInitLongitude),
        span: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan)
    )
    @State private var lastRegionSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0, longitudeDelta: 0)

    init(sitesViewModel: SitesViewModel) {
        _stationLatestReadingsViewModel = StateObject(wrappedValue: StationLatestReadingsViewModel(viewModel: sitesViewModel));
        _pilotTracksViewModel = StateObject(wrappedValue: PilotTracksViewModel())
    }

    var body: some View {
        ZStack {
            
            // Validate annotation coordinates
            /*            let _ = viewModel.clusteredCameras.forEach { camera in
             assert(camera.latitude >= -90 && camera.latitude <= 90, "Invalid latitude: \(camera.latitude)")
             assert(camera.longitude >= -180 && camera.longitude <= 180, "Invalid longitude: \(camera.longitude)")
             }
             */
            
            Map(coordinateRegion: $region, annotationItems: viewModel.clusteredCameras) { camera in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude)) {
                    Button {
                        selectedCamera = camera
                    } label: {
                        VStack {
                            Image(systemName: cameraAnnotationImage)
                                .foregroundColor(cameraAnnotationColor)
                            Text(camera.location)
                                .font(.footnote)
                                .foregroundColor(cameraAnnotationTextColor)
                            //        .multilineTextAlignment(.center)
                                .frame(width: annotationTextWidth, height: annotationTextHeight)
                        }
                    }
                }
            }
            .cornerRadius(10)
            .padding(.vertical, 8)
            .onAppear {
                viewModel.fetchCameras()
                startMonitoringRegion()
            }
            .sheet(item: $selectedCamera) { camera in
                CameraDetailView(camera: camera)
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
                                Text("Layers")
                                    .font(.caption)
                                    .foregroundColor(layersFontColor)
                            }
                        }
                        .sheet(isPresented: $isLayerSheetPresented) {
                            MapLayerView(
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
                updateAnnotationSourceItems()
                startTimer() // Cancels existing timer and restarts
                isActive = true
            } else {
                isActive = false
            }
        }
        .onAppear {
            updateAnnotationSourceItems()
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
                updateAnnotationSourceItems()
            }
        }
        refreshWorkItem = workItem

        // Schedule the new timer
        DispatchQueue.main.asyncAfter(deadline: .now() + pageRefreshInterval, execute: workItem)
        }

        // Update the annotation source item list based on the active layers.
        private func updateAnnotationSourceItems() {

        annotationSourceItems.removeAll()

        if mapSettingsViewModel.activeLayers.contains(.sites) {
                let filteredSites = sitesViewModel.sites.filter { $0.siteType == "Mountain" || $0.siteType == "Soaring" }
            for site in filteredSites {
                if let lat = Double(site.siteLat), let lon = Double(site.siteLon) {
                let annotationSourceItem = AnnotationSourceItem(
                        annotationType: "site",
                        annotationID: site.siteName,
                        annotationName: site.siteName,
                        coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        altitude: Double((site.readingsAlt.replacingOccurrences(of: ",", with: ""))) ?? 0.0,
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
                    annotationSourceItems.append(annotationSourceItem)
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
                        let annotationSourceItem = AnnotationSourceItem(
                            annotationType: "station",
                            annotationID: reading.stationID,
                            annotationName: reading.stationName,
                            coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            altitude: Double((reading.stationElevation.replacingOccurrences(of: ",", with: ""))) ?? 0.0,
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
                        annotationSourceItems.append(annotationSourceItem)
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
                    let annotationSourceItem = AnnotationSourceItem(
                        annotationType: "pilot",
                        annotationID: trackNode.pilotName,
                        annotationName: trackNode.pilotName,
                        coordinates: CLLocationCoordinate2D(latitude: trackNode.coordinates.latitude, longitude: trackNode.coordinates.longitude),
                        altitude: trackNode.altitude,
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
                    annotationSourceItems.append(annotationSourceItem)
                }
            }
        }
    }

    private func startMonitoringRegion() {
        Timer.scheduledTimer(withTimeInterval: mapBatchProcessingInterval, repeats: true) { _ in
            let currentSpan = region.span
            if hasRegionSpanChanged(from: lastRegionSpan, to: currentSpan) {
                lastRegionSpan = currentSpan
                viewModel.updateClusters(regionSpan: currentSpan)
            }
        }
    }

    private func hasRegionSpanChanged(from oldSpan: MKCoordinateSpan, to newSpan: MKCoordinateSpan) -> Bool {
        return abs(oldSpan.latitudeDelta - newSpan.latitudeDelta) > mapScaleChangeTolerance ||
            abs(oldSpan.longitudeDelta - newSpan.longitudeDelta) > mapScaleChangeTolerance
    }
}
*/
