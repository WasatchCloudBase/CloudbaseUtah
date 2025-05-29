import SwiftUI
import Combine
import Charts

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
    @StateObject var viewModel = StationReadingsHistoryDataModel()
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
                
                VStack(alignment: .leading) {
                    if site.readingsSource == "Mesonet" {
                        Text("Readings data aggregated by Synoptic")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                        Text("https://synopticdata.com")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                            .padding(.bottom, 8)
                    }
                    if site.readingsSource == "CUASA" {
                        Text("Readings data aggregated by CUASA")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                        Text("https://sierragliding.us/cuasa")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                            .padding(.bottom, 8)
                    }
                    Text("Forecast data provided by Open-meteo")
                        .font(.caption)
                        .foregroundColor(infoFontColor)
                    Text("https://open-meteo.com")
                        .font(.caption)
                        .foregroundColor(infoFontColor)
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
            } else {
                isActive = false
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
