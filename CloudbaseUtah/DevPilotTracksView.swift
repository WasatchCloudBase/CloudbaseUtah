import SwiftUI
import Foundation

// Developer view to check on pilot live tracks being created
struct PilotTrackView: View {
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @EnvironmentObject var pilotTrackViewModel: PilotTrackViewModel
    
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
                                        Spacer()
                                        // maybe show how many points?
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
            .sheet(item: $selectedPilotTrack) { track in
                PilotTrackNodeView(originalPilotTrack: track)
            }
        }
    }
}
