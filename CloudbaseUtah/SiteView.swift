//  SiteView.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/6/25.

import SwiftUI

struct Site: Identifiable {
    let id = UUID()
    let area: String
    let siteName: String
    let readingsNote: String
    let forecastNote: String
    let siteType: String
    let readingsAlt: String
    let readingsSource: String
    let readingsStation: String
    let includeIn5DayForecast: String
    let pressureZoneReadingTime: String
    let forecastLat: String
    let forecastLon: String
    
    // New properties to store additional data
    var windSpeed: String?
    var windDirection: String?
    var windDirectionAngle: Angle?
    var windGust: String?
    var windTime: String?
    var windColor: Color?
    var windGustColor: Color?
}

class SiteViewModel: ObservableObject {
    @Published var sites: [Site] = []
    
    init() {
        fetchData { [weak self] sites in
            DispatchQueue.main.async {
                self?.sites = sites ?? []
                self?.fetchMesonetData()
            }
        }
    }
    
    func fetchData(completion: @escaping ([Site]?) -> Void) {
        let spreadsheetID = "1s72R3YCHxNIJVLVa5nmsTphRpqRsfG2QR2koWxE19ls"
        let rangeName = "Sites"
        let apiKey = "AIzaSyDSro1lDdAQsNEZq06IxwjOlQQP1tip-fs"
        let GoogleURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetID)/values/\(rangeName)?alt=json&key=\(apiKey)"
        guard let url = URL(string: GoogleURLString) else {
            completion(nil)
            return
        }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let values = json["values"] as? [[String]] {
                    var sites = [Site]()
                    // Skip first row, which contains headers
                    for row in values.dropFirst() {
                        if row[0] != "Yes" {    // Excludes sites marked in metadata as 'Exclude from App'
                            let site = Site(
                                area: row[1],
                                siteName: row[2],
                                readingsNote: row[3],
                                forecastNote: row[4],
                                siteType: row[5],
                                readingsAlt: row[6],
                                readingsSource: row[7],
                                readingsStation: row[8],
                                includeIn5DayForecast: row[9],
                                pressureZoneReadingTime: row[10],
                                forecastLat: row[11],
                                forecastLon: row[12]
                            )
                            sites.append(site)
                        }
                    }
                    completion(sites)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }
    
    func fetchMesonetData() {
        let mesonetSites = sites.filter { $0.readingsSource == "Mesonet" && $0.readingsStation != "" }
        guard !mesonetSites.isEmpty else { return }
        let baseURL = "https://api.mesowest.net/v2/station/latest?"
        let parameters = mesonetSites.map { "&stid=\($0.readingsStation)" }.joined()
        let trailer = "&recent=420&vars=air_temp,altimeter,wind_direction,wind_gust,wind_speed&units=english,speed|mph,temp|F&within=120&obtimezone=local&timeformat=%-I:%M%20%p&token=ef3b9f4584b64e6da12d8688f19d9f4a"
        let urlString = baseURL + parameters + trailer
        guard let url = URL(string: urlString) else { return }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let stations = json["STATION"] as? [[String: Any]] {
                    DispatchQueue.main.async {
                        for station in stations {
                            if let stid = station["STID"] as? String,
                               let observations = station["OBSERVATIONS"] as? [String: Any],
                               let windSpeed = observations["wind_speed_value_1"] as? [String: Any],
                               let windDirection = observations["wind_direction_value_1"] as? [String: Any],
                               let windSpeedValue = windSpeed["value"] as? Double,
                               let windDirectionValue = windDirection["value"] as? Double,
                               let windTime = windSpeed["date_time"] as? String
                            {  // Make windGust optional
                                let windGust = observations["wind_gust_value_1"] as? [String: Any]
                                let windGustValue = windGust?["value"] as? Double
                                // Find all matching sites and update the readings for each
                                // (in some cases, multiple sites use the same station for actuals)
                                let matchingIndices = self.sites.enumerated().filter { $0.element.readingsStation == stid }.map { $0.offset }
                                for index in matchingIndices {
                                    self.sites[index].windSpeed = String(Int(windSpeedValue.rounded()))
                                    self.sites[index].windColor = windSpeedColor(windSpeed: Int(windSpeedValue.rounded()), siteType: self.sites[index].siteType)
                                    let adjustedWindDirection = Double((Int(windDirectionValue.rounded()) + 180) % 360)
                                    self.sites[index].windDirection = String(adjustedWindDirection)
                                    self.sites[index].windDirectionAngle = Angle(degrees: adjustedWindDirection)
                                    self.sites[index].windTime = windTime
                                    // Handle optional windGustValue
                                    if let windGustValue = windGustValue {
                                        self.sites[index].windGust = String(Int(windGustValue.rounded()))
                                        self.sites[index].windGustColor = windSpeedColor(windSpeed: Int(windGustValue.rounded()), siteType: self.sites[index].siteType)
                                    } else {
                                        self.sites[index].windGust = ""
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                print("Failed to parse Mesonet data: \(error)")
            }
        }
        
        task.resume()
    }
}

struct SiteView: View {
    @ObservedObject var viewModel = SiteViewModel()
    @State private var selectedSite: Site?
    
    var body: some View {
        VStack {
            Text("Tap on a site for forecast and readings history")
                .font(.caption)
                .foregroundColor(infoFontColor)
                .padding(.top, 8)
            List {
                let groupedSites = Dictionary(grouping: viewModel.sites) { $0.area }
                 let sortedGroupedSites = groupedSites.sorted(by: { $0.key < $1.key })
                 
                 ForEach(sortedGroupedSites, id: \.key) { area, sites in
                     // Split is used to strip the order sequence number from the front of the category on display
                     let areaName = area.split(separator: " ", maxSplits: 1).dropFirst().joined(separator: " ")
                     
                     Section(header: Text(areaName)
                         .font(.headline)
                         .foregroundColor(sectionHeaderColor)
                         .bold())
                     {
                         ForEach(sites) { site in
                             VStack(alignment: .leading) {
                                 HStack {
                                     Text(site.siteName)
                                         .font(.headline)
                                         .foregroundColor(rowHeaderColor)
                                     if site.readingsAlt != "" {
                                         Text("\(site.readingsAlt) ft")
                                             .font(.caption)
                                             .foregroundColor(infoFontColor)
                                     }
                                     Spacer()
                                     HStack {
                                         if let windTime = site.windTime {
                                             // Split keeps hh:mm and strips the trailing "  %p" the JSON parser is creating
                                             let windTimeText = windTime.split(separator: " ", maxSplits: 1)[0]
                                             Text(windTimeText)
                                                 .font(.caption)
                                                 .foregroundColor(infoFontColor)
                                         }
                                         if let windSpeed = site.windSpeed {
                                             if windSpeed == "0" {
                                                 Text("calm")
                                                     .font(.subheadline)
                                             } else {
                                                 Text(windSpeed)
                                                     .font(.title3)
                                                     .foregroundColor(site.windColor)
                                             }
                                         } else {
                                             Text ("Station down")
                                                 .font(.caption)
                                                 .foregroundColor(infoFontColor)
                                         }
                                         if let windGust = site.windGust {
                                             if windGust != "0" && windGust != "" {
                                                 Text("g" + windGust)
                                                     .font(.title3)
                                                     .foregroundColor(site.windGustColor)
                                             }
                                         }
                                         if let windDirectionAngle = site.windDirectionAngle {
                                             Image(systemName: "arrow.up")
                                                 .rotationEffect(windDirectionAngle)
                                                 .font(.title3)
                                         }
                                     }
                                 }
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
        .sheet(item: $selectedSite) { site in
            SiteDetailView(site: site)
        }
     }
     func openSiteDetail(_ site: Site) {
         selectedSite = site
     }
 }
