import SwiftUI
import MapKit

@main
struct CloudbaseUtahApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshMetadata: Bool = false
    @StateObject private var liftParametersViewModel = LiftParametersViewModel()
    @StateObject private var sunriseSunsetViewModel = SunriseSunsetViewModel()
    @StateObject private var weatherCodesViewModel = WeatherCodesViewModel()
    @StateObject private var sitesViewModel = SitesViewModel()
    @StateObject private var pilotsViewModel = PilotsViewModel()
    @StateObject private var mapSettingsViewModel = MapSettingsViewModel(
        region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: mapInitLatitude, longitude: mapInitLongitude),
            span: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan)
        ),
        selectedMapType: defaultmapType,
        pilotTrackDays: defaultPilotTrackDays,
        mapDisplayMode: defaultmapDisplayMode,
        showSites: true,
        showStations: true
    )

    var body: some Scene {
        WindowGroup {
            BaseAppView(refreshMetadata: $refreshMetadata)
                .environmentObject(liftParametersViewModel)
                .environmentObject(weatherCodesViewModel)
                .environmentObject(sunriseSunsetViewModel)
                .environmentObject(sitesViewModel)
                .environmentObject(pilotsViewModel)
                .environmentObject(mapSettingsViewModel)
                .environment(\.colorScheme, .dark)
                .onAppear {
                    loadInitialMetadata()
                }
                .onChange(of: refreshMetadata) { _, newValue in
                    if newValue {
                        loadInitialMetadata()
                        refreshMetadata = false
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    refreshMetadata = true
                }
        }
    }

    private func loadInitialMetadata() {
        liftParametersViewModel.getLiftParameters() {}
        weatherCodesViewModel.getWeatherCodes() {}
        sunriseSunsetViewModel.getSunriseSunset() {}
        sitesViewModel.getSites() {}
        pilotsViewModel.getPilots() {}
        initializeLoggingFile()
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
            metadataLoaded = true
            checkIfReadyToTransition()
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
