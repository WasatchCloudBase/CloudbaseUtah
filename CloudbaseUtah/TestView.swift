/*
import SwiftUI
import Combine

struct SkewTData: Codable {
    let pressure_mb: Double
    let altitude_m: Double
    let temp_c: Double
    let dewpoint_c: Double
    let wind_direction: Int
    let wind_speed_kt: Double
}

class SkewTViewModel: ObservableObject {
    @Published var skewtData: [SkewTData] = []
    private var cancellable: AnyCancellable?

    func fetchSkewTData() {
        guard let url = URL(string: "https://storage.googleapis.com/wasatch-wind-static/raob.json") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 60 // Increase timeout interval

        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .tryMap { data -> [SkewTData] in
                let decoder = JSONDecoder()
                let allData = try decoder.decode([SkewTData].self, from: data)
                return Array(allData.prefix(2)) // Fetch only the first 10 rows for debugging
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("Finished fetching data")
                case .failure(let error):
                    print("Error fetching data: \(error)")
                }
            }, receiveValue: { [weak self] data in
                print("Fetched data: \(data)")
                self?.skewtData = data
            })
    }
}

struct SkewTChartView: View {
    @ObservedObject var viewModel = SkewTViewModel()

    var body: some View {
        VStack {
            if viewModel.skewtData.isEmpty {
                Text("Loading data...")
                    .onAppear {
                        viewModel.fetchSkewTData()
                    }
            } else {
                GeometryReader { geometry in
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height

                        // Draw the Skew-T chart
                        for data in viewModel.skewtData {
                            let x = CGFloat(data.temp_c) * width / 50.0 // Adjust scale as needed
                            let y = height - CGFloat(data.altitude_m) * height / 20000.0 // Adjust scale as needed

                            if path.isEmpty {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
            }
        }
        .padding()
    }
}
*/
