import SwiftUI
import Combine
import SDWebImage
import SDWebImageSwiftUI
import Foundation

struct TFR: Identifiable, Codable {
    var id: String { notam_id }
    let notam_id: String
    let type: String
    let facility: String
    let state: String
    let description: String
    let creation_date: String
}

class TFRViewModel: ObservableObject {
    @Published var tfrs: [TFR] = []
    @Published var isLoading: Bool = false
    
    func fetchTFRs() {
        guard let url = URL(string: TFRAPI) else { return }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let tfrList = try JSONDecoder().decode([TFR].self, from: data)
                    DispatchQueue.main.async {
                        self.tfrs = tfrList.filter { $0.state == "UT" }
                        self.isLoading = false
                    }
                } catch {
                    print("Error decoding JSON: \(error)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }
}

struct WeatherAlert: Identifiable, Decodable {
    let id: String
    let areaDesc: String
    let event: String
    let headline: String

    private enum CodingKeys: String, CodingKey {
        case id = "@id"
        case areaDesc
        case event
        case headline
    }
}

struct Feature: Decodable {
    let properties: WeatherAlert
}

struct ApiResponse: Decodable {
    let features: [Feature]
}


// SLC Area Forecast Discussion (AFD)
struct AFD: Identifiable {
    let id = UUID()
    let date: String
    let synopsis: String?
    let shortTerm: String?
    let longTerm: String?
    let aviation: String?
}
class AFDViewModel: ObservableObject {
    @Published var AFDvar: AFD?
    private var cancellable: AnyCancellable?

    func fetchAFD() {
        guard let url = URL(string: forecastDiscussionLink) else { return }
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .compactMap { String(data: $0, encoding: .utf8) }
            .map { self.parseAFDData($0) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .assign(to: \.AFDvar, on: self)
    }

    private func parseAFDData(_ data: String) -> AFD? {
        guard let startRange = data.range(of: "National Weather Service Salt Lake City UT") else { return nil }
        let AFDData = data[startRange.upperBound...]
        
        // Date expected in a format like: "334 PM MDT Mon Mar 17 2025"
        guard let dateRange = AFDData.range(of: "\\d{3,4} [A-Za-z]{2} [A-Za-z]{3} [A-Za-z]{3} [A-Za-z]{3} \\d{1,2} \\d{4}", options: .regularExpression) else { return nil }
        let date = String(AFDData[dateRange])
        
        let synopsis = collapseTextLines(extractSection(from: AFDData, start: ".SYNOPSIS", end: "&&"))
        let shortTerm = collapseTextLines(extractSection(from: AFDData, start: ".SHORT TERM", end: ".LONG TERM"))
        let longTerm = collapseTextLines(extractSection(from: AFDData, start: ".LONG TERM", end: "&&"))
        let aviation = collapseTextLines(extractSection(from: AFDData, start: ".AVIATION", end: "&&"))
        
        return AFD(date: date, synopsis: synopsis, shortTerm: shortTerm, longTerm: longTerm, aviation: aviation)
    }
}

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
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
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

struct WeatherView: View {
    @StateObject private var AFDviewModel = AFDViewModel()
    @StateObject private var windAloftData = WindAloftData()
    @StateObject private var soaringForecastViewModel = SoaringForecastViewModel()
    @StateObject private var TFRviewModel = TFRViewModel()
    @Environment(\.openURL) var openURL     // Used to open URL links as an in-app sheet using Safari
    @State private var externalURL: URL?    // Used to open URL links as an in-app sheet using Safari
    @State private var showWebView = false  // Used to open URL links as an in-app sheet using Safari
    @State private var showSynopsis = true
    @State private var showShortTerm = false
    @State private var showLongTerm = false
    @State private var showAviation = true
    @State private var showSoaringForecast = true
    @State private var showSoundingData = true
    @State private var showSoaringModelData = false
    
    @State private var weatherAlerts: [WeatherAlert] = []
    @State private var noWeatherAlerts = false
    @State private var isLoadingWeatherAlerts = true
    @State private var isLoadingTFRs = true

    func fetchWeatherAlerts() {
        guard let url = URL(string: weatherAlertsAPI) else {
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let decodedResponse = try JSONDecoder().decode(ApiResponse.self, from: data)
                    DispatchQueue.main.async {
                        if !decodedResponse.features.isEmpty {
                            self.weatherAlerts = decodedResponse.features.map { $0.properties }
                        } else {
                            self.noWeatherAlerts = true
                        }
                        self.isLoadingWeatherAlerts = false
                    }
                } catch {
                    print("Error decoding JSON: \(error)")
                    DispatchQueue.main.async {
                        self.isLoadingWeatherAlerts = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoadingWeatherAlerts = false
                }
            }
        }.resume()
    }


    var body: some View {
        List {
            
            // National forecast map
            Section(header: Text("National Forecast (12 hour)")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold()) {
                    VStack {
                        WebImage (url: URL(string: forecastUSMapLink)) { image in image.resizable() }
                        placeholder: {
                            Text("Tap to view")
                                .foregroundColor(infoFontColor)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .onSuccess { image, data, cacheType in }
                        .indicator(.activity) // Activity Indicator
                        .transition(.fade(duration: 0.5)) // Fade Transition with duration
                        .scaledToFit()
                    }
                    .onTapGesture { if let url = URL(string: forecastUSMapLink) { openLink(url) } }
                }
            
            // TFRs for Utah
            Section(header: Text("Temporary Flight Restrictions")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                if TFRviewModel.isLoading {
                    ProgressView("TFRs loading...")
                } else if TFRviewModel.tfrs.isEmpty {
                    Text("There are no current TFRs for Utah")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                } else {
                    ForEach(TFRviewModel.tfrs) { tfr in
                        VStack(alignment: .leading) {
                            Text(tfr.type.capitalized)
                                .font(.subheadline)
                                .foregroundColor(warningFontColor)
                            Text(tfr.description)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())      // Makes entire area tappable
                        .onTapGesture {
                            if let url = URL(string: "https://tfr.faa.gov/tfr3/?page=detail_\(tfr.notam_id.replacingOccurrences(of: "/", with: "_"))") {
                                openLink(url)
                            }
                        }
                    }
                }
            }
            
            // Weather alerts for Utah
            Section(header: Text("Weather Alerts")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                if isLoadingWeatherAlerts {
                    ProgressView("Weather alerts loading...")
                } else if noWeatherAlerts {
                    Text("There are no current weather alerts for Utah")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                } else {
                    ForEach(weatherAlerts) { alert in
                        VStack(alignment: .leading) {
                            Text(alert.event)
                                .font(.subheadline)
                                .foregroundColor(warningFontColor)
                            Text(alert.headline)
                                .font(.subheadline)
                            Text(alert.areaDesc)
                                .font(.footnote)
                                .foregroundColor(infoFontColor)
                        }
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())      // Makes entire area tappable
                        .onTapGesture {
                            if let url = URL(string: weatherAlertsLink) {
                                openLink(url)
                            }
                        }
                    }
                }
            }
            
            // SLC Forecast Discussion
            Section(header: Text("SLC Area Forecast Discussion")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                if let AFDdata = AFDviewModel.AFDvar {
                    Text("Forecast Date: \(AFDdata.date)")
                        .font(.footnote)
                    if let synopsis = AFDdata.synopsis {
                        DisclosureGroup(
                            isExpanded: $showSynopsis,
                            content: {
                                Text(synopsis)
                                    .font(.subheadline)
                            }, label: {
                                Text("Synopsis")
                                    .font(.headline)
                                    .foregroundColor(rowHeaderColor)
                            }
                        )
                    }
                    if let shortTerm = AFDdata.shortTerm {
                        DisclosureGroup(
                            isExpanded: $showShortTerm,
                            content: {
                                Text(shortTerm)
                                    .font(.subheadline)
                            }, label: {
                                Text("Short Term Forecast")
                                    .font(.headline)
                                    .foregroundColor(rowHeaderColor)
                            }
                        )
                    }
                    if let longTerm = AFDdata.longTerm {
                        DisclosureGroup(
                            isExpanded: $showLongTerm,
                            content: {
                                Text(longTerm)
                                    .font(.subheadline)
                            }, label: {
                                Text("Long Term Forecast")
                                    .font(.headline)
                                    .foregroundColor(rowHeaderColor)
                            }
                        )
                    }
                    if let aviation = AFDdata.aviation {
                        DisclosureGroup(
                            isExpanded: $showAviation,
                            content: {
                                Text(aviation)
                                    .font(.subheadline)
                            }, label: {
                                Text("Aviation Forecast")
                                    .font(.headline)
                                    .foregroundColor(rowHeaderColor)
                            }
                        )
                    }
                } else {
                    Text("Loading...")
                }
            }
            
            // Soaring forecast
            Section(header: Text("Soaring Forecast")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                Text("Forecast Date: \(soaringForecastViewModel.soaringForecast?.date ?? "")")
                    .font(.footnote)
                DisclosureGroup(isExpanded: $showSoaringForecast) {
                    VStack(alignment: .leading) {
                        if ((soaringForecastViewModel.soaringForecast?.soaringForecastFormat) == "Rich") {
                            Text(soaringForecastViewModel.soaringForecast?.triggerTempData ?? "")
                                .font(.subheadline)
                                .padding(.bottom, 5)
                        }
                        ForEach(soaringForecastViewModel.soaringForecast?.soaringForecastData ?? []) { data in
                            HStack {
                                Text(data.heading)
                                    .multilineTextAlignment(.trailing)
                                    .font(.subheadline)
                                    .padding(.trailing, 2)
                                    .foregroundColor(infoFontColor)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(data.value ?? "")
                                    .font(.subheadline)
                                    .padding(.leading, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.bottom, 5)
                        }
                        .padding(.bottom, 1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())      // Makes entire area tappable
                    .onTapGesture {
                        if let url = URL(string: soaringForecastLink) {
                            openLink(url)
                        }
                    }
                } label: {
                    Text("Soaring Forecast")
                        .font(.headline)
                        .foregroundColor(rowHeaderColor)
                }
                DisclosureGroup(isExpanded: $showSoundingData) {
                    // Process rich format sounding data
                    if ((soaringForecastViewModel.soaringForecast?.soaringForecastFormat) == "Rich") {
                        LazyVGrid(columns: [
                            GridItem(.fixed(64), spacing: 5, alignment: .trailing),
                            GridItem(.fixed(52), spacing: 5, alignment: .trailing),
                            GridItem(.fixed(52), spacing: 5, alignment: .trailing),
                            GridItem(.fixed(56), spacing: 5, alignment: .trailing),
                            GridItem(.fixed(52), spacing: 5, alignment: .trailing)
                        ], spacing: 6) {
                            Text("Altitude")
                                .font(.footnote)
                                .foregroundColor(infoFontColor)
                            Text("Temp")
                                .font(.footnote)
                                .foregroundColor(infoFontColor)
                            Text("Wind (mph)")
                                .font(.footnote)
                                .foregroundColor(infoFontColor)
                            Text("Thermal Index")
                                .font(.footnote)
                                .foregroundColor(infoFontColor)
                                .multilineTextAlignment(.trailing)
                            Text("Lift (m/s)")
                                .font(.footnote)
                                .foregroundColor(infoFontColor)
                                .multilineTextAlignment(.trailing)
                            ForEach(soaringForecastViewModel.soaringForecast?.richSoundingData ?? []) { data in
                                Text("\(data.altitude) ft")
                                    .font(.footnote)
                                HStack {
                                    Text("\(String(Int(data.temperatureF)))")
                                        .font(.caption)
                                        .foregroundColor(tempColor(Int(data.temperatureF))) +
                                    Text(" ° F")
                                        .font(.footnote)
                                }
                                HStack {
                                    Text("\(String(Int(data.windSpeedMph)))")
                                        .font(.footnote)
                                        .foregroundColor(windSpeedColor(windSpeed: Int(data.windSpeedMph), siteType: ""))
                                    Image(systemName: windArrow)
                                        .rotationEffect(Angle(degrees: Double(data.windDirection+180)))
                                        .font(.caption)
                                }
                                Text(String(format: "%.1f", data.thermalIndex))
                                    .font(.footnote)
                                Text(String(format: "%.1f", data.liftRateMs))
                                    .font(.footnote)
                                    .foregroundStyle(thermalColor(data.liftRateMs))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())      // Makes entire area tappable
                        .onTapGesture {
                            if let url = URL(string: soaringForecastLink) {
                                openLink(url)
                            }
                        }
                    }
                    // Process simple format sounding data
                    else {
                        VStack(alignment: .leading) {
                            ForEach(soaringForecastViewModel.soaringForecast?.soundingData ?? []) { data in
                                HStack {
                                    Text(data.altitude.lowercased())
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .font(.subheadline)
                                    Spacer()
                                    Group {
                                        Text("\(data.windSpeed)")
                                            .font(.subheadline)
                                            .foregroundColor(windSpeedColor(windSpeed: Int(data.windSpeed), siteType: "")) +
                                        Text(" mph")
                                            .font(.subheadline)
                                        Image(systemName: windArrow)
                                            .rotationEffect(.degrees(Double(data.windDirection+180)))
                                            .font(.footnote)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    Spacer()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())      // Makes entire area tappable
                        .onTapGesture {
                            if let url = URL(string: soaringForecastLink) {
                                openLink(url)
                            }
                        }
                    }
                } label: {
                    Text("Sounding Data")
                        .font(.headline)
                        .foregroundColor(rowHeaderColor)
                }
                // Process rich format numerical model data
                if ((soaringForecastViewModel.soaringForecast?.soaringForecastFormat) == "Rich") {
                    DisclosureGroup(isExpanded: $showSoaringModelData) {
                        ScrollView(.horizontal) {
                            VStack(alignment: .leading) {
                                ForEach(soaringForecastViewModel.soaringForecast?.modelData ?? []) { data in
                                    Text(data.value)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .font(.system(.subheadline, design: .monospaced))
                                }
                                .padding(.vertical, 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())      // Makes entire area tappable
                            .onTapGesture {
                                if let url = URL(string: soaringForecastLink) {
                                    openLink(url)
                                }
                            }
                        }
                    } label: {
                        Text("Numerical Model Data")
                            .font(.headline)
                            .foregroundColor(rowHeaderColor)
                    }
                }
            }
            
            // Winds aloft forecast
            Section(header: Text("SLC Winds Aloft Forecast")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                Text("Forecast for the next \(windAloftData.cycle) hours")
                    .font(.footnote)
                    LazyVGrid(columns: [
                    GridItem(.fixed(64), spacing: 5, alignment: .trailing),
                    GridItem(.fixed(64), spacing: 5, alignment: .trailing),
                    GridItem(.fixed(64), spacing: 5, alignment: .trailing),
                ], spacing: 6) {
                    Text("Altitude")
                        .font(.footnote)
                        .foregroundColor(infoFontColor)
                    Text("Temp")
                        .font(.footnote)
                        .foregroundColor(infoFontColor)
                    Text("Wind (mph)")
                        .font(.footnote)
                        .foregroundColor(infoFontColor)
                    ForEach(windAloftData.readings, id: \.altitude) { reading in
                        Text("\(reading.altitude) ft")
                            .font(.footnote)
                        HStack {
                            Text("\(reading.temperature)")
                                .font(.footnote)
                                .foregroundColor(tempColor(reading.temperature)) +
                            Text(" ° F")
                                .font(.footnote)
                        }
                        if reading.windDirection == 990 {
                            Text("Light and variable")
                                .font(.footnote)
                        } else {
                            HStack {
                                Text("\(reading.windSpeed)")
                                    .font(.footnote)
                                    .foregroundColor(windSpeedColor(windSpeed: reading.windSpeed, siteType: ""))
                                Image(systemName: windArrow)
                                    .rotationEffect(Angle(degrees: Double(reading.windDirection)))
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            
            // High res Skew-T from morning sounding (from Matt Hansen)
            Section(header: Text("SLC Morning Sounding Skew-T")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold()) {
                VStack {
                    SkewTChartView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            
            // Skew-T from latest forecast model
            Section(header: Text("SLC Latest Forecast Skew-T")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold()) {
                VStack {
                    WebImage (url: URL(string: skewTLink)) { image in image.resizable() }
                    placeholder: {
                        Text("Tap to view")
                            .foregroundColor(infoFontColor)
                    }
                    .onSuccess { image, data, cacheType in }
                    .indicator(.activity) // Activity Indicator
                    .transition(.fade(duration: 0.5)) // Fade Transition with duration
                    .scaledToFit()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())      // Makes entire area tappable
                .onTapGesture { if let url = URL(string: skewTLink) { openLink(url) } }
            }
            
        }
        .onAppear (perform: fetchWeatherAlerts)
        .onAppear {
            TFRviewModel.fetchTFRs()
            AFDviewModel.fetchAFD()
            windAloftData.fetchWindAloftData()
        }
        // Used to open URL links as an in-app sheet using Safari
        .sheet(isPresented: $showWebView) { if let url = externalURL { SafariView(url: url) } }
    }
    // Used to open URL links as an in-app sheet using Safari
    func openLink(_ url: URL) { externalURL = url; showWebView = true }
}
