import SwiftUI
import Combine

// Get pilots for live tracking
struct Pilots: Codable, Identifiable, Equatable {
    var id = UUID()
    var pilotName: String
    var trackingShareURL: String
    var trackingFeedURL: String
}

struct PilotsResponse: Codable {
    let values: [[String]]
}

class PilotsViewModel: ObservableObject {
    @Published var pilots: [Pilots] = []
    private var cancellables = Set<AnyCancellable>()
    
    func getPilots(completion: @escaping () -> Void) {
        let rangeName = "Pilots"
        let sitesURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(googleApiKey)"
        guard let url = URL(string: sitesURLString) else {
            print("Invalid URL")
            DispatchQueue.main.async { completion() }
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: PilotsResponse.self, decoder: JSONDecoder())
            .map { response in
                response.values.dropFirst().compactMap { row -> Pilots? in
                    // Skip row if data missing
                    guard row.count >= 2 else {
                        print("Skipping malformed pilot row: \(row)")
                        return nil
                    }
                    
                    let pilotName = row[0]
                    let trackingShareURL = row[1]
                    
                    // Check for a valid share URL format
                    guard trackingShareURL.contains("https://share.garmin.com/") else {
                        print("Skipping malformed InReach share URL for row: \(row)")
                        return nil
                    }
                    
                    // Extract pilot name from the share URL
                    let pilotNameFromURL = trackingShareURL.components(separatedBy: "/").last ?? ""
                    let trackingFeedURL = "https://share.garmin.com/Feed/Share/\(pilotNameFromURL)"
                    
                    return Pilots(
                        pilotName: pilotName,
                        trackingShareURL: trackingShareURL,
                        trackingFeedURL: trackingFeedURL
                    )
                }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { [weak self] pilots in
                self?.pilots = pilots
            }, receiveCompletion: { _ in
                completion()
            })
            .sink { _ in }
            .store(in: &cancellables)
    }
    
    func trackingShareURL(for pilotName: String) -> String? {
        return pilots.first(where: { $0.pilotName == pilotName })?.trackingShareURL
    }
}
