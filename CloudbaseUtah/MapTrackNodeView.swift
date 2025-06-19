import SwiftUI
import MapKit
import Combine
import Foundation

// Structure to process API call to elevation for a set of coordinates
struct ElevationResponse: Codable {
    let elevation: [Double]
}

struct PilotTrackNodeView: View {
    @EnvironmentObject var pilotsViewModel: PilotsViewModel
    @EnvironmentObject var pilotTracksViewModel: PilotTracksViewModel
    @Environment(\.presentationMode) var presentationMode

    let originalPilotTrack: PilotTracks
    
    @State private var groundElevation: Int? = 0
    @State private var cancellables = Set<AnyCancellable>()
    @State private var currentTrackIndex: Int = 0

    // Set a live timer to track time elapsed since the last track update
    @State private var now = Date()
    private let timer = Timer
        .publish(every: 1, on: .main, in: .common)
        .autoconnect()
    
    var body: some View {
        let colWidth: CGFloat = 140
        let rowVerticalPadding: CGFloat = 4

        let calendar = Calendar.current
        let sameDayTracks = pilotTracksViewModel.pilotTracks
            .filter { $0.pilotName == originalPilotTrack.pilotName && calendar.isDate($0.dateTime, inSameDayAs: originalPilotTrack.dateTime) }
            .sorted { $0.dateTime < $1.dateTime }

        let pilotTrack = sameDayTracks[safe: currentTrackIndex] ?? originalPilotTrack

        let (flightStartDateTime, flightLatestDateTime, formattedFlightDuration, startToEndDistance, maxAltitude, totalDistance) = getPilotTrackInfo(pilotTrack: pilotTrack)
        var trackingShareURL: String { pilotsViewModel.trackingShareURL(for: pilotTrack.pilotName) ?? "" }

        var formattedNodeDate: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yyyy"
            return formatter.string(from: pilotTrack.dateTime)
        }

        var formattedNodeTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: pilotTrack.dateTime)
        }
        
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
                        Text(pilotTrack.pilotName)
                            .foregroundColor(sectionHeaderColor)
                            .bold()
                    }
                }
                .padding()
                Spacer()
            }
            .background(toolbarBackgroundColor)

            HStack { //Arrows for navigating track nodes
                Button(action: {
                    currentTrackIndex -= 1
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(toolbarActiveImageColor)
                        Text("Back")
                            .foregroundColor(toolbarActiveFontColor)
                    }
                    .padding(.horizontal, 8)
                }
                .id("backButton")
                // Hide and disable the button when it's not applicable
                .opacity(currentTrackIndex > 0 ? 1.0 : 0.0)
                .disabled(currentTrackIndex == 0)

                Spacer()
                
                Text("Track Points")
                
                Spacer()

                Button(action: {
                    currentTrackIndex += 1
                }) {
                    HStack {
                        Text("Next")
                            .foregroundColor(toolbarActiveFontColor)
                        Image(systemName: "chevron.right")
                            .foregroundColor(toolbarActiveImageColor)
                    }
                    .padding(.horizontal, 8)
                }
                .id("nextButton")
                // Hide and disable the button when it's not applicable
                .opacity(currentTrackIndex < sameDayTracks.count - 1 ? 1.0 : 0.0)
                .disabled(currentTrackIndex >= sameDayTracks.count - 1)
            }
            .padding()
            .background(navigationBackgroundColor)
            
            List {
                if pilotTrack.inEmergency {
                    Section(header: Text("Emergency Status")
                        .font(.headline)
                        .foregroundColor(sectionHeaderColor)
                        .bold())
                    {
                        Text("InReach is in emergency status; track points not provided (except to emergency services)")
                            .foregroundColor(warningFontColor)
                            .bold()
                            .padding(.vertical, rowVerticalPadding)
                    }
                }

                Section(header: Text("Track point")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    VStack(alignment: .leading, spacing: 0) {

                        HStack {
                            Text("Date")
                                .frame(width: colWidth, alignment: .trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                            Text(formattedNodeDate)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)

                        HStack {
                            Text("Time")
                                .frame(width: colWidth, alignment: .trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                            Text(formattedNodeTime)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)

                        HStack {
                            Text("Coordinates")
                                .frame(width: colWidth, alignment: .trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                            Text("\(pilotTrack.latitude), \(pilotTrack.longitude)")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)

                        HStack {
                            Text("Speed")
                                .frame(width: colWidth, alignment: .trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                            Text("\(Int(pilotTrack.speed.rounded())) mph")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)

                        HStack {
                            Text("Altitude")
                                .frame(width: colWidth, alignment: .trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                            Text("\(Int(pilotTrack.altitude)) ft")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)

                        if let groundElevation = groundElevation {
                            HStack {
                                Text("Surface")
                                    .frame(width: colWidth, alignment: .trailing)
                                    .font(.subheadline)
                                    .padding(.trailing, 2)
                                    .foregroundColor(infoFontColor)
                                Text("\(groundElevation) ft")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, rowVerticalPadding)

                            HStack {
                                Text("Height")
                                    .frame(width: colWidth, alignment: .trailing)
                                    .font(.subheadline)
                                    .padding(.trailing, 2)
                                    .foregroundColor(infoFontColor)
                                Text("\(Int(pilotTrack.altitude) - groundElevation) ft")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, rowVerticalPadding)
                        }

                        if let message = pilotTrack.message, !message.isEmpty {
                            HStack {
                                Text("Message")
                                    .frame(width: colWidth, alignment: .trailing)
                                    .font(.subheadline)
                                    .padding(.trailing, 2)
                                    .foregroundColor(infoFontColor)
                                Text(message)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, rowVerticalPadding)
                        }
                    }
                }
                
                Section(header: Text("Track")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold()
                    .onReceive(timer) { now = $0 })  // Track current time to calculate elapsed time since track update
                {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        HStack {
                            Text("Track last updated")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                                .frame(width: colWidth, alignment: .trailing)
                            
                            // calculate time interval
                            let interval = now.timeIntervalSince(flightLatestDateTime)
                            let days = Int(interval) / 86_400
                            let hours = (Int(interval) % 86_400) / 3_600
                            let minutes = (Int(interval) % 3_600) / 60
                            let seconds = Int(interval) % 60
                            
                            if days > 0 {
                                Text("\(days) d \(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, rowVerticalPadding)
                        
                        HStack {
                            Text("Start")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                                .frame(width: colWidth, alignment: .trailing)
                            Text(flightStartDateTime.formatted())
                                .font(.subheadline)
                                .padding(.leading, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)
                        
                        HStack {
                            Text("End")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                                .frame(width: colWidth, alignment: .trailing)
                            Text(flightLatestDateTime.formatted())
                                .font(.subheadline)
                                .padding(.leading, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)
                        
                        HStack {
                            Text("Duration")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                                .frame(width: colWidth, alignment: .trailing)
                            Text("\(formattedFlightDuration)")
                                .font(.subheadline)
                                .padding(.leading, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)
                        
                        HStack {
                            Text("Max altitude")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                                .frame(width: colWidth, alignment: .trailing)
                            Text("\(Int(maxAltitude)) ft")
                                .font(.subheadline)
                                .padding(.leading, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)

                        HStack {
                            Text("Distance flown")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                                .frame(width: colWidth, alignment: .trailing)
                            Text("\(Int(totalDistance)) km")
                                .font(.subheadline)
                                .padding(.leading, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)

                        HStack {
                            Text("Start to end")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                                .frame(width: colWidth, alignment: .trailing)
                            Text("\(Int(startToEndDistance)) km")
                                .font(.subheadline)
                                .padding(.leading, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)
                    }
                }
                
                Section(header: Text("Links")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {

                    Button(action: {
                        if let url = URL(string: trackingShareURL) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("InReach share page")
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    Button(action: {
                        UIPasteboard.general.string = "\(pilotTrack.latitude),\(pilotTrack.longitude)"
                    }) {
                        Text("Copy coordinates to clipboard")
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    Button(action: {
                        openGoogleMaps(latitude: pilotTrack.latitude, longitude: pilotTrack.longitude)
                    }) {
                        Text("Open track point in Google Maps")
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    Button(action: {
                        openAppleMaps(latitude: pilotTrack.latitude, longitude: pilotTrack.longitude)
                    }) {
                        Text("Open track point in Apple Maps")
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                }
            }
            .padding(0)
            
            .onAppear {
                if let index = sameDayTracks.firstIndex(where: { $0.id == originalPilotTrack.id }) {
                    currentTrackIndex = index // Match initial view to correct track
                }
                fetchGroundElevation(latitude: pilotTrack.latitude, longitude: pilotTrack.longitude)
            }
        }
        Spacer()
    }
    
    private func fetchGroundElevation(latitude: Double, longitude: Double) {
        let urlString = "https://api.open-meteo.com/v1/elevation?latitude=\(latitude)&longitude=\(longitude)"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: ElevationResponse.self, decoder: JSONDecoder())
            .map { $0.elevation.first }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { elevation in
                self.groundElevation = convertMetersToFeet(elevation ?? 0)
            }
            .store(in: &cancellables)
    }
    
    private func getPilotTrackInfo(pilotTrack: PilotTracks) -> (flightStartDateTime: Date, flightLatestDateTime: Date, formattedFlightDuration: String, startToEndDistance: CLLocationDistance, maxAltitude: Double, totalDistance: CLLocationDistance) {
        // Get the oldest and newest tracks for the same pilot and the same date
        let calendar = Calendar.current
        let targetDate = pilotTrack.dateTime
        let sameDayTracks = pilotTracksViewModel.pilotTracks
            .filter { $0.pilotName == pilotTrack.pilotName && calendar.isDate($0.dateTime, inSameDayAs: targetDate) }

        guard let oldestTrack = sameDayTracks.min(by: { $0.dateTime < $1.dateTime }) else {
            return (Date(), Date(), "", 0, 0, 0)
        }
        guard let latestTrack = sameDayTracks.max(by: { $0.dateTime < $1.dateTime }) else {
            return (Date(), Date(), "", 0, 0, 0)
        }

        let flightStartDateTime = oldestTrack.dateTime
        let flightLatestDateTime = latestTrack.dateTime
        let flightDuration = Int(flightLatestDateTime.timeIntervalSince(flightStartDateTime))
        let flightHours = flightDuration / 3600
        let flightMinutes = (flightDuration % 3600) / 60
        let formattedFlightDuration = String(format: "%d:%02d", flightHours, flightMinutes)
        
        // Calculate start to end distance
        let startCoordinates = CLLocation(latitude: oldestTrack.latitude, longitude: oldestTrack.longitude)
        let latestCoordinates = CLLocation(latitude: latestTrack.latitude, longitude: latestTrack.longitude)
        let startToEndDistance = startCoordinates.distance(from: latestCoordinates) / 1000  // convert m to km

        // Calculate maximum altitude
        let maxAltitude = sameDayTracks.map { $0.altitude }.max() ?? 0.0

        // Calculate total distance flown
        var totalDistance: CLLocationDistance = 0
        for (index, track) in sameDayTracks.enumerated() {
            if index > 0 {
                let previousTrack = sameDayTracks[index - 1]
                let previousCoordinates = CLLocation(latitude: previousTrack.latitude, longitude: previousTrack.longitude)
                let currentCoordinates = CLLocation(latitude: track.latitude, longitude: track.longitude)
                totalDistance += previousCoordinates.distance(from: currentCoordinates)
            }
        }
        totalDistance = totalDistance / 1000 // Convert meters to kilometers

        return (flightStartDateTime, flightLatestDateTime, formattedFlightDuration, startToEndDistance, maxAltitude, totalDistance)
    }
    
    private func openGoogleMaps(latitude: Double, longitude: Double) {
        if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(latitude),\(longitude)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openAppleMaps(latitude: Double, longitude: Double) {
        if let url = URL(string: "https://maps.apple.com/?q=Track&ll=\(latitude),\(longitude)") {
            UIApplication.shared.open(url)
        }
    }
}

