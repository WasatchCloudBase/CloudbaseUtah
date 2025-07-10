import SwiftUI
import Foundation

// Developer view to troubleshoot pilot live tracks
struct DevPilotTracksView: View {
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @EnvironmentObject var pilotTrackViewModel: PilotTrackViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    
    // for driving the sheet
    @State private var selectedPilotTrack: PilotTrack?

    // formatters
    private let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()
    private let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()

    var body: some View {
        NavigationView {
                
            List {
                
                Text("Note: Pilots tracks are filtered based user map settings")
                    .font(.caption)
                
                if pilotTrackViewModel.isLoading {
                    HStack(spacing: 8) {
                        Spacer()
                        Text("Loading pilot tracks")
                            .font(.subheadline)
                            .foregroundStyle(loadingBarTextColor)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.75)
                            .padding(.horizontal, 8)
                    }
                    .padding(.vertical, 4)
                    
                } else {
                    
                    ForEach(pilotViewModel.pilots) { pilot in
                        
                        // Filter tracks by pilot
                        let tracksForPilot = pilotTrackViewModel.pilotTracks
                            .filter { $0.pilotName == pilot.pilotName }
                        
                        // Group tracks by date
                        let tracksByDay = Dictionary(
                            grouping: tracksForPilot,
                            by: { Calendar.current.startOfDay(for: $0.dateTime) }
                        )
                        
                        // Only show a pilot if there are any tracks
                        if !tracksByDay.isEmpty {
                            Section(header: Text(pilot.pilotName)) {
                                // sort the days descending, for example
                                ForEach(
                                    tracksByDay.keys.sorted(by: >),
                                    id: \.self
                                ) { day in
                                    Button {
                                        // Choose the first track point of that day
                                        selectedPilotTrack = tracksByDay[day]?.first
                                    } label: {
                                        HStack {
                                            Text(dayFormatter.string(from: day))
                                                .font(.subheadline)
                                            Spacer()
                                            Text("(\(tracksByDay[day]?.count ?? 0) pts)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            .onAppear {
                DispatchQueue.main.async {
                    pilotTrackViewModel.getPilotTracks(days: userSettingsViewModel.pilotTrackDays,
                                                       selectedPilots: userSettingsViewModel.selectedPilots) {}
                }
            }
            
            .sheet(item: $selectedPilotTrack) { track in
                PilotTrackNodeView(originalPilotTrack: track)
            }
        }
    }
}
