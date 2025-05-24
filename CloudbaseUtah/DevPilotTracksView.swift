import SwiftUI
import Foundation

// Developer view to check on pilot live track nodes being created
struct PilotTracksView: View {
    @EnvironmentObject var pilotsViewModel: PilotsViewModel
    @ObservedObject var pilotTracksViewModel: PilotTracksViewModel
    let pilotTrackDays: Double
    @State private var hasFetched = false
    
    var body: some View {
        VStack {
            if pilotTracksViewModel.pilotTracks.isEmpty {
                Text("No pilot track data loaded.")
            } else {
                List(pilotTracksViewModel.pilotTracks, id: \.dateTime) { track in
                    
                    var trackingShareURL: String { pilotsViewModel.trackingShareURL(for: track.pilotName) ?? "" }
                    
                    VStack(alignment: .leading) {
                        Text("Pilot: \(track.pilotName)")
                            .font(.subheadline)
                            .bold()
                        Text("Time: \(track.dateTime.formatted())")
                            .font(.caption)
                        Text("Coordinates: \(track.coordinates.latitude), \(track.coordinates.longitude)")
                            .font(.caption)
                        Text("Speed: \(track.speed)")
                            .font(.caption)
                        Text("Altitude: \(track.altitude)")
                            .font(.caption)
                        if track.message != nil {
                            Text("Message: \(track.message ?? "")")
                                .font(.caption)
                        }
                        if track.inEmergency {
                            Text("InReach is in emergency status; track points not provided (except to emergency services)")
                                .font(.subheadline)
                                .foregroundColor(warningFontColor)
                                .bold()
                        }
                        Button(action: {
                            if let url = URL(string: trackingShareURL) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("InReach share page")
                                .font(.caption)
                                .foregroundColor(rowHeaderColor)
                        }
                    }
                }
            }
        }
        .onAppear {
            guard !hasFetched else { return }
            hasFetched = true
            for pilot in pilotsViewModel.pilots {
                pilotTracksViewModel.getPilotTrackingData(pilotName: pilot.pilotName, trackingURL: pilot.trackingFeedURL, days: pilotTrackDays) {}
            }
        }
    }
}
