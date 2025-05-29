import SwiftUI
import Combine

// SLC Soaring Forecast and Sounding
struct SoaringForecast: Identifiable {
    let id = UUID()
    let date: String
    let soaringForecastFormat: String
    let triggerTempData: String
    let soaringForecastData: [SoaringForecastData]
    let soundingData: [SoundingData]
    let richSoundingData: [RichSoundingData]
    let modelData: [ModelData]
    let forecastMaxTemp: Int
}
struct SoaringForecastData: Identifiable {
    let id = UUID()
    let heading: String
    let value: String?
}
struct SoundingData: Identifiable {
    let id = UUID()
    let altitude: String
    let windDirection: Int
    let windSpeed: Int
}
struct RichSoundingData: Identifiable {
    let id = UUID()
    let altitude: Int
    let temperatureF: Double
    let windDirection: Int
    let windSpeedKt: Int
    let thermalIndex: Double
    let liftRateMs: Double
    var windSpeedMph: Double {return Double(windSpeedKt) * 1.15078}
}
struct ModelData: Identifiable {
    let id = UUID()
    let value: String
}

class SoaringForecastViewModel: ObservableObject {
    @Published var soaringForecast: SoaringForecast?
    init() {
        fetchSoaringForecast()
    }
    func fetchSoaringForecast() {
        guard let url = URL(string: soaringForecastLink) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else { return }
            if let content = String(data: data, encoding: .utf8) {
                // Check if the output is formatted using the summer (rich) forecast
                if content.contains("Soaring Forecast") {
                    self.parseRichSoaringForecast(content: content)
                }
                // The winter (simple) version should contain "SOARING FORECAST" instead
                else {
                    self.parseSimpleSoaringForecast(content: content)
                }
            }
        }.resume()
    }
    
    // Summer soaring forecast with additional data
    func parseRichSoaringForecast(content: String) {
        let start = "National Weather Service Salt Lake City, Utah"
        let datePrefix = "This forecast is for "
        let triggerTempPrefix = ":"
        let soaringForecastPrefix = "...then"
        let remarksPrefix = "Remarks..."
        // let soundingSummaryPrefix = "Upper air data from rawinsonde observation taken on "
        // Prefix below skips header rows on sounding table data
        let soundingPrefix = "--------------------------------------------------------------------------------"
        let modelPrefix = "* * * * * * Numerical weather prediction model forecast data valid * * * * * *"
        var endPrefix = "This product is issued"
        guard let startRange = content.range(of: start)
        else {
            print("Soaring forecast: could not parse start date (e.g., no row for \(start))")
            return
        }
        guard let dateRange = content.range(of: datePrefix, range: startRange.upperBound..<content.endIndex)
        else {
            print("Soaring forecast: could not parse date range (e.g., no row for \(datePrefix))")
            return
        }
        guard let triggerTempRange = content.range(of: triggerTempPrefix, range: dateRange.upperBound..<content.endIndex)
        else {
            print("Soaring forecast: could not parse soaring forecast data range (e.g., no row for \(soaringForecastPrefix))")
            return
        }
        guard let soaringForecastRange = content.range(of: soaringForecastPrefix, range: triggerTempRange.upperBound..<content.endIndex)
        else {
            print("Soaring forecast: could not parse soaring forecast data range (e.g., no row for \(soaringForecastPrefix))")
            return
        }
        guard let remarksRange = content.range(of: remarksPrefix, range: soaringForecastRange.upperBound..<content.endIndex)
        else {
            print("Soaring forecast: could not parse remarks data range (e.g., no row for \(remarksPrefix))")
            return
        }
        guard let soundingRange = content.range(of: soundingPrefix, range: remarksRange.upperBound..<content.endIndex)
        else {
            print("Soaring forecast: could not parse sounding data range (e.g., no row for \(soundingPrefix))")
            return
        }
        guard let modelRange = content.range(of: modelPrefix, range: soundingRange.upperBound..<content.endIndex)
        else {
            print("Soaring forecast: could not parse model forecast data range (e.g., no row for \(soundingPrefix))")
            return
        }
        // Forecast had typos on 5/8/2025; added code to fix for this scenario
        if (content.range(of: endPrefix, range: modelRange.upperBound..<content.endIndex) == nil) {
            endPrefix = "s product is issued"
        }
        guard let endRange = content.range(of: endPrefix, range: modelRange.upperBound..<content.endIndex)
        else {
            print("Could not parse end range (e.g., no row for \(endPrefix))")
            return
        }
        
        // Process soaring forecast date
        let date = removeExtraBlankLines(String(content[dateRange.upperBound..<triggerTempRange.lowerBound]))
        
        // Process trigger temp statement
        var triggerTempString = removeExtraBlankLines(String(content[triggerTempRange.upperBound..<soaringForecastRange.lowerBound])) + ":"
        triggerTempString = triggerTempString
            .replacingOccurrences(of: "the ", with: "")
            .replacingOccurrences(of: "temperature", with: "temp")
        triggerTempString = removeTextFromOpenToClose(triggerTempString, open: "/", close: "C")     // Remove max temp in Celsius
        triggerTempString = roundNumbersInString(in: triggerTempString)
        
        // Process soaring forecast
        let soaringForecastDataString = removeExtraBlankLines(String(content[soaringForecastRange.upperBound..<remarksRange.lowerBound]))
        let soaringForecast = parseRichSoaringForecastData(soaringForecastDataString)
        // Note:  remarks section is ignored
        
        // Process rich sounding data
        let soundingDataString = removeExtraBlankLines(String(content[soundingRange.upperBound..<modelRange.lowerBound]))
        let richSoundingData = parseRichSoundingData(soundingDataString)
        
        // Set default for simple sounding data (rich sounding data above used instead)
        var soundingData: [SoundingData] = []
        soundingData.append(SoundingData(altitude: "0", windDirection: 0, windSpeed: 0))
        
        // Process numerical model data
        let modelDataString = String(content[modelRange.upperBound..<endRange.lowerBound])
        let modelData = parseModelData(modelDataString)
        
        // Get forecast max temp for use in Skew-T diagram
        var forecastMaxTemp = 0
        let maxTempRange = soaringForecastDataString.lowercased().range(of: "forecast maximum temperature")
        if maxTempRange != nil {
            let substringAfterKeyword = soaringForecastDataString[maxTempRange!.upperBound... ]
            let maxTempPattern = "\\d+"
            if let maxTempMatch = substringAfterKeyword.range(of: maxTempPattern, options: .regularExpression) {
                forecastMaxTemp = Int(substringAfterKeyword[maxTempMatch]) ?? 0
            }
        }
        
        DispatchQueue.main.async {
            self.soaringForecast = SoaringForecast(date: date, soaringForecastFormat: "Rich", triggerTempData: triggerTempString, soaringForecastData: soaringForecast, soundingData: soundingData, richSoundingData: richSoundingData, modelData: modelData, forecastMaxTemp: forecastMaxTemp)
        }
    }
    
    // Winter soaring forecast with limited data
    func parseSimpleSoaringForecast(content: String) {
        let start = "SOARING FORECAST FOR SALT LAKE CITY"
        let datePrefix = "DATE..."
        let soaringForecastPrefix = "THERMAL INDEX..."
        let soundingPrefix = "UPPER LEVEL WINDS AT SALT LAKE CITY"
        let endPrefix = "20000 FT"
        guard let startRange = content.range(of: start)
        else {
            print("Soaring forecast: could not parse start date (e.g., no row for \(start))")
            return
        }
        guard let dateRange = content.range(of: datePrefix, range: startRange.upperBound..<content.endIndex)
        else {
            print("Soaring forecast: could not parse date range (e.g., no row for \(datePrefix))")
            return
        }
        guard let SoaringForecastRange = content.range(of: soaringForecastPrefix, range: dateRange.upperBound..<content.endIndex)
        else {
            print("Soaring forecast: could not parse soaring forecast data range (e.g., no row for \(soaringForecastPrefix))")
            return
        }
        guard let soundingRange = content.range(of: soundingPrefix, range: SoaringForecastRange.upperBound..<content.endIndex)
        else {
            print("Soaring forecast: could not parse sounding data range (e.g., no row for \(soundingPrefix))")
            return
        }
        guard let endRange = content.range(of: endPrefix, range: soundingRange.upperBound..<content.endIndex)
        else {
            print("Could not parse end range (e.g., no row for \(endPrefix))")
            return
        }
        let modelData: [ModelData] = []     // Not used in this forecast
        let date = String(content[dateRange.upperBound...].prefix(9)).trimmingCharacters(in: .whitespacesAndNewlines)
        let soaringForecastDataString = removeExtraBlankLines(String(content[SoaringForecastRange.upperBound..<soundingRange.lowerBound]))
        let soaringForecast = parseSimpleSoaringForecastData(soaringForecastDataString)
        let soundingDataString = removeExtraBlankLines(String(content[soundingRange.upperBound..<endRange.lowerBound]))
        let soundingData = soundingDataString
            .replacingOccurrences(of: " FT MSL", with: "")
            .replacingOccurrences(of: ".", with: "")
            .split(separator: "\n")
            .compactMap { line -> SoundingData? in
                let components = line.split(separator: " ")
                guard components.count >= 6,
                      let altitude = components.first,
                      let windDirection = Int(components[1]),
                      let windSpeed = Int(components[4])
                else {
                    return nil }
                let windSpeedMph = convertKnotsToMPH(Int(windSpeed))
                let altitudeString = formatAltitude(String(altitude))
                return SoundingData(altitude: altitudeString, windDirection: windDirection, windSpeed: windSpeedMph)
        }
        
        // pass back default for rich sounding data (not used)
        var richSoundingData: [RichSoundingData] = []
        richSoundingData.append(RichSoundingData(altitude: 0, temperatureF: 0.0, windDirection: 0, windSpeedKt: 0, thermalIndex: 0.0, liftRateMs: 0.0))

        // Find forecast max temp to use in skew-T diagarm
        var forecastMaxTemp: Int = 0
        let pattern = "forecast max temp\\s+(\\d+\\.?\\d*)"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let nsString = soaringForecastDataString as NSString
        let results = regex?.matches(in: soaringForecastDataString, options: [], range: NSRange(location: 0, length: nsString.length))
        if let match = results?.first, let range = Range(match.range(at: 1), in: soaringForecastDataString) {
            forecastMaxTemp = Int(soaringForecastDataString[range]) ?? 0
        }
        
        DispatchQueue.main.async {
            self.soaringForecast = SoaringForecast(date: date, soaringForecastFormat: "Simple", triggerTempData: "", soaringForecastData: soaringForecast, soundingData: soundingData.reversed(), richSoundingData: richSoundingData, modelData: modelData, forecastMaxTemp: forecastMaxTemp)
        }
    }
    
    func parseRichSoaringForecastData(_ input: String) -> [SoaringForecastData] {
        var formattedInput = input
            .replacingOccurrences(of: "Maximum", with: "Max")
            .replacingOccurrences(of: "maximum", with: "max")
            .replacingOccurrences(of: "Temperature", with: "Temp")
            .replacingOccurrences(of: "temperature", with: "temp")
            .replacingOccurrences(of: "MSL", with: "")
            .replacingOccurrences(of: "Degrees", with: "°")
            .replacingOccurrences(of: "Slc", with: "SLC")  // override capitalized for SLC
        formattedInput = removeTextFromOpenToClose(formattedInput, open: "/", close: "C")     // Remove max temp in Celsius
        formattedInput = formatTimeinString(from: formattedInput)
        
        // Remove the max rate of lift containing "# ft/min"
        let patternFtMin = "\\d+ ft/min"
        let regexFtMin = try! NSRegularExpression(pattern: patternFtMin)
        let rangeFtMin = NSRange(location: 0, length: formattedInput.utf16.count)
        formattedInput = regexFtMin.stringByReplacingMatches(in: formattedInput, options: [], range: rangeFtMin, withTemplate: "").trimmingCharacters(in: .whitespaces)
        
        // Remove parentheses around max rate of lift containing "# m/s"
        let patternMsWithParentheses = "\\((\\d+\\.\\d+ m/s)\\)"
        let regexMsWithParentheses = try! NSRegularExpression(pattern: patternMsWithParentheses)
        let rangeMsWithParentheses = NSRange(location: 0, length: formattedInput.utf16.count)
        formattedInput = regexMsWithParentheses.stringByReplacingMatches(in: formattedInput, options: [], range: rangeMsWithParentheses, withTemplate: "$1").trimmingCharacters(in: .whitespaces)
        
        formattedInput = formatNumbersInString(removeTextInParentheses(formattedInput))
        // Removed rounding because I care more about m/s with decimal than removing decimal from temps
        // formattedInput = roundNumbersInString(in: formattedInput)
        let lines = formattedInput.split(separator: "\n")
        var dataRows: [SoaringForecastData] = []
        for line in lines {
            let components = line.split(separator: ".", omittingEmptySubsequences: true)
            if components.count > 1 {
                let heading = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = components.dropFirst().joined(separator: ".").trimmingCharacters(in: .whitespacesAndNewlines)
                dataRows.append(SoaringForecastData(heading: heading, value: value))
            } else {
                let heading = line.trimmingCharacters(in: .whitespacesAndNewlines)
                dataRows.append(SoaringForecastData(heading: heading, value: nil))
            }
        }
        return dataRows
    }
    
    func parseRichSoundingData(_ input: String) -> [RichSoundingData] {
        let lines = input.split(separator: "\n")
        var richSoundingData: [RichSoundingData] = []
        for line in lines { // Header rows parsed out above; otherwise use .dropFirst(3)
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            if columns.count >= 13, let altitude = Int(columns[0]), altitude <= 18000 {
                let temperatureF = Double(columns[2]) ?? 0.0
                let windDirection = Int(columns[3]) ?? 0
                let windSpeedKt = Int(columns[4]) ?? 0
                let thermalIndex = Double(columns[10]) ?? 0.0
                let liftRateMs = Double(columns[12]) ?? 0.0
                
                let dataRow = RichSoundingData(altitude: altitude, temperatureF: temperatureF, windDirection: windDirection, windSpeedKt: windSpeedKt, thermalIndex: thermalIndex, liftRateMs: liftRateMs)
                richSoundingData.append(dataRow)
            }
        }
        return richSoundingData
    }
    
    func parseSimpleSoaringForecastData(_ input: String) -> [SoaringForecastData] {
        let cleanedInput = input
            .replacingOccurrences(of: "MSL", with: "")
            .replacingOccurrences(of: "DEGREES", with: "°")
            .capitalized(with: Locale.current)
            .replacingOccurrences(of: "Slc", with: "SLC")  // override capitalized for SLC
        let lines = cleanedInput.split(separator: "\n")
        var dataRows: [SoaringForecastData] = []
        for line in lines {
            let components = line.split(separator: ".", omittingEmptySubsequences: true)
            if components.count > 1 {
                let heading = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = components.dropFirst().joined(separator: ".").trimmingCharacters(in: .whitespacesAndNewlines)
                dataRows.append(SoaringForecastData(heading: heading, value: value))
            } else {
                let heading = line.trimmingCharacters(in: .whitespacesAndNewlines)
                dataRows.append(SoaringForecastData(heading: heading, value: nil))
            }
        }
        return dataRows
    }
    
    func parseModelData(_ input: String) -> [ModelData] {
        let lines = input.split(separator: "\n")
        var dataRows: [ModelData] = []
        for line in lines {
            dataRows.append(ModelData(value: String(line)))
        }
        return dataRows
    }

}
