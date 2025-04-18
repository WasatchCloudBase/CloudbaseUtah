//
//  CommonData.swift
//  CloudbaseUtah
//
//  Created by Brown, Mike on 3/30/25.
//
import SwiftUI
import Combine

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
let sunriseLatitude: Double = 40.7862               // SLC airport coordinates
let sunriseLongitude: Double = -111.9801
let centerLatitude: Double = 39.6                   // Center of Utah for maps
let centerLongitude: Double = -111.5
let windArrow: String = "arrow.up"
    // options are:  arrowshape.up.fill, arrow.up, arrow.up.circle.fill, arrow.up.circle, arrow.up.circle.dotted, arrowshape.up.circle
let defaultTopOfLiftAltitude = 18000.0              // Use in lift area graph when top of lift isn't reached in calculations
let pageRefreshInterval: TimeInterval = 120         // Time in seconds to refresh wind readings (300 for 5 min)

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
var ipCamLink: String = "https://apps.apple.com/us/app/ip-camera-viewer-ipcams/id1045600272"
var UHGPGAcamsLink: String = "https://www.uhgpga.org/webcams"

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
    
    func fetchLiftParameters() {
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
    init() {
        fetchWeatherCodes()
    }
    func fetchWeatherCodes() {
        let weatherCodesURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(sheetName)?alt=json&key=\(googleApiKey)"
        guard let url = URL(string: weatherCodesURLString) else {
            print("Invalid URL")
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
    func weatherCodeImage(for weatherCode: Int) -> String? {
        return weatherCodes.first { $0.weatherCode == weatherCode }?.imageName
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
    func fetchSunriseSunset() {
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
