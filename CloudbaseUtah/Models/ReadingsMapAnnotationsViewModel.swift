import SwiftUI
import Combine
import MapKit

// Full listing of items used as the source for creating map annotations
// Created based on active layers and refreshed on app navigation or elapsed time
struct ReadingsMapAnnotations: Identifiable {
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

class ReadingsMapAnnotationsViewModel: ObservableObject {
    @Published var readingsMapAnnotations: [ReadingsMapAnnotations] = []
    @Published var clusteredReadingsMapAnnotations: [ReadingsMapAnnotations] = []
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
    func updateReadingsMapAnnotations(completion: @escaping () -> Void) {
        
        // Remove all existing readingsMapAnnotations before starting parallel/async processing
        readingsMapAnnotations = []

        // Define dispatch group for async/parallel processing, and will be used later to ensure all have completed
        let readingsMapAnnotionsGroup = DispatchGroup()
        
        // Process sites (synchronous)
        if mapSettingsViewModel.isMapDisplayingSites {
            
            let filteredSites = sitesViewModel.sites.filter { $0.siteType == "Mountain" || $0.siteType == "Soaring" }
            for site in filteredSites {
                if let lat = Double(site.siteLat), let lon = Double(site.siteLon) {
                let readingsMapAnnotation = ReadingsMapAnnotations(
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
                    readingsMapAnnotations.append(readingsMapAnnotation)
                }
            }
        }
        
        if mapSettingsViewModel.isMapDisplayingStations {
            readingsMapAnnotionsGroup.enter()
            
            // Define another dispatch group for to ensure station annotations aren't added until prior calls complete
            let readingsGroup = DispatchGroup()
            readingsGroup.enter()
            stationLatestReadingsViewModel.getLatestReadingsData(sitesOnly: false) {
                readingsGroup.leave()
            }

            // When all CUASA readings are received, update annotations
            readingsGroup.notify(queue: .main) { [self] in
                // Create annotations for each latest reading
                for reading in stationLatestReadingsViewModel.latestAllReadings {
                    if let lat = Double(reading.stationLatitude), let lon = Double(reading.stationLongitude) {
                        let readingsMapAnnotation = ReadingsMapAnnotations(
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
                        readingsMapAnnotations.append(readingsMapAnnotation)
                    }
                }
                readingsMapAnnotionsGroup.leave()
            }
        }
        
        if mapSettingsViewModel.isMapTrackingMode {
            // Do nothing; pilot tracks handled separately
        }
        
        readingsMapAnnotionsGroup.notify(queue: .main) {
            completion()
        }
    }
    
    func clusterReadingsMapAnnotations(regionSpan: MKCoordinateSpan) {
        let threshold = max(regionSpan.latitudeDelta, regionSpan.longitudeDelta)
                      * mapClusterThresholdFactor
        clusteredReadingsMapAnnotations = []

        for newAnn in readingsMapAnnotations {
            if newAnn.annotationType == "station" {
                // Get only what we've already accepted
                let clusteredStations = clusteredReadingsMapAnnotations
                                       .filter { $0.annotationType == "station" }

                // Compare each existing station's coords against the candidate's coords
                let isFarEnough = clusteredStations.allSatisfy { existing in
                    let dLat = existing.coordinates.latitude
                             - newAnn.coordinates.latitude
                    let dLon = existing.coordinates.longitude
                             - newAnn.coordinates.longitude
                    let distance = sqrt(dLat * dLat + dLon * dLon)
                    return distance > threshold
                }

                if isFarEnough {
                    clusteredReadingsMapAnnotations.append(newAnn)
                }
            } else {
                // non-stations always get included
                clusteredReadingsMapAnnotations.append(newAnn)
            }
        }
    }
}
