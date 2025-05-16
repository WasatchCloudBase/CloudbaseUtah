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
                    Text("Contact info")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                    Text("mike.del.brown@gmail.com")
                        .font(.subheadline)
                }
            }
            
            if devMenuAvailable {
                
            Section(header: Text("Development Tools")
                .font(.subheadline)
                .foregroundColor(sectionHeaderColor)
                .bold())
                {
                    
                    // Force reload app (e.g., metadata changes)
                    Button(action: {
                        // Trigger a change to appRefreshID to reload metadata by making BaseAppView reappear
                        refreshMetadata = true
                    }) {
                        Text("Reload metadata changes")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    
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
                    
                    // Site coordiunates map
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
                 
                    // UDOT camera map
                    NavigationLink(destination: PilotTracksView(pilotTracksViewModel: pilotTracksViewModel)
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
