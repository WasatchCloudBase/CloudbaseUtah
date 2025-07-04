import SwiftUI
import Combine

struct Site: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    var area: String
    var siteName: String
    var readingsNote: String
    var forecastNote: String
    var siteType: String
    var readingsAlt: String
    var readingsSource: String
    var readingsStation: String
    var pressureZoneReadingTime: String
    var siteLat: String
    var siteLon: String
    var sheetRow: Int // New property to store the row index
}

struct SitesResponse: Codable {
    let values: [[String]]
}

class SiteViewModel: ObservableObject {
    @Published var sites: [Site] = []
    private var cancellables = Set<AnyCancellable>()
    
    func getSites(completion: @escaping () -> Void) {
        let rangeName = "Sites"
        let sitesURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(googleApiKey)"
        guard let url = URL(string: sitesURLString) else {
            print("Invalid URL")
            DispatchQueue.main.async { completion() }
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: SitesResponse.self, decoder: JSONDecoder())
            .map { response in
                response.values.enumerated().compactMap { index, row -> Site? in
                    
                    // Skip the header row
                    guard index > 0 else { return nil }
                    
                    // Skip row if data missing
                    guard row.count >= 12 else { return nil }
                    
                    // Skip row not to be used in app (e.g., site is not active)
                    guard row[0] != "Yes" else { return nil }
                    
                    // Make sure coordinates are valid
                    let siteLat = row[10].trimmingCharacters(in: .whitespacesAndNewlines)
                    let siteLon = row[11].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let _ = Double(siteLat), let _ = Double(siteLon) else {
                        print("Skipping row with invalid coordinates: \(row[10]), \(row[11])")
                        return nil
                    }
                    
                    return Site(
                        area: row[1],
                        siteName: row[2],
                        readingsNote: row[3],
                        forecastNote: row[4],
                        siteType: row[5],
                        readingsAlt: row[6],
                        readingsSource: row[7],
                        readingsStation: row[8],
                        pressureZoneReadingTime: row[9],
                        siteLat: siteLat,
                        siteLon: siteLon,
                        sheetRow: index + 1 // Store the source row index and add one (Google sheets start at 1, not 0)
                    )
                }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { [weak self] sites in
                self?.sites = sites
            }, receiveCompletion: { _ in
                completion()
            })
            .sink { _ in }
            .store(in: &cancellables)
    }
}
