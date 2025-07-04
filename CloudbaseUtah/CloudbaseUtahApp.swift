import SwiftUI
import MapKit
import UIKit
let timeChangeNotification = UIApplication.significantTimeChangeNotification

@main
struct CloudbaseUtahApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshMetadata: Bool = false
    @StateObject private var liftParametersViewModel = LiftParametersViewModel()
    @StateObject private var sunriseSunsetViewModel = SunriseSunsetViewModel()
    @StateObject private var weatherCodesViewModel = WeatherCodeViewModel()
    @StateObject private var siteViewModel = SiteViewModel()
    @StateObject private var pilotViewModel = PilotViewModel()
    @StateObject private var stationLatestReadingViewModel: StationLatestReadingViewModel
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
        let weatherVM  = WeatherCodeViewModel()
        let sitesVM    = SiteViewModel()
        let pilotsVM   = PilotViewModel()
        let stationsVM = StationLatestReadingViewModel(siteViewModel: sitesVM)
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
        _siteViewModel               = StateObject(wrappedValue: sitesVM)
        _pilotViewModel              = StateObject(wrappedValue: pilotsVM)
        _stationLatestReadingViewModel = StateObject(wrappedValue: stationsVM)
        _mapSettingsViewModel         = StateObject(wrappedValue: mapVM)
    }

    var body: some Scene {
        WindowGroup {
            BaseAppView(refreshMetadata: $refreshMetadata)
                .environmentObject(liftParametersViewModel)
                .environmentObject(weatherCodesViewModel)
                .environmentObject(sunriseSunsetViewModel)
                .environmentObject(siteViewModel)
                .environmentObject(pilotViewModel)
                .environmentObject(stationLatestReadingViewModel)
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
    @EnvironmentObject var weatherCodesViewModel: WeatherCodeViewModel
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @EnvironmentObject var siteViewModel: SiteViewModel
    @EnvironmentObject var stationLatestReadingViewModel: StationLatestReadingViewModel

    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            VStack {
                if isActive && metadataLoaded {
                    MainView(refreshMetadata: $refreshMetadata)
                } else {
                    SplashScreenView()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
        siteViewModel.getSites {
            group.leave()
        }
        group.enter()
        pilotViewModel.getPilots {
            group.leave()
        }
        initializeLoggingFile()
        group.notify(queue: .main) {
            stationLatestReadingViewModel.getLatestReadingsData(sitesOnly: true) {
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
