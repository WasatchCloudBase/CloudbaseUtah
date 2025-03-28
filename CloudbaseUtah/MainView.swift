//  ContentView.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/6/25.

import SwiftUI

// Sunrise and sunset URL fetch response structure
struct SunriseSunsetResponse: Codable {
    let results: Results
    let status: String
}
// Sunrise and sunset JSON decode for Results portion of URL response
struct Results: Codable {
    let sunrise: String
    let sunset: String
}
// Get sunrise / sunset for SLC airport
func fetchSunriseSunset(forLatitude latitude: Double, longitude: Double, completion: @escaping (String, String) -> Void) {
    let urlString = "https://api.sunrise-sunset.org/json?lat=\(latitude)&lng=\(longitude)&formatted=0"
    guard let url = URL(string: urlString) else {
        print("Invalid URL")
        return
    }
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error: \(error.localizedDescription)")
            return
        }
        guard let data = data else {
            print("No data received")
            return
        }
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(SunriseSunsetResponse.self, from: data)
            let sunrise = convertISODateToLocalTime(isoDateString: response.results.sunrise)
            let sunset = convertISODateToLocalTime(isoDateString: response.results.sunset)
            DispatchQueue.main.async {
                completion(sunrise, sunset)
            }
        } catch {
            print("Error decoding JSON: \(error.localizedDescription)")
        }
    }
    task.resume()
}

struct BaseAppView: View {
    @State private var isActive = false
    var body: some View {
        VStack {
            if isActive {
                MainView()
            } else {
                SplashScreenView()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
    }
}

struct SplashScreenView: View {
    var body: some View {
        Image("UtahPGicon8")
            .resizable()
            .scaledToFit()
        Text("Cloudbase Utah")
            .bold()
            .foregroundColor(titleFontColor)
            .padding(.top, 2)
    }
}


struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State var sunrise: String = ""
    @State var sunset: String = ""
    @State var selectedView:NavBarSelectedView = .site
    @State var siteViewActive = true
    @State var weatherViewActive = false
    @State var alertsViewActive = false
    @State var webcamViewActive = false
    @State var linkViewActive = false
    @State var devViewActive = false

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)
                
                // Call content based on selected navigation
                if selectedView == .site {
                    SiteView()
                }
                if selectedView == .weather {
                    WeatherView()
                }
                if selectedView == .alerts {
                    AlertsView()
                }
                if selectedView == .webcam {
                    WebcamView()
                }
                if selectedView == .link {
                    LinkView()
                }
                if selectedView == .dev {
                    AboutView()
                }
                Spacer()
                  
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Title bar (top of screen)
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack (spacing:1) {
                            Image(systemName: "sunrise")
                                .foregroundColor(sunImageColor)
                            Text(sunrise)
                                .foregroundColor(sunFontColor)
                                .font(.caption)
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Button {
                            selectedView = .dev
                            siteViewActive = false
                            weatherViewActive = false
                            alertsViewActive = false
                            webcamViewActive = false
                            linkViewActive = false
                            devViewActive = true
                        } label: {
                            Text("Cloudbase Utah")
                                .font(.body.width(.condensed) .bold())
                                .foregroundColor(titleFontColor)
                        }

                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack (spacing:1) {
                            Text(sunset)
                                .foregroundColor(sunFontColor)
                                .font(.caption)
                            Image(systemName: "sunset")
                                .foregroundColor(sunImageColor)
                        }
                    }
                    // Navigation bar (bottom of screen)
                    ToolbarItemGroup(placement: .bottomBar) {
                        HStack {
                            Button {
                                selectedView = .site
                                siteViewActive = true
                                weatherViewActive = false
                                alertsViewActive = false
                                webcamViewActive = false
                                linkViewActive = false
                                devViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "cloud.sun")
                                        .foregroundColor(siteViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .imageScale(.medium)
                                    Text("Sites")
                                        .foregroundColor(siteViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                            }
                            Spacer()
                            Button {
                                selectedView = .weather
                                siteViewActive = false
                                weatherViewActive = true
                                alertsViewActive = false
                                webcamViewActive = false
                                linkViewActive = false
                                devViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "cloud.sun")
                                        .foregroundColor(weatherViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .imageScale(.medium)
                                    Text("Region")
                                        .foregroundColor(weatherViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                            }
                            Spacer()
                            Button {
                                selectedView = .alerts
                                siteViewActive = false
                                weatherViewActive = false
                                alertsViewActive = true
                                webcamViewActive = false
                                linkViewActive = false
                                devViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(alertsViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .imageScale(.medium)
                                    Text("Alerts")
                                        .foregroundColor(alertsViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                            }
                            Spacer()
                            Button {
                                selectedView = .webcam
                                siteViewActive = false
                                weatherViewActive = false
                                alertsViewActive = false
                                webcamViewActive = true
                                linkViewActive = false
                                devViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "photo")
                                        .foregroundColor(webcamViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .imageScale(.medium)
                                    Text("Cams")
                                        .foregroundColor(webcamViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                            }
                            Spacer()
                            Button {
                                selectedView = .link
                                siteViewActive = false
                                weatherViewActive = false
                                alertsViewActive = false
                                webcamViewActive = false
                                linkViewActive = true
                                devViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "link")
                                        .foregroundColor(linkViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .imageScale(.medium)
                                    Text("Links")
                                        .foregroundColor(linkViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                            }
                        }

                    }
                }
                // Separator bar below title bar
                VStack {
                    Rectangle()
                        .fill(titlebarSeparatorColor)
                        .frame(height: 1)
                    Spacer()
                }
            }.onAppear {
                fetchSunriseSunset (forLatitude: sunriseLatitude, longitude: sunriseLongitude)
                { sunriseTime, sunsetTime in
                    sunrise = sunriseTime
                    sunset = sunsetTime
                }
            }
        }
    }
}
