import SwiftUI
import Combine
import Foundation
import SDWebImage
import SDWebImageSwiftUI

var webcamLastUpdate: Date = Date.distantPast

struct WeatherCamView: View {
    @StateObject private var weatherCamViewModel = WeatherCamViewModel()
    @Environment(\.openURL) var openURL     // Used to open URL links as an in-app sheet using Safari
    @State private var externalURL: URL?    // Used to open URL links as an in-app sheet using Safari
    @State private var showWebView = false  // Used to open URL links as an in-app sheet using Safari
    
    var body: some View {
        Group {
            if weatherCamViewModel.isLoading {
                loadingView
            } else if weatherCamViewModel.weatherCams.isEmpty {
                emptyView
            } else {
                contentView
            }
        }
        .onAppear {
            // Clear all image caches and force reload if images are odler than refresh interval
            if Date().timeIntervalSince(webcamLastUpdate) > readingsRefreshInterval {
                SDImageCache.shared.clear(with: .all) {
                    webcamLastUpdate = Date()
                }
            }
            weatherCamViewModel.fetchWeatherCams()
        }
        // Used to open URL links as an in-app sheet using Safari
        .sheet(isPresented: $showWebView) { if let url = externalURL { SafariView(url: url) } }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView() // ("Loading weather cams…")
                .progressViewStyle(CircularProgressViewStyle())
            Spacer()
        }
    }
    
    private var emptyView: some View {
        VStack {
            Spacer()
            Text("No weather cams available")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding()
            Spacer()
        }
    }

    private var contentView: some View {
        List {
            Section(header: Text("Point of the Mountain")
                .font(.subheadline)
                .foregroundColor(sectionHeaderColor)
                .bold()) {
                    Button(action: {
                        if let url = URL(string: ipCamLink) {
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
            ForEach(weatherCamViewModel.groupedWeatherCams.keys.sorted(), id: \.self) { category in
                // Split is used to strip the order sequence number from the front of the category on display
                Section(header: Text(category.split(separator: " ", maxSplits: 1)[1])
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold()) {
                        ForEach(weatherCamViewModel.groupedWeatherCams[category] ?? [], id: \.id) { cam in
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
    }
    
    // Used to open URL links as an in-app sheet using Safari
    func openLink(_ url: URL) { externalURL = url; showWebView = true }
}
