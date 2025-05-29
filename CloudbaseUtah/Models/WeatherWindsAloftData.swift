import SwiftUI
import Combine

// Winds Aloft forecast
class WindAloftData: ObservableObject {
    @Published var readings: [WindAloftReading] = []
    @Published var cycle: String = ""
    struct WindAloftReading {
        let altitude: Int
        let windDirection: Int
        let windSpeed: Int
        let temperature: Int
    }
    func fetchWindAloftData() {
        let cycle = determineCycle()
        self.cycle = cycle
        let urlString = "https://aviationweather.gov/api/data/windtemp?region=slc&level=low&fcst=\(cycle)"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            if let responseString = String(data: data, encoding: .utf8) {
                self.parseWindAloftData(responseString)
            }
        }.resume()
    }
    private func determineCycle() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 3...13:
            return "12"
        case 14...18:
            return "06"
        default:
            return "24"
        }
    }
    private func parseWindAloftData(_ data: String) {
        let lines = data.split(separator: "\n")
        guard let slcLine = lines.first(where: { $0.starts(with: "SLC") }) else { return }

        let columns = slcLine.split(separator: " ")
        let altitudes = [6000, 9000, 12000, 18000]
        let indices = [2, 3, 4, 5] // Corresponding indices for the altitudes

        var newReadings: [WindAloftReading] = []
        for (index, altitude) in zip(indices, altitudes) {
            let reading = columns[index]
            if let parsedReading = parseReading(String(reading), altitude: altitude) {
                newReadings.append(parsedReading)
            }
        }
        DispatchQueue.main.async {
            self.readings = newReadings.reversed()
        }
    }
    private func parseReading(_ reading: String, altitude: Int) -> WindAloftReading? {
        guard reading.count >= 4 else { return nil }
        var windDirection = 10 * (Int(reading.prefix(2)) ?? 0)
        var windSpeedKnots = Int(reading.dropFirst(2).prefix(2)) ?? 0
        // Check for wind greater than 100 knots, which is indicated by adding 500 degrees to the wind direction
        // (anything greater than 199 knots is indicated as 199 knots)
        // Ignore 990, which indicated light and variable winds
        if windDirection > 360 && windDirection < 990 {
            windDirection = windDirection - 360
            windSpeedKnots = windSpeedKnots + 100
        }
        let windSpeed = convertKnotsToMPH(windSpeedKnots)
        // Convert wind direction to arrow direction (offset by 180 degrees)
        windDirection = (windDirection + 180) % 360
        var temperature: Int? = nil
        if reading.count > 4 {
            let tempString = reading.dropFirst(4)
            if let tempValue = Int(tempString) {
                temperature = Int(tempValue)
            }
        }
        if let tempCelsius = temperature {
            let tempFahrenheit = convertCelsiusToFahrenheit(Int(tempCelsius))
            return WindAloftReading(altitude: altitude, windDirection: windDirection, windSpeed: windSpeed, temperature: tempFahrenheit)
        } else {
            return WindAloftReading(altitude: altitude, windDirection: windDirection, windSpeed: windSpeed, temperature: 0)
        }
    }
}
