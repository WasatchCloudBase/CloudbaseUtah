//  SiteView.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/6/25.

import SwiftUI
import Combine


// Define a model to represent the data
struct Site: Identifiable {
    let id = UUID()
    let siteName: String
    let area: String
    let readingsAlt: String
    let readingsSource: String
    let readingsStation: String
}

struct StationReading: Identifiable {
    let id = UUID()
    let siteName: String
    let readingsAlt: String
    let windSpeed: Double?
    let windDirection: Double?
    let windGust: Double?
}

// ViewModel to fetch and store the data
class SitesViewModel: ObservableObject {
    @Published var sites: [Site] = []
    @Published var stationReadings: [StationReading] = []
    
    private var cancellable: AnyCancellable?
    
    init() {
        fetchData()
    }
    
    func fetchData() {
        let spreadsheetID = "1s72R3YCHxNIJVLVa5nmsTphRpqRsfG2QR2koWxE19ls"
        let rangeName = "Sites"
        let apiKey = "AIzaSyDSro1lDdAQsNEZq06IxwjOlQQP1tip-fs"
        let GoogleURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetID)/values/\(rangeName)?alt=json&key=\(apiKey)"
        
        print("---------")
        print(GoogleURLString)
        print("--------")

        
        guard let url = URL(string: GoogleURLString) else { return }
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: GoogleSheetsResponse.self, decoder: JSONDecoder())
            .map { response in
                response.values.dropFirst().map { row in
                    Site(
                        siteName: row[0],
                        area: row[1],
                        readingsAlt: row[5],
                        readingsSource: row[6],
                        readingsStation: row[7]
                    )
                }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .assign(to: \.sites, on: self)
        
            print("---------")
            print("assigning data to sites:")
            for printsite in sites {
                print(printsite.area + " " + printsite.siteName + " " + printsite.readingsStation)
            }
            print("--------")

    }
    
    func fetchStationReadings() {
        let baseURL = "https://api.mesowest.net/v2/station/latest?"
        let token = "ef3b9f4584b64e6da12d8688f19d9f4a"
        
        print("---------")
        print("sites:")
        for printsite in sites {
            print(printsite.area + " " + printsite.siteName + " " + printsite.readingsStation)
        }
        print("--------")
        let mesonetSites = sites.filter { $0.readingsSource == "Mesonet" }
        let stid = mesonetSites.map { $0.readingsStation }.joined(separator: ",")
        
        print("---------")
        print("Mesonet sites:")
        for printmesosite in mesonetSites {
            print(printmesosite.area + " " + printmesosite.siteName + " " + printmesosite.readingsStation)
        }
        print("---------")
        
        let readingsURLString = "\(baseURL)" + "&stid=\(stid)" + "&recent=420&vars=air_temp,altimeter,wind_direction,wind_gust,wind_speed&units=english,speed|mph,temp|F" + "&within=120&obtimezone=local&timeformat=%-I:%M%20%p&token=\(token)"
        
        print(readingsURLString)
        
        guard let url = URL(string: readingsURLString) else { return }
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: MesonetResponse.self, decoder: JSONDecoder())
            .map { response in
                response.STATION.map { station in
                    StationReading(
                        siteName: mesonetSites.first { $0.readingsStation == station.STID }?.siteName ?? "",
                        readingsAlt: mesonetSites.first { $0.readingsStation == station.STID }?.readingsAlt ?? "",
                        windSpeed: station.OBSERVATIONS.wind_speed_value_1?.value,
                        windDirection: station.OBSERVATIONS.wind_direction_value_1?.value,
                        windGust: station.OBSERVATIONS.wind_gust_value_1?.value
                    )
                }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .assign(to: \.stationReadings, on: self)
    }
}

// Define the response structure for Google Sheets
struct GoogleSheetsResponse: Decodable {
    let values: [[String]]
}

// Define the response structure for Mesonet API
struct MesonetResponse: Decodable {
    let STATION: [Station]
}

struct Station: Decodable {
    let STID: String
    let NAME: String
    let OBSERVATIONS: Observations
}

struct Observations: Decodable {
    let wind_speed_value_1: ObservationValue?
    let wind_direction_value_1: ObservationValue?
    let wind_gust_value_1: ObservationValue?
}

struct ObservationValue: Decodable {
    let value: Double
}

// SwiftUI view to display the data
struct SiteView: View {
    @ObservedObject var viewModel = SitesViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.stationReadings) { reading in
                    VStack(alignment: .leading) {
                        Text("SiteName: \(reading.siteName)")
                        Text("ReadingsAlt: \(reading.readingsAlt)")
                        if let windSpeed = reading.windSpeed {
                            Text("Wind Speed: \(windSpeed)")
                        }
                        if let windDirection = reading.windDirection {
                            Text("Wind Direction: \(windDirection)")
                        }
                        if let windGust = reading.windGust {
                            Text("Wind Gust: \(windGust)")
                        }
                    }
                }
            }
            .navigationTitle("Latest Station Readings")
            .onAppear {
                viewModel.fetchStationReadings()
            }
//            .onChange (of: sites) {
//                viewModel.fetchStationReadings(forceRefresh: true)
//            }
        }
    }
}

#Preview {
    SiteView()
}
