//
//  DevMenuView.swift
//  CloudbaseUtah
//
//  Created by Brown, Mike on 3/15/25.
//
import SwiftUI

struct DevView: View {
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)
                VStack {
                    NavigationLink(destination: UDOTCameraListView()) {
                        Text("UDOT cameras map")
                    }
                }
            }
        }
    }
}

#Preview {
    DevView()
}
