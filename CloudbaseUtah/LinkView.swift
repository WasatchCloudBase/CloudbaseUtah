import SwiftUI
import Combine
import Foundation

struct LinkView: View {
    @StateObject private var viewModel = LinkViewModel()
    @Environment(\.openURL) var openURL     // Used to open URL links as an in-app sheet using Safari
    @State private var externalURL: URL?    // Used to open URL links as an in-app sheet using Safari
    @State private var showWebView = false  // Used to open URL links as an in-app sheet using Safari
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.groupedLinks.isEmpty {
                emptyView
            } else {
                contentView
            }
        }
        .onAppear {
            viewModel.fetchLinks()
        }
        // Used to open URL links as an in-app sheet using Safari
        .sheet(isPresented: $showWebView) {
            if let url = externalURL { SafariView(url: url) }
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView() // ("Loading links…")
                .progressViewStyle(CircularProgressViewStyle())
            Spacer()
        }
    }
    
    private var emptyView: some View {
        VStack {
            Spacer()
            Text("No links available.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding()
            Spacer()
        }
    }
    
    private var contentView: some View {
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
    }
    
    // Used to open URL links as an in-app sheet using Safari
    func openLink(_ url: URL) { externalURL = url; showWebView = true }
}
