import SwiftUI
import Combine

struct SiteView: View {
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodesViewModel
    @EnvironmentObject var sitesViewModel: SitesViewModel
    @StateObject var stationLatestReadingsViewModel: StationLatestReadingsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedSite: Sites?
    @State private var isActive = false
    
    init(sitesViewModel: SitesViewModel) {
        _stationLatestReadingsViewModel = StateObject(wrappedValue: StationLatestReadingsViewModel(viewModel: sitesViewModel))
    }
    
    var body: some View {
        VStack {
            Text("Tap on a site for forecast and readings history")
                .font(.caption)
                .foregroundColor(infoFontColor)
                .padding(.top, 8)
            List {
                let groupedSites = Dictionary(grouping: sitesViewModel.sites) { $0.area }
                 let sortedGroupedSites = groupedSites.sorted(by: { $0.key < $1.key })
                 
                 ForEach(sortedGroupedSites, id: \.key) { area, areaSites in
                     // Split is used to strip the order sequence number from the front of the category on display
                     let areaName = area.split(separator: " ", maxSplits: 1).dropFirst().joined(separator: " ")
                     
                     Section(header: Text(areaName)
                         .font(.subheadline)
                         .foregroundColor(sectionHeaderColor)
                         .bold())
                     {
                         ForEach(areaSites) { site in
                             VStack(alignment: .leading) {
                                 HStack {
                                     Text(site.siteName)
                                         .font(.subheadline)
                                         .foregroundColor(rowHeaderColor)
                                     if site.readingsAlt != "" {
                                         Text("\(site.readingsAlt) ft")
                                             .font(.caption)
                                             .foregroundColor(infoFontColor)
                                             .lineLimit(1)
                                             .fixedSize(horizontal: true, vertical: false)
                                     }
                                     Spacer()
                                     
                                     if let latestReading = stationLatestReadingsViewModel.latestReadings.first (where: { $0.stationID == site.readingsStation }) {
                                         if let windTime = latestReading.windTime {
                                             // Split keeps hh:mm and strips the trailing "  %p" the JSON parser is creating
                                             let windTimeText = windTime.split(separator: " ", maxSplits: 1)[0]
                                             Text(windTimeText)
                                                 .font(.caption)
                                                 .foregroundColor(infoFontColor)
                                                 .lineLimit(1)
                                                 .fixedSize(horizontal: true, vertical: false)
                                         }

                                         if let windSpeed = latestReading.windSpeed {
                                             if windSpeed == 0 {
                                                 Text("calm")
                                                     .font(.subheadline)
                                                     .lineLimit(1)
                                                     .fixedSize(horizontal: true, vertical: false)
                                             } else {
                                                 Text(String(Int(windSpeed.rounded())))
                                                     .font(.subheadline)
                                                     .foregroundColor(windSpeedColor(windSpeed: Int(windSpeed.rounded()), siteType: site.siteType))
                                                     .lineLimit(1)
                                                     .fixedSize(horizontal: true, vertical: false)
                                             }
                                         } else {
                                             Text ("Station down")
                                                 .font(.caption)
                                                 .foregroundColor(infoFontColor)
                                                 .lineLimit(1)
                                                 .fixedSize(horizontal: true, vertical: false)
                                         }

                                         if let windGust = latestReading.windGust {
                                             if windGust > 0 {
                                                 HStack {
                                                     Text("g")
                                                         .font(.subheadline)
                                                         .foregroundColor(infoFontColor)
                                                         .lineLimit(1)
                                                         .fixedSize(horizontal: true, vertical: false)
                                                     Text(String(Int(windGust.rounded())))
                                                         .font(.subheadline)
                                                         .foregroundColor(windSpeedColor(windSpeed: Int(windGust.rounded()), siteType: site.siteType))
                                                         .lineLimit(1)
                                                         .fixedSize(horizontal: true, vertical: false)
                                                 }
                                             }
                                         }

                                         if let windDirection = latestReading.windDirection {
                                             Image(systemName: windArrow)
                                                 .rotationEffect(.degrees(windDirection - 180))
                                                 .font(.footnote)
                                         }
 
                                     } else {
                                         Text ("Station down")
                                             .font(.caption)
                                             .foregroundColor(infoFontColor)
                                             .lineLimit(1)
                                             .fixedSize(horizontal: true, vertical: false)
                                     }
                                 }
                                 .contentShape(Rectangle()) // Makes entire area tappable
                                 .onTapGesture { openSiteDetail(site) }
                             }
                         }
                     }
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
         }
        .onAppear {
            isActive = true
            startTimer()
        }
        .onDisappear {
            isActive = false
        }
        .sheet(item: $selectedSite, onDismiss: {
            stationLatestReadingsViewModel.reloadLatestReadingsData() {}
        }) { site in
            SiteDetailView(site: site)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                stationLatestReadingsViewModel.reloadLatestReadingsData() {}
            } else {
                isActive = false
            }
        }
    }
    func openSiteDetail(_ site: Sites) {
        selectedSite = site
    }
    private func startTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + pageRefreshInterval) {
            if isActive {
                stationLatestReadingsViewModel.reloadLatestReadingsData() {}
            }
        }
    }
}
