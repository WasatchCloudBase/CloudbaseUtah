import SwiftUI
import MapKit
import Combine
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import CoreGraphics
import CoreLocation
import Foundation

class RainViewerTileOverlay: MKTileOverlay {
    let path: String
    let host: String
    let colorScheme = 3
    let smoothing = 1
    let snow = 0
    let tileSizePx = 256

    init(host: String, path: String) {
        self.host = host
        self.path = path
        super.init(urlTemplate: nil)
        self.tileSize = CGSize(width: tileSizePx, height: tileSizePx)
        self.canReplaceMapContent = false
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let urlString = "\(host)\(self.path)/\(tileSizePx)/\(path.z)/\(path.x)/\(path.y)/\(colorScheme)/\(smoothing)_\(snow).png"
        return URL(string: urlString)!
    }
}

struct RainViewerResponse: Decodable {
    let host: String
    let radar: RadarData?
    let satellite: SatelliteData?
}

struct RadarData: Decodable {
    let past: [Frame]
    let nowcast: [Frame]
}

struct SatelliteData: Decodable {
    let infrared: [Frame]
}

struct Frame: Decodable {
    let time: Int
    let path: String
}

func fetchRainViewerFrames(completion: @escaping ([RainViewerTileOverlay]) -> Void) {
    guard let url = URL(string: rainviewerAPI) else { return }

    URLSession.shared.dataTask(with: url) { data, _, _ in
        guard let data = data,
              let decoded = try? JSONDecoder().decode(RainViewerResponse.self, from: data),
              let radarFrames = decoded.radar?.past else { return }

        // Get only the last radar frame for simplicity (or animate multiple later)
        // nowcast would be used for future forecast (30 min)
        if let last = radarFrames.last {
            let overlay = RainViewerTileOverlay(host: decoded.host, path: last.path)
            completion([overlay])
        }
    }.resume()
}


