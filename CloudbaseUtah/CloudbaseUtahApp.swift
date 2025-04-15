//  CloudbaseUtahApp.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/6/25.

import SwiftUI

@main
struct CloudbaseUtahApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()
    @StateObject private var liftParametersViewModel = LiftParametersViewModel()
    @StateObject private var sunriseSunsetViewModel = SunriseSunsetViewModel()
    @StateObject private var weatherCodesViewModel = WeatherCodesViewModel()
    var body: some Scene {
        WindowGroup {
            
            BaseAppView()
            
                // Force dark mode
                .environment(\.colorScheme, .dark)

                // Load thermal lift parameters
                .environmentObject(liftParametersViewModel)
                .onAppear {
                    liftParametersViewModel.fetchLiftParameters()
                }
            
                // Load weather codes
                .environmentObject(weatherCodesViewModel)
                .onAppear {
                    weatherCodesViewModel.fetchWeatherCodes()
                }
            
                // Load sunrise / sunset times
                .environmentObject(sunriseSunsetViewModel)
                .onAppear {
                    sunriseSunsetViewModel.fetchSunriseSunset()
                }

                // Reset logging file
                .onAppear {
                    initializeLoggingFile()
                }
            
                // Check for date changes to force app reload
                .environmentObject(appState)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    appState.reload()
                }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { appState.reload() }
        }
    }
}

// Reload app when date changes
class AppState: ObservableObject {
    @Published var lastUpdated: Date = Date()
    func reload() {
        // Implement your reload logic here
        lastUpdated = Date()
        print("App reloaded at \(lastUpdated)")
    }
}
