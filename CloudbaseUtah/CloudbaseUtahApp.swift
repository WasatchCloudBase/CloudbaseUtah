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
        activeLayers: [.sites, .pilots],
//        activeLayers: [.stations, .sites],
        selectedMapType: .standard,
    )
    
    var body: some Scene {
        WindowGroup {
            
            // Call app base view and track flag for requests to refresh metadata
            BaseAppView(refreshMetadata: $refreshMetadata)

            // Establish metadata and map setting view models
            .environmentObject(liftParametersViewModel)
            .environmentObject(weatherCodesViewModel)
            .environmentObject(sunriseSunsetViewModel)
            .environmentObject(sitesViewModel)
            .environmentObject(pilotsViewModel)
            .environmentObject(mapSettingsViewModel)
            
            // Force dark mode and black background
            .environment(\.colorScheme, .dark)
        
            // Initial load of metadata
            .onAppear {
                liftParametersViewModel.getLiftParameters()
                weatherCodesViewModel.getWeatherCodes()
                sunriseSunsetViewModel.getSunriseSunset()
                sitesViewModel.getSites()
                pilotsViewModel.getPilots()
                initializeLoggingFile()
            }

            // Reload metadata when refresh requested
            .onChange(of: refreshMetadata) { _, newValue in
                if newValue {
                    liftParametersViewModel.getLiftParameters()
                    weatherCodesViewModel.getWeatherCodes()
                    sunriseSunsetViewModel.getSunriseSunset()
                    sitesViewModel.getSites()
                    pilotsViewModel.getPilots()
                    refreshMetadata = false
                }
            }
        
            // Check for date changes to force base view to reapper (reloading matadata)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                refreshMetadata = true
            }
        
        }
    }
}
