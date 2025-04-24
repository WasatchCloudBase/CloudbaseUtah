import SwiftUI

struct BaseAppView: View {
    @Binding var refreshMetadata: Bool
    @State private var isActive = false
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var sitesViewModel: SitesViewModel
    
    var body: some View {
        VStack {
            if isActive {
                MainView(refreshMetadata: $refreshMetadata)
            } else {
                SplashScreenView()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
        .onChange(of: refreshMetadata) { oldValue, newValue in
            if newValue {
                self.isActive = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        self.isActive = true
                    }
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
    @Binding var refreshMetadata: Bool
    @State var selectedView:NavBarSelectedView = .site
    @State var siteViewActive = true
    @State var weatherViewActive = false
    @State var mapViewActive = false
    @State var webcamViewActive = false
    @State var linkViewActive = false
    @State var devViewActive = false
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodesViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var sitesViewModel: SitesViewModel

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)

                // Call content based on selected navigation
                if selectedView == .site {
                    SiteView(sitesViewModel: sitesViewModel)
                        .environmentObject(sitesViewModel)
                }
                if selectedView == .weather {
                    WeatherView()
                }
                if selectedView == .map {
                    MapView()
                }
                if selectedView == .webcam {
                    WebcamView()
                }
                if selectedView == .link {
                    LinkView()
                }
                if selectedView == .dev {
                    // Pass appRefreshID to enable button forcing app refresh
                    AboutView(refreshMetadata: $refreshMetadata)
                }
                Spacer()
                  
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Title bar (top of screen)
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack (spacing:3) {
                            Image(systemName: "sunrise")
                                .foregroundColor(sunImageColor)
                                .imageScale(.medium)
                            Text(sunriseSunsetViewModel.sunriseSunset?.sunrise ?? "")
                                .foregroundColor(sunFontColor)
                                .font(.caption)
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Button {
                            selectedView = .dev
                            siteViewActive = false
                            weatherViewActive = false
                            mapViewActive = false
                            webcamViewActive = false
                            linkViewActive = false
                            devViewActive = true
                        } label: {
                            Text("Cloudbase Utah")
                                .bold()
                                .foregroundColor(titleFontColor)
                        }

                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack (spacing:3) {
                            Text(sunriseSunsetViewModel.sunriseSunset?.sunset ?? "")
                                .foregroundColor(sunFontColor)
                                .font(.caption)
                            Image(systemName: "sunset")
                                .foregroundColor(sunImageColor)
                                .imageScale(.medium)
                        }
                    }
                    // Navigation bar (bottom of screen)
                    ToolbarItemGroup(placement: .bottomBar) {
                        HStack {
                            Button {
                                selectedView = .site
                                siteViewActive = true
                                weatherViewActive = false
                                mapViewActive = false
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
                                mapViewActive = false
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
                                selectedView = .map
                                siteViewActive = false
                                weatherViewActive = false
                                mapViewActive = true
                                webcamViewActive = false
                                linkViewActive = false
                                devViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "map")
                                        .foregroundColor(mapViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .imageScale(.medium)
                                    Text("Map")
                                        .foregroundColor(mapViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                            }
                            Spacer()
                            Button {
                                selectedView = .webcam
                                siteViewActive = false
                                weatherViewActive = false
                                mapViewActive = false
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
                                mapViewActive = false
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
            }
        }
    }
}
