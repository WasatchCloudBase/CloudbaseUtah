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
                VStack(alignment: .leading) {
                    Text("Cloudbase Utah github repository")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                    Text("https://github.com/WasatchCloudBase/CloudbaseUtah")
                        .font(.footnote)
                }

            }
            Section(header: Text("Development Tools")
                .font(.subheadline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                
                Button(action: {
                    if let url = URL(string: "https://docs.google.com/spreadsheets/d/1s72R3YCHxNIJVLVa5nmsTphRpqRsfG2QR2koWxE19ls/edit?gid=0#gid=0") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Cloudbase Utah Metadata")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }
                NavigationLink(destination: UDOTCameraListView()) {
                    Text("UDOT cameras map")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }
                NavigationLink(destination: MapView()) {
                    Text("Map View")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }

            }
        }
    }
}
