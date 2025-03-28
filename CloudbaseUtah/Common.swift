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
func tempColor(_ tempF: Int) -> Color {
    switch tempF {
    case ...32:
        return displayValueBlue
    case 33...59:
        return displayValueTeal
    case 59...79:
        return displayValueGreen
    case 80...89:
        return displayValueYellow
    case 90...99:
        return displayValueOrange
    case 100...:
        return displayValueRed
    default:
        return .clear
    }
}
func cloudCoverColor(_ cloudCoverPct: Int) -> Color {
    switch cloudCoverPct {
    case ...39:
        return displayValueGreen
    case 39...59:
        return displayValueYellow
    case 60...79:
        return displayValueOrange
    case 80...:
        return displayValueRed
    default:
        return .clear
    }
}
func precipColor(_ precipPct: Int) -> Color {
    switch precipPct {
    case ...19:
        return displayValueGreen
    case 20...39:
        return displayValueYellow
    case 40...59:
        return displayValueOrange
    case 60...:
        return displayValueRed
    default:
        return .clear
    }
}
func CAPEColor(_ CAPEvalue: Int) -> Color {
    switch CAPEvalue {
    case 0...299:
        return displayValueGreen
    case 300...599:
        return displayValueYellow
    case 600...799:
        return displayValueOrange
    case 800...:
        return displayValueRed
    default:
        return .clear
    }
}
func windSpeedColor(windSpeed: Int, siteType: String) -> Color {
    switch siteType {
    case "Aloft", "Mountain":
        switch windSpeed {
        case 0...11:
            return displayValueGreen
        case 12...17:
            return displayValueYellow
        case 18...23:
            return displayValueOrange
        case 24...:
            return displayValueRed
        default:
            return .clear
        }
    case "Soaring":
        switch windSpeed {
        case 0...19:
            return displayValueGreen
        case 20...24:
            return displayValueYellow
        case 25...29:
            return displayValueOrange
        case 30...:
            return displayValueRed
        default:
            return .clear
        }
    default:
        switch windSpeed {
        case 0...13:
            return displayValueGreen
        case 14...21:
            return displayValueYellow
        case 22...27:
            return displayValueOrange
        case 28...:
            return displayValueRed
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
func convertMetersToFeet(_ meters: Double) -> Int {
    return Int((meters * 3.28084).rounded())
}
func formatAltitude(_ altitudeData: String) -> String {
    let numberFormatter = NumberFormatter()
     numberFormatter.numberStyle = .decimal
    if let altitudeData = Int(altitudeData.replacingOccurrences(of: ",", with: "")) {
        let formattedAltitude = numberFormatter.string(from: NSNumber(value: altitudeData))
        return "\(formattedAltitude ?? "0") ft"
     } else {
         return altitudeData
     }
}
func buildReferenceNote(Alt: String, Note: String) -> String {
    var NoteString: String = ""
    if Alt != "" {
        let formattedAlt = formatAltitude(Alt)
        NoteString = "At \(formattedAlt)"
    }
    if Note != "" {
        NoteString = NoteString + " (\(Note))"
    }
    return NoteString
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
