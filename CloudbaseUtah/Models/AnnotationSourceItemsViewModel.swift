import SwiftUI
import Combine
import MapKit

// Full listing of items used as the source for creating map annotations
// Created based on active layers and refreshed on app navigation or elapsed time
struct AnnotationSourceItem: Identifiable {
    let id = UUID()
    let annotationType: String              // e.g., "site" or "station"
    let annotationID: String                // an identifier based on the type
    let annotationName: String
    let coordinates: CLLocationCoordinate2D
    let altitude: Double
    let readingsNote: String                // For site annotations
    let forecastNote: String
    let siteType: String                    // For site annotations
    let readingsStation: String             // For site annotations
    let readingsSource: String
    let windSpeed: Double?                  // For station annotations
    let windDirection: Double?
    let windGust: Double?
}

class AnnotationSourceItemsViewModel: ObservableObject {
    @Published var annotationSourceItems: [AnnotationSourceItem] = []
    @Published var clusteredAnnotationSourceItems: [AnnotationSourceItem] = []
    private var cancellables = Set<AnyCancellable>()
    
    var mapSettingsViewModel: MapSettingsViewModel
    var sitesViewModel: SitesViewModel
    var stationLatestReadingsViewModel: StationLatestReadingsViewModel

    init(
        mapSettingsViewModel: MapSettingsViewModel,
        sitesViewModel: SitesViewModel,
        stationLatestReadingsViewModel: StationLatestReadingsViewModel
    ) {
        self.mapSettingsViewModel = mapSettingsViewModel
        self.sitesViewModel = sitesViewModel
        self.stationLatestReadingsViewModel = stationLatestReadingsViewModel
    }

    
    // Update the annotation source item list based on the active layers.
    func updateAnnotationSourceItems(completion: @escaping () -> Void) {

        // Remove all existing annotationSourceItems before starting parallel/async processing
        annotationSourceItems = []

        // Define dispatch group for async/parallel processing, and will be used later to ensure all have completed
        let annotationSourceItemGroup = DispatchGroup()
        
        // Process sites (synchronous)
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
                        windGust: 0.0
                    )
                    annotationSourceItems.append(annotationSourceItem)
                }
            }
        }
        
        if mapSettingsViewModel.activeLayers.contains(.stations) {
            
            annotationSourceItemGroup.enter()
            
            // Define another dispatch group for to ensure station annotations aren't added until prior calls complete
            let readingsGroup = DispatchGroup()
            readingsGroup.enter()
            stationLatestReadingsViewModel.getLatestMesonetReadings(stationParameters: "") { [self] in
                stationLatestReadingsViewModel.getLatestCUASAReadings() {
                    readingsGroup.leave()
                }
            }

            // When all CUASA readings are received, update annotations
            readingsGroup.notify(queue: .main) { [self] in
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
                            windGust: reading.windGust
                        )
                        annotationSourceItems.append(annotationSourceItem)
                    }
                }
                annotationSourceItemGroup.leave()
            }
        }
        
        if mapSettingsViewModel.activeLayers.contains(.pilots){
            // Do nothing; pilot tracks handled separately
        }
        
        annotationSourceItemGroup.notify(queue: .main) {
            completion()
        }
    }
    
    func clusterAnnotationSourceItems(regionSpan: MKCoordinateSpan) {
        let thresholdDistance = max(regionSpan.latitudeDelta, regionSpan.longitudeDelta) * mapClusterThresholdFactor
        clusteredAnnotationSourceItems = []

        for annotationSourceItem in annotationSourceItems {
            if annotationSourceItem.annotationType == "station" {
                // Only compare against already-clustered stations
                let clusteredStations = clusteredAnnotationSourceItems.filter { $0.annotationType == "station" }
                if clusteredStations.allSatisfy({ existingAnnotationSourceItem in
                    let distance = sqrt(
                        pow(annotationSourceItem.coordinates.latitude - existingAnnotationSourceItem.coordinates.latitude, 2) +
                        pow(annotationSourceItem.coordinates.longitude - existingAnnotationSourceItem.coordinates.longitude, 2)
                    )
                    return distance > thresholdDistance
                }) {
                    clusteredAnnotationSourceItems.append(annotationSourceItem)
                }
            } else {
                // For others (sites, pilots, etc.), append without clustering
                clusteredAnnotationSourceItems.append(annotationSourceItem)
            }
        }
    }
    
}
