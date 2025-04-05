//  DevUtilView.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/15/25.

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
    @StateObject private var viewModel = CameraViewModel()
    @State private var selectedCamera: CameraData?
    var body: some View {
        NavigationView {
            Map(coordinateRegion: .constant(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.320980, longitude: -111.093731),
                span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
            )), annotationItems: viewModel.cameras) { camera in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude)) {
                    Button(action: {
                        selectedCamera = camera
                    }) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.blue)
                            .padding(5)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                }
            }
            .navigationTitle("UDOT Cameras")
            .onAppear {
                viewModel.fetchCameras()
            }
            .sheet(item: $selectedCamera) { camera in
                VStack(alignment: .leading) {
                    Text("Location: \(camera.location)")
                        .font(.subheadline)
                    Text("Latitude: \(camera.latitude)")
                    Text("Latitude: \(camera.longitude)")
                    Text("URL: \(camera.views[0].url)")
                }
                .padding()
            }
        }
    }
}
// Preview
#Preview {
    UDOTCameraListView()
}
