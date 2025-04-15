//  SiteView.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/6/25.

import SwiftUI
import Combine
import SDWebImage
import SDWebImageSwiftUI

var webcamLastUpdate: Date = Date.distantPast

struct WeatherCam: Identifiable {
    let id = UUID()
    let category: String
    let name: String
    let linkURL: String
    let imageURL: String
}

class WeatherCamsViewModel: ObservableObject {
    @Published var weatherCams: [WeatherCam] = []
    @Published var groupedWeatherCams: [String: [WeatherCam]] = [:]
    
    func fetchWeatherCams() {
        let rangeName = "WeatherCams"
        let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(googleApiKey)"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Failed to fetch data")
                return
            }
            
            do {
                let response = try JSONDecoder().decode(GoogleSheetResponse.self, from: data)
                
                // Define the condition to skip rows that should be excluded from app (e.g., cam is not active)
                let skipCondition: ([Any]) -> Bool = { row in
                    if let skipRow = row.first as? String {
                        return skipRow == "Yes"
                    }
                    return false
                }
                let cams = response.values.dropFirst().filter {!skipCondition($0)}.map { row in
                    return WeatherCam(category: row[1], name: row[2], linkURL: row[3], imageURL: row[4])
                }
                
                DispatchQueue.main.async {
                    self.weatherCams = cams
                    self.groupedWeatherCams = Dictionary(grouping: cams, by: { $0.category })
                }
            } catch {
                print("Failed to decode JSON")
            }
        }.resume()
    }
}

struct GoogleSheetResponse: Codable {
    let values: [[String]]
}

struct WebcamView: View {
    @StateObject private var viewModel = WeatherCamsViewModel()
    @Environment(\.openURL) var openURL     // Used to open URL links as an in-app sheet using Safari
    @State private var externalURL: URL?    // Used to open URL links as an in-app sheet using Safari
    @State private var showWebView = false  // Used to open URL links as an in-app sheet using Safari
    var ipCamURL: String = "https://apps.apple.com/us/app/ip-camera-viewer-ipcams/id1045600272"
    var UHGPGAcamsURL: String = "https://www.uhgpga.org/webcams"
    var body: some View {
        List {
            Section(header: Text("Point of the Mountain")
                .font(.subheadline)
                .foregroundColor(sectionHeaderColor)
                .bold()) {
                    Button(action: {
                        if let url = URL(string: ipCamURL) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        VStack(alignment: .leading) {
                            Text("Download IPCams to view POTM webcams")
                                .font(.subheadline)
                                .foregroundColor(rowHeaderColor)
                            Text("UHGPGA webcam page has IP and PW info")
                                .font(.subheadline)
                        }
                    }
                }
            ForEach(viewModel.groupedWeatherCams.keys.sorted(), id: \.self) { category in
                // Split is used to strip the order sequence number from the front of the category on display
                Section(header: Text(category.split(separator: " ", maxSplits: 1)[1])
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold()) {
                    ForEach(viewModel.groupedWeatherCams[category] ?? [], id: \.id) { cam in
                        VStack {
                            Text(cam.name)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .font(.subheadline)
                                .foregroundColor(rowHeaderColor)
                            WebImage (url: URL(string: cam.imageURL.isEmpty ? cam.linkURL : cam.imageURL)) { image in
                                image.resizable() // Control layout like SwiftUI.AsyncImage
                                                  // Must use this modifier or the view will use the image bitmap size
                            } placeholder: {
                                Text("Tap to view")
                                    .foregroundColor(infoFontColor)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            // Supports options and context, like `.delayPlaceholder` to show placeholder only when error
                            .onSuccess { image, data, cacheType in
                                // Success
                                // Note: Data exist only when queried from disk cache or network.
                                // Use `.queryMemoryData` if you really need data
                            }
                            .indicator(.activity) // Activity Indicator
                            .transition(.fade(duration: 0.5)) // Fade Transition with duration
                            .scaledToFit()
                        }
                        .onTapGesture {
                            if let url = URL(string: cam.linkURL) {
                                openLink(url)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            // Clear all image caches and force reload if more than 5 minutes have passed since last update
            if Date().timeIntervalSince(webcamLastUpdate) > pageRefreshInterval {
                SDImageCache.shared.clear(with: .all) {
                    webcamLastUpdate = Date()
                }
            }
            viewModel.fetchWeatherCams()
        }
        // Used to open URL links as an in-app sheet using Safari
        .sheet(isPresented: $showWebView) { if let url = externalURL { SafariView(url: url) } }
    }
    // Used to open URL links as an in-app sheet using Safari
    func openLink(_ url: URL) { externalURL = url; showWebView = true }
}
