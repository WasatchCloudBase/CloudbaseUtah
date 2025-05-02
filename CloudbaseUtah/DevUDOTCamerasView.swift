import SwiftUI
import MapKit
import Combine
import SDWebImage
import SDWebImageSwiftUI

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

class CamerasViewModel: ObservableObject {
    @Published var cameras: [CameraData] = []
    @Published var clusteredCameras: [CameraData] = []

    func fetchCameras() {
        guard let url = URL(string: "https://www.udottraffic.utah.gov/api/v2/get/cameras?key=6035b1d6b660471a89c9b0c0804a584b&format=json") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            do {
                let decodedData = try JSONDecoder().decode([CameraData].self, from: data)
                DispatchQueue.main.async {
                    self.cameras = decodedData
                    self.updateClusters(regionSpan: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 6.0)) // Initial clustering
                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
        }.resume()
    }

    func updateClusters(regionSpan: MKCoordinateSpan) {
        let thresholdDistance = max(regionSpan.latitudeDelta, regionSpan.longitudeDelta) * 0.1
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

struct UDOTCameraListView: View {
    @StateObject private var viewModel = CamerasViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: mapInitLongitude, longitude: mapInitLatitude),
        span: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan)
    )
    @State private var selectedCamera: CameraData?
    @State private var lastRegionSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0, longitudeDelta: 0)

    var body: some View {
        NavigationView {
            Map(coordinateRegion: $region, annotationItems: viewModel.clusteredCameras) { camera in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude)) {
                    Button {
                        selectedCamera = camera
                    } label: {
                        VStack {
                            Image(systemName: cameraAnnotationImage)
                                .foregroundColor(cameraAnnotationColor)
                            Text(camera.location)
                                .font(.footnote)
                                .foregroundColor(cameraAnnotationTextColor)
                        //        .multilineTextAlignment(.center)
                                .frame(width: annotationTextWidth, height: annotationTextHeight)
                        }
                    }
                }
            }
            .cornerRadius(10)
            .padding(.vertical, 8)
            .onAppear {
                viewModel.fetchCameras()
                startMonitoringRegion()
            }
            .sheet(item: $selectedCamera) { camera in
                CameraDetailView(camera: camera)
            }
        }
    }

    private func startMonitoringRegion() {
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            let currentSpan = region.span
            if hasRegionSpanChanged(from: lastRegionSpan, to: currentSpan) {
                lastRegionSpan = currentSpan
                viewModel.updateClusters(regionSpan: currentSpan)
            }
        }
    }

    private func hasRegionSpanChanged(from oldSpan: MKCoordinateSpan, to newSpan: MKCoordinateSpan) -> Bool {
        let tolerance: Double = 0.01
        return abs(oldSpan.latitudeDelta - newSpan.latitudeDelta) > tolerance ||
            abs(oldSpan.longitudeDelta - newSpan.longitudeDelta) > tolerance
    }
}

struct CameraDetailView: View {
    let camera: CameraData
    @Environment(\.presentationMode) var presentationMode

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
                    }
                }
                .padding()
                Spacer()
            }
            .background(toolbarBackgroundColor)
            
            List {

                VStack(alignment: .leading, spacing: 16) {
                    Text("Location: \(camera.location)")
                    Text("Latitude: \(camera.latitude)")
                    Text("Longitude: \(camera.longitude)")
                    if let view = camera.views.first {
                        Text("View ID: \(view.viewId)")
                        HStack {
                            Text("View URL: ")
                            Text (view.viewURL)
                                .foregroundColor(.blue)
                                .onTapGesture {
                                    if let url = URL(string: view.viewURL) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                        }
                        WebImage (url: URL(string: view.viewURL)) { image in
                            image.resizable() // Control layout like SwiftUI.AsyncImage
                            // Must use this modifier or the view will use the image bitmap size
                        } placeholder: {
                            Text("Image not available")
                                .foregroundColor(infoFontColor)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        // Supports options and context, like `.delayPlaceholder` to show placeholder only when error
                        .onSuccess { image, data, cacheType in
                            // Success
                            // Note: Data exist only when queried from disk cache or network.
                            // Use `.queryMemoryData` if you really need data
                        }
                        .indicator(.activity) // Activity Indicator
                        .transition(.fade(duration: 0.5)) // Fade Transition with duration
                        .scaledToFit()
                    }
                }
            }
        }
    }
}
