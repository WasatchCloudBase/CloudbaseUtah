import Foundation
import MapKit

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

    // Fetch both overlays, using the passed-in radarColorScheme.
    func getRainViewerOverlays(
        radarColorScheme: Int,
        completion: @escaping (
            _ radarOverlays: [RainViewerTileOverlay],
            _ infraredOverlays: [RainViewerTileOverlay]
        ) -> Void
    ) {
        let group = DispatchGroup()
        var radarResult:    [RainViewerTileOverlay] = []
        var infraredResult: [RainViewerTileOverlay] = []

        // Radar
        group.enter()
        fetchMetadata { resp in
            if let last = resp.radar?.past.last {
                let overlay = RainViewerTileOverlay(
                    host: resp.host,
                    framePath: last.path,
                    type: .radar,
                    radarColorScheme: radarColorScheme
                )
                radarResult = [overlay]
            }
            group.leave()
        }

        // Satellite / Infrared
        group.enter()
        fetchMetadata { resp in
            if let last = resp.satellite?.infrared.last {
                let overlay = RainViewerTileOverlay(
                    host: resp.host,
                    framePath: last.path,
                    type: .satellite,
                    radarColorScheme: radarColorScheme // ignored for satellite
                )
                infraredResult = [overlay]
            }
            group.leave()
        }

        group.notify(queue: .main) {
            completion(radarResult, infraredResult)
        }
    }

    // Helper to load the JSON metadata once per call
    private func fetchMetadata(_ cb: @escaping (RainViewerResponse) -> Void) {
        guard let url = URL(string: apiURL) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard
                let data = data,
                let resp = try? JSONDecoder().decode(RainViewerResponse.self, from: data)
            else { return }
            DispatchQueue.main.async { cb(resp) }
        }.resume()
    }
}
