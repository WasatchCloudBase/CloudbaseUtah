//
//  SiteForecast.swift
//  CloudbaseUtah
//
//  Created by Brown, Mike on 3/31/25.
//
import SwiftUI
import Combine

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
    var topOfLiftTemp: [Double]?
    // formatted variables to prevent errors where compiler cannot determine types when converting double to string in a view
    var formattedCloudbaseAltitude: [String]?
    var topOfLiftAltitude: [Double]?
    var formattedTopOfLiftAltitude: [String]?
    var formattedTopOfLiftTemp: [String]?
    var formattedCAPE: [String]?
    var formattedPrecipProbability: [String]?
    var formattedCloudCover: [String]?
    var formattedSurfaceTemp: [String]?
}

// Structure used to store data that is common for all altitudes and pass to thermal calculation function
struct ForecastBaseData {
    var siteName: String
    var date: String
    var time: String
    var surfaceAltitude: Double
    var surfaceTemp: Double
}

class SiteForecastViewModel: ObservableObject {
    @Published var forecastData: ForecastData?
    private var liftParametersViewModel: LiftParametersViewModel
    private var sunriseSunsetViewModel: SunriseSunsetViewModel
    private var weatherCodesViewModel: WeatherCodesViewModel
    @Published var weatherCodes: [String: String] = [:]
    @Published var maxPressureReading: Int = 1000       // Pressure to start displaying winds aloft (1000 hpa is sea level)
    
    // Make thermal lift parameters, weather code images, and sunrise/sunset times available in this view model
    init(liftParametersViewModel: LiftParametersViewModel,
         sunriseSunsetViewModel: SunriseSunsetViewModel,
         weatherCodesViewModel: WeatherCodesViewModel) {
        self.liftParametersViewModel = liftParametersViewModel
        self.sunriseSunsetViewModel = sunriseSunsetViewModel
        self.weatherCodesViewModel = weatherCodesViewModel
    }
    
    func fetchForecast(SiteName: String, ForecastLat: String, ForecastLon: String) {
        
        // Get forecast
        let forecastURLString = "https://api.open-meteo.com/v1/gfs?latitude=\(ForecastLat)&longitude=\(ForecastLon)&hourly=temperature_2m,relativehumidity_2m,dewpoint_2m,pressure_msl,surface_pressure,precipitation,precipitation_probability,weathercode,cloudcover,cloudcover_low,cloudcover_mid,cloudcover_high,cape,lifted_index,windspeed_10m,windspeed_80m,winddirection_10m,windgusts_10m,temperature_950hPa,temperature_900hPa,temperature_850hPa,temperature_800hPa,temperature_750hPa,temperature_700hPa,temperature_650hPa,temperature_600hPa,temperature_550hPa,temperature_500hPa,dewpoint_950hPa,dewpoint_900hPa,dewpoint_850hPa,dewpoint_800hPa,dewpoint_750hPa,dewpoint_700hPa,dewpoint_650hPa,dewpoint_600hPa,dewpoint_550hPa,dewpoint_500hPa,windspeed_950hPa,windspeed_900hPa,windspeed_850hPa,windspeed_800hPa,windspeed_750hPa,windspeed_700hPa,windspeed_650hPa,windspeed_600hPa,windspeed_550hPa,windspeed_500hPa,winddirection_950hPa,winddirection_900hPa,winddirection_850hPa,winddirection_800hPa,winddirection_750hPa,winddirection_700hPa,winddirection_650hPa,winddirection_600hPa,winddirection_550hPa,winddirection_500hPa,geopotential_height_950hPa,geopotential_height_900hPa,geopotential_height_850hPa,geopotential_height_800hPa,geopotential_height_750hPa,geopotential_height_700hPa,geopotential_height_650hPa,geopotential_height_600hPa,geopotential_height_550hPa,geopotential_height_500hPa&current_weather=true&windspeed_unit=mph&precipitation_unit=inch&timezone=America%2FDenver"
        
        if printForecastURL { print(forecastURLString) }
        
        guard let forecastURL = URL(string: forecastURLString) else { return }
        URLSession.shared.dataTask(with: forecastURL) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                // Remove occasional value of null in the results
                let modifiedData = replaceNullsInJSON(data: data)
                // Uses the original data as the default if the removal of nulls failed
                if let forecastData = try? decoder.decode(ForecastData.self, from: modifiedData ?? data) {
                    DispatchQueue.main.async {
                        self.forecastData = self.filterForecastData(siteName: SiteName, data: forecastData)
                    }
                } else {
                    print("JSON decode failed for forecast")
                }
            }
        }.resume()
    }
    
    func filterForecastData(siteName: String, data: ForecastData) -> ForecastData {
        
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
            topOfLiftTemp: [],
            formattedCloudbaseAltitude: [],
            topOfLiftAltitude: [],
            formattedTopOfLiftAltitude: [],
            formattedTopOfLiftTemp: [],
            formattedCAPE: [],
            formattedPrecipProbability: [],
            formattedCloudCover: [],
            formattedSurfaceTemp: []
        )
        
        // Get sunrise/sunset times from environment object
        var forecastStartTime = 6
        var forecastEndTime = 21
        if let sunriseSunset = sunriseSunsetViewModel.sunriseSunset {
            // Get the hour from sunrise and sunset times (provided in format hh:mm)
            // Add 13 to sunset to convert to pm and provide forecast at least until after sunset
            forecastStartTime = Int(sunriseSunset.sunrise.split(separator: ":", maxSplits: 1).first ?? "6") ?? 6
            forecastEndTime = ( Int(sunriseSunset.sunset.split(separator: ":", maxSplits: 1).first ?? "6") ?? 6 ) + 13
        } else {
            print("Sunrise/sunset not available")
            if turnOnLogging {logToFile("Sunrise/sunset times not available") }
        }
        
        let currentDate = Date()
        let startOfDay = Calendar.current.startOfDay(for: currentDate)
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: currentDate)!
        var priorReadingFormattedDate: String?
        var newDateFlag: Bool = true
        var thermalTriggerReachedForDay: Bool = false
        
        // Determine altitude in feet and limit wind readings to only those more than 200 ft above the surface
        // by reducing the number of rows to display and specifying the max pressure reading to display
        let surfaceAltitude = Double(convertMetersToFeet(data.elevation) + 10).rounded()
        let surfaceBuffer = 200.0           // Don't display winds aloft within surface buffer distance above surface
        var maxPressureReading: Int = 1000  // hPa, which is sea level
        if (data.hourly.geopotential_height_900hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 850 }
        if (data.hourly.geopotential_height_850hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 800 }
        if (data.hourly.geopotential_height_800hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 750 }
        if (data.hourly.geopotential_height_750hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 700 }
        if (data.hourly.geopotential_height_700hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 650 }
        if (data.hourly.geopotential_height_650hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 600 }
        if (data.hourly.geopotential_height_600hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 550 }
        if (data.hourly.geopotential_height_550hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 500 }
        if (data.hourly.geopotential_height_500hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 450 }
        self.maxPressureReading = maxPressureReading

        for (index, time) in data.hourly.time.enumerated() {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            if let timeObj = timeFormatter.date(from: time) {
                // Process all times starting at beginning of today in order to correctly calculate if
                // thermal trigger temperature was reached for today.
                // There is logic below to filter the display for only times starting from one hour prior to now
                if timeObj >= startOfDay {
                    let hour = Calendar.current.component(.hour, from: timeObj)
                    if hour >= forecastStartTime && hour <= forecastEndTime {

                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "E"
                        let formattedDay = dateFormatter.string(from: timeObj)
                        dateFormatter.dateFormat = "M/d"
                        let formattedDate = dateFormatter.string(from: timeObj)
                        timeFormatter.dateFormat = "h a"
                        let formattedTime = timeFormatter.string(from: timeObj).lowercased()
                        let surfaceTemp = convertCelsiusToFahrenheit(Int(data.hourly.temperature_2m[index]))
                                                
                        // Determine if this reading is a new day to set a divider in the view
                        if formattedDate == priorReadingFormattedDate {
                            newDateFlag = false
                        } else {
                            newDateFlag = true
                            // Reset thermal trigger temp reached for the day
                            thermalTriggerReachedForDay = false
                        }
                        priorReadingFormattedDate = formattedDate
                        
                        // Set weather code image
                        var weatherCodeImage = self.weatherCodesViewModel.weatherCodeImage(for: data.hourly.weathercode[index]) ?? ""
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
                        
                        // Create variables to store thermal lift at each altitude
                        var thermalVelocity_900hPa: Double = 0.0
                        var thermalVelocity_850hPa: Double = 0.0
                        var thermalVelocity_800hPa: Double = 0.0
                        var thermalVelocity_750hPa: Double = 0.0
                        var thermalVelocity_700hPa: Double = 0.0
                        var thermalVelocity_650hPa: Double = 0.0
                        var thermalVelocity_600hPa: Double = 0.0
                        var thermalVelocity_550hPa: Double = 0.0
                        var thermalVelocity_500hPa: Double = 0.0
                        
                        // Set base data (common for all altitudes) used to calculate thermal velocity
                        let forecastBaseData = ForecastBaseData(
                            siteName: siteName,
                            date: formattedDate,
                            time: formattedTime,
                            surfaceAltitude: surfaceAltitude,
                            surfaceTemp: data.hourly.temperature_2m[index]
                        )
                        // 900 hpa pressure level thermal calcs
                        var thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_900hPa[index],
                            ambientTemp: data.hourly.temperature_900hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_900hPa[index],
                            priorAmbientDPTemp: 0.0,
                            priorThermalDPTemp: data.hourly.temperature_2m[index],
                            priorAltitude: surfaceAltitude,
                            thermalTriggerReachedForDay: thermalTriggerReachedForDay,
                            topOfLiftAltitude: 0.0,
                            topOfLiftTemp: 0.0,
                            cloudbaseAltitude: 0.0)
                        thermalVelocity_900hPa = thermalResult.thermalVelocity
                        
                        // 850 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_850hPa[index],
                            ambientTemp: data.hourly.temperature_850hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_850hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_900hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_900hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_850hPa = thermalResult.thermalVelocity
                        
                        // 800 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_800hPa[index],
                            ambientTemp: data.hourly.temperature_800hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_800hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_850hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_850hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_800hPa = thermalResult.thermalVelocity
                        
                        // 750 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_750hPa[index],
                            ambientTemp: data.hourly.temperature_750hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_750hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_800hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_800hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_750hPa = thermalResult.thermalVelocity
                        
                        // 700 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_700hPa[index],
                            ambientTemp: data.hourly.temperature_700hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_700hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_750hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_750hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_700hPa = thermalResult.thermalVelocity
                        
                        // 650 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_650hPa[index],
                            ambientTemp: data.hourly.temperature_650hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_650hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_700hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_700hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_650hPa = thermalResult.thermalVelocity
                        
                        // 600 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_600hPa[index],
                            ambientTemp: data.hourly.temperature_600hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_600hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_650hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_650hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_600hPa = thermalResult.thermalVelocity
                        
                        // 550 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_550hPa[index],
                            ambientTemp: data.hourly.temperature_550hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_550hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_600hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_600hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_550hPa = thermalResult.thermalVelocity
                        
                        // 500 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_500hPa[index],
                            ambientTemp: data.hourly.temperature_500hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_500hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_550hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_550hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_500hPa = thermalResult.thermalVelocity

                        // Maintain status if thermal trigger has been reached for the day
                        thermalTriggerReachedForDay = thermalResult.thermalTriggerReachedForDay
                        
                        // Format cloudbase data
                        // Altitudes are / 1000 so they can be displayed like "13k)
                        var formattedCloudbaseAltitude = ""
                        if thermalResult.cloudbaseAltitude > 0 {
                            formattedCloudbaseAltitude = String(Int((thermalResult.cloudbaseAltitude/1000).rounded())) + "k"
                        }
                        
                        // Format top of lift data
                        // Altitudes are / 1000 so they can be displayed like "13k)
                        var topOfLiftAltitude = thermalResult.topOfLiftAltitude
                        var formattedTopOfLiftAltitude = ""
                        var topOfLiftTemp = 0.0
                        if topOfLiftAltitude > 0 {
                            if topOfLiftAltitude > surfaceAltitude {
                                formattedTopOfLiftAltitude = String(Int((topOfLiftAltitude/1000).rounded())) + "k"
                            } else {
                                formattedTopOfLiftAltitude = ""
                                topOfLiftTemp = data.hourly.temperature_2m[index]
                            }
                        } else if thermalResult.thermalDPTemp > data.hourly.dewpoint_500hPa[index] {
                            // Never reached top of lift
                            formattedTopOfLiftAltitude = "rocket"
                            topOfLiftAltitude = defaultTopOfLiftAltitude
                            topOfLiftTemp = data.hourly.temperature_500hPa[index]
                        }
                        // Convert top of Lift Temp to F
                        let topOfLiftTempF = convertCelsiusToFahrenheit(Int(topOfLiftTemp))

                        // Only append display structure for times that are no more than an hour ago
                        // (earlier times only processed to determine if thermal trigger temp has already been reached today)
                        if timeObj >= oneHourAgo {
                            filteredHourly.time.append(time)
                            filteredHourly.dateTime?.append(timeObj)
                            filteredHourly.formattedDay?.append(formattedDay)
                            filteredHourly.formattedDate?.append(formattedDate)
                            filteredHourly.formattedTime?.append(formattedTime)
                            filteredHourly.newDateFlag?.append(newDateFlag)
                            filteredHourly.weatherCodeImage?.append(weatherCodeImage)
                            filteredHourly.weathercode.append(data.hourly.weathercode[index])
                            filteredHourly.cloudcover.append(data.hourly.cloudcover[index])
                            if data.hourly.cloudcover[index] == 0 {
                                filteredHourly.formattedCloudCover?.append("")
                            } else {
                                filteredHourly.formattedCloudCover?.append(String(Int(data.hourly.cloudcover[index])))
                            }
                            filteredHourly.precipitation_probability.append(data.hourly.precipitation_probability[index])
                            if data.hourly.precipitation_probability[index] == 0 {
                                filteredHourly.formattedPrecipProbability?.append("")
                            } else {
                                filteredHourly.formattedPrecipProbability?.append(String(Int(data.hourly.precipitation_probability[index])))
                            }
                            filteredHourly.cape.append(data.hourly.cape[index])
                            if data.hourly.cape[index].rounded() == 0 {
                                filteredHourly.formattedCAPE?.append("")
                            } else {
                                filteredHourly.formattedCAPE?.append(String(Int(data.hourly.cape[index].rounded())))
                            }
                            filteredHourly.temperature_2m.append(Double(surfaceTemp))
                            filteredHourly.formattedSurfaceTemp?.append(String(surfaceTemp) + "°")
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
                            filteredHourly.thermalVelocity_900hPa?.append(thermalVelocity_900hPa)
                            filteredHourly.thermalVelocity_850hPa?.append(thermalVelocity_850hPa)
                            filteredHourly.thermalVelocity_800hPa?.append(thermalVelocity_800hPa)
                            filteredHourly.thermalVelocity_750hPa?.append(thermalVelocity_750hPa)
                            filteredHourly.thermalVelocity_700hPa?.append(thermalVelocity_700hPa)
                            filteredHourly.thermalVelocity_650hPa?.append(thermalVelocity_650hPa)
                            filteredHourly.thermalVelocity_600hPa?.append(thermalVelocity_600hPa)
                            filteredHourly.thermalVelocity_550hPa?.append(thermalVelocity_550hPa)
                            filteredHourly.thermalVelocity_500hPa?.append(thermalVelocity_500hPa)
                            // Add top of lift results to data structure
                            filteredHourly.formattedCloudbaseAltitude?.append(formattedCloudbaseAltitude)
                            if topOfLiftAltitude.isNaN {
                                print(String(topOfLiftAltitude))
                                topOfLiftAltitude = 0 }
                            // Set top of lift altitude to a minimum of surface altitude for area chart
                            // (leaves formatted top of lift altitude set to ""
                            filteredHourly.topOfLiftAltitude?.append(max(topOfLiftAltitude, surfaceAltitude))
                            filteredHourly.formattedTopOfLiftAltitude?.append(formattedTopOfLiftAltitude)
                            filteredHourly.topOfLiftTemp?.append(Double(topOfLiftTempF))
                            filteredHourly.formattedTopOfLiftTemp?.append(String(topOfLiftTempF) + "°")
                        }
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
        let topOfLiftTemp: Double
        let thermalTriggerReachedForDay: Bool
    }
    
    func calcThermalVelocity(
        forecastBaseData: ForecastBaseData,
        altitude: Double,
        ambientTemp: Double,
        ambientDPTemp: Double,
        priorAmbientDPTemp: Double,
        priorThermalDPTemp: Double,
        priorAltitude: Double,
        thermalTriggerReachedForDay: Bool,
        topOfLiftAltitude: Double,
        topOfLiftTemp: Double,
        cloudbaseAltitude: Double
    ) -> ThermalResult {

        // Set buffer for calculation altitudes (should be the same as the buffer set in the above function)
        let surfaceBuffer = 200.0
        
        // Base values passed (common for all altitudes)
        let siteName = forecastBaseData.siteName
        let forecastDate = forecastBaseData.date
        let forecastTime = forecastBaseData.time
        let surfaceAltitude = forecastBaseData.surfaceAltitude
        let surfaceTemp = forecastBaseData.surfaceTemp
        
        // Initial values (setting here to allow all to be written to log file)
        var thermalDPTemp = priorThermalDPTemp
        var thermalVelocity: Double = 0.0
        var cloudbaseRatio: Double = 0.0
        var cloudbaseAltitude = cloudbaseAltitude
        var topOfLiftAltitude  = topOfLiftAltitude
        var topOfLiftTemp = topOfLiftTemp
        var thermalTriggerReachedForDay = thermalTriggerReachedForDay
        var topOfLiftRatio: Double = 0.0
        var altitudeChange: Double = 0.0
        var thermalRampTop: Double = 0.0
        var rampImpactAltitude: Double = 0.0
        var rampImpactPortion: Double = 0.0
        var rampReductionFactor: Double = 0.0
        var thermalDPTempToAmbientDPTempDiff: Double = 0.0
        var ambientTempToAmbientDPTempDiff: Double = 0.0
        var ambientDPTempDiff: Double = 0.0
        var priorAmbientDPTempToAmbientTempDiff: Double = 0.0
        var priorAltitudeThermalDPDiff: Double = 0.0
        var priorThermalDPTempToAmbientDPTempDiff: Double = 0.0

        // Get thermal lift parameters from environment object
        guard let liftParameters = liftParametersViewModel.liftParameters else {
            // End processing if lift parameters are not available
            print("Error - thermal lift parameters not available")
            if turnOnLogging {logToFile("Error - thermal lift parameters not available") }
            return ThermalResult(
                thermalVelocity: thermalVelocity,
                thermalDPTemp: thermalDPTemp,
                cloudbaseAltitude: cloudbaseAltitude,
                topOfLiftAltitude: topOfLiftAltitude,
                topOfLiftTemp: topOfLiftTemp,
                thermalTriggerReachedForDay: thermalTriggerReachedForDay)
        }

        // Check if altitude is less than surfaceAltitude
        guard altitude >= (surfaceAltitude + surfaceBuffer) else {
            // End processing if altitude is less than surfaceAltitude
            return ThermalResult(
                thermalVelocity: thermalVelocity,
                thermalDPTemp: thermalDPTemp,
                cloudbaseAltitude: cloudbaseAltitude,
                topOfLiftAltitude: topOfLiftAltitude,
                topOfLiftTemp: topOfLiftTemp,
                thermalTriggerReachedForDay: thermalTriggerReachedForDay)
        }
        
        // Set priorAltitude to surfaceAltitude if it is less than surfaceAltitude
        let adjustedPriorAltitude = priorAltitude < surfaceAltitude ? surfaceAltitude : priorAltitude
        
        // Only process if top of lift has not been previously reached
        if topOfLiftAltitude < surfaceAltitude {
            
            // Check if initial thermal trigger temperature difference between ground temp and ambient temp is not yet reached for the day
            // If it has previously been reached, use ongoing thermal trigger temperature difference instead
            var adjustedThermalTriggerTempDiff = liftParameters.initialTriggerTempDiff
            if thermalTriggerReachedForDay {
                adjustedThermalTriggerTempDiff = liftParameters.ongoingTriggerTempDiff
            }
            // if thermals not yet triggering; set top of lift to surface altitude
            if  surfaceTemp < ( ambientTemp + adjustedThermalTriggerTempDiff) {
                topOfLiftAltitude = adjustedPriorAltitude
            }
            // Thermal trigger temp reached...continue processing
            else {

                // Ensure thermal trigger temp reached is set to true
                thermalTriggerReachedForDay = true
                
                // Determine altitude change
                altitudeChange = altitude - adjustedPriorAltitude
                
                // Convert altitude from feet to kilometers
                let altitudeKm = convertFeetToMeters(altitude) / 1000
                let adjustedPriorAltitudeKm = convertFeetToMeters(adjustedPriorAltitude) / 1000
                let altitudeChangeKm = altitudeKm - adjustedPriorAltitudeKm
                
                // Td = T - (DALR * altitudeChange in km) where DALR is the thermalLapseRate
                thermalDPTemp = priorThermalDPTemp - ( liftParameters.thermalLapseRate * altitudeChangeKm )
                
                // Calculate temperature differences
                thermalDPTempToAmbientDPTempDiff = max( (thermalDPTemp - ambientDPTemp), 0.0 )
                ambientTempToAmbientDPTempDiff = max( (ambientTemp - ambientDPTemp), 0.0 )
                ambientDPTempDiff = max( (priorAmbientDPTemp - ambientDPTemp), 0.0 )
                priorAmbientDPTempToAmbientTempDiff = max( priorAmbientDPTemp - ambientTemp, 0.0)
                priorAltitudeThermalDPDiff = max( (priorAmbientDPTemp - thermalDPTemp), 0.0 )
                priorThermalDPTempToAmbientDPTempDiff = max( (priorThermalDPTemp - priorAmbientDPTemp), 0.0 )
                
                // Determine if cloudbase is reached (thermal dew point temp does not exceed ambient temp)
                if  ambientTemp <= ambientDPTemp {
                    if ambientDPTempDiff == 0 {
                        cloudbaseAltitude = adjustedPriorAltitude
                    } else {
                        cloudbaseRatio = priorAmbientDPTempToAmbientTempDiff / priorAltitudeThermalDPDiff
                        cloudbaseAltitude = adjustedPriorAltitude + ( altitudeChange * cloudbaseRatio )
                    }
                }
                
                // Determine if top of lift is reached (thermal dew point temp does not exceed ambient dew point)
                if thermalDPTemp <= ambientDPTemp {
                    if priorThermalDPTempToAmbientDPTempDiff == 0 {
                        topOfLiftAltitude = adjustedPriorAltitude
                        topOfLiftTemp = ambientTemp     // Should actually be prior ambient temp, which is not available
                    } else {
                        if priorAltitudeThermalDPDiff == 0 {
                            // Prior ambient DP temp <= thermal DP temp (top of lift should have been already reached)
                            // May be indicative of an inversion layer
                            topOfLiftAltitude = adjustedPriorAltitude
                            topOfLiftTemp = ambientTemp     // Should actually be prior ambient temp, which is not available
                        } else {
                            topOfLiftRatio = ( priorAmbientDPTempToAmbientTempDiff / priorAltitudeThermalDPDiff )
                            if topOfLiftRatio.isNaN {
                                print("topOfLiftRatio is NaN, \(priorAmbientDPTempToAmbientTempDiff), \(priorAltitudeThermalDPDiff), \(priorAmbientDPTemp), \(thermalDPTemp)")
                                topOfLiftRatio = 0.0
                            }
                            topOfLiftAltitude = adjustedPriorAltitude + ( altitudeChange * topOfLiftRatio )
                            topOfLiftTemp = ambientTemp     // Should actually be a ratio of prior and current ambient Temps
                        }
                    }
                }
                
                // If cloudbase < top of lift, set top of (usable) lift to cloudbase
                if cloudbaseAltitude > 0.0 && topOfLiftAltitude > 0.0 && cloudbaseAltitude < topOfLiftAltitude {
                    topOfLiftAltitude = cloudbaseAltitude
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
                    
                    // Adjust thermal velocity for glider sink rate
                    thermalVelocity = max( (thermalVelocity - liftParameters.thermalGliderSinkRate ), 0.0)
                    
                    // Adjust down top of usaeable lift if thermalVelocity is less than glider sink rate
                    if thermalVelocity <= 0 {
                        if topOfLiftAltitude > 0 {
                            topOfLiftAltitude = min(altitude, topOfLiftAltitude)
                            topOfLiftTemp = ambientTemp
                        } else {
                            // Set top of lift conservatively to the bottom of the altitude range being evaluated
                            topOfLiftAltitude = adjustedPriorAltitude
                            topOfLiftTemp = ambientTemp     // Should actually be prior ambient temp, which is not available
                        }
                    }
                }
            }
        }
        
        // If logging is turned on, write data for thermal calc troubleshooting
        if turnOnLogging {
            logToFile(
                "\(siteName)," +
                "\(forecastDate)," +
                "\(forecastTime)," +
                "\(surfaceAltitude)," +
                "\(surfaceTemp)," +
                "\(altitude)," +
                "\(ambientTemp)," +
                "\(ambientDPTemp)," +
                "\(thermalVelocity)," +
                "\(thermalTriggerReachedForDay)," +
                "\(topOfLiftAltitude)," +
                "\(cloudbaseAltitude)," +
                "\(adjustedPriorAltitude)," +
                "\(altitudeChange)," +
                "\(topOfLiftRatio)," +
                "\(cloudbaseRatio)," +
                "\(priorAmbientDPTemp)," +
                "\(thermalDPTemp)," +
                "\(priorThermalDPTemp)," +
                "\(thermalDPTempToAmbientDPTempDiff)," +
                "\(ambientTempToAmbientDPTempDiff)," +
                "\(ambientDPTempDiff)," +
                "\(priorThermalDPTempToAmbientDPTempDiff)," +
                "\(priorAmbientDPTempToAmbientTempDiff)," +
                "\(thermalRampTop)," +
                "\(rampImpactAltitude)," +
                "\(rampImpactPortion)," +
                "\(rampReductionFactor)," +
                "\(liftParameters.thermalLapseRate)," +
                "\(liftParameters.thermalVelocityConstant)," +
                "\(liftParameters.initialTriggerTempDiff)," +
                "\(liftParameters.ongoingTriggerTempDiff)," +
                "\(liftParameters.thermalRampDistance)," +
                "\(liftParameters.thermalRampStartPct)," +
                "\(liftParameters.cloudbaseLapseRatesDiff)," +
                "\(liftParameters.thermalGliderSinkRate)"
            )
        }
        
        return ThermalResult(
            thermalVelocity: roundToOneDecimal(thermalVelocity),
            thermalDPTemp: thermalDPTemp,
            cloudbaseAltitude: cloudbaseAltitude,
            topOfLiftAltitude: topOfLiftAltitude,
            topOfLiftTemp: topOfLiftTemp,
            thermalTriggerReachedForDay: thermalTriggerReachedForDay
        )
    }
}
