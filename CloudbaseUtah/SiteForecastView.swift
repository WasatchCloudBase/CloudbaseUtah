//
//  SiteForecastView.swift
//  CloudbaseUtah
//
//  Created by Brown, Mike on 3/24/25.
//
import SwiftUI
import Combine

struct ForecastData: Codable {
    let elevation: Double
    let hourly: HourlyData
}

struct HourlyData: Codable {
    let time: [String]
    let weathercode: [Int]
    let cloudcover: [Double]
    let precipitation_probability: [Double]
    let cape: [Double]
    let temperature_2m: [Double]
    let windspeed_500hPa: [Double]
    let windspeed_550hPa: [Double]
    let windspeed_600hPa: [Double]
    let windspeed_650hPa: [Double]
    let windspeed_700hPa: [Double]
    let windspeed_750hPa: [Double]
    let windspeed_800hPa: [Double]
    let windspeed_850hPa: [Double]
    let windspeed_900hPa: [Double]
    let windspeed_10m: [Double]
}

class SiteForecastViewModel: ObservableObject {
    @Published var forecastData: ForecastData?
    
    func fetchForecast(ForecastLat: String, ForecastLon: String) {
        let urlString = "https://api.open-meteo.com/v1/gfs?latitude=\(ForecastLat)&longitude=\(ForecastLon)&hourly=temperature_2m,relativehumidity_2m,dewpoint_2m,pressure_msl,surface_pressure,precipitation,precipitation_probability,weathercode,cloudcover,cloudcover_low,cloudcover_mid,cloudcover_high,cape,lifted_index,windspeed_10m,windspeed_80m,winddirection_10m,windgusts_10m,temperature_950hPa,temperature_900hPa,temperature_850hPa,temperature_800hPa,temperature_750hPa,temperature_700hPa,temperature_650hPa,temperature_600hPa,temperature_550hPa,temperature_500hPa,dewpoint_950hPa,dewpoint_900hPa,dewpoint_850hPa,dewpoint_800hPa,dewpoint_750hPa,dewpoint_700hPa,dewpoint_650hPa,dewpoint_600hPa,dewpoint_550hPa,dewpoint_500hPa,windspeed_950hPa,windspeed_900hPa,windspeed_850hPa,windspeed_800hPa,windspeed_750hPa,windspeed_700hPa,windspeed_650hPa,windspeed_600hPa,windspeed_550hPa,windspeed_500hPa,winddirection_950hPa,winddirection_900hPa,winddirection_850hPa,winddirection_800hPa,winddirection_750hPa,winddirection_700hPa,winddirection_650hPa,winddirection_600hPa,winddirection_550hPa,winddirection_500hPa,geopotential_height_950hPa,geopotential_height_900hPa,geopotential_height_850hPa,geopotential_height_800hPa,geopotential_height_750hPa,geopotential_height_700hPa,geopotential_height_650hPa,geopotential_height_600hPa,geopotential_height_550hPa,geopotential_height_500hPa&current_weather=true&windspeed_unit=mph&precipitation_unit=inch&timezone=America%2FDenver"

        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let forecastData = try? decoder.decode(ForecastData.self, from: data) {
                    DispatchQueue.main.async {
                        self.forecastData = forecastData
                    }
                }
            }
        }.resume()
    }
}

struct SiteForecastView: View {
    @StateObject private var viewModel = SiteForecastViewModel()
    var forecastLat: String
    var forecastLon: String
    var forecastNote: String
    
    init(forecastLat: String, forecastLon: String, forecastNote: String) {
        self.forecastLat = forecastLat
        self.forecastLon = forecastLon
        self.forecastNote = forecastNote
    }
    
    func formatDate(_ date: String, format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let dateObj = dateFormatter.date(from: date) else { return date }
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: dateObj)
    }
    
    func formatTime(_ time: String, format: String) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        guard let timeObj = timeFormatter.date(from: time) else { return time }
        timeFormatter.dateFormat = format
        return timeFormatter.string(from: timeObj)
    }
    
    var body: some View {
        VStack (alignment: .leading) {
            if let forecastData = viewModel.forecastData {
                VStack(alignment: .leading) {
                    Text(buildReferenceNote(Alt: "\(convertMetersToFeet(forecastData.elevation))", Note: forecastNote))
                        .font(.footnote)
                        .foregroundColor(infoFontColor)
                        .padding(.top, 8)
                        .padding(.bottom, 5)
                    HStack(alignment: .top) {
                        LazyHGrid(rows: Array(repeating: GridItem(.fixed(14)), count: 17)) {
                            Group {
                                Text("Date")
                                Text("Time")
                                Text("Weather")
                                Text("Cloud Cover")
                                Text("Precip %")
                                Text("CAPE")
                                Text("Temp (2m)")
                                Text("Wind (500 hpa)")
                                Text("Wind (550 hpa)")
                                Text("Wind (600 hpa)")
                                Text("Wind (650 hpa)")
                                Text("Wind (700 hpa)")
                                Text("Wind (750 hpa)")
                                Text("Wind (800 hpa)")
                                Text("Wind (850 hpa)")
                                Text("Wind (900 hpa)")
                                Text("Wind (10 m)")
                            }
                            .frame(width: 125, alignment: .leading)
                            .background(Color.gray.opacity(0.2))
                            .border(Color.black)
                        }
                        
                        ScrollView(.horizontal) {
                            LazyHGrid(rows: Array(repeating: GridItem(.fixed(14)), count: 17)) {
                                if let forecastData = viewModel.forecastData {
                                    ForEach(forecastData.hourly.time.indices, id: \.self) { index in
                                        let time = forecastData.hourly.time[index]
                                        let date = String(time.prefix(10))
                                        let formattedDate = formatDate(date, format: "E, MMM d")
                                        let formattedTime = formatTime(time, format: "HH:mm")
                                        
                                        Group {
                                            Text(formattedDate)
                                            Text(formattedTime)
                                            Text("\(forecastData.hourly.weathercode[index])")
                                            Text("\(Int(forecastData.hourly.cloudcover[index]))")
                                            Text("\(Int(forecastData.hourly.precipitation_probability[index]))")
                                            Text("\(Int(forecastData.hourly.cape[index]))")
                                            let tempF = (forecastData.hourly.temperature_2m[index] * 9/5) + 32
                                            Text("\(Int(tempF))")
                                            Text("\(Int(forecastData.hourly.windspeed_500hPa[index]))")
                                            Text("\(Int(forecastData.hourly.windspeed_550hPa[index]))")
                                            Text("\(Int(forecastData.hourly.windspeed_600hPa[index]))")
                                            Text("\(Int(forecastData.hourly.windspeed_650hPa[index]))")
                                            Text("\(Int(forecastData.hourly.windspeed_700hPa[index]))")
                                            Text("\(Int(forecastData.hourly.windspeed_750hPa[index]))")
                                            Text("\(Int(forecastData.hourly.windspeed_800hPa[index]))")
                                            Text("\(Int(forecastData.hourly.windspeed_850hPa[index]))")
                                            Text("\(Int(forecastData.hourly.windspeed_900hPa[index]))")
                                            Text("\(Int(forecastData.hourly.windspeed_10m[index]))")
                                        }
                                        .frame(width: 100, alignment: .center)
                                        .border(Color.black)
                                    }
                                }
                            }
                        }
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
