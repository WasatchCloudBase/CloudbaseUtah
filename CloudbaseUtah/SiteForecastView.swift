//
//  SiteForecastView.swift
//  CloudbaseUtah
//
//  Created by Brown, Mike on 3/24/25.
//
import SwiftUI
import Combine

let MaxDisplayRows = 19        // Used to calculate the reduced rows based on surface altitude; needs to be updated if rows added to view

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
}

struct GoogleSheetsResponse: Codable {
    let range: String
    let majorDimension: String
    let values: [[String]]
}

class SiteForecastViewModel: ObservableObject {
    @Published var forecastData: ForecastData?
    @Published var weatherCodes: [String: String] = [:]
    @Published var displayRows: Int = 0                 // Number of forecast rows to display based on surface altitude
    @Published var maxPressureReading: Int = 1000       // Pressure to start displaying winds aloft (1000 hpa is sea level)
    
    func fetchForecast(ForecastLat: String, ForecastLon: String) {
        let urlString = "https://api.open-meteo.com/v1/gfs?latitude=\(ForecastLat)&longitude=\(ForecastLon)&hourly=temperature_2m,relativehumidity_2m,dewpoint_2m,pressure_msl,surface_pressure,precipitation,precipitation_probability,weathercode,cloudcover,cloudcover_low,cloudcover_mid,cloudcover_high,cape,lifted_index,windspeed_10m,windspeed_80m,winddirection_10m,windgusts_10m,temperature_950hPa,temperature_900hPa,temperature_850hPa,temperature_800hPa,temperature_750hPa,temperature_700hPa,temperature_650hPa,temperature_600hPa,temperature_550hPa,temperature_500hPa,dewpoint_950hPa,dewpoint_900hPa,dewpoint_850hPa,dewpoint_800hPa,dewpoint_750hPa,dewpoint_700hPa,dewpoint_650hPa,dewpoint_600hPa,dewpoint_550hPa,dewpoint_500hPa,windspeed_950hPa,windspeed_900hPa,windspeed_850hPa,windspeed_800hPa,windspeed_750hPa,windspeed_700hPa,windspeed_650hPa,windspeed_600hPa,windspeed_550hPa,windspeed_500hPa,winddirection_950hPa,winddirection_900hPa,winddirection_850hPa,winddirection_800hPa,winddirection_750hPa,winddirection_700hPa,winddirection_650hPa,winddirection_600hPa,winddirection_550hPa,winddirection_500hPa,geopotential_height_950hPa,geopotential_height_900hPa,geopotential_height_850hPa,geopotential_height_800hPa,geopotential_height_750hPa,geopotential_height_700hPa,geopotential_height_650hPa,geopotential_height_600hPa,geopotential_height_550hPa,geopotential_height_500hPa&current_weather=true&windspeed_unit=mph&precipitation_unit=inch&timezone=America%2FDenver"

        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
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
    
    func fetchWeatherCodes(completion: @escaping ([String: String]) -> Void) {
        let rangeName = "WeatherCodes"
        let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(GoogleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(GoogleApiKey)"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let result = try? decoder.decode(GoogleSheetsResponse.self, from: data) {
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
    
    private func filterForecastData(_ data: ForecastData) -> ForecastData {
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
            weatherCodeImage: []
        )
        
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
            displayRows -= 1
        }
        if data.hourly.geopotential_height_850hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 800
            displayRows -= 1
        }
        if data.hourly.geopotential_height_800hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 750
            displayRows -= 1
        }
        if data.hourly.geopotential_height_750hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 700
            displayRows -= 1
        }
        if data.hourly.geopotential_height_700hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 650
            displayRows -= 1
        }
        if data.hourly.geopotential_height_650hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 600
            displayRows -= 1
        }
        if data.hourly.geopotential_height_600hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 550
            displayRows -= 1
        }
        if data.hourly.geopotential_height_550hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 500
            displayRows -= 1
        }
        if data.hourly.geopotential_height_500hPa.first ?? 0 < surfaceAltitude {
            maxPressureReading = 450
            displayRows -= 1
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
                    }
                }
            }
        }
        return ForecastData(elevation: data.elevation, hourly: filteredHourly)
    }
}

struct SiteForecastView: View {
    @StateObject private var viewModel = SiteForecastViewModel()
    var forecastLat: String
    var forecastLon: String
    var forecastNote: String
    var siteType: String
    
    init(forecastLat: String, forecastLon: String, forecastNote: String, siteType: String) {
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

                    HStack(alignment: .top) {
                        LazyHGrid(rows: Array(repeating: GridItem(.fixed(14)), count: displayRows)) {
                            Group {
                                Text(" ")
                                Text(" ")
                                Text(" ")
                                Text("Temp")
                                Text("Skies")
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
                            }
                            .frame(width: 58, alignment: .trailing)
                        }
                        .padding(.vertical, 6)
                        
                        ScrollView(.horizontal) {
                            LazyHGrid(rows: Array(repeating: GridItem(.fixed(14)), count: displayRows)) {
                                if let forecastData = viewModel.forecastData {
                                    ForEach(forecastData.hourly.dateTime?.indices ?? 0..<0, id: \.self) { index in
                                        Group {
                                            if forecastData.hourly.newDateFlag?[index] ?? true {
                                                Text(forecastData.hourly.formattedDay?[index] ?? "")
                                            } else {
                                                Text(forecastData.hourly.formattedDay?[index] ?? "")
                                                    .foregroundColor(repeatDateTimeColor)
                                            }
                                            if forecastData.hourly.newDateFlag?[index] ?? true {
                                                Text(forecastData.hourly.formattedDate?[index] ?? "")
                                            } else {
                                                Text(forecastData.hourly.formattedDate?[index] ?? "")
                                                    .foregroundColor(repeatDateTimeColor)
                                            }
                                            Text(forecastData.hourly.formattedTime?[index] ?? "")
                                            Text("\(Int(forecastData.hourly.temperature_2m[index]))°")
                                                .foregroundStyle(tempColor(Int(forecastData.hourly.temperature_2m[index])))
                                            Image(systemName: forecastData.hourly.weatherCodeImage?[index] ?? "questionmark")
                                                .renderingMode(.original) // Use .multicolor for multicolor rendering
                                            Text(forecastData.hourly.cloudcover[index] == 0 ? "" : "\(Int(forecastData.hourly.cloudcover[index]))")
                                                .foregroundStyle(cloudCoverColor(Int(forecastData.hourly.cloudcover[index])))
                                            Text(forecastData.hourly.precipitation_probability[index] == 0 ? "" : "\(Int(forecastData.hourly.precipitation_probability[index]))")
                                                .foregroundStyle(precipColor(Int(forecastData.hourly.precipitation_probability[index])))
                                            Text(forecastData.hourly.cape[index] == 0 ? "" : "\(Int(forecastData.hourly.cape[index]))")
                                                .foregroundStyle(CAPEColor(Int(forecastData.hourly.cape[index])))
                                            Text(" ")
                                            if maxPressureReading >= 500 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_500hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_500hPa[index]), siteType: siteType))
                                                    Image(systemName: "arrow.up")
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_500hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 550 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_550hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_550hPa[index]), siteType: siteType))
                                                    Image(systemName: "arrow.up")
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_550hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 600 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_600hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_600hPa[index]), siteType: siteType))
                                                    Image(systemName: "arrow.up")
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_600hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 650 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_650hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_650hPa[index]), siteType: siteType))
                                                    Image(systemName: "arrow.up")
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_650hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 700 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_700hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_700hPa[index]), siteType: siteType))
                                                    Image(systemName: "arrow.up")
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_700hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 750 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_750hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_750hPa[index]), siteType: siteType))
                                                    Image(systemName: "arrow.up")
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_750hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 800 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_800hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_800hPa[index]), siteType: siteType))
                                                    Image(systemName: "arrow.up")
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_800hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 850 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_850hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_850hPa[index]), siteType: siteType))
                                                    Image(systemName: "arrow.up")
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_850hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 900 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_900hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_900hPa[index]), siteType: siteType))
                                                    Image(systemName: "arrow.up")
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_900hPa[index] - 180))
                                                }
                                            }
                                            HStack(spacing: 2) {
                                                Text("\(Int(forecastData.hourly.windspeed_10m[index]))")
                                                    .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_10m[index]), siteType: siteType))
                                                Text("g")
                                                    .font(.caption)
                                                Text("\(Int(forecastData.hourly.windgusts_10m[index]))")
                                                    .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windgusts_10m[index]), siteType: siteType))
                                                Image(systemName: "arrow.up")
                                                    .rotationEffect(.degrees(forecastData.hourly.winddirection_10m[index] - 180))
                                            }
                                        }
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
}
