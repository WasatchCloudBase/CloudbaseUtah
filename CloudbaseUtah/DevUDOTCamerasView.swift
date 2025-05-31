import SwiftUI
import MapKit
import Combine
import SDWebImage
import SDWebImageSwiftUI

struct UDOTCameraListView: View {
    @StateObject private var camerasViewModel = UDOTCamerasViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: mapInitLatitude, longitude: mapInitLongitude),
        span: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan)
    )
    @State private var lastRegionSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0, longitudeDelta: 0)
    @State private var selectedCamera: UDOTCameraData?

    var body: some View {
        NavigationView {
            
            // Validate camera coordinates
            let _ = camerasViewModel.clusteredCameras.forEach { camera in
                assert(camera.latitude >= -90 && camera.latitude <= 90, "Invalid latitude: \(camera.latitude)")
                assert(camera.longitude >= -180 && camera.longitude <= 180, "Invalid longitude: \(camera.longitude)")
            }
            
            Map(coordinateRegion: $region, annotationItems: camerasViewModel.clusteredCameras) { camera in
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
                camerasViewModel.fetchCameras()
                startMonitoringRegion()
            }
            .sheet(item: $selectedCamera) { camera in
                CameraDetailView(camera: camera)
            }
        }
    }

    private func startMonitoringRegion() {
        Timer.scheduledTimer(withTimeInterval: mapBatchProcessingInterval, repeats: true) { _ in
            let currentSpan = region.span
            if hasRegionSpanChanged(from: lastRegionSpan, to: currentSpan) {
                lastRegionSpan = currentSpan
                camerasViewModel.updateClusters(regionSpan: currentSpan)
            }
        }
    }

    private func hasRegionSpanChanged(from oldSpan: MKCoordinateSpan, to newSpan: MKCoordinateSpan) -> Bool {
        return abs(oldSpan.latitudeDelta - newSpan.latitudeDelta) > mapScaleChangeTolerance ||
            abs(oldSpan.longitudeDelta - newSpan.longitudeDelta) > mapScaleChangeTolerance
    }
}

struct CameraDetailView: View {
    let camera: UDOTCameraData
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
