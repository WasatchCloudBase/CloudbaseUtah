import SwiftUI
import SwiftData

@main
struct CloudbaseUtah: App {
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
        showSites: false,
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
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    refreshMetadata = true
                }
        }
    }
}
