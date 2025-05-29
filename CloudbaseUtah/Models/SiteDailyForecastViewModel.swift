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
    let cloud_cover_mean: [Int]
    let cloud_cover_max: [Int]
    let cloud_cover_min: [Int]
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
        let dailyForecastURLString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,cloud_cover_mean,cloud_cover_max,cloud_cover_min&timezone=America%2FDenver&wind_speed_unit=mph&temperature_unit=fahrenheit&precipitation_unit=inch"
        if printForecastURL { print(dailyForecastURLString) }

        guard let dailyForecastURL = URL(string: dailyForecastURLString) else { return }
        URLSession.shared.dataTask(with: dailyForecastURL) { [weak self] data, response, error in
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
                            formattedMaxTemp[index] = String(Int(dailyForecastData.daily.temperature_2m_max[index].rounded()))
                            formattedMinTemp[index] = String(Int(dailyForecastData.daily.temperature_2m_min[index].rounded()))
                            
                            // Set weather code image
                            // Set weather code image
                            weatherCodeImage[index] = self?.weatherCodesViewModel.weatherCodeImage (
                                weatherCode: Int(dailyForecastData.daily.weather_code[index]),
                                cloudcover: Double(dailyForecastData.daily.cloud_cover_mean[index]),
                                precipProbability: Double(dailyForecastData.daily.precipitation_probability_max[index]),
                                tempF: (dailyForecastData.daily.temperature_2m_max[index])
                            ) ?? ""

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
                        self?.dailyForecastData = DailyForecastData(elevation: dailyForecastData.elevation, daily: updatedDaily)
                    }
                } else {
                    print("JSON decode failed for forecast")
                }
            }
        }.resume()
    }
}
