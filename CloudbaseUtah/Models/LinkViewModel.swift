import SwiftUI
import Combine


struct LinkGoogleSheetResponse: Codable {
    let range: String
    let majorDimension: String
    let values: [[String]]
}

struct LinkItem: Identifiable {
    let id = UUID()
    let category: String
    let title: String
    let description: String
    let link: String
}

class LinkViewModel: ObservableObject {
    @Published var groupedLinks: [String: [LinkItem]] = [:]
    private var cancellable: AnyCancellable?
    func fetchLinks() {
        let rangeName = "Links"
        let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(googleApiKey)"
        guard let url = URL(string: urlString) else
        {
            return
        }
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: LinkGoogleSheetResponse.self, decoder: JSONDecoder())
            .map { response in
                // Skip the first row (headers)
                let dataRows = response.values.dropFirst()
                // Map and group the data
                return Dictionary(grouping: dataRows.map { LinkItem(category: $0[0], title: $0[1], description: $0[2], link: $0[3]) }) { $0.category }
            }
            .replaceError(with: [:])
            .receive(on: DispatchQueue.main)
            .assign(to: \.groupedLinks, on: self)
    }
}
