import SwiftUI
import Combine
import Charts

struct ReadingsData: Codable {
    let STATION: [Station]
}

struct Station: Codable {
    let OBSERVATIONS: Observations
}

struct Observations: Codable {
    let date_time: [String]
    let wind_speed_set_1: [Double?]
    let wind_gust_set_1: [Double?]?
    let wind_direction_set_1: [Double]
}

struct ReadingsHistoryData {
    var times: [String]
    var windSpeed: [Double]
    var windGust: [Double?]
    var windDirection: [Double]
    var errorMessage: String?
}

class ReadingsHistoryDataModel: ObservableObject {
    @Published var readingsHistoryData = ReadingsHistoryData(
        times: [],
        windSpeed: [],
        windGust: [],
        windDirection: [],
        errorMessage: nil
    )
    private var cancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    func GetReadingsHistoryData(stationID: String, readingsSource: String) {
        switch readingsSource {
        case "Mesonet":
            let parameters = "&stid=\(stationID)"
            let urlString = historyReadingsAPIHeader + parameters + historyReadingsAPITrailer + mesowestAPIToken
            let url = URL(string: urlString)!
            cancellable = URLSession.shared.dataTaskPublisher(for: url)
                .map { $0.data }
                .map { data in
                    // Convert data to string, replace "null" with "0.0", and convert back to data
                    if var jsonString = String(data: data, encoding: .utf8) {
                        jsonString = jsonString.replacingOccurrences(of: "null", with: "0.0")
                        return Data(jsonString.utf8)
                    }
                    return data
                }
                .decode(type: ReadingsData.self, decoder: JSONDecoder())
                .replaceError(with: ReadingsData(STATION: []))
                .receive(on: DispatchQueue.main)
                .sink { [weak self] data in
                    guard let self = self, let station = data.STATION.first else {
                        print("No valid data found for station: \(stationID)")
                        self?.readingsHistoryData.errorMessage = "No valid data found for station: \(stationID)"
                        return
                    }
                    let recentTimes = Array(station.OBSERVATIONS.date_time.suffix(8))
                    let recentWindSpeed = Array(station.OBSERVATIONS.wind_speed_set_1.suffix(8)).map { $0 ?? 0.0 }
                    let recentWindGust = station.OBSERVATIONS.wind_gust_set_1?.suffix(8).map { $0 ?? 0.0 } ?? Array(repeating: nil, count: 8)
                    let recentWindDirection = Array(station.OBSERVATIONS.wind_direction_set_1.suffix(8))
                    if let latestTimeString = recentTimes.last,
                       let latestTime = ISO8601DateFormatter().date(from: latestTimeString),
                       Date().timeIntervalSince(latestTime) > 2 * 60 * 60 {
                        self.readingsHistoryData.errorMessage = "Station \(stationID) has not updated in the past 2 hours"
                        print("Station \(stationID) has not updated in the past 2 hours")
                    } else {
                        self.readingsHistoryData.times = recentTimes
                        self.readingsHistoryData.windSpeed = recentWindSpeed
                        self.readingsHistoryData.windGust = recentWindGust
                        self.readingsHistoryData.windDirection = recentWindDirection
                        self.readingsHistoryData.errorMessage = nil
                    }
                }
            // end of let url...URLSession... section
        case "CUASA":
            let readingInterval: Double = 5 * 60 // 5 minutes in seconds
            let readingEnd = Date().timeIntervalSince1970 // current timestamp in seconds
            let readingStart = readingEnd - (readingInterval * 10) // to ensure >= 8 readings
            let urlString = "https://sierragliding.us/api/station/" + stationID + "/data?start=" + String(readingStart) + "&end=" + String(readingEnd) + "&sample=" + String(readingInterval)
            guard let url = URL(string: urlString) else {
                self.readingsHistoryData.errorMessage = "Invalid CUASA readings URL"
                print("Invalid CUASA readings URL")
                return
            }
            URLSession.shared.dataTaskPublisher(for: url)
                .map { $0.data }
                .decode(type: [CUASAReadingsData].self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        self.readingsHistoryData.errorMessage = error.localizedDescription
                        print("Error fetching CUASA data: \(error.localizedDescription)")
                    case .finished:
                        break
                    }
                }, receiveValue: { [weak self] readingsHistoryDataArray in
                    self?.processCUASAReadingsHistoryData(readingsHistoryDataArray)
                })
                .store(in: &cancellables)
            // end of let url...URLSession... section
        default:
            print("Invalid readings source for station: \(stationID)")
        }
    }
    
    private func processCUASAReadingsHistoryData(_ readingsHistoryDataArray: [CUASAReadingsData]) {
        guard let latestEntry = readingsHistoryDataArray.last else {
            self.readingsHistoryData.errorMessage = "No data available"
            print("No data available from CUASA")
            return
        }
        let currentTime = Date().timeIntervalSince1970
        let twoHoursInSeconds: Double = 2 * 60 * 60
        if currentTime - latestEntry.timestamp > twoHoursInSeconds {
            self.readingsHistoryData.errorMessage = "Station has not updated in the past 2 hours"
            print("Station has not updated in the past 2 hours")
            return
        }
        let recentEntries = Array(readingsHistoryDataArray.suffix(8))
        updateCUASAReadingsHistory(with: recentEntries)
    }
    
    private func updateCUASAReadingsHistory(with readingsHistoryDataArray: [CUASAReadingsData]) {
        var times = [String]()
        var windSpeed = [Double]()
        var windGust = [Double?]()
        var windDirection = [Double]()
        for data in readingsHistoryDataArray {
            let date = Date(timeIntervalSince1970: data.timestamp)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "H:mm"
            times.append(dateFormatter.string(from: date))
            windSpeed.append(convertKMToMiles(data.windspeed_avg))
            windGust.append(convertKMToMiles(data.windspeed_max))
            windDirection.append(data.wind_direction_avg)
        }
        self.readingsHistoryData = ReadingsHistoryData(
            times: times,
            windSpeed: windSpeed,
            windGust: windGust,
            windDirection: windDirection,
            errorMessage: nil
        )
    }
}

struct ReadingsHistoryBarChartView: View {
    var readingsHistoryData: ReadingsHistoryData
    var siteType: String

    var body: some View {
        let count = min(readingsHistoryData.times.count, 10)
        let dataRange = (readingsHistoryData.times.count - count)..<readingsHistoryData.times.count
        
        Chart {
            ForEach(dataRange, id: \.self) { index in
                let windSpeed = readingsHistoryData.windSpeed[index]
                let windGust = readingsHistoryData.windGust[index] ?? 0.0
                let windDirection = readingsHistoryData.windDirection[index]
                let time = readingsHistoryData.times[index]
                let windColor = windSpeedColor(windSpeed: Int(windSpeed), siteType: siteType)
                let gustColor = windSpeedColor(windSpeed: Int(windGust), siteType: siteType)
                
                BarMark(
                    x: .value("Time", time),
                    yStart: .value("Wind Speed", 0),
                    yEnd: .value("Wind Speed", windSpeed)
                )
                .foregroundStyle(windColor)
                .annotation(position: .bottom) {
                    VStack {
                        Text("\(Int(windSpeed))")
                            .font(.caption)
                            .foregroundColor(windColor)
                            .bold()
                        Image(systemName: windArrow)
                            .rotationEffect(.degrees(Double(windDirection + 180)))
                            .bold()
                            .font(.footnote)
                        // Replace x-axis values with hh:mm and strip the am/pm
                        Text(String(time).split(separator: " ", maxSplits: 1).first ?? "")
                            .font(.caption)
                    }
                }
                if windGust > 0 {
                    BarMark(
                        x: .value("Time", time),
                        yStart: .value("Wind Speed", windSpeed + 1), // Create a gap
                        yEnd: .value("Wind Gust", windSpeed + windGust + 1)
                    )
                    .foregroundStyle(gustColor)
                    .annotation(position: .top) {
                        HStack(spacing: 4) {
                            Text("g")
                                .font(.caption)
                            Text("\(Int(windGust))")
                                .font(.caption)
                                .foregroundColor(gustColor)
                                .bold()
                        }
                    }
                }
            }
        }
        .chartYAxis(.hidden) // Remove the y-axis values
        .chartXAxis(.hidden)
        .chartXAxis { AxisMarks(stroke: StrokeStyle(lineWidth: 0)) }  // Hide vertical column separators
        .frame(height: 90) // Reduce the chart height
    }
}

struct SiteDetailView: View {
    var site: Sites  // Received from parent view
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodesViewModel
    @StateObject var viewModel = ReadingsHistoryDataModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) var openURL     // Used to open URL links as an in-app sheet using Safari
    @State private var externalURL: URL?    // Used to open URL links as an in-app sheet using Safari
    @State private var showWebView = false  // Used to open URL links as an in-app sheet using Safari
    @State private var isActive = false
    @State private var historyIsLoading = true
        
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(toolbarActiveImageColor)
                        Text("Back")
                            .foregroundColor(toolbarActiveFontColor)
                        Spacer()
                        Text(site.siteName)
                            .foregroundColor(sectionHeaderColor)
                            .bold()
                    }
                }
                .padding()
                Spacer()
            }
            .background(toolbarBackgroundColor)
            
            List {
                
                Section(header: Text("Wind Readings")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    VStack {
                        VStack (alignment: .leading) {
                            Text(buildReferenceNote(Alt: site.readingsAlt, Note: site.readingsNote))
                                .font(.footnote)
                                .foregroundColor(infoFontColor)
                            if historyIsLoading {
                                Text ("Loading readings history...")
                                    .padding(.top, 8)
                                    .font(.caption)
                                    .foregroundColor(infoFontColor)
                            } else if let errorMessage = viewModel.readingsHistoryData.errorMessage {
                                Text("Error message:")
                                    .padding(.top, 8)
                                Text(errorMessage)
                            } else if viewModel.readingsHistoryData.times.isEmpty {
                                Text("Station down")
                                    .padding(.top, 8)
                                    .font(.caption)
                                    .foregroundColor(infoFontColor)
                            } else {
                                ReadingsHistoryBarChartView(readingsHistoryData: viewModel.readingsHistoryData, siteType: site.siteType)
                            }
                        }
                        VStack (alignment: .center) {
                            switch site.readingsSource {
                            case "Mesonet":
                                Text("Tap for 2 day readings history")
                                    .font(.caption)
                                    .foregroundColor(infoFontColor)
                                    .padding(.top, 4)
                            case "CUASA":
                                Text("Tap for CUASA live readings site")
                                    .font(.caption)
                                    .foregroundColor(infoFontColor)
                                    .padding(.top, 4)
                            default:
                                Text("Invalid readings source; no history available")
                                    .font(.caption)
                                    .foregroundColor(infoFontColor)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .contentShape(Rectangle()) // Makes entire area tappable
                    .onTapGesture {
                        switch site.readingsSource {
                        case "Mesonet":
                            if let url = URL(string: "https://www.weather.gov/wrh/timeseries?site=\(site.readingsStation)&hours=48&units=english&chart=off&headers=none&obs=tabular") {
                                openLink(url)
                            }
                        case "CUASA":
                            if let url = URL(string: "https://sierragliding.us/cuasa/#station=\(site.readingsStation)") {
                                openLink(url)
                            }
                        default:
                            print ("Invalid readings source")
                        }
                    }
                }
                
                Section(header: Text("Daily Forecast")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    SiteDailyForecastView (
                        weatherCodesViewModel: weatherCodesViewModel,
                        siteLat: site.siteLat,
                        siteLon: site.siteLon,
                        forecastNote: site.forecastNote,
                        siteName: site.siteName,
                        siteType: site.siteType )
                }
                
                Section(header: Text("Detailed Forecast")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    SiteForecastView (
                        liftParametersViewModel: liftParametersViewModel,
                        sunriseSunsetViewModel: sunriseSunsetViewModel,
                        weatherCodesViewModel: weatherCodesViewModel,
                        siteLat: site.siteLat,
                        siteLon: site.siteLon,
                        forecastNote: site.forecastNote,
                        siteName: site.siteName,
                        siteType: site.siteType )
                }
                
                if site.readingsSource == "Mesonet" {
                    VStack(alignment: .leading) {
                        Text("Readings data aggregated by Synoptic")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                        Text("https://synopticdata.com")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                    }
                }
            }
            Spacer() // Push the content to the top of the sheet
        }
        .onAppear {
            viewModel.GetReadingsHistoryData(stationID: site.readingsStation, readingsSource: site.readingsSource)
            isActive = true
            historyIsLoading = true
            startTimer()
        }
        .onReceive(viewModel.$readingsHistoryData) { newData in
            historyIsLoading = false
        }
        .onDisappear {
            isActive = false
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                viewModel.GetReadingsHistoryData(stationID: site.readingsStation, readingsSource: site.readingsSource)
            }
        }
        .sheet(isPresented: $showWebView) { if let url = externalURL { SafariView(url: url) } }
    }

    // Used to open URL links as an in-app sheet using Safari
    func openLink(_ url: URL) { externalURL = url; showWebView = true }
    
    // Reload readings data when page is active for a time interval
    private func startTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + pageRefreshInterval) {
            if isActive {
                viewModel.GetReadingsHistoryData(stationID: site.readingsStation, readingsSource: site.readingsSource)
                startTimer() // Continue the timer loop
            }
        }
    }
}
