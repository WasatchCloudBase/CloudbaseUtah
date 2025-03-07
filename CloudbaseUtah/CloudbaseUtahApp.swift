//
//  CloudbaseUtahApp.swift
//  CloudbaseUtah
//
//  Created by Brown, Mike on 3/6/25.
//

import SwiftUI

@main
struct CloudbaseUtahApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()
    var body: some Scene {
        WindowGroup {
            
            // This is the view for the production app
            BaseAppView()
            
            // Alternate views for development utilities
            // (comment out for production)
            //UDOTCameraListView()
            
            // Check for date changes to force app reload
                .environmentObject(appState)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    appState.reload()
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                appState.reload()
            }
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
