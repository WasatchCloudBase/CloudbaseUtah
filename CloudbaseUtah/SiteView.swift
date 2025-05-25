import SwiftUI
import Combine

struct StationLatestReadings: Identifiable {
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

class StationLatestReadingsViewModel: ObservableObject {
    @Published var latestReadings: [StationLatestReadings] = []
    @Published var stationParameters: String = ""
    var sitesViewModel: SitesViewModel
    
    // sites available in this view model
    init(viewModel: SitesViewModel) {
        self.sitesViewModel = viewModel
        
        // Build list of Mesoewst stations for latest readings API call
        let mesonetStations = sitesViewModel.sites.filter { $0.readingsSource == "Mesonet" && !$0.readingsStation.isEmpty }
        guard !mesonetStations.isEmpty else {
            print ("filtered sites are empty:  none matched 'Mesonet' and had a readingsStation ")
            return
        }
        let stationParameters = mesonetStations.map { "&stid=\($0.readingsStation)" }.joined()
        
        // Get latest readings; these calls are structured to ensure Mesonet function (which resets the latest readings structure)
        // completes before CUASA function is called.  This prevents a timing issue that would clear out CUASA readings
        self.getLatestMesonetReadings(stationParameters: stationParameters) {
            self.getLatestCUASAReadings() {}
        }
    }

    func reloadLatestReadingsData() {
            self.getLatestMesonetReadings (stationParameters: self.stationParameters) {
                self.getLatestCUASAReadings() {}
            }
    }

    func getLatestMesonetReadings(stationParameters: String, completion: @escaping () -> Void) {
        let urlString = latestReadingsAPIHeader + stationParameters + latestReadingsAPITrailer + mesowestAPIToken
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            stationReadingsQueue.async {
                guard let data = data, error == nil else { return }
                do {
                    let decodedResponse = try JSONDecoder().decode(MesonetLatestResponse.self, from: data)
                    let latestReadings: [StationLatestReadings] = decodedResponse.station.compactMap { station in
                        guard let _ = station.observations.windSpeed?.value,
                              let _ = station.observations.windSpeed?.dateTime
                        else { return nil }
                        
                        return StationLatestReadings(
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
                        self.latestReadings = latestReadings
                        completion()
                    }
                } catch {
                    print("Failed to decode JSON: \(error)")
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
        }.resume()
    }

        func getLatestCUASAReadings(completion: @escaping () -> Void) {
            // Get unique list of CUASA stations
            let CUASAStations = Array(
                Dictionary(grouping: sitesViewModel.sites.filter { $0.readingsSource == "CUASA" }, by: { $0.readingsStation })
                    .compactMap { $0.value.first }
            )
            guard !CUASAStations.isEmpty else {
                print("CUASA stations are empty")
                completion() // Call completion if nothing to do
                return
            }
            
            let readingInterval: Double = 5 * 60 // 5 minutes in seconds
            let readingEnd = Date().timeIntervalSince1970 // current timestamp in seconds
            let readingStart = readingEnd - readingInterval // to ensure at least one reading is returned
            
            let group = DispatchGroup()
            
            for station in CUASAStations {
                group.enter()
                
                // Get station info (lat, lon)
                let stationURLString = "https://sierragliding.us/api/station/" + station.readingsStation
                guard let stationInfoURL = URL(string: stationURLString) else {
                    print("Could not build station data URL for station: \(station.readingsStation)")
                    group.leave()
                    continue
                }
                
                URLSession.shared.dataTask(with: stationInfoURL) { data, response, error in
                    guard let data = data, error == nil else {
                        print("Error fetching CUASA station data: \(String(describing: error))")
                        DispatchQueue.main.async { group.leave() }
                        return
                    }
                    do {
                        let decoder = JSONDecoder()
                        let CUASAStationInfo = try decoder.decode(CUASAStationData.self, from: data)
                        
                        // Get readings for station
                        let urlString = "https://sierragliding.us/api/station/" + station.readingsStation + "/data?start=" + String(readingStart) + "&end=" + String(readingEnd) + "&sample=" + String(readingInterval)
                        guard let readingsURL = URL(string: urlString) else {
                            print("Could not build readings URL for station: \(station.readingsStation)")
                            DispatchQueue.main.async { group.leave() }
                            return
                        }
                        
                        URLSession.shared.dataTask(with: readingsURL) { data, response, error in
                            DispatchQueue.main.async {
                                defer { group.leave() }
                                guard let data = data, error == nil else {
                                    print("Error fetching data: \(String(describing: error))")
                                    return
                                }
                                
                                do {
                                    let readingsDataArray = try JSONDecoder().decode([CUASAReadingsData].self, from: data)
                                    if let latestData = readingsDataArray.max(by: { $0.timestamp < $1.timestamp }) {
                                        let date = Date(timeIntervalSince1970: latestData.timestamp)
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "h:mm"
                                        let formattedTime = formatter.string(from: date)
                                        let newReading = StationLatestReadings(
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
                                        self.latestReadings.append(newReading)
                                    }
                                } catch {
                                    print("Error decoding JSON: \(error)")
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
                completion() // Called once, after all requests finish
            }
        }

}

struct SiteView: View {
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodesViewModel
    @EnvironmentObject var sitesViewModel: SitesViewModel
    @StateObject var stationLatestReadingsViewModel: StationLatestReadingsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedSite: Sites?
    @State private var isActive = false
    
    init(sitesViewModel: SitesViewModel) {
        _stationLatestReadingsViewModel = StateObject(wrappedValue: StationLatestReadingsViewModel(viewModel: sitesViewModel))
    }
    
    var body: some View {
        VStack {
            Text("Tap on a site for forecast and readings history")
                .font(.caption)
                .foregroundColor(infoFontColor)
                .padding(.top, 8)
            List {
                let groupedSites = Dictionary(grouping: sitesViewModel.sites) { $0.area }
                 let sortedGroupedSites = groupedSites.sorted(by: { $0.key < $1.key })
                 
                 ForEach(sortedGroupedSites, id: \.key) { area, areaSites in
                     // Split is used to strip the order sequence number from the front of the category on display
                     let areaName = area.split(separator: " ", maxSplits: 1).dropFirst().joined(separator: " ")
                     
                     Section(header: Text(areaName)
                         .font(.subheadline)
                         .foregroundColor(sectionHeaderColor)
                         .bold())
                     {
                         ForEach(areaSites) { site in
                             VStack(alignment: .leading) {
                                 HStack {
                                     Text(site.siteName)
                                         .font(.subheadline)
                                         .foregroundColor(rowHeaderColor)
                                     if site.readingsAlt != "" {
                                         Text("\(site.readingsAlt) ft")
                                             .font(.caption)
                                             .foregroundColor(infoFontColor)
                                             .lineLimit(1)
                                             .fixedSize(horizontal: true, vertical: false)
                                     }
                                     Spacer()
                                     
                                     if let latestReading = stationLatestReadingsViewModel.latestReadings.first (where: { $0.stationID == site.readingsStation }) {
                                         if let windTime = latestReading.windTime {
                                             // Split keeps hh:mm and strips the trailing "  %p" the JSON parser is creating
                                             let windTimeText = windTime.split(separator: " ", maxSplits: 1)[0]
                                             Text(windTimeText)
                                                 .font(.caption)
                                                 .foregroundColor(infoFontColor)
                                                 .lineLimit(1)
                                                 .fixedSize(horizontal: true, vertical: false)
                                         }

                                         if let windSpeed = latestReading.windSpeed {
                                             if windSpeed == 0 {
                                                 Text("calm")
                                                     .font(.subheadline)
                                                     .lineLimit(1)
                                                     .fixedSize(horizontal: true, vertical: false)
                                             } else {
                                                 Text(String(Int(windSpeed)))
                                                     .font(.subheadline)
                                                     .foregroundColor(windSpeedColor(windSpeed: Int(windSpeed), siteType: site.siteType))
                                                     .lineLimit(1)
                                                     .fixedSize(horizontal: true, vertical: false)
                                             }
                                         } else {
                                             Text ("Station down")
                                                 .font(.caption)
                                                 .foregroundColor(infoFontColor)
                                                 .lineLimit(1)
                                                 .fixedSize(horizontal: true, vertical: false)
                                         }

                                         if let windGust = latestReading.windGust {
                                             if windGust > 0 {
                                                 HStack {
                                                     Text("g")
                                                         .font(.subheadline)
                                                         .foregroundColor(infoFontColor)
                                                         .lineLimit(1)
                                                         .fixedSize(horizontal: true, vertical: false)
                                                     Text(String(Int(windGust)))
                                                         .font(.subheadline)
                                                         .foregroundColor(windSpeedColor(windSpeed: Int(windGust), siteType: site.siteType))
                                                         .lineLimit(1)
                                                         .fixedSize(horizontal: true, vertical: false)
                                                 }
                                             }
                                         }

                                         if let windDirection = latestReading.windDirection {
                                             Image(systemName: windArrow)
                                                 .rotationEffect(.degrees(windDirection - 180))
                                                 .font(.footnote)
                                         }
 
                                     } else {
                                         Text ("Station down")
                                             .font(.caption)
                                             .foregroundColor(infoFontColor)
                                             .lineLimit(1)
                                             .fixedSize(horizontal: true, vertical: false)
                                     }
                                 }
                                 .contentShape(Rectangle()) // Makes entire area tappable
                                 .onTapGesture { openSiteDetail(site) }
                             }
                         }
                     }
                 }
                 VStack(alignment: .leading) {
                     Text("Readings data aggregated by Synoptic")
                         .font(.caption)
                         .foregroundColor(infoFontColor)
                     Text("https://synopticdata.com")
                         .font(.caption)
                         .foregroundColor(infoFontColor)
                 }
             }
         }
        .onAppear {
            isActive = true
            startTimer()
        }
        .onDisappear {
            isActive = false
        }
        .sheet(item: $selectedSite, onDismiss: {
            stationLatestReadingsViewModel.reloadLatestReadingsData()
        }) { site in
            SiteDetailView(site: site)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                stationLatestReadingsViewModel.reloadLatestReadingsData()
            } else {
                isActive = false
            }
        }
    }
    func openSiteDetail(_ site: Sites) {
        selectedSite = site
    }
    private func startTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + pageRefreshInterval) {
            if isActive {
                stationLatestReadingsViewModel.reloadLatestReadingsData()
            }
        }
    }
}
