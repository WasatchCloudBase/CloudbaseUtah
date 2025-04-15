//  DevUtilView.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/15/25.

import SwiftUI
import MapKit

struct MapView: View {
    @State private var mapType: MKMapType = .standard
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.6, longitude: -111.5), // Utah's approximate center
        span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
    )
    
    var body: some View {
        VStack {
            BuildMapView(mapType: $mapType, region: $region)
                .cornerRadius(10)
            Picker("Map Style", selection: $mapType) {
                Text("Standard").tag(MKMapType.standard)
                Text("Hybrid").tag(MKMapType.hybrid)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
        }
        .padding(.top, 12)
    }
}

struct BuildMapView: UIViewRepresentable {
    @Binding var mapType: MKMapType
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.setRegion(region, animated: true)
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.mapType = mapType
    }
}
