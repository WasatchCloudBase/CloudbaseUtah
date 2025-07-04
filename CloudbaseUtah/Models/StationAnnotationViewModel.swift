import SwiftUI
import Combine
import MapKit

// Full listing of station latest readings used as the source for creating map annotations
// Created based on active layers and refreshed on app navigation or elapsed time
struct StationAnnotation: Identifiable {
    let id = UUID()
    let annotationID: String
    let annotationName: String
    let coordinate: CLLocationCoordinate2D
    let altitude: Double
    let readingsSource: String
    let windSpeed: Double?
    let windDirection: Double?
    let windGust: Double?
}

class WeatherStationAnnotation: NSObject, MKAnnotation, Identifiable {
  let coordinate: CLLocationCoordinate2D
  let title: String?
  let windSpeed: Double?
  let windDirection: Double?
  
  init(lat: Double, lon: Double, name: String, speed: Double?, direction: Double?) {
    self.coordinate    = CLLocationCoordinate2D(latitude: lat,
                                                longitude: lon)
    self.title         = name
    self.windSpeed     = speed
    self.windDirection = direction
  }
}

class StationAnnotationViewModel: ObservableObject {
    @Published var stationAnnotations: [StationAnnotation] = []
    @Published var clusteredStationAnnotations: [StationAnnotation] = []
    private var cancellables = Set<AnyCancellable>()
    
    var mapSettingsViewModel: MapSettingsViewModel
    var siteViewModel: SiteViewModel
    var stationLatestReadingViewModel: StationLatestReadingViewModel

    init(
        mapSettingsViewModel: MapSettingsViewModel,
        siteViewModel: SiteViewModel,
        stationLatestReadingViewModel: StationLatestReadingViewModel
    ) {
        self.mapSettingsViewModel = mapSettingsViewModel
        self.siteViewModel = siteViewModel
        self.stationLatestReadingViewModel = stationLatestReadingViewModel
    }

    
    // Update the annotation source item list based on the active layers.
    func updateStationAnnotations(completion: @escaping () -> Void) {
        
        // Remove all existing station annotations before starting parallel/async processing
        stationAnnotations = []

        // Define dispatch group for async/parallel processing, and will be used later to ensure all have completed
        let stationAnnotationsGroup = DispatchGroup()
        
        if mapSettingsViewModel.isMapDisplayingStations {
            stationAnnotationsGroup.enter()
            
            // Define another dispatch group for to ensure station annotations aren't added until prior calls complete
            let readingsGroup = DispatchGroup()
            readingsGroup.enter()
            stationLatestReadingViewModel.getLatestReadingsData(sitesOnly: false) {
                readingsGroup.leave()
            }

            // When all CUASA readings are received, update annotations
            readingsGroup.notify(queue: .main) { [self] in
                // Create annotations for each latest reading
                for reading in stationLatestReadingViewModel.latestAllReadings {
                    if let lat = Double(reading.stationLatitude), let lon = Double(reading.stationLongitude) {
                        let stationAnnotation = StationAnnotation(
                            annotationID: reading.stationID,
                            annotationName: reading.stationName,
                            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            altitude: Double((reading.stationElevation.replacingOccurrences(of: ",", with: ""))) ?? 0.0,
                            readingsSource: reading.readingsSource,
                            windSpeed: reading.windSpeed,
                            windDirection: reading.windDirection,
                            windGust: reading.windGust
                        )
                        stationAnnotations.append(stationAnnotation)
                    }
                }
                stationAnnotationsGroup.leave()
            }
        }
        
        if mapSettingsViewModel.isMapTrackingMode {
            // Do nothing; pilot tracks handled separately
        }
        
        stationAnnotationsGroup.notify(queue: .main) {
            completion()
        }
    }
    
    func clusterStationAnnotations(regionSpan: MKCoordinateSpan) {
        let threshold = max(regionSpan.latitudeDelta, regionSpan.longitudeDelta)
                      * mapClusterThresholdFactor
        clusteredStationAnnotations = []

        // Split out CUASA stations so that filtering will prioritize CUASA stations
        // e.g., we want to see the Cove launch CUASA reading over the Mesonet Signal Peak reading
        let cuasaStations = stationAnnotations.filter { $0.readingsSource == "CUASA" }
        let otherStations = stationAnnotations.filter { $0.readingsSource != "CUASA" }

        // Concatenate so CUASA ones get considered first
        let orderedStations = cuasaStations + otherStations

        // Standard clustering loop on the ordered list
        for station in orderedStations {
            // only compare against already‐accepted (clustered) stations
            let isFarEnough = clusteredStationAnnotations.allSatisfy { existing in
                let dLat = existing.coordinate.latitude  - station.coordinate.latitude
                let dLon = existing.coordinate.longitude - station.coordinate.longitude
                let distance = sqrt(dLat * dLat + dLon * dLon)
                return distance > threshold
            }

            if isFarEnough {
                clusteredStationAnnotations.append(station)
            }
        }
    }
}
