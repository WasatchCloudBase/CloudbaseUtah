import SwiftUI
import Combine
import Foundation

// Set development build flags
let devMenuAvailable: Bool = true
let turnOnLogging: Bool = false
let printForecastURL: Bool = false

// Set global constants
enum NavBarSelectedView:Int {
    case site = 0
    case weather = 1
    case map = 2
    case webcam = 3
    case link = 4
    case dev = 9
}
let googleSpreadsheetID = "1s72R3YCHxNIJVLVa5nmsTphRpqRsfG2QR2koWxE19ls"
let googleApiKey = "AIzaSyDSro1lDdAQsNEZq06IxwjOlQQP1tip-fs"
let sunriseLatitude: Double = 40.7862                   // SLC airport coordinates
let sunriseLongitude: Double = -111.9801
let mapInitLatitude: Double = 40.53                     // Center point for map on initial opening
let mapInitLongitude: Double = -111.87
let mapInitLatitudeSpan: Double = 0.60                  // Size of map on initial opening
let mapInitLongitudeSpan: Double = mapInitLatitudeSpan * 1.5
let mapEnableRotation: Bool = false
let defaultTopOfLiftAltitude = 18000.0                  // Use in lift area graph when top of lift isn't reached in calculations
let pageRefreshInterval: TimeInterval = 150             // Time in seconds to refresh wind readings (300 for 5 min)
let defaultPilotTrackDays: Double = 1.0                 // Default days of live tracking to display

// HTTP links and APIs
let forecastUSMapLink: String = "https://www.wpc.ncep.noaa.gov/basicwx/92fndfd.gif"
let weatherAlertsAPI: String = "https://api.weather.gov/alerts/active?area=UT"
let weatherAlertsLink: String = "https://www.weather.gov/slc/WWA"
let TFRAPI: String = "https://tfr.faa.gov/tfrapi/exportTfrList"
let forecastDiscussionLink: String = "https://forecast.weather.gov/product.php?site=NWS&issuedby=SLC&product=AFD&format=txt&version=1&glossary=0"
let soaringForecastLink: String = "https://forecast.weather.gov/product.php?site=NWS&product=SRG&issuedby=SLC"
let skewTLink: String = "https://www.weather.gov/zse/ModelSounding?id=kslc&model=hrrr"
// prior skewTLink: String = "https://weather.ral.ucar.edu/upper/displayUpper.php?img=KSLC.png&endDate=-1&endTime=-1&duration=0"
let uDOTCamerasAPI: String = "https://www.udottraffic.utah.gov/api/v2/get/cameras?key=6035b1d6b660471a89c9b0c0804a584b&format=json"
let uDOTCamerasLink: String = "https://www.udottraffic.utah.gov"
let cloudbaseUtahGitLink: String = "https://github.com/WasatchCloudBase/CloudbaseUtah"
let cloudbaseUtahGoogleSheetLink: String = "https://docs.google.com/spreadsheets/d/1s72R3YCHxNIJVLVa5nmsTphRpqRsfG2QR2koWxE19ls/edit?gid=0#gid=0"
let ipCamLink: String = "https://apps.apple.com/us/app/ip-camera-viewer-ipcams/id1045600272"
let UHGPGAcamsLink: String = "https://www.uhgpga.org/webcams"

// Build APIs for Mesowest weather readings
// latestReadings API is header + parameters (stations; can be blank) + trailer + token
let latestReadingsAPIHeader = "https://api.mesowest.net/v2/station/latest?"
let latestReadingsAPITrailer =  "&recent=420&vars=air_temp,altimeter,wind_direction,wind_gust,wind_speed&units=english,speed|mph,temp|F&within=120&obtimezone=local&timeformat=%-I:%M%20%p"
// historyReadings API is header + parameters (station) + trailer + token
let historyReadingsAPIHeader = "https://api.mesowest.net/v2/station/timeseries?"
let historyReadingsAPITrailer = "&recent=420&vars=air_temp,wind_direction,wind_gust,wind_speed&units=english,speed|mph,temp|F&within=120&obtimezone=local&timeformat=%-I:%M %p"
let mesowestAPIToken = "&token=ef3b9f4584b64e6da12d8688f19d9f4a"

// Grid structure sizing parameters
let headingHeight: CGFloat = 16                                 // Day, date, time rows
let imageHeight: CGFloat = 38                                   // Weather skies image
let dataHeight: CGFloat = 22
let labelHeight: CGFloat = 22                                   // Wind, Lift label rows
let doubleHeight: CGFloat = dataHeight * 2                      // Surface wind + gust combined
var areaChartHeight: CGFloat = 0                                // ToL area chart height calculated below
let areaChartPaddingHeight: CGFloat = 0                         // Adjustment to reflect spacing between table rows
let imageScalingFactor: CGFloat = 0.5                           // Weather skies image
let windArrowSpacing: CGFloat = 3                               // Space between wind speed and direction arrow
let dateChangeDividerSize: CGFloat = 1
let areaChartOpacity: CGFloat = 0.5

// Map parameters
let annotationTextWidth: CGFloat = 60
let annotationTextHeight: CGFloat = 14
let stationAnnotationWidth: CGFloat = 40
let stationAnnotationHeight: CGFloat = 22

// Background processing custom queues
let backgroundQueue = DispatchQueue(label: "backgroundQueue", qos: .background)
let stationReadingsQueue = DispatchQueue(label: "stationReadingsQueue", qos: .background)
let pilotTracksQueue = DispatchQueue(label: "pilotTracksQueue", qos: .background)

// Get lift parameters for common use
struct LiftParameterSource: Codable, Identifiable {
    var id = UUID()
    var parameter: String
    var value: Double
    var notes: String
}
struct LiftParametersResponse: Codable {
    var values: [[String]]
}
// Published view model structure
struct LiftParameters: Codable {
    var thermalLapseRate: Double
    var thermalVelocityConstant: Double
    var initialTriggerTempDiff: Double
    var ongoingTriggerTempDiff: Double
    var thermalRampDistance: Double
    var thermalRampStartPct: Double
    var cloudbaseLapseRatesDiff: Double
    var thermalGliderSinkRate: Double
}
class LiftParametersViewModel: ObservableObject {
    @Published var liftParameters: LiftParameters?
    
    func getLiftParameters() {
        var liftParameters: LiftParameters = .init(thermalLapseRate: 0, thermalVelocityConstant: 0, initialTriggerTempDiff: 0, ongoingTriggerTempDiff: 0, thermalRampDistance: 0, thermalRampStartPct: 0, cloudbaseLapseRatesDiff: 0, thermalGliderSinkRate: 0)
        let rangeName = "LiftParameters"
        let liftParameterURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(googleApiKey)"
        guard let liftParameterURL = URL(string: liftParameterURLString) else {
            print("invalid URL for thermal lift parameters")
            return
        }
        URLSession.shared.dataTask(with: liftParameterURL) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let decodedResponse = try? decoder.decode(LiftParametersResponse.self, from: data) {
                    DispatchQueue.main.async {
                        for row in decodedResponse.values {
                            if row.count >= 2, let value = Double(row[1]) {
                                switch row[0] {
                                case "thermalLapseRate":
                                    liftParameters.thermalLapseRate = value
                                case "thermalVelocityConstant":
                                    liftParameters.thermalVelocityConstant = value
                                case "initialTriggerTempDiff":
                                    liftParameters.initialTriggerTempDiff = value
                                case "ongoingTriggerTempDiff":
                                    liftParameters.ongoingTriggerTempDiff = value
                                case "thermalRampDistance":
                                    liftParameters.thermalRampDistance = value
                                case "thermalRampStartPct":
                                    liftParameters.thermalRampStartPct = value
                                case "cloudbaseLapseRatesDiff":
                                    liftParameters.cloudbaseLapseRatesDiff = value
                                case "thermalGliderSinkRate":
                                    liftParameters.thermalGliderSinkRate = value
                                case "Parameter":
                                    // skip heading row
                                    _ = value
                                default:
                                    break
                                }
                            }
                        }
                        self.liftParameters = liftParameters
                    }
                }
            }
        }.resume()
    }
}

// Load weather codes
struct WeatherCodes: Identifiable {
    let id = UUID()
    let weatherCode: Int
    let imageName: String
}
struct WeatherCodesResponse: Codable {
    let values: [[String]]
}
class WeatherCodesViewModel: ObservableObject {
    @Published var weatherCodes: [WeatherCodes] = []
    private var cancellables = Set<AnyCancellable>()
    let sheetName = "WeatherCodes"
    func getWeatherCodes() {
        let weatherCodesURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(sheetName)?alt=json&key=\(googleApiKey)"
        guard let url = URL(string: weatherCodesURLString) else {
            print("Invalid URL for weather codes")
            return
        }
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: WeatherCodesResponse.self, decoder: JSONDecoder())
            .map { response in
                response.values.dropFirst().map { WeatherCodes(weatherCode: Int($0[0]) ?? 0, imageName: $0[1]) }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .assign(to: \.weatherCodes, on: self)
            .store(in: &cancellables)
    }
    func weatherCodeImage(weatherCode: Int, cloudcover: Double, precipProbability: Double, tempF: Double) -> String? {
        var weatherCodeImage: String = weatherCodes.first { $0.weatherCode == weatherCode }?.imageName ?? ""
        // Adjust sun/cloud/rain weather code image based on high % precip
        if weatherCodeImage == "cloud.sun.fill" || weatherCodeImage == "sun.max.fill" || weatherCodeImage == "cloud.fill" {
            if precipProbability > 50.0 {
                if tempF < 32.0 {
                    weatherCodeImage = "cloud.snow.fill"
                } else {
                    weatherCodeImage = "cloud.rain.fill"
                }
            } else {
                if cloudcover > 70.0 {
                    weatherCodeImage = "cloud.fill"
                } else if cloudcover > 30.0 {
                    weatherCodeImage = "cloud.sun.fill"
                } else {
                    weatherCodeImage = "sun.max.fill"
                }
            }
        }
        return weatherCodeImage
    }
}

// Get sunrise/sunset times for common use
// Sunrise and sunset URL fetch response structure
struct SunriseSunsetResponse: Codable {
    let results: Results
    let status: String
}
// Sunrise and sunset JSON decode for Results portion of URL response
struct Results: Codable {
    let sunrise: String
    let sunset: String
}
// Published view model structure
struct SunriseSunset: Codable {
    var sunrise: String
    var sunset: String
}
class SunriseSunsetViewModel: ObservableObject {
    @Published var sunriseSunset: SunriseSunset?
    
    // Get sunrise / sunset for SLC airport
    func getSunriseSunset() {
        var sunriseSunset: SunriseSunset = .init(sunrise: "", sunset: "")
        let urlString = "https://api.sunrise-sunset.org/json?lat=\(sunriseLatitude)&lng=\(sunriseLongitude)&formatted=0"
        guard let url = URL(string: urlString) else {
            print("Invalid URL for sunrise and sunset times")
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error for sunrise and sunset times: \(error.localizedDescription)")
                return
            }
            guard let data = data else {
                print("No data received for sunrise and sunset times")
                return
            }
            let decoder = JSONDecoder()
            if let decodedResponse = try? decoder.decode(SunriseSunsetResponse.self, from: data) {
                DispatchQueue.main.async {
                    sunriseSunset.sunrise = convertISODateToLocalTime(isoDateString: decodedResponse.results.sunrise)
                    sunriseSunset.sunset = convertISODateToLocalTime(isoDateString: decodedResponse.results.sunset)
                    self.sunriseSunset = sunriseSunset
                }
            }
        }.resume()
    }
}

// Get sites metadata
struct Sites: Codable, Identifiable, Equatable {
    var id = UUID()
    var area: String
    var siteName: String
    var readingsNote: String
    var forecastNote: String
    var siteType: String
    var readingsAlt: String
    var readingsSource: String
    var readingsStation: String
    var pressureZoneReadingTime: String
    var siteLat: String
    var siteLon: String
    var sheetRow: Int // New property to store the row index
}

struct SitesResponse: Codable {
    let values: [[String]]
}

class SitesViewModel: ObservableObject {
    @Published var sites: [Sites] = []
    private var cancellables = Set<AnyCancellable>()
    
    func getSites() {
        let rangeName = "Sites"
        let sitesURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(googleApiKey)"
        guard let url = URL(string: sitesURLString) else {
            print("Invalid URL")
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: SitesResponse.self, decoder: JSONDecoder())
            .map { response in
                response.values.enumerated().compactMap { index, row -> Sites? in
                    // Skip the header row
                    guard index > 0 else { return nil }
                    // Skip row if data missing
                    guard row.count >= 12 else { return nil }
                    // Skip row not to be used in app (e.g., site is not active)
                    guard row[0] != "Yes" else { return nil }
                    return Sites(
                        area: row[1],
                        siteName: row[2],
                        readingsNote: row[3],
                        forecastNote: row[4],
                        siteType: row[5],
                        readingsAlt: row[6],
                        readingsSource: row[7],
                        readingsStation: row[8],
                        pressureZoneReadingTime: row[9],
                        siteLat: row[10],
                        siteLon: row[11],
                        sheetRow: index + 1 // Store the source row index and add one (Google sheets start at 1, not 0)
                    )
                }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .assign(to: \.sites, on: self)
            .store(in: &cancellables)
    }
}

// Get pilots for live tracking
struct Pilots: Codable, Identifiable {
    var id = UUID()
    var pilotName: String
    var trackingShareURL: String
    var trackingFeedURL: String
}

struct PilotsResponse: Codable {
    let values: [[String]]
}

class PilotsViewModel: ObservableObject {
    @Published var pilots: [Pilots] = []
    private var cancellables = Set<AnyCancellable>()
    
    func getPilots() {
        let rangeName = "Pilots"
        let sitesURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(googleApiKey)"
        guard let url = URL(string: sitesURLString) else {
            print("Invalid URL")
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: PilotsResponse.self, decoder: JSONDecoder())
            .map { response in
                response.values.dropFirst().compactMap { row -> Pilots? in
                    // Skip row if data missing
                    guard row.count >= 2 else { return nil }
                    
                    let pilotName = row[0]
                    let trackingShareURL = row[1]
                    
                    // Extract pilot name from the share URL
                    let pilotNameFromURL = trackingShareURL.components(separatedBy: "/").last ?? ""
                    let trackingFeedURL = "https://share.garmin.com/Feed/Share/\(pilotNameFromURL)"
                    
                    return Pilots(
                        pilotName: pilotName,
                        trackingShareURL: trackingShareURL,
                        trackingFeedURL: trackingFeedURL
                    )
                }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .assign(to: \.pilots, on: self)
            .store(in: &cancellables)
    }
    
    func trackingShareURL(for pilotName: String) -> String? {
        return pilots.first(where: { $0.pilotName == pilotName })?.trackingShareURL
    }
}
