import SwiftUI
import Combine

// Load weather codes
struct WeatherCode: Identifiable {
    let id = UUID()
    let weatherCode: Int
    let imageName: String
}
struct WeatherCodesResponse: Codable {
    let values: [[String]]
}
class WeatherCodeViewModel: ObservableObject {
    @Published var weatherCodes: [WeatherCode] = []
    private var cancellables = Set<AnyCancellable>()
    let sheetName = "WeatherCodes"
    
    func getWeatherCodes(completion: @escaping () -> Void) {
        let weatherCodesURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(sheetName)?alt=json&key=\(googleApiKey)"
        guard let url = URL(string: weatherCodesURLString) else {
            print("Invalid URL for weather codes")
            DispatchQueue.main.async { completion() }
            return
        }
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: WeatherCodesResponse.self, decoder: JSONDecoder())
        
            .map { response in
                response.values.dropFirst().compactMap { row in
                    guard row.count >= 2 else {
                        print("Skipping malformed weather code row: \(row)")
                        return nil
                    }
                    let code = Int(row[0]) ?? 0
                    let imageName = row[1]
                    return WeatherCode(weatherCode: code, imageName: imageName)
                }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { [weak self] codes in
                self?.weatherCodes = codes
            }, receiveCompletion: { _ in
                completion()
            })
            .sink { _ in }
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
