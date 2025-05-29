import SwiftUI
import Combine

struct WeatherCam: Identifiable {
    let id = UUID()
    let category: String
    let name: String
    let linkURL: String
    let imageURL: String
}

class WeatherCamsViewModel: ObservableObject {
    @Published var weatherCams: [WeatherCam] = []
    @Published var groupedWeatherCams: [String: [WeatherCam]] = [:]
    
    func fetchWeatherCams() {
        let rangeName = "WeatherCams"
        let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(googleApiKey)"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                print("Failed to fetch data")
                return
            }
            
            do {
                let response = try JSONDecoder().decode(WeatherCamGoogleSheetResponse.self, from: data)
                
                // Skip rows that should be excluded from app (e.g., cam is not active)
                let skipCondition: ([Any]) -> Bool = { row in
                    if let skipRow = row.first as? String {
                        return skipRow == "Yes"
                    }
                    return false
                }
                let cams = response.values.dropFirst().filter {!skipCondition($0)}.map { row in
                    return WeatherCam(category: row[1], name: row[2], linkURL: row[3], imageURL: row[4])
                }
                
                DispatchQueue.main.async {
                    self.weatherCams = cams
                    self.groupedWeatherCams = Dictionary(grouping: cams, by: { $0.category })
                }
            } catch {
                print("Failed to decode JSON")
            }
        }.resume()
    }
}

struct WeatherCamGoogleSheetResponse: Codable {
    let values: [[String]]
}
