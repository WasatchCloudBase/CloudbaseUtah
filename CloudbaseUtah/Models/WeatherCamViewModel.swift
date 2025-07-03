import SwiftUI
import Combine

struct WeatherCam: Identifiable {
    let id = UUID()
    let category: String
    let name: String
    let linkURL: String
    let imageURL: String
}

struct WeatherCamGoogleSheetResponse: Codable {
    let values: [[String]]
}

class WeatherCamsViewModel: ObservableObject {
    @Published var weatherCams: [WeatherCam] = []
    @Published var groupedWeatherCams: [String: [WeatherCam]] = [:]
    @Published var isLoading: Bool = false
    
    func fetchWeatherCams() {
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        let rangeName = "WeatherCams"
        let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(googleApiKey)"
        guard let url = URL(string: urlString) else {
            // Bad URL → hide spinner
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            defer {
                // Always hide the progress indicator when this closure exits
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
            
            if let error = error {
                print("Failed to fetch data: \(error.localizedDescription)")
                return
            }
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                let response = try JSONDecoder().decode(WeatherCamGoogleSheetResponse.self, from: data)
                
                let skipCondition: ([String]) -> Bool = { row in
                    row.first == "Yes"
                }
                
                let cams: [WeatherCam] = response.values
                    .dropFirst() // skip header row
                    .compactMap { row in
                        guard row.count >= 5 else {
                            print("Skipping malformed row (not enough columns): \(row)")
                            return nil
                        }
                        if skipCondition(row) {
                            return nil
                        }
                        return WeatherCam(
                            category: row[1],
                            name:     row[2],
                            linkURL:  row[3],
                            imageURL: row[4]
                        )
                    }
                
                DispatchQueue.main.async {
                    self.weatherCams = cams
                    self.groupedWeatherCams = Dictionary(grouping: cams, by: \.category)
                    // isLoading will be set to false by the `defer` block above
                }
            } catch {
                print("Failed to decode JSON: \(error)")
            }
        }
        .resume()
    }
}
