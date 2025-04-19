//  DevMenuView.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/15/25.

import SwiftUI

struct AboutView: View {
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
                Button(action: {
                    if let url = URL(string: cloudbaseUtahGoogleSheetLink) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Cloudbase Utah metadata")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }
                
                Button(action: {
                    if let url = URL(string: cloudbaseUtahGitLink) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Cloudbase Utah github repository")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }
                
                NavigationLink(destination: UDOTCameraListView()) {
                    Text("UDOT cameras map")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }
            }
        }
    }
}
