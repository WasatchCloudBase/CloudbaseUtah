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
    @Published var isLoading = false
    private var cancellable: AnyCancellable?

    func fetchLinks() {
        DispatchQueue.main.async {
            self.isLoading = true
        }

        let rangeName = "Links"
        let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(googleApiKey)"
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }

        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: LinkGoogleSheetResponse.self, decoder: JSONDecoder())
            .map { response -> [String:[LinkItem]] in
                let dataRows = response.values.dropFirst()
                let linkItems = dataRows.compactMap { row -> LinkItem? in
                    guard row.count >= 4,
                          !row[3].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    else { return nil }
                    return LinkItem(category: row[0],
                                    title: row[1],
                                    description: row[2],
                                    link: row[3])
                }
                return Dictionary(grouping: linkItems, by: \.category)
            }
            .replaceError(with: [:] as [String:[LinkItem]]) 
            .receive(on: DispatchQueue.main)
            .sink { [weak self] grouped in
                self?.groupedLinks = grouped
                self?.isLoading = false
            }
    }
}
