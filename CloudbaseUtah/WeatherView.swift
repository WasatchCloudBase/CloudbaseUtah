//  SiteView.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/6/25.

import SwiftUI
import Combine
import SDWebImage
import SDWebImageSwiftUI

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
        guard let url = URL(string: "https://tfr.faa.gov/tfrapi/exportTfrList") else { return }
        
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
        guard let url = URL(string: "https://forecast.weather.gov/product.php?site=NWS&issuedby=SLC&product=AFD&format=txt&version=1&glossary=0") else { return }
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
    let soaringForecastData: [SoaringForecastData]
    let soundingData: [SoundingData]
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
class ForecastViewModel: ObservableObject {
    @Published var soaringForecast: SoaringForecast?
    init() {
        fetchWeatherForecast()
    }
    func fetchWeatherForecast() {
        guard let url = URL(string: "https://forecast.weather.gov/product.php?site=SLC&issuedby=SLC&product=SRG&format=TXT&version=1&glossary=0") else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            if let content = String(data: data, encoding: .utf8) {
                self.parseForecast(content: content)
            }
        }.resume()
    }
    func parseForecast(content: String) {
        let start = "SOARING FORECAST FOR SALT LAKE CITY"
        let datePrefix = "DATE..."
        let thermalIndexPrefix = "THERMAL INDEX..."
        let upperLevelWindsPrefix = "UPPER LEVEL WINDS AT SALT LAKE CITY"
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
        guard let thermalIndexRange = content.range(of: thermalIndexPrefix, range: dateRange.upperBound..<content.endIndex)
        else {
            print("Soaring forecast: could not parse thermal index range (e.g., no row for \(thermalIndexPrefix))")
            return
        }
        guard let upperLevelWindsRange = content.range(of: upperLevelWindsPrefix, range: thermalIndexRange.upperBound..<content.endIndex)
        else {
            print("Soaring forecast: could not parse upper level winds range (e.g., no row for \(upperLevelWindsPrefix))")
            return
        }
        guard let endRange = content.range(of: endPrefix, range: upperLevelWindsRange.upperBound..<content.endIndex)
        else {
            print("Could not parse end range (e.g., no row for \(endPrefix))")
            return
        }
        let date = String(content[dateRange.upperBound...].prefix(9)).trimmingCharacters(in: .whitespacesAndNewlines)
        let soaringForecastDataSring = removeExtraBlankLines(String(content[thermalIndexRange.upperBound..<upperLevelWindsRange.lowerBound]))
        let soaringForecast = parseSoaringForecastData(soaringForecastDataSring)
        let soundingDataString = removeExtraBlankLines(String(content[upperLevelWindsRange.upperBound..<endRange.lowerBound]))
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
                let adjustedWindDirection = (windDirection + 180) % 360
                let windSpeedMph = convertKnotsToMPH(Int(windSpeed))
                let altitudeString = formatAltitude(String(altitude))
                return SoundingData(altitude: altitudeString, windDirection: adjustedWindDirection, windSpeed: windSpeedMph)
        }
        DispatchQueue.main.async {
            self.soaringForecast = SoaringForecast(date: date, soaringForecastData: soaringForecast, soundingData: soundingData.reversed())
        }
    }
    func parseSoaringForecastData(_ input: String) -> [SoaringForecastData] {
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
    @StateObject private var viewModel = ForecastViewModel()
    @StateObject private var TFRviewModel = TFRViewModel()
    @Environment(\.openURL) var openURL     // Used to open URL links as an in-app sheet using Safari
    @State private var externalURL: URL?    // Used to open URL links as an in-app sheet using Safari
    @State private var showWebView = false  // Used to open URL links as an in-app sheet using Safari
    @State private var showSynopsis = true
    @State private var showShortTerm = false
    @State private var showLongTerm = false
    @State private var showAviation = false
    @State private var isForecastCollapsed = true
    @State private var isSoundingDataCollapsed = true
    
    @State private var weatherAlerts: [WeatherAlert] = []
    @State private var noWeatherAlerts = false
    @State private var isLoadingWeatherAlerts = true
    @State private var isLoadingTFRs = true

    func fetchWeatherAlerts() {
        guard let url = URL(string: "https://api.weather.gov/alerts/active?area=UT") else {
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
                let forecastURL = "https://www.wpc.ncep.noaa.gov/basicwx/92fndfd.gif"
                VStack {
                    WebImage (url: URL(string: forecastURL)) { image in image.resizable() }
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
                .onTapGesture { if let url = URL(string: forecastURL) { openLink(url) } }
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
                                .font(.headline)
                                .foregroundColor(warningFontColor)
                            Text(tfr.description)
                                .font(.subheadline)
                        }
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
                                .font(.headline)
                                .foregroundColor(warningFontColor)
                            Text(alert.headline)
                                .font(.subheadline)
                            Text(alert.areaDesc)
                                .font(.footnote)
                                .foregroundColor(infoFontColor)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let url = URL(string: "https://www.weather.gov/slc/WWA") {
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
            Section(header: Text("Soaring Forecast and Sounding Data")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                Text("Forecast Date: \(viewModel.soaringForecast?.date ?? "")")
                    .font(.footnote)
                DisclosureGroup(isExpanded: $isForecastCollapsed) {
                    VStack(alignment: .leading) {
                        ForEach(viewModel.soaringForecast?.soaringForecastData ?? []) { data in
                            HStack {
                                Text(data.heading)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .font(.subheadline)
                                    .padding(.trailing, 10)
                                Spacer()
                                Text(data.value ?? "")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .font(.subheadline)
                                    .padding(.leading, 10)
                                Spacer()
                            }
                        }
                        .padding(.bottom, 1)
                    }
                } label: {
                    Text("Soaring Forecast")
                        .font(.headline)
                        .foregroundColor(rowHeaderColor)
                }
                DisclosureGroup(isExpanded: $isSoundingDataCollapsed) {
                    VStack(alignment: .leading) {
                        ForEach(viewModel.soaringForecast?.soundingData ?? []) { data in
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
                                        .rotationEffect(.degrees(Double(data.windDirection)))
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                Spacer()
                            }
                        }
                    }
                } label: {
                    Text("Sounding Data")
                        .font(.headline)
                        .foregroundColor(rowHeaderColor)
                }
            }
            Section(header: Text("SLC Winds Aloft Forecast")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold()) {
                Text("Forecast for the next \(windAloftData.cycle) hours")
                    .font(.footnote)
                VStack(alignment: .leading) {
                    ForEach(windAloftData.readings, id: \.altitude) { reading in
                        HStack {
                            Text("\(reading.altitude) ft")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .font(.subheadline)
                            Spacer()
                            Group {
                                Text("\(reading.temperature)")
                                    .font(.subheadline)
                                    .foregroundColor(tempColor(reading.temperature)) +
                                Text("° F")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            Spacer()
                            if reading.windDirection == 990 {
                                Text("Light and variable")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .font(.subheadline)
                            } else {
                                Group {
                                    Text("\(reading.windSpeed)")
                                        .font(.subheadline)
                                        .foregroundColor(windSpeedColor(windSpeed: reading.windSpeed, siteType: "")) +
                                     Text(" mph")
                                        .font(.subheadline)
                                    Image(systemName: windArrow)
                                        .rotationEffect(Angle(degrees: Double(reading.windDirection)))
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 1)
                    }
                }
            }
            Section(header: Text("SLC Skew-T")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold()) {
//                let skewTURL = "https://weather.ral.ucar.edu/upper/displayUpper.php?img=KSLC.png&endDate=-1&endTime=-1&duration=0"
                let skewTURL = "https://www.weather.gov/zse/ModelSounding?id=kslc&model=hrrr"
                VStack {
                    WebImage (url: URL(string: skewTURL)) { image in image.resizable() }
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
                .onTapGesture { if let url = URL(string: skewTURL) { openLink(url) } }
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
