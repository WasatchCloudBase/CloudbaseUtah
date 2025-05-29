import SwiftUI
import Combine

// SLC Area Forecast Discussion (AFD)
struct AFD: Identifiable {
    let id = UUID()
    let date: String
    let synopsis: String?
    let shortTerm: String?
    let longTerm: String?
    let aviation: String?
}
class AFDViewModel: ObservableObject {
    @Published var AFDvar: AFD?
    private var cancellable: AnyCancellable?

    func fetchAFD() {
        guard let url = URL(string: forecastDiscussionLink) else { return }
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .compactMap { String(data: $0, encoding: .utf8) }
            .map { self.parseAFDData($0) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .assign(to: \.AFDvar, on: self)
    }

    private func parseAFDData(_ data: String) -> AFD? {
        guard let startRange = data.range(of: "National Weather Service Salt Lake City UT") else { return nil }
        let AFDData = data[startRange.upperBound...]
        
        // Date expected in a format like: "334 PM MDT Mon Mar 17 2025"
        guard let dateRange = AFDData.range(of: "\\d{3,4} [A-Za-z]{2} [A-Za-z]{3} [A-Za-z]{3} [A-Za-z]{3} \\d{1,2} \\d{4}", options: .regularExpression) else { return nil }
        let date = String(AFDData[dateRange])
        
        let synopsis = collapseTextLines(extractSection(from: AFDData, start: ".SYNOPSIS", end: "&&"))
        let shortTerm = collapseTextLines(extractSection(from: AFDData, start: ".SHORT TERM", end: ".LONG TERM"))
        let longTerm = collapseTextLines(extractSection(from: AFDData, start: ".LONG TERM", end: "&&"))
        let aviation = collapseTextLines(extractSection(from: AFDData, start: ".AVIATION", end: "&&"))
        
        return AFD(date: date, synopsis: synopsis, shortTerm: shortTerm, longTerm: longTerm, aviation: aviation)
    }
}
