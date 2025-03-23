//  DevMenuView.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/15/25.

import SwiftUI

struct AboutView: View {
    var body: some View {
        backgroundColor.edgesIgnoringSafeArea(.all)
        List {
            Section(header: Text("About Cloudbase Utah")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                VStack(alignment: .leading) {
                    Text("Contact info: ")
                        .font(.headline)
                        .foregroundColor(rowHeaderColor)
                    Text("mike.del.brown@gmail.com")
                        .font(.subheadline)
                }
                VStack(alignment: .leading) {
                    Text("Thanks to:")
                        .font(.headline)
                        .foregroundColor(rowHeaderColor)
                    Text("Matt Hansen for the Wasatch Wind site that was the origin for this app")
                        .font(.subheadline)
                    Text("https://wasatchwind.github.io/")
                        .font(.footnote)
                }

            }
            Section(header: Text("Development Tools")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                VStack(alignment: .leading) {
                    NavigationLink(destination: UDOTCameraListView()) {
                        Text("UDOT cameras map")
                    }
                }
            }
        }
    }
}
