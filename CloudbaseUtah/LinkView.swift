//  SiteView.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/6/25.

import SwiftUI
import Combine
import Foundation

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

class GoogleSheetViewModel: ObservableObject {
    @Published var groupedLinks: [String: [LinkItem]] = [:]
    private var cancellable: AnyCancellable?
    func fetchLinks() {
        let rangeName = "Links"
        let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(GoogleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(GoogleApiKey)"
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

struct LinkView: View {
    @StateObject private var viewModel = GoogleSheetViewModel()
    @Environment(\.openURL) var openURL     // Used to open URL links as an in-app sheet using Safari
    @State private var externalURL: URL?    // Used to open URL links as an in-app sheet using Safari
    @State private var showWebView = false  // Used to open URL links as an in-app sheet using Safari
    var body: some View {
        List {
            ForEach(viewModel.groupedLinks.keys.sorted(), id: \.self) { category in
                // Split is used to strip the order sequence number from the front of the category on display
                Section(header: Text(category.split(separator: " ", maxSplits: 1)[1])
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold()) {
                    ForEach(viewModel.groupedLinks[category] ?? []) { item in
                        Button(action: {
                            if let url = URL(string: item.link) {
                                externalURL = url
                                showWebView = true
                            }
                        }) {
                            VStack(alignment: .leading) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundColor(rowHeaderColor)
                                Text(item.description)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.fetchLinks() }
        // Used to open URL links as an in-app sheet using Safari
        .sheet(isPresented: $showWebView) { if let url = externalURL { SafariView(url: url) } }
    }
    // Used to open URL links as an in-app sheet using Safari
    func openLink(_ url: URL) { externalURL = url; showWebView = true }
}
