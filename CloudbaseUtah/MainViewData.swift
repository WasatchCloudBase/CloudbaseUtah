//  MainViewData.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/6/25.

import SwiftUI
import Foundation
import SafariServices

// Set global constants
enum NavBarSelectedView:Int {
    case site = 0
    case weather = 1
    case alerts = 2
    case webcam = 3
    case link = 4
    case dev = 9
}
let GoogleSpreadsheetID = "1s72R3YCHxNIJVLVa5nmsTphRpqRsfG2QR2koWxE19ls"
let GoogleApiKey = "AIzaSyDSro1lDdAQsNEZq06IxwjOlQQP1tip-fs"
let sunriseLatitude: Double = 40.7862               // SLC airport coordinates
let sunriseLongitude: Double = -111.9801

// Common utility functions
func windSpeedColor(windSpeed: Int, siteType: String) -> Color {
    switch siteType {
    case "Aloft", "Mountain":
        switch windSpeed {
        case 0...11:
            return .green
        case 12...17:
            return .yellow
        case 18...23:
            return .orange
        case 24...:
            return .red
        default:
            return .clear
        }
    case "Soaring":
        switch windSpeed {
        case 0...19:
            return .green
        case 20...24:
            return .yellow
        case 25...29:
            return .orange
        case 30...:
            return .red
        default:
            return .clear
        }
    default:
        switch windSpeed {
        case 0...13:
            return .green
        case 14...21:
            return .yellow
        case 22...27:
            return .orange
        case 28...:
            return .red
        default:
            return .clear
        }
    }
}
func convertKnotsToMPH(_ knots: Int) -> Int {
    let mph = Int((Double(knots) * 1.15078).rounded())
    return mph
}
func convertCelsiusToFahrenheit(_ celsius: Int) -> Int {
    return Int(((Double(celsius) * 9/5) + 32).rounded())
}
func formatAltitude(_ altitudeData: String) -> String {
    let numberFormatter = NumberFormatter()
     numberFormatter.numberStyle = .decimal
    if let altitudeData = Int(altitudeData) {
        let formattedAltitude = numberFormatter.string(from: NSNumber(value: altitudeData))
        return "\(formattedAltitude ?? "0") ft"
     } else {
         return altitudeData
     }
}
func extractSection(from data: Substring, start: String, end: String) -> String? {
    guard let startRange = data.range(of: start)?.upperBound,
          let endRange = data.range(of: end, range: startRange..<data.endIndex)?.lowerBound else { return nil }
    return String(data[startRange..<endRange])
}
func collapseTextLines(_ text: String?) -> String {
    // Set default if input is nil
    let nonOptionalText = text ?? ""
    var cleanedText = removeExtraBlankLines(nonOptionalText)
    // Replace single line returns with a space, keep double line returns
    cleanedText = cleanedText.replacingOccurrences(of: "(?<!\n)\n(?!\n)", with: " ", options: .regularExpression)
    return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
}
func removeExtraBlankLines(_ text: String?) -> String {
    // Set default if input is nil
    let nonOptionalText = text ?? ""
    // Remove leading spaces, tabs, and dots at the beginning of text lines
    var cleanedText = nonOptionalText.replacingOccurrences(of: "(?m)^[ \t.]+", with: "", options: .regularExpression)
    // Remove leading line returns on the first line
    cleanedText = cleanedText.replacingOccurrences(of: "^\n+", with: "", options: .regularExpression)
    // Remove trailing line returns on the last line
    cleanedText = cleanedText.replacingOccurrences(of: "\n+$", with: "", options: .regularExpression)
    return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
}

// Function to open links using Safari in app window
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}

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
// Get sunrise / sunset for SLC airport
func fetchSunriseSunset(forLatitude latitude: Double, longitude: Double, completion: @escaping (String, String) -> Void) {
    let urlString = "https://api.sunrise-sunset.org/json?lat=\(latitude)&lng=\(longitude)&formatted=0"
    guard let url = URL(string: urlString) else {
        print("Invalid URL")
        return
    }
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error: \(error.localizedDescription)")
            return
        }
        guard let data = data else {
            print("No data received")
            return
        }
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(SunriseSunsetResponse.self, from: data)
            let sunrise = convertISODateToLocalTime(isoDateString: response.results.sunrise)
            let sunset = convertISODateToLocalTime(isoDateString: response.results.sunset)
            DispatchQueue.main.async {
                completion(sunrise, sunset)
            }
        } catch {
            print("Error decoding JSON: \(error.localizedDescription)")
        }
    }
    task.resume()
}

// Convert ISO dates to local time zone and extract hh:mm portion
func convertISODateToLocalTime(isoDateString: String) -> String {
    let isoDateFormatter = ISO8601DateFormatter()
    isoDateFormatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]

    guard let date = isoDateFormatter.date(from: isoDateString) else {
        print("Invalid ISO date string:" + isoDateString)
        return ""
    }

    let localDateFormatter = DateFormatter()
    localDateFormatter.dateFormat = "h:mm"
    localDateFormatter.timeZone = TimeZone.current

    let localTimeString = localDateFormatter.string(from: date)
    return localTimeString
}
