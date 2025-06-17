import SwiftUI

struct AboutView: View {
    @Binding var refreshMetadata: Bool
    @EnvironmentObject var sitesViewModel: SitesViewModel
    @EnvironmentObject var pilotsViewModel: PilotsViewModel
    @StateObject private var pilotTracksViewModel = PilotTracksViewModel()
    
    var body: some View {
        backgroundColor.edgesIgnoringSafeArea(.all)
        List {
            Section(header: Text("About Cloudbase Utah")
                .font(.subheadline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                VStack(alignment: .leading) {
                    Text("Developed by Mike Brown")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                    Text("cloudbaseutah@gmail.com")
                        .font(.subheadline)
                }
                    
                //Github repo
                Button(action: {
                    if let url = URL(string: cloudbaseUtahGitLink) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Cloudbase Utah github repository")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }
            }
            
            Section(header: Text("Application setup")
                .font(.subheadline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                
                // Force reload app (e.g., metadata changes)
                Button(action: {
                    // Trigger a change to appRefreshID to reload metadata by making BaseAppView reappear
                    refreshMetadata = true
                }) {
                    Text("Reload metadata")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }
                                
            }
            

            if devMenuAvailable {
                
            Section(header: Text("Development Tools")
                .font(.subheadline)
                .foregroundColor(sectionHeaderColor)
                .bold())
                {
                    
                    // Metadata
                    Button(action: {
                        if let url = URL(string: cloudbaseUtahGoogleSheetLink) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Cloudbase Utah metadata")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    
                    // Site coordinates map
                    NavigationLink(destination: DevSiteCoordView()) {
                        Text("Site coordinates updates")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    
                    // UDOT camera map
                    NavigationLink(destination: UDOTCameraListView()) {
                        Text("UDOT cameras map")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                 
                    // Pilot track listing
                    NavigationLink(destination:
                                   PilotTracksView(
                                       pilotTracksViewModel: pilotTracksViewModel,
                                       pilotTrackDays: defaultPilotTrackDays
                                   )
                        .environmentObject(pilotsViewModel)) {
                        Text("Pilot track node list")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    
                }
            }
        }
    }
}
