import SwiftUI
import Foundation
import SwiftUI
import UIKit   // needed for UIPasteboard

struct DevInactivePilotsView: View {
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @EnvironmentObject var pilotTrackViewModel: PilotTrackViewModel

    // Pilots with no tracks in the past year are considered inactive
    let daysToBecomeInactive: Double = 365.0

    private var loadingBarTextColor: Color { .secondary }
    
    var body: some View {
        NavigationView {
            List {
                if pilotTrackViewModel.isLoading {
                    loadingRow
                } else {
                    ForEach(pilotViewModel.pilots) { pilot in
                        PilotTrackInfoView(
                            pilot: pilot,
                            allTracks: pilotTrackViewModel.pilotTracks
                        )
                    }
                }
            }
            .onAppear(perform: loadAllPilotTracks)
            
        }
    }

    private func loadAllPilotTracks() {
        pilotTrackViewModel.getPilotTracks(
            days: daysToBecomeInactive,
            selectedPilots: []
        ) { }
    }

    private var loadingRow: some View {
        HStack(spacing: 8) {
            Spacer()
            Text("Loading pilot tracks")
                .font(.subheadline)
                .foregroundStyle(loadingBarTextColor)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.75)
                .padding(.horizontal, 8)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct PilotTrackInfoView: View {
    let pilot: Pilot
    let allTracks: [PilotTrack]
    @EnvironmentObject var pilotViewModel: PilotViewModel
    
    // Only this pilot’s tracks
    private var tracks: [PilotTrack] {
            allTracks.filter { $0.pilotName.lowercased() == pilot.pilotName.lowercased() }
    }

    // Date of the most recent track
    private var mostRecentDate: Date? {
        tracks.map(\.dateTime).max()
    }

    // Full days since that date
    private var daysAgo: Int {
        guard let date = mostRecentDate else { return 0 }
        return Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: date),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                
                // Pilot name
                Text(pilot.pilotName)
                
                if pilot.inactive {
                    Text("Currently inactive")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Button("Activate Pilot") {
                        pilotViewModel.setPilotActiveStatus(pilot: pilot, isInactive: false)
                        pilotViewModel.getPilots {}
                    }
                    .font(.caption)
                    .buttonStyle(BorderlessButtonStyle())
                }
                
            }

            // Share URL
            Text(pilot.trackingShareURL)
                .font(.caption)
                .foregroundColor(.secondary)
                .onTapGesture {
                    UIPasteboard.general.string = pilot.trackingFeedURL
                }

            // Active vs inactive
            if !pilot.inactive {
                if tracks.isEmpty {
                    HStack {
                        Text("No tracks found")
                            .foregroundColor(.yellow)
                            .foregroundColor(.orange)
                        Button("Deactivate Pilot") {
                            pilotViewModel.setPilotActiveStatus(pilot: pilot, isInactive: true)
                            pilotViewModel.getPilots {}
                        }
                        .font(.caption)
                        .buttonStyle(BorderlessButtonStyle())
                    }
                } else {
                    Text("Newest track is \(daysAgo) day\(daysAgo == 1 ? "" : "s") ago")
                }
            }
        }
        .padding(.vertical, 8)
    }
}
