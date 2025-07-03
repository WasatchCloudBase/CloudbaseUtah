import SwiftUI
import MapKit

// Use different time/date change events based on platform
#if os(iOS)
import UIKit
let timeChangeNotification = UIApplication.significantTimeChangeNotification
#elseif os(macOS)
import AppKit
let timeChangeNotification = NSWorkspace.dayDidChangeNotification
#endif

@main
struct CloudbaseUtahApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshMetadata: Bool = false
    @StateObject private var liftParametersViewModel = LiftParametersViewModel()
    @StateObject private var sunriseSunsetViewModel = SunriseSunsetViewModel()
    @StateObject private var weatherCodesViewModel = WeatherCodesViewModel()
    @StateObject private var sitesViewModel = SitesViewModel()
    @StateObject private var pilotsViewModel = PilotsViewModel()
    @StateObject private var stationLatestReadingsViewModel: StationLatestReadingsViewModel
    @StateObject private var mapSettingsViewModel = MapSettingsViewModel(
        region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: mapInitLatitude, longitude: mapInitLongitude),
            span: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan)
        ),
        selectedMapType: defaultmapType,
        pilotTrackDays: defaultPilotTrackDays,
        mapDisplayMode: defaultmapDisplayMode,
        showSites: defaultShowSites,
        showStations: defaultShowStations
    )
    
    init() {
        // Create each view‐model in the proper order, using locals:
        let liftVM     = LiftParametersViewModel()
        let sunVM      = SunriseSunsetViewModel()
        let weatherVM  = WeatherCodesViewModel()
        let sitesVM    = SitesViewModel()
        let pilotsVM   = PilotsViewModel()
        let stationsVM = StationLatestReadingsViewModel(sitesViewModel: sitesVM)
        let mapVM      = MapSettingsViewModel(
            region: MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: mapInitLatitude,
                    longitude: mapInitLongitude
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: mapInitLatitudeSpan,
                    longitudeDelta: mapInitLongitudeSpan
                )
            ),
            selectedMapType: defaultmapType,
            pilotTrackDays: defaultPilotTrackDays,
            mapDisplayMode: defaultmapDisplayMode,
            showSites: defaultShowSites,
            showStations: defaultShowStations
        )
        
        // Wire them up into their @StateObject wrappers:
        _liftParametersViewModel      = StateObject(wrappedValue: liftVM)
        _sunriseSunsetViewModel       = StateObject(wrappedValue: sunVM)
        _weatherCodesViewModel        = StateObject(wrappedValue: weatherVM)
        _sitesViewModel               = StateObject(wrappedValue: sitesVM)
        _pilotsViewModel              = StateObject(wrappedValue: pilotsVM)
        _stationLatestReadingsViewModel = StateObject(wrappedValue: stationsVM)
        _mapSettingsViewModel         = StateObject(wrappedValue: mapVM)
    }

    var body: some Scene {
        WindowGroup {
            BaseAppView(refreshMetadata: $refreshMetadata)
                .environmentObject(liftParametersViewModel)
                .environmentObject(weatherCodesViewModel)
                .environmentObject(sunriseSunsetViewModel)
                .environmentObject(sitesViewModel)
                .environmentObject(pilotsViewModel)
                .environmentObject(stationLatestReadingsViewModel)
                .environmentObject(mapSettingsViewModel)
                .environment(\.colorScheme, .dark)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    refreshMetadata = true
                }
        }
    }
}


struct BaseAppView: View {
    @Binding var refreshMetadata: Bool
    @State private var isActive = false
    @State private var metadataLoaded = false
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodesViewModel
    @EnvironmentObject var pilotsViewModel: PilotsViewModel
    @EnvironmentObject var sitesViewModel: SitesViewModel
    @EnvironmentObject var stationLatestReadingsViewModel: StationLatestReadingsViewModel

    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            VStack {
                if isActive && metadataLoaded {
                    MainView(refreshMetadata: $refreshMetadata)
                        .preferredColorScheme(.dark)
                } else {
                    SplashScreenView()
                        .preferredColorScheme(.dark)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                checkIfReadyToTransition()
                            }
                        }
                }
            }
        }
        .onAppear {
            loadInitialMetadata()

        }
        .onChange(of: refreshMetadata) { oldValue, newValue in
            if newValue {
                isActive = false
                metadataLoaded = false
                loadInitialMetadata()
                refreshMetadata = false
            }
        }
    }

    private func loadInitialMetadata() {
        let group = DispatchGroup()
        group.enter()
        liftParametersViewModel.getLiftParameters {
            group.leave()
        }
        group.enter()
        weatherCodesViewModel.getWeatherCodes {
            group.leave()
        }
        group.enter()
        sunriseSunsetViewModel.getSunriseSunset {
            group.leave()
        }
        group.enter()
        sitesViewModel.getSites {
            group.leave()
        }
        group.enter()
        pilotsViewModel.getPilots {
            group.leave()
        }
        initializeLoggingFile()
        group.notify(queue: .main) {
            stationLatestReadingsViewModel.getLatestReadingsData(sitesOnly: true) {
                metadataLoaded = true
                checkIfReadyToTransition()
            }
        }
    }

    private func checkIfReadyToTransition() {
        if metadataLoaded {
            withAnimation {
                isActive = true
            }
        }
    }
}

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            VStack {
                Image("UtahPGicon")
                    .resizable()
                    .scaledToFit()
                Text("Cloudbase Utah")
                    .bold()
                    .foregroundColor(titleFontColor)
                    .padding(.top, 2)
            }
        }
    }
}
