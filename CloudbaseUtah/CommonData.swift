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
    case alerts = 2
    case webcam = 3
    case link = 4
    case dev = 9
}
let GoogleSpreadsheetID = "1s72R3YCHxNIJVLVa5nmsTphRpqRsfG2QR2koWxE19ls"
let GoogleApiKey = "AIzaSyDSro1lDdAQsNEZq06IxwjOlQQP1tip-fs"
let sunriseLatitude: Double = 40.7862               // SLC airport coordinates
let sunriseLongitude: Double = -111.9801
let windArrow: String = "arrow.up"
    // options are:  arrowshape.up.fill, arrow.up, arrow.up.circle.fill, arrow.up.circle, arrow.up.circle.dotted, arrowshape.up.circle
let defaultTopOfLiftAltitude = 18000.0              // Use in lift area graph when top of lift isn't reached in calculations

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
        let liftParameterURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(GoogleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(GoogleApiKey)"
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
