//  AlertsView.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/6/25.
/*
import SwiftUI

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

struct AlertsView: View {
    @StateObject private var viewModel = TFRViewModel()
    @Environment(\.openURL) var openURL     // Used to open URL links as an in-app sheet using Safari
    @State private var externalURL: URL?    // Used to open URL links as an in-app sheet using Safari
    @State private var showWebView = false  // Used to open URL links as an in-app sheet using Safari
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
            // TFRs for Utah
            Section(header: Text("Temporary Flight Restrictions")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                if viewModel.isLoading {
                    ProgressView("TFRs loading...")
                } else if viewModel.tfrs.isEmpty {
                    Text("There are no current TFRs for Utah")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                } else {
                    ForEach(viewModel.tfrs) { tfr in
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
        }
        .onAppear (perform: fetchWeatherAlerts)
        .onAppear {viewModel.fetchTFRs()}
        // Used to open URL links as an in-app sheet using Safari
        .sheet(isPresented: $showWebView) { if let url = externalURL { SafariView(url: url) } }
    }
    // Used to open URL links as an in-app sheet using Safari
    func openLink(_ url: URL) { externalURL = url; showWebView = true }
}
*/
