import SwiftUI
import Combine

struct SiteDailyForecastView: View {
    @ObservedObject var weatherCodesViewModel: WeatherCodeViewModel
    @StateObject private var viewModel: DailyForecastViewModel
    var siteLat: String
    var siteLon: String
    var forecastNote: String
    var siteName: String
    var siteType: String
    
    init(weatherCodesViewModel: WeatherCodeViewModel, siteLat: String, siteLon: String, forecastNote: String, siteName: String, siteType: String) {
        self._weatherCodesViewModel = ObservedObject(wrappedValue: weatherCodesViewModel)
        self._viewModel = StateObject(wrappedValue: DailyForecastViewModel(weatherCodesViewModel: weatherCodesViewModel))
        self.siteLat = siteLat
        self.siteLon = siteLon
        self.forecastNote = forecastNote
        self.siteName = siteName
        self.siteType = siteType
    }

    var body: some View {
        VStack {
            let dataWidth: CGFloat = 40                                     // Width for each data column
            let dataFrameWidth: CGFloat = ( dataWidth * 1.5 )
            
            if let daily = viewModel.dailyForecastData?.daily {

                let surfaceAltitude = convertMetersToFeet(viewModel.dailyForecastData?.elevation ?? 0.0)
                HStack {
                    Text(buildReferenceNote(Alt: String(surfaceAltitude), Note: forecastNote))
                        .font(.footnote)
                        .foregroundColor(infoFontColor)
                        .padding(.bottom, 5)
                    Spacer()
                }
                ScrollView(.horizontal) {
                    HStack (alignment: .top, spacing: 4) {
                        ForEach(0..<daily.time.count, id: \.self) { index in
                            VStack (spacing: 0) {
                                Text(daily.forecastDay?[index] ?? "")
                                    .font(.caption)
                                    .foregroundColor(repeatDateTimeColor)
                                    .frame(height: headingHeight)
                                    .padding(.top, 6)
                                Text(daily.forecastDate?[index] ?? "")
                                    .font(.caption)
                                    .foregroundColor(repeatDateTimeColor)
                                    .frame(height: headingHeight)
                                Image(systemName: daily.weatherCodeImage?[index] ?? "questionmark")
                                    .renderingMode(.original) // Use .multicolor for multicolor rendering
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: dataWidth * imageScalingFactor, height: imageHeight)
                                // let minTempColor = tempColor(Int(daily.temperature_2m_min[index].rounded()))
                                let maxTempColor = tempColor(Int(daily.temperature_2m_max[index].rounded()))
                                HStack  (spacing: 0) {
                                    /*  Skipping min temp in display
                                     Text(daily.formattedMinTemp?[index] ?? "")
                                     .foregroundStyle(minTempColor)
                                     .font(.caption)
                                     Text("/")
                                     .font(.caption)
                                     */
                                    Text(daily.formattedMaxTemp?[index] ?? "")
                                        .foregroundStyle(maxTempColor)
                                        .font(.caption)
                                    Text("°")
                                        .font(.caption)
                                }
                                .frame(height: dataHeight)
                                let windColor = windSpeedColor(windSpeed: Int(daily.wind_speed_10m_mean[index].rounded()), siteType: siteType)
                                // let gustColor = windSpeedColor(windSpeed: Int(daily.wind_gusts_10m_max[index].rounded()), siteType: siteType)
                                Group {
                                    HStack(spacing: windArrowSpacing) {
                                        VStack(alignment: .trailing, spacing: 1) {
                                            Text("\(Int(daily.wind_speed_10m_mean[index].rounded()))")
                                                .font(.caption)
                                                .foregroundStyle(windColor)
                                            /*  Removing gust from display
                                             HStack (spacing: 1) {
                                             Text("g")
                                             .font(.caption2)
                                             Text("\(Int(daily.wind_gusts_10m_max[index].rounded()))")
                                             .font(.caption)
                                             .foregroundStyle(gustColor)
                                             }
                                             */
                                        }
                                        Image(systemName: windArrow)
                                            .rotationEffect(.degrees(Double(Int(daily.wind_direction_10m_dominant[index]) - 180)))
                                            .font(.footnote)
                                    }
                                    .frame(height: dataHeight) // adjusted for removing gust doubleHeight)
                                }
                                VStack (spacing: 0) {
                                    if daily.precipitation_sum[index] > 0 || daily.precipitation_probability_max[index] > 0 {
                                        HStack (spacing: 0) {
                                            Image(systemName: daily.precipImage?[index] ?? "questionmark")
                                                .font(.caption2)
                                                .imageScale(.small)
                                                .foregroundStyle(.titanium)
                                            Text(" \(String(daily.precipitation_probability_max[index]))%")
                                                .font(.caption)
                                        }
                                        let roundedPrecip = (daily.precipitation_sum[index] * 10).rounded() / 10
                                        Text("\(String(roundedPrecip))\"")
                                            .font(.caption)
                                            .padding(.bottom, 6)
                                    } else {
                                        Text("")
                                        Text("")
                                            .padding(.bottom, 6)
                                    }
                                }
                                .frame(height: doubleHeight)
                            }
                            .frame(width: dataFrameWidth)
                            .background(tableBackgroundColor)
                            .cornerRadius(10)
                            .padding(.horizontal, 2)
                        }
                    }
                }
            }
            else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.75)
                    .frame(width: 20, height: 20)
            }
        }
        .onAppear {
            viewModel.fetchDailyWeatherData(latitude: siteLat, longitude: siteLon)
        }
    }
}
