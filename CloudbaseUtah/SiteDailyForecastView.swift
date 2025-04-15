//
//  SiteDailyForecast.swift
//  CloudbaseUtah
//
//  Created by Brown, Mike on 4/12/25.
//
import SwiftUI
import Combine

struct DailyForecastData: Codable {
    var elevation: Double
    var daily: Daily
}

struct Daily: Codable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let precipitation_sum: [Double]
    let precipitation_probability_max: [Int]
    let wind_speed_10m_max: [Double]
    let wind_gusts_10m_max: [Double]
    let wind_direction_10m_dominant: [Int]
    var forecastDay: [String]?
    var forecastDate: [String]?
    var weatherCodeImage: [String]?
    var formattedMinTemp: [String]?
    var formattedMaxTemp: [String]?
    var precipImage: [String]?
}

class DailyForecastViewModel: ObservableObject {
    @Published var dailyForecastData: DailyForecastData?
    private var weatherCodesViewModel: WeatherCodesViewModel
    private var cancellable: AnyCancellable?
    
    // Make weather code images available in this view model
    init(weatherCodesViewModel: WeatherCodesViewModel) { self.weatherCodesViewModel = weatherCodesViewModel }

    func fetchDailyWeatherData(latitude: String, longitude: String) {
        let dailyForecastURLString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant&timezone=America%2FDenver&wind_speed_unit=mph&temperature_unit=fahrenheit&precipitation_unit=inch"

        if printForecastURL { print(dailyForecastURLString) }

        guard let dailyForecastURL = URL(string: dailyForecastURLString) else { return }
        URLSession.shared.dataTask(with: dailyForecastURL) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                // Remove occasional value of null in the results
                let modifiedData = replaceNullsInJSON(data: data)
                // Uses the original data as the default if the removal of nulls failed
                if let dailyForecastData = try? decoder.decode(DailyForecastData.self, from: modifiedData ?? data) {
                    DispatchQueue.main.async {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        let dayFormatter = DateFormatter()
                        dayFormatter.dateFormat = "E"
                        let shortDateFormatter = DateFormatter()
                        shortDateFormatter.dateFormat = "M/d"
                        
                        // Initialize optional data arrays
                        var forecastDay = [String](repeating: "", count: dailyForecastData.daily.time.count)
                        var forecastDate = [String](repeating: "", count: dailyForecastData.daily.time.count)
                        var weatherCodeImage = [String](repeating: "", count: dailyForecastData.daily.time.count)
                        var formattedMaxTemp = [String](repeating: "", count: dailyForecastData.daily.time.count)
                        var formattedMinTemp = [String](repeating: "", count: dailyForecastData.daily.time.count)
                        var precipImage = [String](repeating: "", count: dailyForecastData.daily.time.count)
                        
                        for index in 0..<dailyForecastData.daily.time.count {
                            let date = dateFormatter.date(from: dailyForecastData.daily.time[index])
                            forecastDay[index] = dayFormatter.string(from: date ?? Date())
                            forecastDate[index] = shortDateFormatter.string(from: date ?? Date())
                            weatherCodeImage[index] = self.weatherCodesViewModel.weatherCodeImage(for: dailyForecastData.daily.weather_code[index]) ?? ""
                            formattedMaxTemp[index] = String(Int(dailyForecastData.daily.temperature_2m_max[index].rounded()))
                            formattedMinTemp[index] = String(Int(dailyForecastData.daily.temperature_2m_min[index].rounded()))
                            
                            // Set precip image
                            precipImage[index] = "drop.fill"
                            if Int(dailyForecastData.daily.temperature_2m_max[index].rounded()) <= 32 {
                                precipImage[index] = "snowflake"
                            }
                        }
                        
                        // Assign the initialized arrays to the dailyForecastData
                        var updatedDaily = dailyForecastData.daily
                        updatedDaily.forecastDay = forecastDay
                        updatedDaily.forecastDate = forecastDate
                        updatedDaily.weatherCodeImage = weatherCodeImage
                        updatedDaily.formattedMaxTemp = formattedMaxTemp
                        updatedDaily.formattedMinTemp = formattedMinTemp
                        updatedDaily.precipImage = precipImage
                        self.dailyForecastData = DailyForecastData(elevation: dailyForecastData.elevation, daily: updatedDaily)
                    }
                } else {
                    print("JSON decode failed for forecast")
                }
            }
        }.resume()
    }
}

struct SiteDailyForecastView: View {
    @ObservedObject var weatherCodesViewModel: WeatherCodesViewModel
    @StateObject private var viewModel: DailyForecastViewModel
    var forecastLat: String
    var forecastLon: String
    var forecastNote: String
    var siteName: String
    var siteType: String
    
    init(weatherCodesViewModel: WeatherCodesViewModel, forecastLat: String, forecastLon: String, forecastNote: String, siteName: String, siteType: String) {
        self._weatherCodesViewModel = ObservedObject(wrappedValue: weatherCodesViewModel)
        self._viewModel = StateObject(wrappedValue: DailyForecastViewModel(weatherCodesViewModel: weatherCodesViewModel))
        self.forecastLat = forecastLat
        self.forecastLon = forecastLon
        self.forecastNote = forecastNote
        self.siteName = siteName
        self.siteType = siteType
    }

    var body: some View {
        ScrollView(.horizontal) {

            let dataWidth: CGFloat = 40                                     // Width for each data column
            let dataFrameWidth: CGFloat = ( dataWidth * 1.5 )
            
            if let daily = viewModel.dailyForecastData?.daily {

                let surfaceAltitude = convertMetersToFeet(viewModel.dailyForecastData?.elevation ?? 0.0)
                let Alt = formatAltitude(String(surfaceAltitude))
                HStack {
                    Text(buildReferenceNote(Alt: "\(Alt)", Note: forecastNote))
                        .font(.footnote)
                        .foregroundColor(infoFontColor)
                        .padding(.bottom, 5)
                    Spacer()
                }

                HStack (alignment: .top, spacing: 4) {
                    ForEach(0..<daily.time.count, id: \.self) { index in
                        VStack (spacing: 0) {
                            Text(daily.forecastDay?[index] ?? "")
                                .font(.caption)
                                .foregroundColor(repeatDateTimeColor)
                                .frame(height: headingHeight)
                                .padding(.top, 6)
                            Text(daily.forecastDate?[index] ?? "")
                                .font(.caption)
                                .foregroundColor(repeatDateTimeColor)
                                .frame(height: headingHeight)
                            Image(systemName: daily.weatherCodeImage?[index] ?? "questionmark")
                                .renderingMode(.original) // Use .multicolor for multicolor rendering
                                .resizable()
                                .scaledToFit()
                                .frame(width: dataWidth * imageScalingFactor, height: imageHeight)
                            // let minTempColor = tempColor(Int(daily.temperature_2m_min[index].rounded()))
                            let maxTempColor = tempColor(Int(daily.temperature_2m_max[index].rounded()))
                            HStack  (spacing: 0) {
                                /*  Skipping min temp in display
                                Text(daily.formattedMinTemp?[index] ?? "")
                                    .foregroundStyle(minTempColor)
                                    .font(.caption)
                                Text("/")
                                    .font(.caption)
                                 */
                                Text(daily.formattedMaxTemp?[index] ?? "")
                                    .foregroundStyle(maxTempColor)
                                    .font(.caption)
                                Text("°")
                                    .font(.caption)
                            }
                            .frame(height: dataHeight)
                            let windColor = windSpeedColor(windSpeed: Int(daily.wind_speed_10m_max[index].rounded()), siteType: siteType)
                            // let gustColor = windSpeedColor(windSpeed: Int(daily.wind_gusts_10m_max[index].rounded()), siteType: siteType)
                            Group {
                                HStack(spacing: windArrowSpacing) {
                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text("\(Int(daily.wind_speed_10m_max[index].rounded()))")
                                            .font(.caption)
                                            .foregroundStyle(windColor)
                                        /*  Removing gust from display
                                        HStack (spacing: 1) {
                                            Text("g")
                                                .font(.caption2)
                                            Text("\(Int(daily.wind_gusts_10m_max[index].rounded()))")
                                                .font(.caption)
                                                .foregroundStyle(gustColor)
                                        }
                                         */
                                    }
                                    Image(systemName: windArrow)
                                        .rotationEffect(.degrees(Double(Int(daily.wind_direction_10m_dominant[index]) - 180)))
                                        .font(.footnote)
                                }
                                .frame(height: dataHeight) // adjusted for removing gust doubleHeight)
                            }
                            VStack (spacing: 0) {
                                if daily.precipitation_sum[index] > 0 || daily.precipitation_probability_max[index] > 0 {
                                    HStack (spacing: 0) {
                                        Image(systemName: daily.precipImage?[index] ?? "questionmark")
                                            .font(.caption2)
                                            .imageScale(.small)
                                            .foregroundStyle(.titanium)
                                        Text(" \(String(daily.precipitation_probability_max[index]))%")
                                            .font(.caption)
                                    }
                                    let roundedPrecip = (daily.precipitation_sum[index] * 10).rounded() / 10
                                    Text("\(String(roundedPrecip))\"")
                                        .font(.caption)
                                        .padding(.bottom, 6)
                                } else {
                                    Text("")
                                    Text("")
                                        .padding(.bottom, 6)
                                }
                            }
                            .frame(height: doubleHeight)
                        }
                        .frame(width: dataFrameWidth)
                        .background(tableBackgroundColor)
                        .cornerRadius(10)
                        .padding(.horizontal, 2)
                    }
                }
            }
            else {
                Text("Loading...")
            }
        }
        .onAppear {
            viewModel.fetchDailyWeatherData(latitude: forecastLat, longitude: forecastLon)
        }
    }
}
