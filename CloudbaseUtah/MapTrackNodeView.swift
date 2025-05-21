import SwiftUI
import MapKit
import Combine
import Foundation

// Structure to process API call to elevation for a set of coordinates
struct ElevationResponse: Codable {
    let elevation: [Double]
}

// Display selected pilot live track node details
struct PilotTrackNodeView: View {
    @EnvironmentObject var pilotsViewModel: PilotsViewModel
    @EnvironmentObject var pilotTracksViewModel: PilotTracksViewModel
    @Environment(\.presentationMode) var presentationMode
    var pilotTrack: PilotTracks
    @State private var groundElevation: Int? = 0
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {

        let colWidth: CGFloat = 140
        let rowVerticalPadding: CGFloat = 4
        let (flightStartDateTime, flightLatestDateTime, formattedFlightDuration, flightDistance) = getPilotTrackInfo(pilotTrack: pilotTrack)
        var trackingShareURL: String { pilotsViewModel.trackingShareURL(for: pilotTrack.pilotName) ?? "" }
        var formattedNodeDate: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yyyy"
            return formatter.string(from: pilotTrack.dateTime)
        }
        var formattedNodeTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a" // 12-hour format with AM/PM
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
            .padding(0)
            
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
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                                .frame(width: colWidth, alignment: .trailing)
                            Text(formattedNodeDate)
                                .font(.subheadline)
                                .padding(.leading, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)
                        
                        HStack {
                            Text("Time")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                                .frame(width: colWidth, alignment: .trailing)
                            Text(formattedNodeTime)
                                .font(.subheadline)
                                .padding(.leading, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)
                        
                        HStack {
                            Text("Coordinates")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                                .frame(width: colWidth, alignment: .trailing)
                            Text("\(pilotTrack.coordinates.latitude), \(pilotTrack.coordinates.longitude)")
                                .font(.subheadline)
                                .padding(.leading, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)
                        
                        HStack {
                            Text("Speed")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                                .frame(width: colWidth, alignment: .trailing)
                            Text("\(Int(pilotTrack.speed.rounded())) mph")
                                .font(.subheadline)
                                .padding(.leading, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)
                        
                        HStack {
                            Text("Altitude")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                                .frame(width: colWidth, alignment: .trailing)
                            Text("\(Int(pilotTrack.altitude)) ft")
                                .font(.subheadline)
                                .padding(.leading, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, rowVerticalPadding)
                        
                        if let groundElevation = groundElevation {
                            HStack {
                                Text("Surface")
                                    .multilineTextAlignment(.trailing)
                                    .font(.subheadline)
                                    .padding(.trailing, 2)
                                    .foregroundColor(infoFontColor)
                                    .frame(width: colWidth, alignment: .trailing)
                                Text("\(groundElevation) ft")
                                    .font(.subheadline)
                                    .padding(.leading, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, rowVerticalPadding)
                            
                            HStack {
                                Text("Height")
                                    .multilineTextAlignment(.trailing)
                                    .font(.subheadline)
                                    .padding(.trailing, 2)
                                    .foregroundColor(infoFontColor)
                                    .frame(width: colWidth, alignment: .trailing)
                                Text("\(Int(pilotTrack.altitude) - groundElevation) ft")
                                    .font(.subheadline)
                                    .padding(.leading, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, rowVerticalPadding)
                        }
                        
                        if let message = pilotTrack.message, !message.isEmpty {
                            HStack {
                                Text("Message")
                                    .multilineTextAlignment(.trailing)
                                    .font(.subheadline)
                                    .padding(.trailing, 2)
                                    .foregroundColor(infoFontColor)
                                    .frame(width: colWidth, alignment: .trailing)
                                Text(message)
                                    .font(.subheadline)
                                    .padding(.leading, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, rowVerticalPadding)
                        }
                        
                    }
                }
                
                Section(header: Text("Track")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    VStack(alignment: .leading, spacing: 0) {
                        
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
                            Text("Latest")
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
                            Text("Distance")
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .padding(.trailing, 2)
                                .foregroundColor(infoFontColor)
                                .frame(width: colWidth, alignment: .trailing)
                            Text("\(Int(flightDistance)) km")
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
                        UIPasteboard.general.string = "\(pilotTrack.coordinates.latitude),\(pilotTrack.coordinates.longitude)"
                    }) {
                        Text("Copy coordinates to clipboard")
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    Button(action: openGoogleMaps) {
                        Text("Open track point in Google Maps")
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    Button(action: openAppleMaps) {
                        Text("Open track point in Apple Maps")
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                }
            }
            .padding(0)
            .onAppear {
                fetchGroundElevation(latitude: pilotTrack.coordinates.latitude, longitude: pilotTrack.coordinates.longitude)
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
    
    private func getPilotTrackInfo(pilotTrack: PilotTracks) -> (
        flightStartDateTime: Date,
        flightLatestDateTime: Date,
        formattedFlightDuration: String,
        flightDistance: CLLocationDistance
    ) {
        // Get the oldest and newest tracks for the same pilot and the same date
        let calendar = Calendar.current
        let targetDate = pilotTrack.dateTime
        let sameDayTracks = pilotTracksViewModel.pilotTracks
            .filter {
                $0.pilotName == pilotTrack.pilotName &&
                calendar.isDate($0.dateTime, inSameDayAs: targetDate)
            }
        guard let oldestTrack = sameDayTracks.min(by: { $0.dateTime < $1.dateTime }) else {
            return (Date(), Date(), "", 0)
        }
        guard let latestTrack = sameDayTracks.max(by: { $0.dateTime < $1.dateTime }) else {
            return (Date(), Date(), "", 0)
        }

        let flightStartDateTime = oldestTrack.dateTime
        let flightLatestDateTime = latestTrack.dateTime
        let flightDuration = Int(flightLatestDateTime.timeIntervalSince(flightStartDateTime))
        let flightHours = flightDuration / 3600
        let flightMinutes = (flightDuration % 3600) / 60
        let formattedFlightDuration = String(format: "%d:%02d", flightHours, flightMinutes)
        let startCoordinates = CLLocation(latitude: oldestTrack.coordinates.latitude, longitude: oldestTrack.coordinates.longitude)
        let latestCoordinates = CLLocation(latitude: latestTrack.coordinates.latitude, longitude: latestTrack.coordinates.longitude)
        let flightDistance = startCoordinates.distance(from: latestCoordinates) / 1000  // convert m to km

        return (flightStartDateTime, flightLatestDateTime, formattedFlightDuration, flightDistance)
    }
    
    private func openGoogleMaps() {
        let latitude = pilotTrack.coordinates.latitude
        let longitude = pilotTrack.coordinates.longitude
        if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(latitude),\(longitude)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openAppleMaps() {
        let latitude = pilotTrack.coordinates.latitude
        let longitude = pilotTrack.coordinates.longitude
        if let url = URL(string: "https://maps.apple.com/?q=Track&ll=\(latitude),\(longitude)") {
            UIApplication.shared.open(url)
        }
    }
}
