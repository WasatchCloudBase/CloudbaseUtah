import Foundation
import MapKit
import Combine

class RainViewerTileOverlay: MKTileOverlay {
    enum OverlayType { case radar, satellite }

    private let radarColorScheme: Int
    private let satelliteColorScheme = 0

    private let smoothing   = 1
    private let snow        = 0
    private let tileSizePx  = 256

    init(
        host: String,
        framePath: String,
        type: OverlayType,
        radarColorScheme: Int
    ) {
        self.radarColorScheme = radarColorScheme

        // pick segment
        let segment = (type == .radar) ? "radar" : "satellite"
        // pick the proper scheme
        let colorScheme = (type == .radar)
            ? self.radarColorScheme
            : self.satelliteColorScheme

        let template = "\(host)/v2/\(segment)/\(framePath)/" +
                       "\(tileSizePx)/{z}/{x}/{y}/" +
                       "\(colorScheme)/\(smoothing)_\(snow).png"

        super.init(urlTemplate: template)
        self.canReplaceMapContent = false
        self.tileSize = CGSize(width: tileSizePx, height: tileSizePx)
    }
}

// JSON models
struct RainViewerResponse: Decodable {
    let host: String
    let radar:   RadarData?
    let satellite: SatelliteData?
}

struct RadarData: Decodable { let past: [Frame]; let nowcast: [Frame]? }
struct SatelliteData: Decodable { let infrared: [Frame] }
struct Frame: Decodable { let time: Int; let path: String }

class RainViewerOverlayProvider {
    private let apiURL = "https://api.rainviewer.com/public/weather-maps.json"

    func getRainViewerOverlays(
        radarColorScheme: Int
    ) -> AnyPublisher<(
        radar: [RainViewerTileOverlay],
        infrared: [RainViewerTileOverlay]
    ), Error> {
        // We’ll fetch metadata only once, then build both overlays from it.
        guard let url = URL(string: apiURL) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: RainViewerResponse.self, decoder: JSONDecoder())
            .map { resp in
                var radarResult:    [RainViewerTileOverlay] = []
                var infraredResult: [RainViewerTileOverlay] = []

                if let lastRadar = resp.radar?.past.last {
                    radarResult = [
                        RainViewerTileOverlay(
                            host: resp.host,
                            framePath: lastRadar.path,
                            type: .radar,
                            radarColorScheme: radarColorScheme
                        )
                    ]
                }
                if let lastInfra = resp.satellite?.infrared.last {
                    infraredResult = [
                        RainViewerTileOverlay(
                            host: resp.host,
                            framePath: lastInfra.path,
                            type: .satellite,
                            radarColorScheme: radarColorScheme
                        )
                    ]
                }
                return (radar: radarResult, infrared: infraredResult)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

class RainViewerOverlayViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var radarOverlays:    [RainViewerTileOverlay] = []
    @Published var infraredOverlays: [RainViewerTileOverlay] = []

    private let provider: RainViewerOverlayProvider
    private var cancellables = Set<AnyCancellable>()

    init(provider: RainViewerOverlayProvider = .init()) {
        self.provider = provider
    }

    func loadOverlays(radarColorScheme: Int) {
        // flip on the spinner
        isLoading = true

        provider
            .getRainViewerOverlays(radarColorScheme: radarColorScheme)
            .sink { [weak self] completion in
                // on error or finished, hide loader
                self?.isLoading = false
                if case .failure(let err) = completion {
                    // handle/report the error...
                    print("Failed to load overlays:", err)
                }
            } receiveValue: { [weak self] result in
                // publish the new overlays
                self?.radarOverlays    = result.radar
                self?.infraredOverlays = result.infrared
            }
            .store(in: &cancellables)
    }
}
