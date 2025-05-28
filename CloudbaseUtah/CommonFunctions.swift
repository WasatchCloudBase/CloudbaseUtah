import SwiftUI
import Foundation
import SafariServices
import UIKit

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
    case 40...59:
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
    }
}

func thermalColor(_ thermalVelocity: Double) -> Color {
    // Assumes thermalVelocity already rounded to nearest tenth
    switch thermalVelocity {
    case ...1.0:
        return displayValueWhite
    case 1.1...3.0:
        return displayValueGreen
    case 3.0...4.0:
        return displayValueYellow
    case 4.0...5.0:
        return displayValueOrange
    case 6.0...:
        return displayValueRed
    default:
        return .clear
    }
}

func roundToOneDecimal(_ value: Double) -> Double {
    return (value * 10).rounded() / 10
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

func convertFeetToMeters(_ feet: Double) -> Double {
    return (feet / 3.28084).rounded()
}

func convertKMToMiles(_ km: Double) -> Double {
    return (km * 0.621371).rounded()
}

func formatAltitude(_ altitudeData: String) -> String {
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .decimal
    numberFormatter.maximumFractionDigits = 0
    numberFormatter.minimumFractionDigits = 0
    let altitude = altitudeData.replacingOccurrences(of: ",", with: "")
    let altitudeInt = Int(Double(altitude) ?? 0.0)
    if let formattedAltitude = numberFormatter.string(from: NSNumber(value: altitudeInt)) {
        return "\(formattedAltitude) ft"
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

func formatNumbersInString(_ input: String) -> String {
    let pattern = "\\d+"
    let regex = try! NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(location: 0, length: input.utf16.count)
    let matches = regex.matches(in: input, options: [], range: range)
    var formattedString = input as NSString
    for match in matches.reversed() {
        let numberString = formattedString.substring(with: match.range)
        if let number = Int(numberString) {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            if let formattedNumberString = numberFormatter.string(from: NSNumber(value: number)) {
                formattedString = formattedString.replacingCharacters(in: match.range, with: formattedNumberString) as NSString
            }
        }
    }
    return formattedString as String
}

func removeTextInParentheses(_ text: String?) -> String {
    // Set default if input is nil
    let nonOptionalText = text ?? ""
    let pattern = "\\([^()]*\\)"
    return nonOptionalText.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// Function to look for two strings, and when found, remove everything in the data string from openingString through closingString
// For example, passing " [" and "]" will change "data [including bracketed data] here" to "data here"
func removeTextFromOpenToClose(_ data: String, open: String, close: String) -> String {
    let pattern = "\(NSRegularExpression.escapedPattern(for: open)).*?\(NSRegularExpression.escapedPattern(for: close))"
    let regex = try! NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(location: 0, length: data.utf16.count)
    let updatedData = regex.stringByReplacingMatches(in: data, options: [], range: range, withTemplate: "")
    return updatedData
}

// Convert numbers followed by MDT to MST to time format
func formatTimeinString(from string: String) -> String {
    let pattern = "\\b(\\d+) ?(MDT|MST)\\b"
    let regex = try! NSRegularExpression(pattern: pattern, options: [])
    let nsString = string as NSString
    let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: nsString.length))
    var resultString = string
    for match in matches.reversed() {
        let numberRange = match.range(at: 1)
        let timezoneRange = match.range(at: 2)
        if let number = Int(nsString.substring(with: numberRange)) {
            let hours = number / 100
            let minutes = number % 100
            let formattedTime = String(format: "%02d:%02d", hours, minutes)
            let timezone = nsString.substring(with: timezoneRange)
            
            let fullMatchRange = match.range(at: 0)
            let replacement = "\(formattedTime) \(timezone)"
            resultString = (resultString as NSString).replacingCharacters(in: fullMatchRange, with: replacement)
        }
    }
    return resultString
}

// Convert all numbers with decimal components to integers
func roundNumbersInString (in data: String) -> String {
    // Regular expression to find numbers with decimal digits
    let pattern = "\\d+\\.\\d+"
    let regex = try! NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(location: 0, length: data.utf16.count)
    // Use the matches to find and replace each decimal number
    let matches = regex.matches(in: data, options: [], range: range)
    var newString = data
    for match in matches.reversed() {
        if let matchRange = Range(match.range, in: data) {
            let numberString = String(data[matchRange])
            if let number = Double(numberString) {
                let roundedNumber = Int(round(number))
                newString.replaceSubrange(matchRange, with: "\(roundedNumber)")
            }
        }
    }
    return newString
}

// Extracts the first number (integer or decimal) from a string
func extractNumber(from input: String) -> Double? {
    let pattern = #"(\d+(\.\d+)?)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(input.startIndex..., in: input)
    if let match = regex.firstMatch(in: input, range: range),
       let numberRange = Range(match.range(at: 1), in: input) {
        return Double(input[numberRange])
    }
    return nil
}

// Created for site forecast results that occassionally contain null for a weather code
func replaceNullsInJSON(data: Data) -> Data? {
    // Convert Data to String
    guard let dataString = String(data: data, encoding: .utf8) else {
        print("Failed to convert Data to String.")
        return nil
    }
    // Replace all occurrences of "null" with "0"
    let modifiedString = dataString.replacingOccurrences(of: "null", with: "0")
    // Convert String back to Data
    guard let modifiedData = modifiedString.data(using: .utf8) else {
        print("Failed to convert modified String back to Data.")
        return nil
    }
    return modifiedData
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

func getDateForDays(days: Double) -> Date {
    // Get date string based on "days" value:
    // Days = 1, today
    // Days = 2, today and yesterday
    // Days = 3, today, yesterday, and prior day
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime]
    var calendar = Calendar.current
    calendar.timeZone = TimeZone.current
    // Set the base date to today at 12:01 AM, then subtract (days - 1)
    let baseDate = calendar.date(bySettingHour: 0, minute: 1, second: 0, of: Date()) ?? Date()
    let targetDate = calendar.date(byAdding: .day, value: -(Int(days) - 1), to: baseDate)!
    return targetDate
}

// Function to determine distinct values from an array
extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}

// Scale UI Image for map display
extension UIImage {
    func scaled(toWidth newWidth: CGFloat) -> UIImage? {
        let aspectRatio = size.height / size.width
        let newHeight = newWidth * aspectRatio
        let newSize = CGSize(width: newWidth, height: newHeight)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaledImage
    }
}

// Set color for UI Images
func tintedImage(_ image: UIImage, color: UIColor) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
    color.set()
    image.draw(in: CGRect(origin: .zero, size: image.size))
    let tinted = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return tinted ?? image
}
