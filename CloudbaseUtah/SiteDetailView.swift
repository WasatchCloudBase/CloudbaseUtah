//
//  SiteDetailView.swift
//  CloudbaseUtah
//
//  Created by Brown, Mike on 3/23/25.
//
import SwiftUI
import Combine
import Charts

struct WindData: Codable {
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

struct WindViewData {
    var times: [String]
    var windSpeed: [Double]
    var windGust: [Double?]
    var windDirection: [Double]
    var errorMessage: String?
}

class WindDataViewModel: ObservableObject {
    @Published var windViewData = WindViewData(
        times: [],
        windSpeed: [],
        windGust: [],
        windDirection: [],
        errorMessage: nil
    )
    private var cancellable: AnyCancellable?
    
    func fetchWindData(stationID: String) {
        let url = URL(string: "https://api.mesowest.net/v2/station/timeseries?&stid=\(stationID)&recent=420&vars=air_temp,wind_direction,wind_gust,wind_speed&units=english,speed|mph,temp|F&within=120&obtimezone=local&timeformat=%-I:%M %p&token=ef3b9f4584b64e6da12d8688f19d9f4a")!
        
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
            .decode(type: WindData.self, decoder: JSONDecoder())
            .replaceError(with: WindData(STATION: []))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                guard let self = self, let station = data.STATION.first else { return }
                let recentTimes = Array(station.OBSERVATIONS.date_time.suffix(8))
                let recentWindSpeed = Array(station.OBSERVATIONS.wind_speed_set_1.suffix(8)).map { $0 ?? 0.0 }
                let recentWindGust = station.OBSERVATIONS.wind_gust_set_1?.suffix(8).map { $0 ?? 0.0 } ?? Array(repeating: nil, count: 8)
                let recentWindDirection = Array(station.OBSERVATIONS.wind_direction_set_1.suffix(8))
                
                if let latestTimeString = recentTimes.last,
                   let latestTime = ISO8601DateFormatter().date(from: latestTimeString),
                   Date().timeIntervalSince(latestTime) > 2 * 60 * 60 {
                    self.windViewData.errorMessage = "Station has not updated in the past 2 hours"
                } else {
                    self.windViewData.times = recentTimes
                    self.windViewData.windSpeed = recentWindSpeed
                    self.windViewData.windGust = recentWindGust
                    self.windViewData.windDirection = recentWindDirection
                    self.windViewData.errorMessage = nil
                }
            }
    }
}

struct SiteDetailView: View {
    var site: Site  // Received from parent view
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @ObservedObject var viewModel = WindDataViewModel()
    
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
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    VStack (alignment: .leading) {
                        Text(buildReferenceNote(Alt: site.readingsAlt, Note: site.readingsNote))
                            .font(.footnote)
                            .foregroundColor(infoFontColor)
                        if let errorMessage = viewModel.windViewData.errorMessage {
                            Text("Error message:")
                            Text(errorMessage)
                        } else if viewModel.windViewData.times.isEmpty {
                            Text("Station down")
                                .font(.caption)
                                .foregroundColor(infoFontColor)
                                .onAppear {
                                    viewModel.fetchWindData(stationID: site.readingsStation)
                                }
                        } else {
                            WindReadingsBarChartView(windViewData: viewModel.windViewData, siteType: site.siteType)
                        }
                    }
                }
                Section(header: Text("Forecast")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    SiteForecastView (
                        liftParametersViewModel: liftParametersViewModel,
                        forecastLat: site.forecastLat,
                        forecastLon: site.forecastLon,
                        forecastNote: site.forecastNote,
                        siteType: site.siteType )
                }
                VStack(alignment: .leading) {
                    Text("Readings data aggregated by Synoptic")
                        .font(.caption)
                        .foregroundColor(infoFontColor)
                    Text("https://synopticdata.com")
                        .font(.caption)
                        .foregroundColor(infoFontColor)
                }
            }
            Spacer() // Push the content to the top of the sheet
        }
    }
}

struct WindReadingsBarChartView: View {
    var windViewData: WindViewData
    var siteType: String

    var body: some View {
        let count = min(windViewData.times.count, 10)
        let dataRange = (windViewData.times.count - count)..<windViewData.times.count
        
        Chart {
            ForEach(dataRange, id: \.self) { index in
                let windSpeed = windViewData.windSpeed[index]
                let windGust = windViewData.windGust[index] ?? 0.0
                let windDirection = windViewData.windDirection[index]
                let time = windViewData.times[index]
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
                            .foregroundColor(.white)
                            .bold()
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
