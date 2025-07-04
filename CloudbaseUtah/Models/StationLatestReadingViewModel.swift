import SwiftUI
import Combine

struct StationLatestReading: Identifiable {
    let id = UUID()
    let stationID: String
    let stationName: String
    let readingsSource: String
    let stationElevation: String
    let stationLatitude: String
    let stationLongitude: String
    let windSpeed: Double?
    let windDirection: Double?
    let windGust: Double?
    let windTime: String?
}

// Structures to parse Mesonet latest readings data
struct MesonetLatestResponse: Codable {
    let station: [MesonetLatestStation]
    
    enum CodingKeys: String, CodingKey {
        case station = "STATION"
    }
}

struct MesonetLatestStation: Codable {
    let id: String
    let stationID: String
    let stationName: String
    let elevation: String
    let latitude: String
    let longitude: String
    let status: String
    let observations: MesonetLatestObservations
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case stationID = "STID"
        case stationName = "NAME"
        case elevation = "ELEVATION"
        case latitude = "LATITUDE"
        case longitude = "LONGITUDE"
        case status = "STATUS"
        case observations = "OBSERVATIONS"
    }
}
struct MesonetLatestObservations: Codable {
    let airTemp: MesonetLatestObservationsValues?
    let windSpeed: MesonetLatestObservationsValues?
    let windDirection: MesonetLatestObservationsValues?
    let windGust: MesonetLatestObservationsValues?
    
    enum CodingKeys: String, CodingKey {
        case airTemp = "air_temp_value_1"
        case windSpeed = "wind_speed_value_1"
        case windDirection = "wind_direction_value_1"
        case windGust = "wind_gust_value_1"
    }
}
struct MesonetLatestObservationsValues: Codable {
    let value: Double?
    let dateTime: String?
    
    enum CodingKeys: String, CodingKey {
        case value
        case dateTime = "date_time"
    }
}

struct CUASAStationData: Codable {
    var id: Int
    var name: String
    var lat: Double
    var lon: Double
}

struct CUASAReadingsData: Codable {
    var ID: String
    var timestamp: Double
    var windspeed: Double
    var windspeed_avg: Double
    var windspeed_max: Double
    var windspeed_min: Double
    var wind_direction: Double
    var wind_direction_avg: Double
    var battery_level: Double?
    var internal_temp: Double?
    var external_temp: Double?
    var current: Double?
    var pwm: Double?
}

class StationLatestReadingViewModel: ObservableObject {
    @Published var latestSiteReadings: [StationLatestReading] = []
    @Published var latestAllReadings: [StationLatestReading] = []
    @Published var stationParameters: String = ""
    @Published var isLoading = false
    
    private var lastSiteFetchTime: Date? = nil
    private var lastAllFetchTime: Date? = nil

    let siteViewModel: SiteViewModel
    
    // sites available in this view model
    init(siteViewModel: SiteViewModel) {
        self.siteViewModel = siteViewModel
        
        let mesonetStations = siteViewModel.sites.filter {
            $0.readingsSource == "Mesonet" && !$0.readingsStation.isEmpty
        }
        guard !mesonetStations.isEmpty else { return }
        
        self.stationParameters = mesonetStations.map { "&stid=\($0.readingsStation)" }.joined()
        
        // Only fetch site readings at init
        self.getLatestReadingsData(sitesOnly: true) {}
    }
    
    // sitesOnly determines whether to only get Mesonet readings for stations associated with sites (SiteView)
    // or all stations in Utah (MapView)
    // These are published as separate structures with separate refresh timers
    func getLatestReadingsData(sitesOnly: Bool, completion: @escaping () -> Void) {
        let now = Date()
        
        // Pick the correct last fetch timestamp
        let lastFetchTime = sitesOnly ? lastSiteFetchTime : lastAllFetchTime
        if let last = lastFetchTime, now.timeIntervalSince(last) < readingsRefreshInterval {
            completion()
            return
        }

        if sitesOnly {
            lastSiteFetchTime = now
        } else {
            lastAllFetchTime = now
        }

        isLoading = true
        var combinedReadings: [StationLatestReading] = []
        let group = DispatchGroup()

        group.enter()
        let stationParams = sitesOnly ? self.stationParameters : ""
        self.getLatestMesonetReadings(stationParameters: stationParams) { mesonetReadings in
            combinedReadings.append(contentsOf: mesonetReadings)
            group.leave()
        }

        group.enter()
        self.getLatestCUASAReadings { cuasaReadings in
            combinedReadings.append(contentsOf: cuasaReadings)
            group.leave()
        }

        group.notify(queue: .main) {
            if sitesOnly {
                self.latestSiteReadings = combinedReadings
            } else {
                self.latestAllReadings = combinedReadings
            }
            self.isLoading = false
            completion()
        }
    }
    
    func getLatestMesonetReadings(stationParameters: String, completion: @escaping ([StationLatestReading]) -> Void) {
        let urlString = latestReadingsAPIHeader + stationParameters + latestReadingsAPITrailer + mesowestAPIToken
        guard let url = URL(string: urlString) else { return }
        if printReadingsURL { print(url) }
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else { return }
                do {
                    let decodedResponse = try JSONDecoder().decode(MesonetLatestResponse.self, from: data)
                    let latestReadings: [StationLatestReading] = decodedResponse.station.compactMap { station in
                        guard let _ = station.observations.windSpeed?.value,
                              let _ = station.observations.windSpeed?.dateTime
                        else { return nil }
                        return StationLatestReading(
                            stationID: station.stationID,
                            stationName: station.stationName,
                            readingsSource: "Mesonet",
                            stationElevation: station.elevation,
                            stationLatitude: station.latitude,
                            stationLongitude: station.longitude,
                            windSpeed: station.observations.windSpeed?.value,
                            windDirection: station.observations.windDirection?.value,
                            windGust: station.observations.windGust?.value,
                            windTime: station.observations.windSpeed?.dateTime
                        )
                    }
                    DispatchQueue.main.async {
                        completion(latestReadings)
                    }
                } catch {
                    print("Failed to decode JSON: \(error)")
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            }
        }.resume()
    }

    func getLatestCUASAReadings(completion: @escaping ([StationLatestReading]) -> Void) {
        let CUASAStations = Array(
            Dictionary(grouping: siteViewModel.sites.filter { $0.readingsSource == "CUASA" }, by: { $0.readingsStation })
                .compactMap { $0.value.first }
        )
        guard !CUASAStations.isEmpty else {
            print("CUASA stations are empty")
            completion([])
            return
        }

        var collectedReadings: [StationLatestReading] = []
        let group = DispatchGroup()

        let readingInterval: Double = 5 * 60
        let readingEnd = Date().timeIntervalSince1970
        let readingStart = readingEnd - readingInterval

        for station in CUASAStations {
            group.enter()
            let stationURLString = "https://sierragliding.us/api/station/" + station.readingsStation
            guard let stationInfoURL = URL(string: stationURLString) else {
                group.leave()
                continue
            }

            URLSession.shared.dataTask(with: stationInfoURL) { data, response, error in
                guard let data = data, error == nil else {
                    DispatchQueue.main.async { group.leave() }
                    return
                }

                do {
                    let CUASAStationInfo = try JSONDecoder().decode(CUASAStationData.self, from: data)

                    let urlString = "https://sierragliding.us/api/station/" + station.readingsStation + "/data?start=\(readingStart)&end=\(readingEnd)&sample=\(readingInterval)"
                    guard let readingsURL = URL(string: urlString) else {
                        DispatchQueue.main.async { group.leave() }
                        return
                    }

                    if printReadingsURL { print(readingsURL) }

                    URLSession.shared.dataTask(with: readingsURL) { data, response, error in
                        DispatchQueue.main.async {
                            defer { group.leave() }
                            guard let data = data, error == nil else { return }

                            do {
                                let readingsDataArray = try JSONDecoder().decode([CUASAReadingsData].self, from: data)
                                if let latestData = readingsDataArray.max(by: { $0.timestamp < $1.timestamp }) {
                                    let date = Date(timeIntervalSince1970: latestData.timestamp)
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "h:mm"
                                    let formattedTime = formatter.string(from: date)

                                    let newReading = StationLatestReading(
                                        stationID: latestData.ID,
                                        stationName: CUASAStationInfo.name,
                                        readingsSource: "CUASA",
                                        stationElevation: station.readingsAlt,
                                        stationLatitude: String(CUASAStationInfo.lat),
                                        stationLongitude: String(CUASAStationInfo.lon),
                                        windSpeed: convertKMToMiles(latestData.windspeed_avg).rounded(),
                                        windDirection: latestData.wind_direction_avg,
                                        windGust: convertKMToMiles(latestData.windspeed_max).rounded(),
                                        windTime: formattedTime
                                    )

                                    collectedReadings.append(newReading)  // Add to local array
                                }
                            } catch {
                                print("Error decoding CUASA readings: \(error)")
                            }
                        }
                    }.resume()
                } catch {
                    print("CUASA station info decoding error: \(error)")
                    DispatchQueue.main.async { group.leave() }
                }
            }.resume()
        }

        group.notify(queue: .main) {
            completion(collectedReadings)  // Return combined array
        }
    }
}
