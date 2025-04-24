import SwiftUI
import Combine
import Charts

// For top of lift area chart
struct TopOfLiftDataPoint: Identifiable {
    var id = UUID()
    var index: Int
    var altitude: Double
}

struct SiteForecastView: View {
    @ObservedObject var liftParametersViewModel: LiftParametersViewModel
    @ObservedObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @ObservedObject var weatherCodesViewModel: WeatherCodesViewModel
    @StateObject private var viewModel: SiteForecastViewModel
    var forecastLat: String
    var forecastLon: String
    var forecastNote: String
    var siteName: String
    var siteType: String
    
    init(liftParametersViewModel: LiftParametersViewModel,
         sunriseSunsetViewModel: SunriseSunsetViewModel,
         weatherCodesViewModel: WeatherCodesViewModel,
         forecastLat: String,
         forecastLon: String,
         forecastNote: String,
         siteName: String,
         siteType: String) {
        self._liftParametersViewModel = ObservedObject(wrappedValue: liftParametersViewModel)
        self._sunriseSunsetViewModel = ObservedObject(wrappedValue: sunriseSunsetViewModel)
        self._weatherCodesViewModel = ObservedObject(wrappedValue: weatherCodesViewModel)
        self._viewModel = StateObject(wrappedValue: SiteForecastViewModel(liftParametersViewModel: liftParametersViewModel,
                                                                          sunriseSunsetViewModel: sunriseSunsetViewModel,
                                                                          weatherCodesViewModel: weatherCodesViewModel))
        self.forecastLat = forecastLat
        self.forecastLon = forecastLon
        self.forecastNote = forecastNote
        self.siteName = siteName
        self.siteType = siteType
    }
    
    var body: some View {
        VStack (alignment: .leading) {
            if let forecastData = viewModel.forecastData {
                VStack(alignment: .leading) {
                    let topOfChartAltitude = 18000.0
                    let surfaceAltitude = convertMetersToFeet(forecastData.elevation)
                    let Alt = formatAltitude(String(surfaceAltitude))
                    Text(buildReferenceNote(Alt: "\(Alt)", Note: forecastNote))
                        .font(.footnote)
                        .foregroundColor(infoFontColor)
                        .padding(.bottom, 5)
                    
                    let maxPressureReading = viewModel.maxPressureReading
                    let dataWidth: CGFloat = 48                                     // Width for each data column
                    let dataRows: Int = forecastData.hourly.dateTime?.count ?? 0    // Total count of data rows returned
                    let dataFrameWidth: CGFloat = CGFloat(dataRows) * (dataWidth)   // Width for all data tables and charts

                    // Create separate grids for each section to enable area graphs to overlay a section
                    let weatherGridItems: [GridItem] = {
                        var weatherItems = Array(repeating: GridItem(.fixed(headingHeight), spacing: 0), count: 1)     // Day
                        weatherItems += Array(repeating: GridItem(.fixed(headingHeight), spacing: 0), count: 1)        // Date
                        weatherItems += Array(repeating: GridItem(.fixed(headingHeight), spacing: 0), count: 1)        // Time
                        weatherItems += Array(repeating: GridItem(.fixed(imageHeight), spacing: 0), count: 1)          // Skies
                        weatherItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)           // ToL Temp
                        weatherItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)           // Surf Temp
                        weatherItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)           // Cloud %
                        weatherItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)           // Precip %
                        weatherItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)           // CAPE
                        weatherItems += Array(repeating: GridItem(.fixed(labelHeight), spacing: 0), count: 1)          // Wind label
                        return weatherItems
                    } ()
                    let windGridItems: [GridItem] = {
                        var windItems = [] as [GridItem]
                        if maxPressureReading >= 500 { windItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1) }
                        if maxPressureReading >= 550 { windItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1) }
                        if maxPressureReading >= 600 { windItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1) }
                        if maxPressureReading >= 650 { windItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1) }
                        if maxPressureReading >= 700 { windItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1) }
                        if maxPressureReading >= 750 { windItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1) }
                        if maxPressureReading >= 800 { windItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1) }
                        if maxPressureReading >= 850 { windItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1) }
                        if maxPressureReading >= 900 { windItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1) }
                        return windItems
                    } ()
                    let surfaceGridItems: [GridItem] = {
                        var surfaceItems = Array(repeating: GridItem(.fixed(doubleHeight), spacing: 0), count: 1)   // Surface wind
                        surfaceItems += Array(repeating: GridItem(.fixed(labelHeight), spacing: 0), count: 1)       // Thermal label
                        surfaceItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)        // Top of lift
                        return surfaceItems
                    } ()
                    let thermalGridItems: [GridItem] = {
                        var thermalItems: [GridItem] = []
                        if maxPressureReading >= 500 {
                            thermalItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)
                            areaChartHeight += dataHeight + areaChartPaddingHeight
                        }
                        if maxPressureReading >= 550 {
                            thermalItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)
                            areaChartHeight += dataHeight + areaChartPaddingHeight
                        }
                        if maxPressureReading >= 600 {
                            thermalItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)
                            areaChartHeight += dataHeight + areaChartPaddingHeight
                        }
                        if maxPressureReading >= 650 {
                            thermalItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)
                            areaChartHeight += dataHeight + areaChartPaddingHeight
                        }
                        if maxPressureReading >= 700 {
                            thermalItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)
                            areaChartHeight += dataHeight + areaChartPaddingHeight
                        }
                        if maxPressureReading >= 750 {
                            thermalItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)
                            areaChartHeight += dataHeight + areaChartPaddingHeight
                        }
                        if maxPressureReading >= 800 {
                            thermalItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)
                            areaChartHeight += dataHeight + areaChartPaddingHeight
                        }
                        if maxPressureReading >= 850 {
                            thermalItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)
                            areaChartHeight += dataHeight + areaChartPaddingHeight
                        }
                        if maxPressureReading >= 900 {
                            thermalItems += Array(repeating: GridItem(.fixed(dataHeight), spacing: 0), count: 1)
                            areaChartHeight += dataHeight + areaChartPaddingHeight
                        }
                        return thermalItems
                    } ()
                    HStack(alignment: .top) {
                        VStack (spacing: 0) {
                            // Create header column from grid sections
                            LazyHGrid(rows: weatherGridItems) {
                                Group {
                                    Text(" ")
                                        .font(.caption)
                                        .padding(.top, 8)
                                    Text(" ")
                                        .font(.caption)
                                        .padding(.top, 4)
                                    Text(" ")
                                        .font(.caption)
                                    Text(" ")
                                        .font(.caption)
                                    Text("ToL Temp")
                                        .font(.caption)
                                    Text("Surf Temp")
                                        .font(.caption)
                                    Text("Cloud %")
                                        .font(.caption)
                                    Text("Precip %")
                                        .font(.caption)
                                    Text("CAPE")
                                        .font(.caption)
                                    Text("Wind")
                                        .font(.caption)
                                        .foregroundColor(infoFontColor)
                                }
                            }
                            LazyHGrid(rows: windGridItems) {
                                Group {
                                    if maxPressureReading >= 500 { Text("\(Int(forecastData.hourly.geopotential_height_500hPa.first ?? 500))k ft").font(.caption) }
                                    if maxPressureReading >= 550 { Text("\(Int(forecastData.hourly.geopotential_height_550hPa.first ?? 550))k ft").font(.caption) }
                                    if maxPressureReading >= 600 { Text("\(Int(forecastData.hourly.geopotential_height_600hPa.first ?? 600))k ft").font(.caption) }
                                    if maxPressureReading >= 650 { Text("\(Int(forecastData.hourly.geopotential_height_650hPa.first ?? 650))k ft").font(.caption) }
                                    if maxPressureReading >= 700 { Text("\(Int(forecastData.hourly.geopotential_height_700hPa.first ?? 700))k ft").font(.caption) }
                                    if maxPressureReading >= 750 { Text("\(Int(forecastData.hourly.geopotential_height_750hPa.first ?? 750))k ft").font(.caption) }
                                    if maxPressureReading >= 800 { Text("\(Int(forecastData.hourly.geopotential_height_800hPa.first ?? 800))k ft").font(.caption) }
                                    if maxPressureReading >= 850 { Text("\(Int(forecastData.hourly.geopotential_height_850hPa.first ?? 850))k ft").font(.caption) }
                                    if maxPressureReading >= 900 { Text("\(Int(forecastData.hourly.geopotential_height_900hPa.first ?? 900))k ft").font(.caption) }
                                }
                            }
                            LazyHGrid(rows: surfaceGridItems) {
                                Group {
                                    Text("Surface")
                                        .font(.caption)
                                    Text("Lift")
                                        .font(.caption)
                                        .foregroundColor(infoFontColor)
                                    Text("Top of Lift")
                                        .font(.caption)
                                }
                            }
                            LazyHGrid(rows: thermalGridItems) {
                                Group {
                                    if maxPressureReading >= 500 { Text("\(Int(forecastData.hourly.geopotential_height_500hPa.first ?? 500))k ft").font(.caption) }
                                    if maxPressureReading >= 550 { Text("\(Int(forecastData.hourly.geopotential_height_550hPa.first ?? 550))k ft").font(.caption) }
                                    if maxPressureReading >= 600 { Text("\(Int(forecastData.hourly.geopotential_height_600hPa.first ?? 600))k ft").font(.caption) }
                                    if maxPressureReading >= 650 { Text("\(Int(forecastData.hourly.geopotential_height_650hPa.first ?? 650))k ft").font(.caption) }
                                    if maxPressureReading >= 700 { Text("\(Int(forecastData.hourly.geopotential_height_700hPa.first ?? 700))k ft").font(.caption) }
                                    if maxPressureReading >= 750 { Text("\(Int(forecastData.hourly.geopotential_height_750hPa.first ?? 750))k ft").font(.caption) }
                                    if maxPressureReading >= 800 { Text("\(Int(forecastData.hourly.geopotential_height_800hPa.first ?? 800))k ft").font(.caption) }
                                    if maxPressureReading >= 850 { Text("\(Int(forecastData.hourly.geopotential_height_850hPa.first ?? 850))k ft").font(.caption) }
                                    if maxPressureReading >= 900 { Text("\(Int(forecastData.hourly.geopotential_height_900hPa.first ?? 900))k ft").font(.caption) }
                                }
                            }
                        }
                        .padding(.vertical, 0)
                        ScrollView(.horizontal) {
                            VStack (spacing: 0) {

                                // Header and weather rows
                                LazyHGrid(rows: weatherGridItems, spacing: 0) {
                                    ForEach(forecastData.hourly.dateTime?.indices ?? 0..<0, id: \.self) { index in
                                        Group {
                                            if forecastData.hourly.newDateFlag?[index] ?? true {
                                                Text(forecastData.hourly.formattedDay?[index] ?? "")
                                                    .font(.caption)
                                                    .frame(width: dataWidth)
                                                    .padding(.top, 8)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: headingHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                                Text(forecastData.hourly.formattedDate?[index] ?? "")
                                                    .font(.caption)
                                                    .frame(width: dataWidth)
                                                    .padding(.top, 4)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: headingHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            } else {
                                                Text(forecastData.hourly.formattedDay?[index] ?? "")
                                                    .font(.caption)
                                                    .foregroundColor(repeatDateTimeColor)
                                                    .frame(width: dataWidth)
                                                    .padding(.top, 8)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: headingHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                                Text(forecastData.hourly.formattedDate?[index] ?? "")
                                                    .font(.caption)
                                                    .foregroundColor(repeatDateTimeColor)
                                                    .frame(width: dataWidth)
                                                    .padding(.top, 4)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: headingHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            Text(forecastData.hourly.formattedTime?[index] ?? "")
                                                .font(.caption)
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: headingHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            Image(systemName: forecastData.hourly.weatherCodeImage?[index] ?? "questionmark")
                                                .renderingMode(.original) // Use .multicolor for multicolor rendering
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: dataWidth * imageScalingFactor)
                                                // Display divider when date changes
                                                .frame(width: dataWidth)
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: imageHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            Text(forecastData.hourly.formattedTopOfLiftTemp?[index] ?? "") //formattedTopOfLiftTemperature?[index] ?? "")
                                                    .font(.caption)
                                                    .foregroundStyle(tempColor(Int(forecastData.hourly.topOfLiftTemp?[index] ?? -999)))
                                                    .frame(width: dataWidth)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            Text(forecastData.hourly.formattedSurfaceTemp?[index] ?? "")
                                                .font(.caption)
                                                .foregroundStyle(tempColor(Int(forecastData.hourly.temperature_2m[index])))
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            Text(forecastData.hourly.formattedCloudCover?[index] ?? "")
                                                .font(.caption)
                                                .foregroundStyle(cloudCoverColor(Int(forecastData.hourly.cloudcover[index])))
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            Text(forecastData.hourly.formattedPrecipProbability?[index] ?? "")
                                                .font(.caption)
                                                .foregroundStyle(precipColor(Int(forecastData.hourly.precipitation_probability[index])))
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            Text(forecastData.hourly.formattedCAPE?[index] ?? "")
                                                .font(.caption)
                                                .foregroundStyle(CAPEColor(Int(forecastData.hourly.cape[index])))
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            Text(" ")
                                                .font(.caption)
                                                .frame(width: dataWidth)
                                                .overlay(
                                                    Rectangle()
                                                        .frame(height: 1)
                                                        .foregroundColor(tableSectionDividerColor),
                                                    alignment: .center)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                        }
                                    }
                                }
                                .frame(width: dataFrameWidth)
                                .background(tableBackgroundColor)

                                // Winds aloft forecast table
                                LazyHGrid(rows: windGridItems, spacing: 0) {
                                    ForEach(forecastData.hourly.dateTime?.indices ?? 0..<0, id: \.self) { index in
                                        Group {
                                            if maxPressureReading >= 500 {
                                                HStack (spacing: windArrowSpacing) {
                                                    Text("\(Int(forecastData.hourly.windspeed_500hPa[index]))")
                                                        .font(.caption)
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_500hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_500hPa[index] - 180))
                                                        .font(.footnote)
                                                }
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 550 {
                                                HStack (spacing: windArrowSpacing) {
                                                    Text("\(Int(forecastData.hourly.windspeed_550hPa[index]))")
                                                        .font(.caption)
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_550hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_550hPa[index] - 180))
                                                        .font(.footnote)
                                                }
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 600 {
                                                HStack (spacing: windArrowSpacing) {
                                                    Text("\(Int(forecastData.hourly.windspeed_600hPa[index]))")
                                                        .font(.caption)
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_600hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_600hPa[index] - 180))
                                                        .font(.footnote)
                                                }
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 650 {
                                                HStack (spacing: windArrowSpacing) {
                                                    Text("\(Int(forecastData.hourly.windspeed_650hPa[index]))")
                                                        .font(.caption)
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_650hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_650hPa[index] - 180))
                                                        .font(.footnote)
                                                }
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 700 {
                                                HStack (spacing: windArrowSpacing) {
                                                    Text("\(Int(forecastData.hourly.windspeed_700hPa[index]))")
                                                        .font(.caption)
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_700hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_700hPa[index] - 180))
                                                        .font(.footnote)
                                                }
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 750 {
                                                HStack (spacing: windArrowSpacing) {
                                                    Text("\(Int(forecastData.hourly.windspeed_750hPa[index]))")
                                                        .font(.caption)
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_750hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_750hPa[index] - 180))
                                                        .font(.footnote)
                                                }
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 800 {
                                                HStack (spacing: windArrowSpacing) {
                                                    Text("\(Int(forecastData.hourly.windspeed_800hPa[index]))")
                                                        .font(.caption)
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_800hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_800hPa[index] - 180))
                                                        .font(.footnote)
                                                }
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 850 {
                                                HStack (spacing: windArrowSpacing) {
                                                    Text("\(Int(forecastData.hourly.windspeed_850hPa[index]))")
                                                        .font(.caption)
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_850hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_850hPa[index] - 180))
                                                        .font(.footnote)
                                                }
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 900 {
                                                HStack (spacing: windArrowSpacing) {
                                                    Text("\(Int(forecastData.hourly.windspeed_900hPa[index]))")
                                                        .font(.caption)
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_900hPa[index]), siteType: siteType))
                                                    Image(systemName: windArrow)
                                                        .rotationEffect(.degrees(forecastData.hourly.winddirection_900hPa[index] - 180))
                                                        .font(.footnote)
                                                }
                                                .frame(width: dataWidth)
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                        }
                                    }
                                }
                                .background(
                                    areaChartBackground(forecastData: forecastData, surfaceAltitude: surfaceAltitude, topOfChartAltitude: topOfChartAltitude)
                                        .opacity(areaChartOpacity)
                                )
                                .background(tableBackgroundColor)
 
                                // Surface wind and Top of Lift forecast table
                                LazyHGrid(rows: surfaceGridItems, spacing: 0) {
                                    ForEach(forecastData.hourly.dateTime?.indices ?? 0..<0, id: \.self) { index in
                                        Group {
                                            HStack(spacing: windArrowSpacing) {
                                                VStack(alignment: .trailing, spacing: 1) {
                                                    Text("\(Int(forecastData.hourly.windspeed_10m[index]))")
                                                        .font(.caption)
                                                        .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windspeed_10m[index]), siteType: siteType))
                                                    HStack (spacing: 1) {
                                                        Text("g")
                                                            .font(.caption2)
                                                        Text("\(Int(forecastData.hourly.windgusts_10m[index]))")
                                                            .font(.caption)
                                                            .foregroundStyle(windSpeedColor(windSpeed: Int(forecastData.hourly.windgusts_10m[index]), siteType: siteType))
                                                    }                                                    
                                                }
                                                .padding(.vertical, 0)
                                                Image(systemName: windArrow)
                                                    .rotationEffect(.degrees(forecastData.hourly.winddirection_10m[index] - 180))
                                                    .font(.footnote)
                                            }
                                            .padding(.vertical, 0)
                                            .frame(width: dataWidth)
                                            // Display divider when date changes
                                            .overlay ( Divider() .frame(width: dateChangeDividerSize, height: doubleHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            Text(" ")
                                                .font(.caption)
                                                .frame(width: dataWidth)
                                                .overlay(
                                                    Rectangle()
                                                        .frame(height: 1)
                                                        .foregroundColor(tableSectionDividerColor),
                                                    alignment: .center )
                                                // Display divider when date changes
                                                .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            if forecastData.hourly.formattedTopOfLiftAltitude?[index] ?? "" == "rocket" {
                                                Image("rocket")
                                                    .renderingMode(.original) // Use .multicolor for multicolor rendering
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: dataWidth) // * imageScalingFactor)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            } else {
                                                Text(forecastData.hourly.formattedTopOfLiftAltitude?[index] ?? "")
                                                    .font(.caption)
                                                    .frame(width: dataWidth)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                        }
                                    }
                                }
                                .frame(width: dataFrameWidth)
                                .background(tableBackgroundColor)

                                // Thermal lift table
                                LazyHGrid(rows: thermalGridItems, spacing: 0) {
                                    ForEach(forecastData.hourly.dateTime?.indices ?? 0..<0, id: \.self) { index in
                                        Group {
                                            if maxPressureReading >= 500 {
                                                Text("\(forecastData.hourly.thermalVelocity_500hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_500hPa?[index] ?? 0))")
                                                    .font(.caption)
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_500hPa?[index] ?? 0))
                                                    .frame(width: dataWidth)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 550 {
                                                Text("\(forecastData.hourly.thermalVelocity_550hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_550hPa?[index] ?? 0))")
                                                    .font(.caption)
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_550hPa?[index] ?? 0))
                                                    .frame(width: dataWidth)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 600 {
                                                Text("\(forecastData.hourly.thermalVelocity_600hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_600hPa?[index] ?? 0))")
                                                    .font(.caption)
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_600hPa?[index] ?? 0))
                                                    .frame(width: dataWidth)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 650 {
                                                Text("\(forecastData.hourly.thermalVelocity_650hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_650hPa?[index] ?? 0))")
                                                    .font(.caption)
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_650hPa?[index] ?? 0))
                                                    .frame(width: dataWidth)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 700 {
                                                Text("\(forecastData.hourly.thermalVelocity_700hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_700hPa?[index] ?? 0))")
                                                    .font(.caption)
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_700hPa?[index] ?? 0))
                                                    .frame(width: dataWidth)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 750 {
                                                Text("\(forecastData.hourly.thermalVelocity_750hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_750hPa?[index] ?? 0))")
                                                    .font(.caption)
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_750hPa?[index] ?? 0))
                                                    .frame(width: dataWidth)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 800 {
                                                Text("\(forecastData.hourly.thermalVelocity_800hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_800hPa?[index] ?? 0))")
                                                    .font(.caption)
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_800hPa?[index] ?? 0))
                                                    .frame(width: dataWidth)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 850 {
                                                Text("\(forecastData.hourly.thermalVelocity_850hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_850hPa?[index] ?? 0))")
                                                    .font(.caption)
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_850hPa?[index] ?? 0))
                                                    .frame(width: dataWidth)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                            if maxPressureReading >= 900 {
                                                Text("\(forecastData.hourly.thermalVelocity_900hPa?[index] == 0 ? "" : String(forecastData.hourly.thermalVelocity_900hPa?[index] ?? 0))")
                                                    .font(.caption)
                                                    .foregroundStyle(thermalColor(forecastData.hourly.thermalVelocity_900hPa?[index] ?? 0))
                                                    .frame(width: dataWidth)
                                                    // Display divider when date changes
                                                    .overlay ( Divider() .frame(width: dateChangeDividerSize, height: dataHeight) .background(getDividerColor(forecastData.hourly.newDateFlag?[index] ?? true)), alignment: .leading )
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 0)
                                .frame(width: dataFrameWidth)
                                .background(
                                    areaChartBackground(forecastData: forecastData, surfaceAltitude: surfaceAltitude, topOfChartAltitude: topOfChartAltitude)
                                        .opacity(areaChartOpacity)
                                .background(tableBackgroundColor)       // Used to hide overrun from wind aloft background area table
                                )
                            }
                            .padding(.bottom, 8)
                            .backgroundStyle(tableBackgroundColor)
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.fetchForecast(SiteName: siteName, ForecastLat: forecastLat, ForecastLon: forecastLon) }
    }
    
    func getDividerColor (_ newDateFlag: Bool) -> Color {
        if newDateFlag {
            return tableMajorDividerColor
        } else {
            return tableMinorDividerColor
        }
    }
    
    @ViewBuilder
    func areaChartBackground(forecastData: ForecastData, surfaceAltitude: Int, topOfChartAltitude: Double) -> some View {
        if let dateTime = forecastData.hourly.dateTime, let topOfLiftAltitude = forecastData.hourly.topOfLiftAltitude {
            let data = zip(dateTime.indices, topOfLiftAltitude).map { TopOfLiftDataPoint(index: $0.0, altitude: $0.1) }
            Chart(data) { item in
                AreaMark(
                    x: .value("Index", item.index),
                    y: .value("Altitude", item.altitude)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.linearGradient(colors: [chartGradientStartColor, chartGradientEndColor], startPoint: .bottom, endPoint: .top))
                LineMark(
                    x: .value("Index", item.index),
                    y: .value("Altitude", item.altitude)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(chartLineColor)

            }
            .chartYAxis(.hidden) // Remove the y-axis values
            .chartXAxis(.hidden)
            .chartXAxis { AxisMarks(stroke: StrokeStyle(lineWidth: 0)) }  // Hide vertical column separators
            .chartYAxis { AxisMarks(stroke: StrokeStyle(lineWidth: 0)) }  // Hide horizontal column separators
            .chartYScale(domain: (Double(surfaceAltitude) - 200)...topOfChartAltitude)
        } else {
            Text("No data available")
        }
    }
}
