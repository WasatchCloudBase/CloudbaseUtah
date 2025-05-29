import SwiftUI
import Combine

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
    func getSunriseSunset(completion: @escaping () -> Void) {
        var sunriseSunset: SunriseSunset = .init(sunrise: "", sunset: "")
        let urlString = "https://api.sunrise-sunset.org/json?lat=\(sunriseLatitude)&lng=\(sunriseLongitude)&formatted=0"
        guard let url = URL(string: urlString) else {
            print("Invalid URL for sunrise and sunset times")
            DispatchQueue.main.async { completion() }
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("Error for sunrise and sunset times: \(error.localizedDescription)")
                DispatchQueue.main.async { completion() }
                return
            }
            guard let data = data else {
                print("No data received for sunrise and sunset times")
                DispatchQueue.main.async { completion() }
                return
            }
            let decoder = JSONDecoder()
            if let decodedResponse = try? decoder.decode(SunriseSunsetResponse.self, from: data) {
                DispatchQueue.main.async {
                    sunriseSunset.sunrise = convertISODateToLocalTime(isoDateString: decodedResponse.results.sunrise)
                    sunriseSunset.sunset = convertISODateToLocalTime(isoDateString: decodedResponse.results.sunset)
                    self?.sunriseSunset = sunriseSunset
                    completion()
                }
            } else {
                DispatchQueue.main.async { completion() }
            }
        }.resume()
    }
}
