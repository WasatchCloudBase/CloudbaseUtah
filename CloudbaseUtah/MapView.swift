import SwiftUI
import MapKit
import Combine
import SDWebImage
import SDWebImageSwiftUI


struct MapView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude),
        span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 6.0)
    )
    @State private var selectedCamera: CameraData?
    @State private var lastRegionSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0, longitudeDelta: 0)

    var body: some View {
        NavigationView {
            Map(coordinateRegion: $region)
            .onAppear {
                startMonitoringRegion()
            }
        }
    }

    private func startMonitoringRegion() {
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            let currentSpan = region.span
            if hasRegionSpanChanged(from: lastRegionSpan, to: currentSpan) {
                lastRegionSpan = currentSpan
            }
        }
    }

    private func hasRegionSpanChanged(from oldSpan: MKCoordinateSpan, to newSpan: MKCoordinateSpan) -> Bool {
        let tolerance: Double = 0.01
        return abs(oldSpan.latitudeDelta - newSpan.latitudeDelta) > tolerance ||
            abs(oldSpan.longitudeDelta - newSpan.longitudeDelta) > tolerance
    }
}
