import SwiftUI
import Combine
import MapKit

struct UDOTCameraData: Codable, Identifiable {
    let id: Int
    let source: String
    let sourceId: String
    let roadway: String
    let direction: String
    let latitude: Double
    let longitude: Double
    let location: String
    let sortOrder: Int
    let views: [UDOTCameraViewData]
     
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

struct UDOTCameraViewData: Codable {
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

class UDOTCamerasViewModel: ObservableObject {
    @Published var cameras: [UDOTCameraData] = []
    @Published var clusteredCameras: [UDOTCameraData] = []

    func fetchCameras() {
        guard let url = URL(string: "https://www.udottraffic.utah.gov/api/v2/get/cameras?key=6035b1d6b660471a89c9b0c0804a584b&format=json") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            do {
                let decodedData = try JSONDecoder().decode([UDOTCameraData].self, from: data)
                DispatchQueue.main.async {
                    self?.cameras = decodedData
                    self?.updateClusters(regionSpan: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan))
                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
        }.resume()
    }

    func updateClusters(regionSpan: MKCoordinateSpan) {
        let thresholdDistance = max(regionSpan.latitudeDelta, regionSpan.longitudeDelta) * mapClusterThresholdFactor
        clusteredCameras = []

        for camera in cameras {
            if clusteredCameras.allSatisfy({ existingCamera in
                let distance = sqrt(pow(camera.latitude - existingCamera.latitude, 2) + pow(camera.longitude - existingCamera.longitude, 2))
                return distance > thresholdDistance
            }) {
                clusteredCameras.append(camera)
            }
        }
    }
}
