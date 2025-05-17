import Foundation
import Combine
import SwiftUI

// Pilot live tracking structure
struct PilotTracks: Identifiable {
    let id: UUID = UUID()
    // Data duplicated for each track point
    let pilotName: String
    let oldestDateTime: Date
    let oldestCoordinates: (latitude: Double, longitude: Double)
    let flightDuration: TimeInterval
    // Data specific to each track point
    let dateTime: Date
    let coordinates: (latitude: Double, longitude: Double)
    let speed: Double
    let altitude: Double
    let heading: Double
    let inEmergency: Bool
}

// Used to identify discrete live track points, and not create duplicates
struct PilotTrackKey: Hashable {
    let pilotName: String
    let dateTime: Date
}

class PilotTracksViewModel: ObservableObject {
    @Published var pilotTracks: [PilotTracks] = []
    
    func fetchTrackingData(trackingURL: String) {
        guard let url = constructURL(trackingURL: trackingURL) else { return }
        var request = URLRequest(url: url)

        // Set headers to handle InReach requirements and redirect to data file location
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("1", forHTTPHeaderField: "DNT")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("none", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        request.setValue("\"Chromium\";v=\"136\", \"Google Chrome\";v=\"136\", \"Not.A/Brand\";v=\"99\"", forHTTPHeaderField: "sec-ch-ua")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")

        // Query InReach KML feed
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else { return }
            DispatchQueue.main.async {
                let newTracks = self.parseKML(data: data)
                // Check if track node already exists for pilot and time stamp; if so, don't append
                let existingKeys: Set<PilotTrackKey> = Set(self.pilotTracks.map { PilotTrackKey(pilotName: $0.pilotName, dateTime: $0.dateTime) })
                let uniqueNewTracks = newTracks.filter { !existingKeys.contains(PilotTrackKey(pilotName: $0.pilotName, dateTime: $0.dateTime)) }
                self.pilotTracks.append(contentsOf: uniqueNewTracks)
            }
        }
        task.resume()
    }

    private func constructURL(trackingURL: String) -> URL? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        let date24HoursAgo = Date().addingTimeInterval(TimeInterval(-24 * pilotTrackDays * 60 * 60))        
        let dateString = dateFormatter.string(from: date24HoursAgo)
        let finalURLString = "\(trackingURL)?d1=\(dateString)"
        return URL(string: finalURLString)
    }
    
    private func parseKML(data: Data) -> [PilotTracks] {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            print("Invalid XML coding for track log")
            return []
        }

        let placemarkStrings = extractAllValues(from: xmlString, using: "<Placemark>", endTag: "</Placemark>")
        guard !placemarkStrings.isEmpty else {
            return []
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy h:mm:ss a"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // First pass: Find oldest/newest date and coordinates, and pilot name
        var oldestDateTime: Date?
        var oldestCoordinates: (latitude: Double, longitude: Double)?
        var pilotName: String?

        var placemarkData: [(placemarkString: String, dateTime: Date?, latitude: Double?, longitude: Double?)] = []

        for placemarkString in placemarkStrings {
            // Capture pilot name on first occurrence
            if pilotName == nil {
                pilotName = extractValue(from: placemarkString, using: "<Data name=\"Name\">", endTag: "</Data>")
            }

            let dateTimeString = extractValue(from: placemarkString, using: "<Data name=\"Time\">", endTag: "</Data>")
            let dateTime = formatter.date(from: dateTimeString ?? "")

            let latitudeString = extractValue(from: placemarkString, using: "<Data name=\"Latitude\">", endTag: "</Data>")
            let longitudeString = extractValue(from: placemarkString, using: "<Data name=\"Longitude\">", endTag: "</Data>")
            let latitude = latitudeString.flatMap(Double.init)
            let longitude = longitudeString.flatMap(Double.init)

            placemarkData.append((placemarkString, dateTime, latitude, longitude))

            // Update oldest date/time and coordinates for this flight
            if let dt = dateTime, let lat = latitude, let lon = longitude {
                if oldestDateTime == nil || dt < oldestDateTime! {
                    oldestDateTime = dt
                    oldestCoordinates = (lat, lon)
                }
            }
        }

        // Use a fallback if pilot name was never found
        let finalPilotName = pilotName ?? "Unknown Pilot"

        // Second pass: Build PilotTracks using the global oldest/newest values and pilotName
        var pilotTracks: [PilotTracks] = []
        for (placemarkString, dateTime, latitude, longitude) in placemarkData {
            guard let dateTime = dateTime,
                  let latitude = latitude,
                  let longitude = longitude,
                  let speedString = extractValue(from: placemarkString, using: "<Data name=\"Velocity\">", endTag: "</Data>"),
                  let speed = extractNumber(from: speedString),
                  let altitudeString = extractValue(from: placemarkString, using: "<Data name=\"Elevation\">", endTag: "</Data>"),
                  let altitude = extractNumber(from: altitudeString),
                  let inEmergencyString = extractValue(from: placemarkString, using: "<Data name=\"In Emergency\">", endTag: "</Data>"),
                  let courseString = extractValue(from: placemarkString, using: "<Data name=\"Course\">", endTag: "</Data>"),
                  let course = extractNumber(from: courseString),
                  let inEmergency = Bool(inEmergencyString.lowercased()),
                  let oldestDateTime = oldestDateTime,
                  let oldestCoordinates = oldestCoordinates
            else {
                // ignore placemark entries that failed parsing (likely did not have a valid dateTime)
                continue
            }

            let speedMph = convertKMToMiles(speed).rounded()
            let altitudeFeet = Double(convertMetersToFeet(altitude))

            let trackPoint = PilotTracks(
                pilotName: finalPilotName,
                oldestDateTime: oldestDateTime,
                oldestCoordinates: oldestCoordinates,
                flightDuration: dateTime.timeIntervalSince(oldestDateTime),
                dateTime: dateTime,
                coordinates: (latitude, longitude),
                speed: speedMph,
                altitude: altitudeFeet,
                heading: course,
                inEmergency: inEmergency
            )
            pilotTracks.append(trackPoint)
        }
        return pilotTracks
    }
    
    private func extractAllValues(from text: String, using startTag: String, endTag: String) -> [String] {
        var values: [String] = []
        var searchRange: Range<String.Index>?
        while let startRange = text.range(of: startTag, options: [], range: searchRange),
              let endRange = text.range(of: endTag, options: [], range: startRange.upperBound..<text.endIndex) {
            let value = String(text[startRange.upperBound..<endRange.lowerBound])
            values.append(value)
            searchRange = endRange.upperBound..<text.endIndex
        }
        return values
    }
    
    private func extractValue(from text: String, using startTag: String, endTag: String) -> String? {
        
        // Get string within tag
        guard let startRange = text.range(of: startTag),
              let endRange = text.range(of: endTag, options: [], range: startRange.upperBound..<text.endIndex) else {
            //print("range lookup failed for startTag: \(startTag), endTag: \(endTag)")
            return nil
        }
        let tagString = String(text[startRange.upperBound..<endRange.lowerBound])

        // The string is in the format <value>xxx</value>
        // Only return the section between the value tags
        guard let startRange = tagString.range(of: "<value>"),
              let endRange = tagString.range(of: "</value>", options: [], range: startRange.upperBound..<tagString.endIndex) else {
            //print("value range lookup failed for startTag: \(startTag), endTag: \(endTag)")
            return nil
        }
        let valueString = String(tagString[startRange.upperBound..<endRange.lowerBound])
        
        return valueString
    }
}

// Developer view to check on pilot live track nodes being created
struct PilotTracksView: View {
    @EnvironmentObject var pilotsViewModel: PilotsViewModel
    @ObservedObject var pilotTracksViewModel: PilotTracksViewModel
    @State private var hasFetched = false

    var body: some View {
        VStack {
            if pilotTracksViewModel.pilotTracks.isEmpty {
                Text("No pilot track data loaded.")
            } else {
                List(pilotTracksViewModel.pilotTracks, id: \.dateTime) { track in
                    VStack(alignment: .leading) {
                        Text("Pilot: \(track.pilotName)")
                            .font(.headline)
                        Text("Track start time: \(track.oldestDateTime.formatted())")
                        Text("Time: \(track.dateTime.formatted())")
                        Text("Coordinates: \(track.coordinates.latitude), \(track.coordinates.longitude)")
                        Text("Speed: \(track.speed)")
                        Text("Altitude: \(track.altitude)")
                        Text("In Emergency: \(track.inEmergency ? "Yes" : "No")")
                    }
                }
            }
        }
        .onAppear {
            guard !hasFetched else { return }
            hasFetched = true
            for pilot in pilotsViewModel.pilots {
                pilotTracksViewModel.fetchTrackingData(trackingURL: pilot.trackingFeedURL)
            }
        }
    }
}
