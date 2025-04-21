//  CloudbaseUtahApp.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/6/25.

import SwiftUI

@main
struct CloudbaseUtahApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshMetadata: Bool = false
    @StateObject private var liftParametersViewModel = LiftParametersViewModel()
    @StateObject private var sunriseSunsetViewModel = SunriseSunsetViewModel()
    @StateObject private var weatherCodesViewModel = WeatherCodesViewModel()
    var body: some Scene {
        WindowGroup {
            
            // Call app base view and pass refresh ID
            BaseAppView(refreshMetadata: $refreshMetadata)

                // Force dark mode
                .environment(\.colorScheme, .dark)

                // Establish metadata view models
                .environmentObject(liftParametersViewModel)
                .environmentObject(weatherCodesViewModel)
                .environmentObject(sunriseSunsetViewModel)
            
                // Initial load of metadata
                .onAppear {
                    liftParametersViewModel.fetchLiftParameters()
                    weatherCodesViewModel.fetchWeatherCodes()
                    sunriseSunsetViewModel.fetchSunriseSunset()
                    initializeLoggingFile()
                    logRefresh()
                }

                // Reload metadata when refresh requested
                .onChange(of: refreshMetadata) { newValue in
                    if newValue {
                        liftParametersViewModel.fetchLiftParameters()
                        weatherCodesViewModel.fetchWeatherCodes()
                        sunriseSunsetViewModel.fetchSunriseSunset()
                        logRefresh()
                        refreshMetadata = false
                    }
                }
            
                // Check for date changes to force base view to reapper (reloading matadata)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    refreshMetadata = true
                }
            
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                // TBD what should be reloaded on change between active, background, and inactive
            }
        }
    }
}

// Log when app refreshes metadata
func logRefresh() {
    let lastUpdated = Date()
}
