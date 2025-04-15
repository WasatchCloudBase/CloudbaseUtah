// DevUtilView.swift
// CloudbaseUtah
// Created by Brown, Mike on 3/15/25.

import SwiftUI
import MapKit
import Combine

// Model to parse JSON data
struct CameraData: Codable, Identifiable {
    let id: Int
    let source: String
    let sourceId: String
    let roadway: String
    let direction: String
    let latitude: Double
    let longitude: Double
    let location: String
    let sortOrder: Int
    let views: [ViewData]
     
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case source = "Source"
        case sourceId = "SourceId"
        case roadway = "Roadway"
        case direction = "Direction"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case location = "Location"
        case sortOrder = "SortOrder"
        case views = "Views"
    }
}

struct ViewData: Codable, Identifiable {
    let id: Int
    let url: String
    let status: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case url = "Url"
        case status = "Status"
        case description = "Description"
    }
}

// ViewModel to handle network request
class CameraViewModel: ObservableObject {
    @Published var cameras = [CameraData]()
    private var cancellable: AnyCancellable?
    
    init() {
        fetchCameras()
    }
    
    func fetchCameras() {
        guard let url = URL(string: "https://www.udottraffic.utah.gov/api/v2/get/cameras?key=6035b1d6b660471a89c9b0c0804a584b&format=json") else { return }
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: [CameraData].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] cameras in
                self?.cameras = cameras
            })
    }
}

// SwiftUI view to display map with camera icons
struct UDOTCameraListView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var selectedCamera: CameraData?
    @State private var mapType: MKMapType = .standard
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.6, longitude: -111.5), // Utah's approximate center
        span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
    )
    
    var body: some View {
        NavigationView {
            VStack {
                // Pass cameras to the BuildMapView
                BuildMapView(mapType: $mapType, region: $region, cameras: cameraViewModel.cameras)
                    .cornerRadius(10)
                Picker("Map Style", selection: $mapType) {
                    Text("Standard").tag(MKMapType.standard)
                    Text("Hybrid").tag(MKMapType.hybrid)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
            }
        }
    }
    
    struct BuildMapView: UIViewRepresentable {
        @Binding var mapType: MKMapType
        @Binding var region: MKCoordinateRegion
        var cameras: [CameraData] // Accept cameras as input
        
        func makeUIView(context: Context) -> MKMapView {
            let mapView = MKMapView()
            mapView.setRegion(region, animated: true)
            mapView.delegate = context.coordinator // Set delegate for annotations
            return mapView
        }
        
        func updateUIView(_ mapView: MKMapView, context: Context) {
            mapView.mapType = mapType
            addAnnotations(to: mapView) // Add annotations for cameras
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        private func addAnnotations(to mapView: MKMapView) {
            mapView.removeAnnotations(mapView.annotations) // Clear existing annotations
            let annotations = cameras.map { camera -> MKPointAnnotation in
                let annotation = MKPointAnnotation()
                annotation.title = camera.location
                annotation.coordinate = CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude)
                return annotation
            }
            mapView.addAnnotations(annotations)
        }
        
        // Coordinator to handle annotations and interactions
        class Coordinator: NSObject, MKMapViewDelegate {
            var parent: BuildMapView
            
            
            init(_ parent: BuildMapView) {
                self.parent = parent
            }
        }
    }
}
