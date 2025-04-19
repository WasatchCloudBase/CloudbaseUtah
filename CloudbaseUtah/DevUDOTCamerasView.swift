// DevUtilView.swift
// CloudbaseUtah
// Created by Brown, Mike on 3/15/25.
import SwiftUI
import MapKit

struct UDOTCameraListView: View {
    @State private var selectedAnnotation: CameraSelection? = nil
    @State private var cameras: [CameraAnnotation] = []
    let initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.320980, longitude: -111.093731), // Center of Utah
        span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0) // Zoom level for Utah
    )
    var body: some View {
        CameraMapView(annotations: cameras, initialRegion: initialRegion, onTapAnnotation: { annotation in
            selectedAnnotation = CameraSelection(
                id: annotation.id,
                name: annotation.name,
                latitude: annotation.coordinate.latitude,
                longitude: annotation.coordinate.longitude,
                viewURL: annotation.viewURL
            )
        })
        .sheet(item: $selectedAnnotation) { cameraSelection in
            AnnotationSheet(
                id: cameraSelection.id,
                latitude: cameraSelection.latitude,
                longitude: cameraSelection.longitude,
                location: cameraSelection.name,
                viewURL: cameraSelection.viewURL
            )
        }
        .onAppear {
            fetchCameras()
        }
    }
    
    private func fetchCameras() {
        guard let url = URL(string: uDOTCamerasAPI) else {
            print("Invalid URL")
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error)")
                return
            }
            guard let data = data else {
                print("No data returned")
                return
            }
            do {
                let cameraDataList = try JSONDecoder().decode([CameraData].self, from: data)
                DispatchQueue.main.async {
                    cameras = cameraDataList.map {
                        CameraAnnotation(
                            id: $0.id,
                            name: $0.location,
                            coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                            viewURL: $0.views.first?.viewURL ?? "MISSING URL"
                        )
                    }
                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
        }.resume()
    }
}

struct AnnotationSheet: View {
    let id: Int
    let latitude: Double
    let longitude: Double
    let location: String
    let viewURL: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Camera Details")
                .font(.headline)
            Text("ID: \(id)")
            Text("Location: \(location)")
            Text("Latitude: \(latitude)")
            Text("Longitude: \(longitude)")
            Text("View URL:")
            Link(viewURL, destination: URL(string: viewURL) ?? URL(string: uDOTCamerasLink)!)
        }
        .padding()
        .font(.body)
    }
}

struct CameraMapView: UIViewRepresentable {
    let annotations: [CameraAnnotation]
    let initialRegion: MKCoordinateRegion
    let onTapAnnotation: (CameraAnnotation) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let cameraMapView = MKMapView()
        cameraMapView.delegate = context.coordinator
        cameraMapView.setRegion(initialRegion, animated: false) // Set initial region
        return cameraMapView
    }
    
    func updateUIView(_ cameraMapView: MKMapView, context: Context) {
        cameraMapView.removeAnnotations(cameraMapView.annotations)
        cameraMapView.addAnnotations(annotations.map { annotation in
            let mapAnnotation = MKPointAnnotation()
            mapAnnotation.title = annotation.name
            mapAnnotation.coordinate = annotation.coordinate
            return mapAnnotation
        })
/*
        for annotation in annotations {
            let mapAnnotation = MKPointAnnotation()
            mapAnnotation.title = annotation.name
            mapAnnotation.coordinate = annotation.coordinate
            cameraMapView.addAnnotation(mapAnnotation)
        }
 */
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(annotations: annotations, onTapAnnotation: onTapAnnotation)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let annotations: [CameraAnnotation]
        let onTapAnnotation: (CameraAnnotation) -> Void
        
        init(annotations: [CameraAnnotation], onTapAnnotation: @escaping (CameraAnnotation) -> Void) {
            self.annotations = annotations
            self.onTapAnnotation = onTapAnnotation
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation as? MKPointAnnotation {
                if let cameraAnnotation = annotations.first(where: {
                    $0.name == annotation.title
                }) {
                    onTapAnnotation(cameraAnnotation)
                }
            }
        }
    }
}

struct CameraAnnotation: Identifiable {
    let id: Int
    let name: String
    let coordinate: CLLocationCoordinate2D
    let viewURL: String
}

struct CameraSelection: Identifiable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let viewURL: String
}

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

struct ViewData: Codable {
    let viewId: Int
    let viewURL: String
    let status: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case viewId = "Id"
        case viewURL = "Url"
        case status = "Status"
        case description = "Description"
    }
}
