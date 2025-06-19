import SwiftUI
import MapKit
import Foundation
import CoreLocation

struct DevSiteCoordView: View {
    @EnvironmentObject var sitesViewModel: SitesViewModel
    @State private var selectedSite: Sites?
    @State private var showMapSheet = false
    @State private var coordinateRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        NavigationView {
            List(sitesViewModel.sites) { site in
                Button(action: {
                    let latitude = Double(site.siteLat) ?? 0.0
                    let longitude = Double(site.siteLon) ?? 0.0

                    selectedSite = site // Set site first
                    coordinateRegion = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                }) {
                    Text(site.siteName)
                        .font(.subheadline)
                        .foregroundColor(sectionHeaderColor)
                }
            }
            .onChange(of: selectedSite) {
                showMapSheet = true
            }
            .sheet(isPresented: $showMapSheet) {
                if let selectedSite = selectedSite {
                    SiteMapView(site: selectedSite, coordinateRegion: $coordinateRegion)
                        .interactiveDismissDisabled(true) // ← disables swipe-to-dismiss
                } else {
                    Text("No selected site found")
                }
            }
        }
    }
}

struct IdentifiableCoordinate: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct SiteCoordMapViewRepresentable: UIViewRepresentable {
    @Binding var coordinateRegion: MKCoordinateRegion
    @Binding var markerCoordinate: CLLocationCoordinate2D?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.delegate = context.coordinator

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleMapTap))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(coordinateRegion, animated: true)

        // Remove existing annotations before adding a new one
        uiView.removeAnnotations(uiView.annotations)

        if let markerCoordinate = markerCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = markerCoordinate
            uiView.addAnnotation(annotation)
        }        
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: SiteCoordMapViewRepresentable

        init(parent: SiteCoordMapViewRepresentable) {
            self.parent = parent
        }

        @objc func handleMapTap(sender: UITapGestureRecognizer) {
            let mapView = sender.view as! MKMapView
            let touchPoint = sender.location(in: mapView)
            let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)

            DispatchQueue.main.async {
                self.parent.markerCoordinate = coordinate // Update tapped marker
                self.parent.coordinateRegion.center = coordinate // Center map on new marker
            }
        }
    }
}

struct SiteMapView: View {
    var site: Sites
    @Binding var coordinateRegion: MKCoordinateRegion
    @State private var markerCoordinate: CLLocationCoordinate2D?
    @EnvironmentObject var sitesViewModel: SitesViewModel
    @Environment(\.presentationMode) var presentationMode

    init(site: Sites, coordinateRegion: Binding<MKCoordinateRegion>) {
        self.site = site
        _coordinateRegion = coordinateRegion
        _markerCoordinate = State(initialValue: coordinateRegion.wrappedValue.center) // Initialize marker at center
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(toolbarActiveImageColor)
                        Text("Back")
                            .foregroundColor(toolbarActiveFontColor)
                        Spacer()
                        Text(site.siteName)
                            .foregroundColor(sectionHeaderColor)
                            .bold()
                    }
                }
                .padding()
                Spacer()
            }
            .background(toolbarBackgroundColor)
            SiteCoordMapViewRepresentable(coordinateRegion: $coordinateRegion, markerCoordinate: $markerCoordinate)
            
            // Commented out...need to implement Google client app authorization to call update APIs
            /*            Button("Update Coordinates") {
             if let newCoordinate = markerCoordinate {
             updateSiteCoordinates(siteName: site.siteName, sheetRow: site.sheetRow, newCoordinate: newCoordinate)
             presentationMode.wrappedValue.dismiss()
             }
             }
             */
            // In the mean time, simply displaying values to cut and paste.
            
            // Display latitude and longitude as buttons
            if let markerCoordinate = markerCoordinate {
                HStack {
                    Button(action: {
                        UIPasteboard.general.string = String(format: "%.5f", markerCoordinate.latitude)
                    }) {
                        Text("Lat: \(String(format: "%.5f", markerCoordinate.latitude))")
                    }
                    .padding()
                    .background(skewTButtonBackgroundColor)
                    .foregroundColor(skewTButtonTextColor)
                    .cornerRadius(8)
                    
                    Button(action: {
                        UIPasteboard.general.string = String(format: "%.5f", markerCoordinate.longitude)
                    }) {
                        Text("Lon: \(String(format: "%.5f", markerCoordinate.longitude))")
                    }
                    .padding()
                    .background(skewTButtonBackgroundColor)
                    .foregroundColor(skewTButtonTextColor)
                    .cornerRadius(8)
                }
                .padding()
            }
        }
    }
            
    func updateSiteCoordinates(siteName: String, sheetRow: Int, newCoordinate: CLLocationCoordinate2D) {
        // Build range to specify row and columns to be updated
        let rangeName = "Sites!R\(sheetRow)C11:R\(sheetRow)C12"
        let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(googleApiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "range": rangeName,
            "majorDimension": "ROWS",
            "values": [
                ["\(newCoordinate.latitude)", "\(newCoordinate.longitude)"]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error updating coordinates: \(error.localizedDescription)")
                return
            }
            print("Coordinates updated successfully.")
        }.resume()
    }
}
