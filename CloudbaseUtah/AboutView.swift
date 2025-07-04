import SwiftUI

struct AboutView: View {
    @Binding var refreshMetadata: Bool
    @EnvironmentObject var siteViewModel: SiteViewModel
    
    var body: some View {
        backgroundColor.edgesIgnoringSafeArea(.all)
        List {
            Section(header: Text("About Cloudbase Utah")
                .font(.subheadline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                    Text("Developed by Mike Brown")
                        .font(.subheadline)
                
                //Submit issue via email
                Button(action: {
                    if let url = URL(string: "mailto:\(cloudbaseUtahEmail)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Email feedback or issues")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }

                //Submit issue via Github repo
                Button(action: {
                    if let url = URL(string: cloudbaseUtahGitIssueLink) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Submit issue via Github")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }
                    
                //Github repo
                Button(action: {
                    if let url = URL(string: cloudbaseUtahGitLink) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Cloudbase Utah Github repository")
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
                 
                }
            }
        }
    }
}
