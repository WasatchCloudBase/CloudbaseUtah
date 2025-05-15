import Foundation
import Combine
import SwiftUI

struct PilotTracksView: View {
    @StateObject private var viewModel = PilotTracksViewModel()
    @State private var trackingURL: String = "https://inreach.garmin.com/Feed/Share/billbelcourt"
    
    var body: some View {
        VStack {
            TextField("Enter tracking URL", text: $trackingURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button(action: {
                self.viewModel.fetchTrackingData(trackingURL: trackingURL)
            }) {
                Text("Fetch Pilot Tracks")
            }
            .padding()
            
            if viewModel.pilotTracks.isEmpty {
                Text("No pilot track data loaded.")
                    .foregroundColor(.secondary)
            } else {
                List(viewModel.pilotTracks, id: \.dateTime) { track in
                    VStack(alignment: .leading) {
                        Text("Pilot: \(track.pilotName)")
                            .font(.headline)
                        Text("Time: \(track.dateTime.formatted())")
                        Text("Coordinates: \(track.coordinates.latitude), \(track.coordinates.longitude)")
                        Text("Speed: \(track.speed, specifier: "%.1f")")
                        Text("Altitude: \(track.altitude, specifier: "%.1f")")
                        Text("In Emergency: \(track.inEmergency ? "Yes" : "No")")
                    }
                }
            }
        }
    }
}
