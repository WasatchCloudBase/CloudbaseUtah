import SwiftUI
import Combine
import MapKit

// Pilot live tracking structure
struct PilotTrack: Identifiable, Equatable, Hashable {
    let id: UUID = UUID()
    let pilotName: String
    let dateTime: Date
    let latitude: Double
    let longitude: Double
    let speed: Double
    let altitude: Double
    let heading: Double
    let inEmergency: Bool
    let message: String?
}

// Listing of pilot live tracks by pilot name and date
// used to determine track groupings for line rendering on track
struct PilotTrackKey: Hashable {
    let pilotName: String
    let date: Date
}

// Annotation for pilot tracks to allow polylines as an overlay on map
class PilotTrackAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let annotationType: String
    let pilotTrack: PilotTrack?

    let pilotName: String
    let isFirst: Bool
    let isLast: Bool
    let isEmergency: Bool
    let hasMessage: Bool

    init(coordinate: CLLocationCoordinate2D,
         title: String?,
         subtitle: String?,
         annotationType: String,
         pilotTrack: PilotTrack?,
         pilotName: String,
         isFirst: Bool,
         isLast: Bool,
         isEmergency: Bool,
         hasMessage: Bool
    ) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.annotationType = annotationType
        self.pilotTrack = pilotTrack
        self.pilotName = pilotName
        self.isFirst = isFirst
        self.isLast = isLast
        self.isEmergency = isEmergency
        self.hasMessage = hasMessage
    }
}

class PilotTrackViewModel: ObservableObject {
    @Published private(set) var pilotTracks: [PilotTrack] = []
    @Published var isLoading = false

    private let pilotViewModel: PilotViewModel
    private var cancellables = Set<AnyCancellable>()
    
    private var lastFetchTime: Date? = nil
    private var lastSelectedPilotsFetched: [Pilot]? = nil
    private var lastDaysFetched: Double = 0

    init(pilotViewModel: PilotViewModel) {
        self.pilotViewModel = pilotViewModel
        
        // Subscribe to any changes in the pilots array
        pilotViewModel.$pilots
            .sink { [weak self] newPilots in
                guard self != nil else { return }
            }
            .store(in: &cancellables)
    }
    
    func getPilotTracks(
        days: Double,
        selectedPilots: [Pilot],   // Only get selected pilots if user has selected in map settings view
        completion: @escaping () -> Void
    ) {
        // Determine which pilots to fetch
        let pilotsToFetch: [Pilot]
        if selectedPilots.isEmpty {
            pilotsToFetch = pilotViewModel.pilots
        } else {
            pilotsToFetch = selectedPilots
        }

        // Check last time pilot tracks were fetched;
        // If pilot list hasn't changed, don't re-fetch until interval has passed
        let now = Date()
        if let last = lastFetchTime,
           now.timeIntervalSince(last) < readingsRefreshInterval,
           lastSelectedPilotsFetched == pilotsToFetch,
           lastDaysFetched == days {
            completion()
            return
        }
        lastFetchTime = now
        lastSelectedPilotsFetched = pilotsToFetch
        lastDaysFetched = days

        
        DispatchQueue.main.async {
            self.isLoading = true
        }

        let group = DispatchGroup()
        var allResults = [PilotTrack]()

        for pilot in pilotsToFetch {
            group.enter()
            getTracksForPilot(for: pilot, days: days) { results in
                allResults.append(contentsOf: results)
                group.leave()
            }
        }

        group.notify(queue: .main) {
            // sort & publish
            self.pilotTracks = allResults
                .sorted { $0.dateTime < $1.dateTime }
            self.isLoading = false
            completion()
        }
    }

    private func getTracksForPilot (
        for pilot: Pilot,
        days: Double,
        completion: @escaping ([PilotTrack]) -> Void
    ) {
        guard let url = constructURL(trackingURL: pilot.trackingFeedURL,
                                     days: days) else {
            completion([])
            return
        }

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
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil else {
                print("Error in pilot track call for: \(url)")
                print(error as Any)
                completion([])
                return
            }

            let parsed = self?.parseKML(pilotName: pilot.pilotName,
                                        data: data) ?? []
            completion(parsed)
        }
        .resume()
    }

    private func constructURL(trackingURL: String, days: Double) -> URL? {
        let targetDate = getDateForDays(days: days)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        let dateString = dateFormatter.string(from: targetDate)
        let finalURLString = "\(trackingURL)?d1=\(dateString)"
        return URL(string: finalURLString)
    }

    private func parseKML(pilotName: String, data: Data) -> [PilotTrack] {
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
        formatter.timeZone = TimeZone(abbreviation: "UTC")      // All live track date/time are in UTC

        var pilotTracks: [PilotTrack] = []
        for placemarkString in placemarkStrings {
            guard var trackPilotName = extractValue(from: placemarkString, using: "<Data name=\"Name\">", endTag: "</Data>"),
                  let dateTimeString = extractValue(from: placemarkString, using: "<Data name=\"Time UTC\">", endTag: "</Data>"),
                  let latitudeString = extractValue(from: placemarkString, using: "<Data name=\"Latitude\">", endTag: "</Data>"),
                  let longitudeString = extractValue(from: placemarkString, using: "<Data name=\"Longitude\">", endTag: "</Data>")
            else {
                // ignore placemark entries that failed parsing (likely did not have a valid dateTime)
                continue
            }

            // Update name if track uses a different name
            if trackPilotName.lowercased() != pilotName.lowercased() {
                trackPilotName = "\(trackPilotName) (\(pilotName))"
            }
                
            // Format data for track point
            let dateTime = formatter.date(from: dateTimeString) ?? Date()
            let speedString = extractValue(from: placemarkString, using: "<Data name=\"Velocity\">", endTag: "</Data>") ?? ""
            let speed = extractNumber(from: speedString) ?? 0.0
            let speedMph = convertKMToMiles(speed).rounded()
            let altitudeString = extractValue(from: placemarkString, using: "<Data name=\"Elevation\">", endTag: "</Data>") ?? ""
            let altitude = extractNumber(from: altitudeString) ?? 0.0
            let altitudeFeet = Double(convertMetersToFeet(altitude))
            let latitude = Double(latitudeString) ?? 0.0
            let longitude = Double(longitudeString) ?? 0.0
            let courseString = extractValue(from: placemarkString, using: "<Data name=\"Course\">", endTag: "</Data>") ?? ""
            let course = extractNumber(from: courseString) ?? 0.0
            let inEmergencyString = extractValue(from: placemarkString, using: "<Data name=\"In Emergency\">", endTag: "</Data>")?.lowercased()
            let inEmergency = Bool(inEmergencyString ?? "false") ?? false
            let message = extractValue(from: placemarkString, using: "<Data name=\"Text\">", endTag: "</Data>") ?? ""
            let trackPoint = PilotTrack(
                pilotName: pilotName,
                dateTime: dateTime,
                latitude: latitude,
                longitude: longitude,
                speed: speedMph,
                altitude: altitudeFeet,
                heading: course,
                inEmergency: inEmergency,
                message: message
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

