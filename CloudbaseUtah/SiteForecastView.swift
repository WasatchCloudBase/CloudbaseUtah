//
//  SiteForecastView.swift
//  CloudbaseUtah
//
//  Created by Brown, Mike on 3/24/25.
//
import SwiftUI
import Combine
import Charts

struct SiteForecastView: View {
    @ObservedObject var liftParametersViewModel: LiftParametersViewModel
    @StateObject private var viewModel: SiteForecastViewModel
    var forecastLat: String
    var forecastLon: String
    var forecastNote: String
    var siteType: String
    
    init(liftParametersViewModel: LiftParametersViewModel, forecastLat: String, forecastLon: String, forecastNote: String, siteType: String) {
        self._liftParametersViewModel = ObservedObject(wrappedValue: liftParametersViewModel)
        self._viewModel = StateObject(wrappedValue: SiteForecastViewModel(liftParametersViewModel: liftParametersViewModel))
        self.forecastLat = forecastLat
        self.forecastLon = forecastLon
        self.forecastNote = forecastNote
        self.siteType = siteType
    }
    
    var body: some View {
        VStack (alignment: .leading) {
            if let forecastData = viewModel.forecastData {
                VStack(alignment: .leading) {
                    let Alt = formatAltitude(String(convertMetersToFeet(forecastData.elevation)))
                    Text(buildReferenceNote(Alt: "\(Alt)", Note: forecastNote))
                        .font(.footnote)
                        .foregroundColor(infoFontColor)
                        .padding(.top, 8)
                        .padding(.bottom, 5)
                    
                    let maxPressureReading = viewModel.maxPressureReading
                    
                    // Create a grid structure to enable different heights by row
                    let headingHeight: CGFloat = 10
                    let imageHeight: CGFloat = 24
                    let dataHeight: CGFloat = 11
                    let labelHeight: CGFloat = 10
                    let doubleHeight: CGFloat = dataHeight * 3
                    let gridItems: [GridItem] = {
                        var items = Array(repeating: GridItem(.fixed(headingHeight)), count: 1)     // Day
                        items += Array(repeating: GridItem(.fixed(headingHeight)), count: 1)        // Date
                        items += Array(repeating: GridItem(.fixed(headingHeight)), count: 1)        // Time
                        items += Array(repeating: GridItem(.fixed(imageHeight)), count: 1)          // Skies
                        items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1)           // ToL Temp
                        items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1)           // Surf Temp
                        items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1)           // Cloud %
                        items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1)           // Precip %
                        items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1)           // CAPE
                        items += Array(repeating: GridItem(.fixed(labelHeight)), count: 1)          // Wind label
                        if maxPressureReading >= 500 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 550 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 600 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 650 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 700 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 750 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 800 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 850 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 900 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        items += Array(repeating: GridItem(.fixed(doubleHeight)), count: 1)         // Surface wind
                        items += Array(repeating: GridItem(.fixed(labelHeight)), count: 1)          // Thermal label
                        items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1)           // Top of lift
                        if maxPressureReading >= 500 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 550 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 600 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 650 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 700 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 750 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 800 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 850 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        if maxPressureReading >= 900 { items += Array(repeating: GridItem(.fixed(dataHeight)), count: 1) }
                        return items
                    } ()
                    HStack(alignment: .top) {
                        LazyHGrid(rows: gridItems) {
                            Group {
                                Text(" ")
                                Text(" ")
                                Text(" ")
                                Text(" ")
                                Text("ToL Temp")
                                Text("Surf Temp")
                                Text("Cloud %")
                                Text("Precip %")
                                Text("CAPE")
                                Text("Wind")
                                    .foregroundColor(infoFontColor)
                                if maxPressureReading >= 500 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_500hPa.first ?? 500))k ft")
                                }
                                if maxPressureReading >= 550 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_550hPa.first ?? 550))k ft")
                                }
                                if maxPressureReading >= 600 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_600hPa.first ?? 600))k ft")
                                }
                                if maxPressureReading >= 650 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_650hPa.first ?? 650))k ft")
                                }
                                if maxPressureReading >= 700 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_700hPa.first ?? 700))k ft")
                                }
                                if maxPressureReading >= 750 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_750hPa.first ?? 750))k ft")
                                }
                                if maxPressureReading >= 800 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_800hPa.first ?? 800))k ft")
                                }
                                if maxPressureReading >= 850 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_850hPa.first ?? 850))k ft")
                                }
                                if maxPressureReading >= 900 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_900hPa.first ?? 900))k ft")
                                }
                                Text("Surface")
                                Text("Thermals")
                                    .foregroundColor(infoFontColor)
                                Text("Top of Lift")
                                if maxPressureReading >= 500 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_500hPa.first ?? 500))k ft")
                                }
                                if maxPressureReading >= 550 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_550hPa.first ?? 550))k ft")
                                }
                                if maxPressureReading >= 600 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_600hPa.first ?? 600))k ft")
                                }
                                if maxPressureReading >= 650 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_650hPa.first ?? 650))k ft")
                                }
                                if maxPressureReading >= 700 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_700hPa.first ?? 700))k ft")
                                }
                                if maxPressureReading >= 750 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_750hPa.first ?? 750))k ft")
                                }
                                if maxPressureReading >= 800 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_800hPa.first ?? 800))k ft")
                                }
                                if maxPressureReading >= 850 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_850hPa.first ?? 850))k ft")
                                }
                                if maxPressureReading >= 900 {
                                    Text("\(Int(forecastData.hourly.geopotential_height_900hPa.first ?? 900))k ft")
                                }
                            }
                        }
                        //                        .padding(.vertical, 6)
                        
                        ScrollView(.horizontal) {
                            LazyHGrid(rows: gridItems) {
                                if let forecastData = viewModel.forecastData {
                                    ForEach(forecastData.hourly.dateTime?.indices ?? 0..<0, id: \.self) { index in
                                        Group {
                                            if forecastData.hourly.newDateFlag?[index] ?? true {
                                                Text(forecastData.hourly.formattedDay?[index] ?? "")
                                                Text(forecastData.hourly.formattedDate?[index] ?? "")
                                            } else {
                                                Text(forecastData.hourly.formattedDay?[index] ?? "")
                                                    .foregroundColor(repeatDateTimeColor)
                                                Text(forecastData.hourly.formattedDate?[index] ?? "")
                                                    .foregroundColor(repeatDateTimeColor)
                                            }
                                            Text(forecastData.hourly.formattedTime?[index] ?? "")
                                            Image(systemName: forecastData.hourly.weatherCodeImage?[index] ?? "questionmark")
                                                .renderingMode(.original) // Use .multicolor for multicolor rendering
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 24, height: 24)
                                            if forecastData.hourly.topOfLiftTemperature?[index] ?? -999 > -999 {
                                                Text("\(Int(forecastData.hourly.topOfLiftTemperature?[index] ?? -999))°")
                                                    .foregroundStyle(tempColor(Int(forecastData.hourly.topOfLiftTemperature?[index] ?? -999)))
                                            } else {
                                                Text("")
                                            }
                                            Text("\(Int(forecastData.hourly.temperature_2m[index]))°")
                                                .foregroundStyle(tempColor(Int(forecastData.hourly.temperature_2m[index])))
                                            Text(forecastData.hourly.cloudcover[index] == 0 ? "" : "\(Int(forecastData.hourly.cloudcover[index]))")
                                                .foregroundStyle(cloudCoverColor(Int(forecastData.hourly.cloudcover[index])))
                                            Text(forecastData.hourly.precipitation_probability[index] == 0 ? "" : "\(Int(forecastData.hourly.precipitation_probability[index]))")
                                                .foregroundStyle(precipColor(Int(forecastData.hourly.precipitation_probability[index])))
                                            Text(forecastData.hourly.cape[index] == 0 ? "" : "\(Int(forecastData.hourly.cape[index]))")
                                                .foregroundStyle(CAPEColor(Int(forecastData.hourly.cape[index])))
                                            Text(" ")
                                                .frame(maxWidth: .infinity)
                                                .overlay(
                                                    Rectangle()
                                                        .frame(height: 1)
                                                        .foregroundColor(tableSectionDividerColor),
                                                    alignment: .center
                                                )
                                            if maxPressureReading >= 500 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_500hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_500hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_500hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 550 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_550hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_550hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_550hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 600 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_600hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_600hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_600hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 650 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_650hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_650hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_650hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 700 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_700hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_700hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_700hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 750 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_750hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_750hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_750hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 800 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_800hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_800hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_800hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 850 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_850hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_850hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_850hPa[index] - 180))
                                                }
                                            }
                                            if maxPressureReading >= 900 {
                                                HStack {
                                                    Text("\(Int(forecastData.hourly.windspeed_900hPa[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_900hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_900hPa[index] - 180))
                                                }
                                            }
                                            HStack(spacing: 1) {
                                                VStack(spacing: 1) {
                                                    Text("\(Int(forecastData.hourly.windspeed_10m[index]))")
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_10m[index]), siteType: siteType))
                                                    HStack (spacing: 1) {
                                                        Text("g")
                                                            .font(.caption)
                                                        Text("\(Int(forecastData.hourly.windgusts_10m[index]))")
                                                            .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windgusts_10m[index]), siteType: siteType))
                                                    }
                                                    
                                                }
                                                Image(systemName: windArrow)
                                                    .rotationEffect(.degrees(forecastData.hourly.winddirection_10m[index] - 180))
                                            }
                                            Text(" ")
                                                .frame(maxWidth: .infinity)
                                                .overlay(
                                                    Rectangle()
                                                        .frame(height: 1)
                                                        .foregroundColor(tableSectionDividerColor),
                                                    alignment: .center
                                                )
                                            if forecastData.hourly.formattedTopOfLiftAltitude?[index] ?? "" == "rocket" {
                                                Image("rocket")
                                                    .renderingMode(.original) // Use .multicolor for multicolor rendering
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 20, height: 20)
                                            } else {
                                                Text(forecastData.hourly.formattedTopOfLiftAltitude?[index] ?? "")
                                            }
                                            if maxPressureReading >= 500 {
                                                Text("\(forecastData.hourly.thermalVelocity_500hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_500hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_500hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 550 {
                                                Text("\(forecastData.hourly.thermalVelocity_550hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_550hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_550hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 600 {
                                                Text("\(forecastData.hourly.thermalVelocity_600hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_600hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_600hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 650 {
                                                Text("\(forecastData.hourly.thermalVelocity_650hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_650hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_650hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 700 {
                                                Text("\(forecastData.hourly.thermalVelocity_700hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_700hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_700hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 750 {
                                                Text("\(forecastData.hourly.thermalVelocity_750hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_750hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_750hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 800 {
                                                Text("\(forecastData.hourly.thermalVelocity_800hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_800hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_800hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 850 {
                                                Text("\(forecastData.hourly.thermalVelocity_850hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_850hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_850hPa?[index] ?? 0))
                                            }
                                            if maxPressureReading >= 900 {
                                                Text("\(forecastData.hourly.thermalVelocity_900hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_900hPa?[index] ?? 0))")
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_900hPa?[index] ?? 0))
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .overlay(
                                            Rectangle()
                                                .frame(width: 1)
                                                .foregroundColor(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)),
                                            alignment: .leading
                                        )
                                    }
                                }
                            }
//                            .padding(.vertical, 6)
//                            .frame(maxWidth: .infinity, alignment: .center)
//                            .background(tableBackgroundColor)
//                            .cornerRadius(15)
                        }
                    }
//print("data for chart:  ")
//print (forecastData.hourly.dateTime.first)
//print(forecastData.hourly.topOfLiftAltitude)
/*                    if let chartDateTime = forecastData.hourly.dateTime, let chartTopOfLiftAltitude = forecastData.hourly.topOfLiftAltitude {
                     Text("so far so good")
                     let data = zip(chartDateTime, chartTopOfLiftAltitude.compactMap { Double($0) }).map { (date: $0.0, altitude: $0.1) }
                     
                     Chart(data) { item in
                     AreaMark(
                     x: .value("Date", item.date),
                     y: .value("Altitude", item.altitude)
                     )
                     .interpolationMethod(.catmullRom)
                     .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))
                     }
                     .chartXAxis {
                     AxisMarks(values: .stride(by: .hour)) { value in
                     AxisValueLabel(format: .dateTime.hour().minute(), centered: true)
                     }
                     }
                     .chartYAxis {
                     AxisMarks { value in
                     AxisValueLabel()
                     }
                     }
                     .frame(height: 300)
                     .padding()
                     
                     } else {
                     Text("No data available")
                     }
*/
                }
                Spacer()
            }
        }
        .onAppear {
            viewModel.fetchForecast(ForecastLat: forecastLat, ForecastLon: forecastLon)
        }
    }
    
    func getDividerColor (_ newDateFlag: Bool) -> Color {
        if newDateFlag {
            return tableMajorDividerColor
        } else {
            return tableMinorDividerColor
        }
    }
}
