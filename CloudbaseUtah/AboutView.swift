import SwiftUI

struct AboutView: View {
    @Binding var refreshMetadata: Bool
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
                
                // UDOT camera map
                NavigationLink(destination: UDOTCameraListView()) {
                    Text("UDOT cameras map")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }
                
                // Test Skew-T view
                NavigationLink(destination: SkewTChartView()) {
                    Text("Test for Skew-T")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }

                
                // Force reload app (e.g., metadata changes)
                Button(action: {
                    // Trigger a change to appRefreshID to reload metadata by making BaseAppView reappear
                    refreshMetadata = true
                }) {
                    Text("Reload metadata changes")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }
                
            }
        }
    }
}
