//  MainViewData.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/6/25.

import SwiftUI
import Foundation

// URL fetch response structure
struct SunriseSunsetResponse: Codable {
    let results: Results
    let status: String
}
// JSON decode for Results portion of URL response
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
