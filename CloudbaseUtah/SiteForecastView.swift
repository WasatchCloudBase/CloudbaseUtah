//
//  SiteForecastView.swift
//  CloudbaseUtah
//
//  Created by Brown, Mike on 3/24/25.
//
import SwiftUI
import Combine

let MaxDisplayRows = 31        // Used to calculate the reduced rows based on surface altitude; needs to be updated if rows added to view

// Forecast data structures
struct ForecastData: Codable {
    var elevation: Double
    var hourly: HourlyData
}

struct HourlyData: Codable {
    var time: [String]
    var weathercode: [Int]
    var cloudcover: [Double]
    var precipitation_probability: [Double]
    var cape: [Double]
    var temperature_2m: [Double]
    var windspeed_500hPa: [Double]
    var windspeed_550hPa: [Double]
    var windspeed_600hPa: [Double]
    var windspeed_650hPa: [Double]
    var windspeed_700hPa: [Double]
    var windspeed_750hPa: [Double]
    var windspeed_800hPa: [Double]
    var windspeed_850hPa: [Double]
    var windspeed_900hPa: [Double]
    var windspeed_10m: [Double]
    var windgusts_10m: [Double]
    var winddirection_500hPa: [Double]
    var winddirection_550hPa: [Double]
    var winddirection_600hPa: [Double]
    var winddirection_650hPa: [Double]
    var winddirection_700hPa: [Double]
    var winddirection_750hPa: [Double]
    var winddirection_800hPa: [Double]
    var winddirection_850hPa: [Double]
    var winddirection_900hPa: [Double]
    var winddirection_10m: [Double]
    var temperature_500hPa: [Double]
    var temperature_550hPa: [Double]
    var temperature_600hPa: [Double]
    var temperature_650hPa: [Double]
    var temperature_700hPa: [Double]
    var temperature_750hPa: [Double]
    var temperature_800hPa: [Double]
    var temperature_850hPa: [Double]
    var temperature_900hPa: [Double]
    var dewpoint_500hPa: [Double]
    var dewpoint_550hPa: [Double]
    var dewpoint_600hPa: [Double]
    var dewpoint_650hPa: [Double]
    var dewpoint_700hPa: [Double]
    var dewpoint_750hPa: [Double]
    var dewpoint_800hPa: [Double]
    var dewpoint_850hPa: [Double]
    var dewpoint_900hPa: [Double]
    var geopotential_height_500hPa: [Double]
    var geopotential_height_550hPa: [Double]
    var geopotential_height_600hPa: [Double]
    var geopotential_height_650hPa: [Double]
    var geopotential_height_700hPa: [Double]
    var geopotential_height_750hPa: [Double]
    var geopotential_height_800hPa: [Double]
    var geopotential_height_850hPa: [Double]
    var geopotential_height_900hPa: [Double]
    var dateTime: [Date]?
    var newDateFlag: [Bool]?
    var formattedDay: [String]?
    var formattedDate: [String]?
    var formattedTime: [String]?
    var weatherCodeImage: [String]?
    var thermalVelocity_500hPa: [Double]?
    var thermalVelocity_550hPa: [Double]?
    var thermalVelocity_600hPa: [Double]?
    var thermalVelocity_650hPa: [Double]?
    var thermalVelocity_700hPa: [Double]?
    var thermalVelocity_750hPa: [Double]?
    var thermalVelocity_800hPa: [Double]?
    var thermalVelocity_850hPa: [Double]?
    var thermalVelocity_900hPa: [Double]?
    var formattedCloudbaseAltitude: [String]?
    var formattedTopOfLiftAltitude: [String]?
    var topOfLiftTemperature: [Double]?
}

struct WeatherCodesResponse: Codable {
    let range: String
    let majorDimension: String
    let values: [[String]]
}

class SiteForecastViewModel: ObservableObject {
    @Published var forecastData: ForecastData?
    private var liftParametersViewModel: LiftParametersViewModel
    @Published var weatherCodes: [String: String] = [:]
    @Published var displayRows: Int = 0                 // Number of forecast rows to display based on surface altitude
    @Published var maxPressureReading: Int = 1000       // Pressure to start displaying winds aloft (1000 hpa is sea level)
    
    // Make thermal lift parameters available in this view model
    init(liftParametersViewModel: LiftParametersViewModel) {
        self.liftParametersViewModel = liftParametersViewModel
    }

    func fetchWeatherCodes(completion: @escaping ([String: String]) -> Void) {
        let rangeName = "WeatherCodes"
        let weatherCodesURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(GoogleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(GoogleApiKey)"
        
        guard let weatherCodesURL = URL(string: weatherCodesURLString) else { return }
        
        URLSession.shared.dataTask(with: weatherCodesURL) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let result = try? decoder.decode(WeatherCodesResponse.self, from: data) {
                    var weatherCodes: [String: String] = [:]
                    for row in result.values.dropFirst() {
                        if row.count >= 2 {
                            weatherCodes[row[0]] = row[1]
                        }
                    }
                    DispatchQueue.main.async {
                        completion(weatherCodes)
                    }
                }
            }
        }.resume()
    }
    
    func fetchForecast(ForecastLat: String, ForecastLon: String) {
        
        // Get forecast
        let forecastURLString = "https://api.open-meteo.com/v1/gfs?latitude=\(ForecastLat)&longitude=\(ForecastLon)&hourly=temperature_2m,relativehumidity_2m,dewpoint_2m,pressure_msl,surface_pressure,precipitation,precipitation_probability,weathercode,cloudcover,cloudcover_low,cloudcover_mid,cloudcover_high,cape,lifted_index,windspeed_10m,windspeed_80m,winddirection_10m,windgusts_10m,temperature_950hPa,temperature_900hPa,temperature_850hPa,temperature_800hPa,temperature_750hPa,temperature_700hPa,temperature_650hPa,temperature_600hPa,temperature_550hPa,temperature_500hPa,dewpoint_950hPa,dewpoint_900hPa,dewpoint_850hPa,dewpoint_800hPa,dewpoint_750hPa,dewpoint_700hPa,dewpoint_650hPa,dewpoint_600hPa,dewpoint_550hPa,dewpoint_500hPa,windspeed_950hPa,windspeed_900hPa,windspeed_850hPa,windspeed_800hPa,windspeed_750hPa,windspeed_700hPa,windspeed_650hPa,windspeed_600hPa,windspeed_550hPa,windspeed_500hPa,winddirection_950hPa,winddirection_900hPa,winddirection_850hPa,winddirection_800hPa,winddirection_750hPa,winddirection_700hPa,winddirection_650hPa,winddirection_600hPa,winddirection_550hPa,winddirection_500hPa,geopotential_height_950hPa,geopotential_height_900hPa,geopotential_height_850hPa,geopotential_height_800hPa,geopotential_height_750hPa,geopotential_height_700hPa,geopotential_height_650hPa,geopotential_height_600hPa,geopotential_height_550hPa,geopotential_height_500hPa&current_weather=true&windspeed_unit=mph&precipitation_unit=inch&timezone=America%2FDenver"

        guard let forecastURL = URL(string: forecastURLString) else { return }
        
        URLSession.shared.dataTask(with: forecastURL) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let forecastData = try? decoder.decode(ForecastData.self, from: data) {
                    DispatchQueue.main.async {
                        self.fetchWeatherCodes { weatherCodes in
                            self.weatherCodes = weatherCodes
                            self.forecastData = self.filterForecastData(forecastData)
                        }
                    }
                }
            }
        }.resume()
    }
    
    func filterForecastData(_ data: ForecastData) -> ForecastData {
        
        var filteredHourly = HourlyData(
            time: [],
            weathercode: [],
            cloudcover: [],
            precipitation_probability: [],
            cape: [],
            temperature_2m: [],
            windspeed_500hPa: [],
            windspeed_550hPa: [],
            windspeed_600hPa: [],
            windspeed_650hPa: [],
            windspeed_700hPa: [],
            windspeed_750hPa: [],
            windspeed_800hPa: [],
            windspeed_850hPa: [],
            windspeed_900hPa: [],
            windspeed_10m: [],
            windgusts_10m: [],
            winddirection_500hPa: [],
            winddirection_550hPa: [],
            winddirection_600hPa: [],
            winddirection_650hPa: [],
            winddirection_700hPa: [],
            winddirection_750hPa: [],
            winddirection_800hPa: [],
            winddirection_850hPa: [],
            winddirection_900hPa: [],
            winddirection_10m: [],
            temperature_500hPa: [],
            temperature_550hPa: [],
            temperature_600hPa: [],
            temperature_650hPa: [],
            temperature_700hPa: [],
            temperature_750hPa: [],
            temperature_800hPa: [],
            temperature_850hPa: [],
            temperature_900hPa: [],
            dewpoint_500hPa: [],
            dewpoint_550hPa: [],
            dewpoint_600hPa: [],
            dewpoint_650hPa: [],
            dewpoint_700hPa: [],
            dewpoint_750hPa: [],
            dewpoint_800hPa: [],
            dewpoint_850hPa: [],
            dewpoint_900hPa: [],

            geopotential_height_500hPa: [],
            geopotential_height_550hPa: [],
            geopotential_height_600hPa: [],
            geopotential_height_650hPa: [],
            geopotential_height_700hPa: [],
            geopotential_height_750hPa: [],
            geopotential_height_800hPa: [],
            geopotential_height_850hPa: [],
            geopotential_height_900hPa: [],
            dateTime: [],
            newDateFlag: [],
            formattedDay: [],
            formattedDate: [],
            formattedTime: [],
            weatherCodeImage: [],
            thermalVelocity_500hPa: [],
            thermalVelocity_550hPa: [],
            thermalVelocity_600hPa: [],
            thermalVelocity_650hPa: [],
            thermalVelocity_700hPa: [],
            thermalVelocity_750hPa: [],
            thermalVelocity_800hPa: [],
            thermalVelocity_850hPa: [],
            thermalVelocity_900hPa: [],
            formattedCloudbaseAltitude: [],
            formattedTopOfLiftAltitude: [],
            topOfLiftTemperature: []
        )

        // If logging is turned on, write header row for thermal calc troubleshooting
        if turnOnLogging {
            logToFile("adjustedPriorAltitude, altitude, altitudeChange, topOfLiftRatio, topOfLiftAltitude, cloudbaseRatio, cloudbaseAltitude, ambientTemp, ambientDPTemp, priorAmbientDPTemp, thermalDPTemp, priorThermalDPTemp, thermalVelocity, thermalDPTempToAmbientDPTempDiff, ambientTempToAmbientDPTempDiff, ambientDPTempDiff, priorThermalDPTempToAmbientDPTempDiff, priorAmbientDPTempToAmbientTempDiff, thermalRampTop, rampImpactAltitude, rampImpactPortion, rampReductionFactor")
        }

        
        let currentDate = Date()
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: currentDate)!
        var priorReadingFormattedDate: String?
        var newDateFlag: Bool = true
        
        // Determine altitude in feet and limit wind readings to only those more than 200 ft above the surface
        // by reducing the number of rows to display and specifying the max pressure reading to display
        let surfaceAltitude = Double(convertMetersToFeet(data.elevation) + 10)
        var maxPressureReading: Int = 1000  // hPa, which is sea level
        var displayRows: Int = MaxDisplayRows
        if data.hourly.geopotential_height_900hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 850
            displayRows -= 2
        }
        if data.hourly.geopotential_height_850hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 800
            displayRows -= 2
        }
        if data.hourly.geopotential_height_800hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 750
            displayRows -= 2
        }
        if data.hourly.geopotential_height_750hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 700
            displayRows -= 2
        }
        if data.hourly.geopotential_height_700hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 650
            displayRows -= 2
        }
        if data.hourly.geopotential_height_650hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 600
            displayRows -= 2
        }
        if data.hourly.geopotential_height_600hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 550
            displayRows -= 2
        }
        if data.hourly.geopotential_height_550hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 500
            displayRows -= 2
        }
        if data.hourly.geopotential_height_500hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 450
            displayRows -= 2
        }
        self.displayRows = displayRows
        self.maxPressureReading = maxPressureReading
        
        for (index, time) in data.hourly.time.enumerated() {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            if let timeObj = timeFormatter.date(from: time) {
                if timeObj >= oneHourAgo {
                    let hour = Calendar.current.component(.hour, from: timeObj)
                    if hour >= 6 && hour <= 21 {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "E"
                        let formattedDay = dateFormatter.string(from: timeObj)
                        dateFormatter.dateFormat = "M/d"
                        let formattedDate = dateFormatter.string(from: timeObj)
                        timeFormatter.dateFormat = "h a"
                        let formattedTime = timeFormatter.string(from: timeObj).lowercased()
                        let surfaceTemp = convertCelsiusToFahrenheit(Int(data.hourly.temperature_2m[index]))
                        
                        filteredHourly.time.append(time)
                        filteredHourly.dateTime?.append(timeObj)
                        filteredHourly.formattedDay?.append(formattedDay)
                        filteredHourly.formattedDate?.append(formattedDate)
                        filteredHourly.formattedTime?.append(formattedTime)
                        filteredHourly.weathercode.append(data.hourly.weathercode[index])
                        filteredHourly.cloudcover.append(data.hourly.cloudcover[index])
                        filteredHourly.precipitation_probability.append(data.hourly.precipitation_probability[index])
                        filteredHourly.cape.append(data.hourly.cape[index])
                        filteredHourly.temperature_2m.append(Double(surfaceTemp))
                        filteredHourly.windspeed_500hPa.append(data.hourly.windspeed_500hPa[index].rounded())
                        filteredHourly.windspeed_550hPa.append(data.hourly.windspeed_550hPa[index].rounded())
                        filteredHourly.windspeed_600hPa.append(data.hourly.windspeed_600hPa[index].rounded())
                        filteredHourly.windspeed_650hPa.append(data.hourly.windspeed_650hPa[index].rounded())
                        filteredHourly.windspeed_700hPa.append(data.hourly.windspeed_700hPa[index].rounded())
                        filteredHourly.windspeed_750hPa.append(data.hourly.windspeed_750hPa[index].rounded())
                        filteredHourly.windspeed_800hPa.append(data.hourly.windspeed_800hPa[index].rounded())
                        filteredHourly.windspeed_850hPa.append(data.hourly.windspeed_850hPa[index].rounded())
                        filteredHourly.windspeed_900hPa.append(data.hourly.windspeed_900hPa[index].rounded())
                        filteredHourly.windspeed_10m.append(data.hourly.windspeed_10m[index].rounded())
                        filteredHourly.windgusts_10m.append(data.hourly.windgusts_10m[index].rounded())
                        filteredHourly.winddirection_500hPa.append(data.hourly.winddirection_500hPa[index])
                        filteredHourly.winddirection_550hPa.append(data.hourly.winddirection_550hPa[index])
                        filteredHourly.winddirection_600hPa.append(data.hourly.winddirection_600hPa[index])
                        filteredHourly.winddirection_650hPa.append(data.hourly.winddirection_650hPa[index])
                        filteredHourly.winddirection_700hPa.append(data.hourly.winddirection_700hPa[index])
                        filteredHourly.winddirection_750hPa.append(data.hourly.winddirection_750hPa[index])
                        filteredHourly.winddirection_800hPa.append(data.hourly.winddirection_800hPa[index])
                        filteredHourly.winddirection_850hPa.append(data.hourly.winddirection_850hPa[index])
                        filteredHourly.winddirection_900hPa.append(data.hourly.winddirection_900hPa[index])
                        filteredHourly.winddirection_10m.append(data.hourly.winddirection_10m[index])
                        
                        // Heights are divided by 1,000 and rounded so they can be displayed like "12k ft"
                        filteredHourly.geopotential_height_500hPa.append((data.hourly.geopotential_height_500hPa[index]/1000).rounded())
                        filteredHourly.geopotential_height_550hPa.append((data.hourly.geopotential_height_550hPa[index]/1000).rounded())
                        filteredHourly.geopotential_height_600hPa.append((data.hourly.geopotential_height_600hPa[index]/1000).rounded())
                        filteredHourly.geopotential_height_650hPa.append((data.hourly.geopotential_height_650hPa[index]/1000).rounded())
                        filteredHourly.geopotential_height_700hPa.append((data.hourly.geopotential_height_700hPa[index]/1000).rounded())
                        filteredHourly.geopotential_height_750hPa.append((data.hourly.geopotential_height_750hPa[index]/1000).rounded())
                        filteredHourly.geopotential_height_800hPa.append((data.hourly.geopotential_height_800hPa[index]/1000).rounded())
                        filteredHourly.geopotential_height_850hPa.append((data.hourly.geopotential_height_850hPa[index]/1000).rounded())
                        filteredHourly.geopotential_height_900hPa.append((data.hourly.geopotential_height_900hPa[index]/1000).rounded())
                        
                        // Determine if this reading is a new day to set a divider in the view
                        if formattedDate == priorReadingFormattedDate {
                            newDateFlag = false
                        } else {
                            newDateFlag = true
                        }
                        filteredHourly.newDateFlag?.append(newDateFlag)
                        priorReadingFormattedDate = formattedDate
                        
                        // Set weather code image
                        let weatherCode = String(data.hourly.weathercode[index])
                        var weatherCodeImage = weatherCodes[weatherCode] ?? ""
                        // Adjust sun/cloud/rain weather code image based on high % precip
                        if weatherCodeImage == "cloud.sun.fill" || weatherCodeImage == "sun.max.fill" || weatherCodeImage == "cloud.fill" {
                            if data.hourly.precipitation_probability[index] > 70 {
                                if surfaceTemp < 32 {
                                    weatherCodeImage = "cloud.snow.fill"
                                } else {
                                    weatherCodeImage = "cloud.rain.fill"
                                }
                            }
                        }
                        filteredHourly.weatherCodeImage?.append(weatherCodeImage)
                        
                        // Calculate thermal velocity
                        var priorThermalDPTemp = data.hourly.temperature_2m[index]  // degrees Celsius
                        var priorAmbientDPTemp = 0.0
                        var priorAltitude = surfaceAltitude // feet
                        var topOfLiftAltitude = 0.0
                        var cloudbaseAltitude = 0.0
                        var topOfLiftTemp = 0.0
                        var thermalResult: ThermalResult?
                        var thermalVelocity = 0.0
                        // 900 hpa pressure level thermal calcs
                        if topOfLiftAltitude == 0 {
                            thermalResult = calcThermalVelocity (altitude: data.hourly.geopotential_height_900hPa[index],
                                                                 ambientTemp: data.hourly.temperature_900hPa[index],
                                                                 ambientDPTemp: data.hourly.dewpoint_900hPa[index],
                                                                 priorAmbientDPTemp: priorAmbientDPTemp,
                                                                 priorThermalDPTemp: priorThermalDPTemp,
                                                                 priorAltitude: priorAltitude,
                                                                 surfaceAltitude: surfaceAltitude)
                            thermalVelocity = thermalResult?.thermalVelocity ?? 0.0
                            priorThermalDPTemp = thermalResult?.thermalDPTemp ?? priorThermalDPTemp
                            topOfLiftAltitude = thermalResult?.topOfLiftAltitude ?? 0.0
                            cloudbaseAltitude = thermalResult?.cloudbaseAltitude ?? 0.0
                            priorAltitude = data.hourly.geopotential_height_900hPa[index]
                            priorAmbientDPTemp = data.hourly.dewpoint_900hPa[index]
                            if topOfLiftAltitude > 0 {
                                topOfLiftTemp = data.hourly.temperature_900hPa[index]
                            }
                        }
                        filteredHourly.thermalVelocity_900hPa?.append(thermalVelocity)
                        
                        // 850 hpa pressure level thermal calcs
                        if topOfLiftAltitude == 0 {
                            thermalResult = calcThermalVelocity (altitude: data.hourly.geopotential_height_850hPa[index],
                                                                 ambientTemp: data.hourly.temperature_850hPa[index],
                                                                 ambientDPTemp: data.hourly.dewpoint_850hPa[index],
                                                                 priorAmbientDPTemp: priorAmbientDPTemp,
                                                                 priorThermalDPTemp: priorThermalDPTemp,
                                                                 priorAltitude: priorAltitude,
                                                                 surfaceAltitude: surfaceAltitude)
                            thermalVelocity = thermalResult?.thermalVelocity ?? 0.0
                            priorThermalDPTemp = thermalResult?.thermalDPTemp ?? priorThermalDPTemp
                            topOfLiftAltitude = thermalResult?.topOfLiftAltitude ?? 0.0
                            cloudbaseAltitude = thermalResult?.cloudbaseAltitude ?? 0.0
                            priorAltitude = data.hourly.geopotential_height_850hPa[index]
                            priorAmbientDPTemp = data.hourly.dewpoint_850hPa[index]
                            if topOfLiftAltitude > 0 {
                                topOfLiftTemp = data.hourly.temperature_850hPa[index]
                            }
                        }
                        filteredHourly.thermalVelocity_850hPa?.append(thermalVelocity)
                        
                        // 800 hpa pressure level thermal calcs
                        if topOfLiftAltitude == 0 {
                            thermalResult = calcThermalVelocity (altitude: data.hourly.geopotential_height_800hPa[index],
                                                                 ambientTemp: data.hourly.temperature_800hPa[index],
                                                                 ambientDPTemp: data.hourly.dewpoint_800hPa[index],
                                                                 priorAmbientDPTemp: priorAmbientDPTemp,
                                                                 priorThermalDPTemp: priorThermalDPTemp,
                                                                 priorAltitude: priorAltitude,
                                                                 surfaceAltitude: surfaceAltitude)
                            thermalVelocity = thermalResult?.thermalVelocity ?? 0.0
                            priorThermalDPTemp = thermalResult?.thermalDPTemp ?? priorThermalDPTemp
                            topOfLiftAltitude = thermalResult?.topOfLiftAltitude ?? 0.0
                            cloudbaseAltitude = thermalResult?.cloudbaseAltitude ?? 0.0
                            priorAltitude = data.hourly.geopotential_height_800hPa[index]
                            priorAmbientDPTemp = data.hourly.dewpoint_800hPa[index]
                            if topOfLiftAltitude > 0 {
                                topOfLiftTemp = data.hourly.temperature_800hPa[index]
                            }
                        }
                        filteredHourly.thermalVelocity_800hPa?.append(thermalVelocity)
                        
                        // 750 hpa pressure level thermal calcs
                        if topOfLiftAltitude == 0 {
                            thermalResult = calcThermalVelocity (altitude: data.hourly.geopotential_height_750hPa[index],
                                                                 ambientTemp: data.hourly.temperature_750hPa[index],
                                                                 ambientDPTemp: data.hourly.dewpoint_750hPa[index],
                                                                 priorAmbientDPTemp: priorAmbientDPTemp,
                                                                 priorThermalDPTemp: priorThermalDPTemp,
                                                                 priorAltitude: priorAltitude,
                                                                 surfaceAltitude: surfaceAltitude)
                            thermalVelocity = thermalResult?.thermalVelocity ?? 0.0
                            priorThermalDPTemp = thermalResult?.thermalDPTemp ?? priorThermalDPTemp
                            topOfLiftAltitude = thermalResult?.topOfLiftAltitude ?? 0.0
                            cloudbaseAltitude = thermalResult?.cloudbaseAltitude ?? 0.0
                            priorAltitude = data.hourly.geopotential_height_750hPa[index]
                            priorAmbientDPTemp = data.hourly.dewpoint_750hPa[index]
                            if topOfLiftAltitude > 0 {
                                topOfLiftTemp = data.hourly.temperature_750hPa[index]
                            }
                        }
                        filteredHourly.thermalVelocity_750hPa?.append(thermalVelocity)
                        
                        // 700 hpa pressure level thermal calcs
                        if topOfLiftAltitude == 0 {
                            thermalResult = calcThermalVelocity (altitude: data.hourly.geopotential_height_700hPa[index],
                                                                 ambientTemp: data.hourly.temperature_700hPa[index],
                                                                 ambientDPTemp: data.hourly.dewpoint_700hPa[index],
                                                                 priorAmbientDPTemp: priorAmbientDPTemp,
                                                                 priorThermalDPTemp: priorThermalDPTemp,
                                                                 priorAltitude: priorAltitude,
                                                                 surfaceAltitude: surfaceAltitude)
                            thermalVelocity = thermalResult?.thermalVelocity ?? 0.0
                            priorThermalDPTemp = thermalResult?.thermalDPTemp ?? priorThermalDPTemp
                            topOfLiftAltitude = thermalResult?.topOfLiftAltitude ?? 0.0
                            cloudbaseAltitude = thermalResult?.cloudbaseAltitude ?? 0.0
                            priorAltitude = data.hourly.geopotential_height_700hPa[index]
                            priorAmbientDPTemp = data.hourly.dewpoint_700hPa[index]
                            if topOfLiftAltitude > 0 {
                                topOfLiftTemp = data.hourly.temperature_700hPa[index]
                            }
                        }
                        filteredHourly.thermalVelocity_700hPa?.append(thermalVelocity)
                        
                        // 650 hpa pressure level thermal calcs
                        if topOfLiftAltitude == 0 {
                            thermalResult = calcThermalVelocity (altitude: data.hourly.geopotential_height_650hPa[index],
                                                                 ambientTemp: data.hourly.temperature_650hPa[index],
                                                                 ambientDPTemp: data.hourly.dewpoint_650hPa[index],
                                                                 priorAmbientDPTemp: priorAmbientDPTemp,
                                                                 priorThermalDPTemp: priorThermalDPTemp,
                                                                 priorAltitude: priorAltitude,
                                                                 surfaceAltitude: surfaceAltitude)
                            thermalVelocity = thermalResult?.thermalVelocity ?? 0.0
                            priorThermalDPTemp = thermalResult?.thermalDPTemp ?? priorThermalDPTemp
                            topOfLiftAltitude = thermalResult?.topOfLiftAltitude ?? 0.0
                            cloudbaseAltitude = thermalResult?.cloudbaseAltitude ?? 0.0
                            priorAltitude = data.hourly.geopotential_height_650hPa[index]
                            priorAmbientDPTemp = data.hourly.dewpoint_650hPa[index]
                            if topOfLiftAltitude > 0 {
                                topOfLiftTemp = data.hourly.temperature_650hPa[index]
                            }
                        }
                        filteredHourly.thermalVelocity_650hPa?.append(thermalVelocity)
                        
                        // 600 hpa pressure level thermal calcs
                        if topOfLiftAltitude == 0 {
                            thermalResult = calcThermalVelocity (altitude: data.hourly.geopotential_height_600hPa[index],
                                                                 ambientTemp: data.hourly.temperature_600hPa[index],
                                                                 ambientDPTemp: data.hourly.dewpoint_600hPa[index],
                                                                 priorAmbientDPTemp: priorAmbientDPTemp,
                                                                 priorThermalDPTemp: priorThermalDPTemp,
                                                                 priorAltitude: priorAltitude,
                                                                 surfaceAltitude: surfaceAltitude)
                            thermalVelocity = thermalResult?.thermalVelocity ?? 0.0
                            priorThermalDPTemp = thermalResult?.thermalDPTemp ?? priorThermalDPTemp
                            topOfLiftAltitude = thermalResult?.topOfLiftAltitude ?? 0.0
                            cloudbaseAltitude = thermalResult?.cloudbaseAltitude ?? 0.0
                            priorAltitude = data.hourly.geopotential_height_600hPa[index]
                            priorAmbientDPTemp = data.hourly.dewpoint_600hPa[index]
                            if topOfLiftAltitude > 0 {
                                topOfLiftTemp = data.hourly.temperature_600hPa[index]
                            }
                        }
                        filteredHourly.thermalVelocity_600hPa?.append(thermalVelocity)
                        
                        // 550 hpa pressure level thermal calcs
                        if topOfLiftAltitude == 0 {
                            thermalResult = calcThermalVelocity (altitude: data.hourly.geopotential_height_550hPa[index],
                                                                 ambientTemp: data.hourly.temperature_550hPa[index],
                                                                 ambientDPTemp: data.hourly.dewpoint_550hPa[index],
                                                                 priorAmbientDPTemp: priorAmbientDPTemp,
                                                                 priorThermalDPTemp: priorThermalDPTemp,
                                                                 priorAltitude: priorAltitude,
                                                                 surfaceAltitude: surfaceAltitude)
                            thermalVelocity = thermalResult?.thermalVelocity ?? 0.0
                            priorThermalDPTemp = thermalResult?.thermalDPTemp ?? priorThermalDPTemp
                            topOfLiftAltitude = thermalResult?.topOfLiftAltitude ?? 0.0
                            cloudbaseAltitude = thermalResult?.cloudbaseAltitude ?? 0.0
                            priorAltitude = data.hourly.geopotential_height_550hPa[index]
                            priorAmbientDPTemp = data.hourly.dewpoint_550hPa[index]
                            if topOfLiftAltitude > 0 {
                                topOfLiftTemp = data.hourly.temperature_550hPa[index]
                            }
                        }
                        filteredHourly.thermalVelocity_550hPa?.append(thermalVelocity)
                        
                        // 500 hpa pressure level thermal calcs
                        if topOfLiftAltitude == 0 {
                            thermalResult = calcThermalVelocity (altitude: data.hourly.geopotential_height_500hPa[index],
                                                                 ambientTemp: data.hourly.temperature_500hPa[index],
                                                                 ambientDPTemp: data.hourly.dewpoint_500hPa[index],
                                                                 priorAmbientDPTemp: priorAmbientDPTemp,
                                                                 priorThermalDPTemp: priorThermalDPTemp,
                                                                 priorAltitude: priorAltitude,
                                                                 surfaceAltitude: surfaceAltitude)
                            thermalVelocity = thermalResult?.thermalVelocity ?? 0.0
                            priorThermalDPTemp = thermalResult?.thermalDPTemp ?? priorThermalDPTemp
                            topOfLiftAltitude = thermalResult?.topOfLiftAltitude ?? 0.0
                            cloudbaseAltitude = thermalResult?.cloudbaseAltitude ?? 0.0
                            priorAltitude = data.hourly.geopotential_height_500hPa[index]
                            priorAmbientDPTemp = data.hourly.dewpoint_500hPa[index]
                            if topOfLiftAltitude > 0 {
                                topOfLiftTemp = data.hourly.temperature_500hPa[index]
                            }
                        }
                        filteredHourly.thermalVelocity_500hPa?.append(thermalVelocity)
                        
                        // Append cloudbase and top of lift data
                        // Altitudes are / 1000 so they can be displayed like "13k)
                        var formattedCloudbaseAltitude = ""
                        if cloudbaseAltitude > 0 {
                            formattedCloudbaseAltitude = String(Int((cloudbaseAltitude/1000).rounded())) + "k"
                        }
                        var formattedTopOfLiftAltitude = ""
                        if topOfLiftAltitude > 0 {
                            formattedTopOfLiftAltitude = String(Int((topOfLiftAltitude/1000).rounded())) + "k"
                        }
                        filteredHourly.formattedCloudbaseAltitude?.append(formattedCloudbaseAltitude)
                        filteredHourly.formattedTopOfLiftAltitude?.append(formattedTopOfLiftAltitude)
                        filteredHourly.topOfLiftTemperature?.append(topOfLiftTemp)
                    }
                }
            }
        }
        return ForecastData(elevation: data.elevation, hourly: filteredHourly)
    }
    
    struct ThermalResult {
        let thermalVelocity: Double
        let thermalDPTemp: Double
        let cloudbaseAltitude: Double
        let topOfLiftAltitude: Double
    }

    func calcThermalVelocity(
        altitude: Double,
        ambientTemp: Double,
        ambientDPTemp: Double,
        priorAmbientDPTemp: Double,
        priorThermalDPTemp: Double,
        priorAltitude: Double,
        surfaceAltitude: Double
    ) -> ThermalResult {

        // Initial values (setting here to allow all to be written to log file)
        var thermalDPTemp = priorThermalDPTemp
        var thermalVelocity: Double = 0.0
        var cloudbaseRatio: Double = 0.0
        var cloudbaseAltitude: Double = 0.0
        var topOfLiftAltitude: Double = 0.0
        var topOfLiftRatio: Double = 0.0
        var altitudeChange: Double = 0.0
        var thermalRampTop: Double = 0.0
        var rampImpactAltitude: Double = 0.0
        var rampImpactPortion: Double = 0.0
        var rampReductionFactor: Double = 0.0

        // Get thermal lift parameters from environment object
        guard let liftParameters = liftParametersViewModel.liftParameters else {
            // End processing if lift parameters are not available
            return ThermalResult(
                thermalVelocity: thermalVelocity,
                thermalDPTemp: thermalDPTemp,
                cloudbaseAltitude: cloudbaseAltitude,
                topOfLiftAltitude: topOfLiftAltitude)
        }

        // Check if altitude is less than surfaceAltitude
        guard altitude >= surfaceAltitude else {
            // End processing if altitude is less than surfaceAltitude
            return ThermalResult(
                thermalVelocity: thermalVelocity,
                thermalDPTemp: thermalDPTemp,
                cloudbaseAltitude: cloudbaseAltitude,
                topOfLiftAltitude: topOfLiftAltitude)
        }
        
        // Check if priorAltitude is less than surfaceAltitude
        let adjustedPriorAltitude = priorAltitude < surfaceAltitude ? surfaceAltitude : priorAltitude
        
        // Determine altitude change
        altitudeChange = altitude - adjustedPriorAltitude
        
        // Convert altitude from feet to kilometers
        let altitudeKm = convertFeetToMeters(altitude) / 1000
        let adjustedPriorAltitudeKm = convertFeetToMeters(adjustedPriorAltitude) / 1000
        let altitudeChangeKm = altitudeKm - adjustedPriorAltitudeKm
        
        // Td = T - (DALR * altitudeChange in km) where DALR is the thermalLapseRate
        thermalDPTemp = priorThermalDPTemp - ( liftParameters.thermalLapseRate * altitudeChangeKm )
        
        // Calculate temperature differences
        let thermalDPTempToAmbientDPTempDiff = max( (thermalDPTemp - ambientDPTemp), 0.0 )
        let ambientTempToAmbientDPTempDiff = max( (ambientTemp - ambientDPTemp), 0.0 )
        let ambientDPTempDiff = max( (priorAmbientDPTemp - ambientDPTemp), 0.0 )
        let priorThermalDPTempToAmbientDPTempDiff = max( (priorThermalDPTemp - priorAmbientDPTemp), 0.0 )
        let priorAmbientDPTempToAmbientTempDiff = max( priorAmbientDPTemp - ambientTemp, 0.0)

        // Determine if cloudbase is reached (thermal dew point temp does not exceed ambient temp)
        if  ambientTemp <= ambientDPTemp {
            cloudbaseRatio = (priorAmbientDPTempToAmbientTempDiff) / (ambientDPTempDiff)
            if ambientDPTempDiff == 0 {
                cloudbaseAltitude = adjustedPriorAltitude
            } else {
                cloudbaseAltitude = adjustedPriorAltitude + ( altitudeChange * cloudbaseRatio )
            }
        }
        
        // Determine if top of lift is reached (thermal dew point temp does not exceed ambient dew point)
        if thermalDPTemp <= ambientDPTemp {
            topOfLiftRatio = (ambientDPTempDiff/priorThermalDPTempToAmbientDPTempDiff)
            if priorThermalDPTempToAmbientDPTempDiff == 0 {
                topOfLiftAltitude = adjustedPriorAltitude
            } else {
                topOfLiftAltitude = adjustedPriorAltitude + ( altitudeChange * topOfLiftRatio )
            }
        }

        // If neither cloudbase or top of lift is reached, calculate thermal velocity (w)
        if cloudbaseAltitude == 0.0 && topOfLiftAltitude == 0.0 {
            // w = thermalVelocityConstant * sqrt [ ((1.1)^(thermalDPTemp - ambDPTemp) - 1) / ((1.1)^(ambTemp - ambDPTemp)-1) ]
            // Thermal velocity:
            //      Increases with warmer or dryer thermal compared to ambient air
            //      Decreases with dryer ambient air
            thermalVelocity = liftParameters.thermalVelocityConstant * sqrt( (pow(1.1, thermalDPTempToAmbientDPTempDiff) - 1) / (pow(1.1, ambientTempToAmbientDPTempDiff) - 1))

            // Adjust thermal velocity if within thermal ramp distance (near the surface)
            thermalRampTop = surfaceAltitude + liftParameters.thermalRampDistance
            if thermalRampTop > adjustedPriorAltitude {
                rampImpactAltitude = min(altitude, thermalRampTop) - adjustedPriorAltitude
                rampImpactPortion = rampImpactAltitude / (altitude - adjustedPriorAltitude)
                rampReductionFactor = liftParameters.thermalRampStartPct / 100 * rampImpactPortion
                thermalVelocity = thermalVelocity * (1 - rampReductionFactor)
            }
 
            
            
        }
        
        // If logging is turned on, write data for thermal calc troubleshooting
        if turnOnLogging {
            logToFile("\(adjustedPriorAltitude.rounded()), \(altitude.rounded()), \(altitudeChange.rounded()), \(topOfLiftRatio.rounded()), \(topOfLiftAltitude.rounded()), \(cloudbaseRatio.rounded()), \(cloudbaseAltitude.rounded()), \(ambientTemp.rounded()), \(ambientDPTemp.rounded()), \(priorAmbientDPTemp.rounded()), \(thermalDPTemp.rounded()), \(priorThermalDPTemp.rounded()), \(thermalVelocity.rounded()), \(thermalDPTempToAmbientDPTempDiff.rounded()), \(ambientTempToAmbientDPTempDiff.rounded()), \(ambientDPTempDiff.rounded()), \(priorThermalDPTempToAmbientDPTempDiff.rounded()), \(priorAmbientDPTempToAmbientTempDiff.rounded()), \(thermalRampTop.rounded()), \(rampImpactAltitude.rounded()), \(rampImpactPortion.rounded()), \(rampReductionFactor.rounded())")
        }
        
        return ThermalResult(
            thermalVelocity: roundToOneDecimal(thermalVelocity),
            thermalDPTemp: thermalDPTemp,
            cloudbaseAltitude: cloudbaseAltitude,
            topOfLiftAltitude: topOfLiftAltitude
        )
    }
}

struct SiteForecastView: View {
    @ObservedObject var liftParametersViewModel: LiftParametersViewModel
    @StateObject private var viewModel: SiteForecastViewModel
    var forecastLat: String
    var forecastLon: String
    var forecastNote: String
    var siteType: String
    
    init(liftParametersViewModel: LiftParametersViewModel, forecastLat: String, forecastLon: String, forecastNote: String, siteType: String) {
        self._liftParametersViewModel = ObservedObject(wrappedValue: liftParametersViewModel)
        self._viewModel = StateObject(wrappedValue: SiteForecastViewModel(liftParametersViewModel: liftParametersViewModel))
        self.forecastLat = forecastLat
        self.forecastLon = forecastLon
        self.forecastNote = forecastNote
        self.siteType = siteType
    }
    
    var body: some View {
        VStack (alignment: .leading) {
            
            if let forecastData = viewModel.forecastData {
                VStack(alignment: .leading) {
                    let Alt = formatAltitude(String(convertMetersToFeet(forecastData.elevation)))
                    Text(buildReferenceNote(Alt: "\(Alt)", Note: forecastNote))
                        .font(.footnote)
                        .foregroundColor(infoFontColor)
                        .padding(.top, 8)
                        .padding(.bottom, 5)
                    
                    let displayRows = viewModel.displayRows
                    let maxPressureReading = viewModel.maxPressureReading
                    
                    HStack(alignment: .center) {
                        LazyHGrid(rows: Array(repeating: GridItem(.fixed(16)), count: displayRows)) {
                            Group {
                                Text(" ")
                                Text(" ")
                                Text(" ")
                                Text(" ")
                                Text("Temp")
                                    .padding(.vertical, 6)
                                Text("Cloud %")
                                Text("Precip %")
                                Text("CAPE")
                                Text("Wind")
                                    .foregroundColor(infoFontColor)
                                if maxPressureReading >= 500 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_500hPa.first ?? 500))k ft")
                                }
                                if maxPressureReading >= 550 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_550hPa.first ?? 550))k ft")
                                }
                                if maxPressureReading >= 600 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_600hPa.first ?? 600))k ft")
                                }
                                if maxPressureReading >= 650 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_650hPa.first ?? 650))k ft")
                                }
                                if maxPressureReading >= 700 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_700hPa.first ?? 700))k ft")
                                }
                                if maxPressureReading >= 750 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_750hPa.first ?? 750))k ft")
                                }
                                if maxPressureReading >= 800 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_800hPa.first ?? 800))k ft")
                                }
                                if maxPressureReading >= 850 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_850hPa.first ?? 850))k ft")
                                }
                                if maxPressureReading >= 900 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_900hPa.first ?? 900))k ft")
                                }
                                Text("Surface")
                                Text("Thermals")
                                    .foregroundColor(infoFontColor)
                                Text("Top of Lift")
                                Text("Cloudbase")
                                if maxPressureReading >= 500 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_500hPa.first ?? 500))k ft")
                                }
                                if maxPressureReading >= 550 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_550hPa.first ?? 550))k ft")
                                }
                                if maxPressureReading >= 600 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_600hPa.first ?? 600))k ft")
                                }
                                if maxPressureReading >= 650 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_650hPa.first ?? 650))k ft")
                                }
                                if maxPressureReading >= 700 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_700hPa.first ?? 700))k ft")
                                }
                                if maxPressureReading >= 750 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_750hPa.first ?? 750))k ft")
                                }
                                if maxPressureReading >= 800 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_800hPa.first ?? 800))k ft")
                                }
                                if maxPressureReading >= 850 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_850hPa.first ?? 850))k ft")
                                }
                                if maxPressureReading >= 900 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_900hPa.first ?? 900))k ft")
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        
                        ScrollView(.horizontal) {
                            LazyHGrid(rows: Array(repeating: GridItem(.fixed(16)), count: displayRows)) {
                                if let forecastData = viewModel.forecastData {
                                    ForEach(forecastData.hourly.dateTime?.indices ?? 0..<0, id: \.self) { index in
                                        Group {
                                            if forecastData.hourly.newDateFlag?[index] ?? true {
                                                Text(forecastData.hourly.formattedDay?[index] ?? "")
                                                Text(forecastData.hourly.formattedDate?[index] ?? "")
                                            } else {
                                                Text(forecastData.hourly.formattedDay?[index] ?? "")
                                                    .foregroundColor(repeatDateTimeColor)
                                                Text(forecastData.hourly.formattedDate?[index] ?? "")
                                                    .foregroundColor(repeatDateTimeColor)
                                            }
                                            Text(forecastData.hourly.formattedTime?[index] ?? "")
                                            Image(systemName: forecastData.hourly.weatherCodeImage?[index] ?? "questionmark")
                                                .renderingMode(.original) // Use .multicolor for multicolor rendering
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 24, height: 24)
                                            Text("\(Int(forecastData.hourly.temperature_2m[index]))°")
                                                .foregroundStyle(tempColor(Int(forecastData.hourly.temperature_2m[index])))
                                            Text(forecastData.hourly.cloudcover[index] == 0 ? "" : "\(Int(forecastData.hourly.cloudcover[index]))")
                                                .foregroundStyle(cloudCoverColor(Int(forecastData.hourly.cloudcover[index])))
                                            Text(forecastData.hourly.precipitation_probability[index] == 0 ? "" : "\(Int(forecastData.hourly.precipitation_probability[index]))")
                                                .foregroundStyle(precipColor(Int(forecastData.hourly.precipitation_probability[index])))
                                            Text(forecastData.hourly.cape[index] == 0 ? "" : "\(Int(forecastData.hourly.cape[index]))")
                                                .foregroundStyle(CAPEColor(Int(forecastData.hourly.cape[index])))
                                            Text(" ")
                                                .frame(maxWidth: .infinity)
                                                .overlay(
                                                    Rectangle()
                                                        .frame(height: 1)
                                                        .foregroundColor(tableDividerColor),
                                                    alignment: .center
                                                )
                                            if maxPressureReading >= 500 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_500hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_500hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_500hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 550 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_550hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_550hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_550hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 600 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_600hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_600hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_600hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 650 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_650hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_650hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_650hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 700 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_700hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_700hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_700hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 750 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_750hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_750hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_750hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 800 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_800hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_800hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_800hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 850 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_850hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_850hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_850hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 900 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_900hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_900hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_900hPa[index] - 180))
                                                }
                                            }
                                            HStack(spacing: 1) {
                                                Text("\(Int(forecastData.hourly.windspeed_10m[index]))")
                                                    .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_10m[index]), siteType: siteType))
                                                Text("g")
                                                    .font(.caption)
                                                Text("\(Int(forecastData.hourly.windgusts_10m[index]))")
                                                    .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windgusts_10m[index]), siteType: siteType))
                                                Image(systemName: windArrow)
                                                    .rotationEffect(.degrees(forecastData.hourly.winddirection_10m[index] - 180))
                                            }
                                            Text(" ")
                                                .frame(maxWidth: .infinity)
                                                .overlay(
                                                    Rectangle()
                                                        .frame(height: 1)
                                                        .foregroundColor(tableDividerColor),
                                                    alignment: .center
                                                )
                                            Text(forecastData.hourly.formattedTopOfLiftAltitude?[index] ?? "")
                                            Text(forecastData.hourly.formattedCloudbaseAltitude?[index] ?? "")
                                            if maxPressureReading >= 500 {
                                                Text("\(forecastData.hourly.thermalVelocity_500hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_500hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_500hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 550 {
                                                Text("\(forecastData.hourly.thermalVelocity_550hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_550hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_550hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 600 {
                                                Text("\(forecastData.hourly.thermalVelocity_600hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_600hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_600hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 650 {
                                                Text("\(forecastData.hourly.thermalVelocity_650hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_650hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_650hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 700 {
                                                Text("\(forecastData.hourly.thermalVelocity_700hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_700hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_700hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 750 {
                                                Text("\(forecastData.hourly.thermalVelocity_750hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_750hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_750hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 800 {
                                                Text("\(forecastData.hourly.thermalVelocity_800hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_800hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_800hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 850 {
                                                Text("\(forecastData.hourly.thermalVelocity_850hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_850hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_850hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 900 {
                                                Text("\(forecastData.hourly.thermalVelocity_900hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_900hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_900hPa?[index] ?? 0))
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .overlay(
                                            Rectangle()
                                                .frame(width: 1)
                                                .foregroundColor(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)),
                                            alignment: .leading
                                        )
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(tableBackgroundColor)
                            .cornerRadius(15)
                        }
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            viewModel.fetchForecast(ForecastLat: forecastLat, ForecastLon: forecastLon)
        }
    }
    
    func getDividerColor (_ newDateFlag: Bool) -> Color {
        if newDateFlag {
            return tableDividerColor
        } else {
            return tableBackgroundColor
        }
    }
}
