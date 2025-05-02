import SwiftUI

@main
struct CloudbaseUtahApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshMetadata: Bool = false
    @StateObject private var liftParametersViewModel = LiftParametersViewModel()
    @StateObject private var sunriseSunsetViewModel = SunriseSunsetViewModel()
    @StateObject private var weatherCodesViewModel = WeatherCodesViewModel()
    @StateObject private var sitesViewModel = SitesViewModel()
    
    var body: some Scene {
        WindowGroup {
            
            // Call app base view and track flag for requests to refresh metadata
            BaseAppView(refreshMetadata: $refreshMetadata)

            // Force dark mode
            .environment(\.colorScheme, .dark)

            // Establish metadata view models
            .environmentObject(liftParametersViewModel)
            .environmentObject(weatherCodesViewModel)
            .environmentObject(sunriseSunsetViewModel)
            .environmentObject(sitesViewModel)
        
            // Initial load of metadata
            .onAppear {
                liftParametersViewModel.getLiftParameters()
                weatherCodesViewModel.getWeatherCodes()
                sunriseSunsetViewModel.getSunriseSunset()
                sitesViewModel.getSites()
                initializeLoggingFile()
            }

            // Reload metadata when refresh requested
            .onChange(of: refreshMetadata) { _, newValue in
                if newValue {
                    liftParametersViewModel.getLiftParameters()
                    weatherCodesViewModel.getWeatherCodes()
                    sunriseSunsetViewModel.getSunriseSunset()
                    sitesViewModel.getSites()
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
