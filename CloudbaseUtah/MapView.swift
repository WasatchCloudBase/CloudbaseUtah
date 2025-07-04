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


class ArrowOverlay: NSObject, MKOverlay {
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect
    let angle: CGFloat           // in degrees
    let color: UIColor
    let size: Double             // in map points

    init(center: CLLocationCoordinate2D, angle: CGFloat, color: UIColor, size: Double = mapPilotArrowDefaultSize) {
        self.coordinate = center
        self.angle = angle
        self.color = color
        self.size = size

        let mapPoint = MKMapPoint(center)
        self.boundingMapRect = MKMapRect(
            x: mapPoint.x - size / 2,
            y: mapPoint.y - size / 2,
            width: size,
            height: size
        )
    }
}

class ArrowOverlayRenderer: MKOverlayRenderer {
    private let arrow: ArrowOverlay
    var zoomLevel: Double = 0  // Set from outside, e.g., in map delegate

    init(arrow: ArrowOverlay) {
        self.arrow = arrow
        super.init(overlay: arrow)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let center = point(for: MKMapPoint(arrow.coordinate))
        
        // Use zoomLevel instead of zoomScale directly
        let sizeFactor: CGFloat = zoomLevelSizeFactor(for: zoomLevel)
        let size: CGFloat = CGFloat(arrow.size) * zoomLevel * mapPilotAnnotationZoomScaleFactor * sizeFactor
        let path = CGMutablePath()
        path.move(to: CGPoint(x: center.x, y: center.y - size / 2))
        path.addLine(to: CGPoint(x: center.x - size / 2, y: center.y + size / 2))
        path.addLine(to: CGPoint(x: center.x + size / 2, y: center.y + size / 2))
        path.closeSubpath()

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: arrow.angle * .pi / 180)
        context.translateBy(x: -center.x, y: -center.y)

        context.setFillColor(arrow.color.cgColor)
        context.addPath(path)
        context.fillPath()

        context.restoreGState()
    }

    private func zoomLevelSizeFactor(for zoomLevel: Double) -> CGFloat {
        return min(0.05 * pow(2.0,(20.0 - zoomLevel)), 200)
    }
}

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var zoomLevel: Double
    @Binding var mapStyle: CustomMapStyle
    @Binding var mapDisplayMode: MapDisplayMode
    @Binding var showRadar: Bool
    @Binding var showInfrared: Bool
    let radarOverlays: [MKTileOverlay]
    let infraredOverlays: [MKTileOverlay]
    let pilotTracks: [PilotTrack]
    let sites: [Site]
    let weatherAnnotations: [WeatherStationAnnotation]
    let onPilotSelected: (PilotTrack) -> Void
    let onStationSelected: (WeatherStationAnnotation) -> Void
    @State private var lastPilotTrackHash: Int = 0     // Used to identify track changes requiring re-rendering
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self,
                    onPilotSelected: onPilotSelected,
                    onStationSelected: onStationSelected)
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.showsUserLocation = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled  = mapEnableRotate
        mapView.isPitchEnabled   = mapEnablePitch
        mapView.mapType = mapStyle.toMapType()
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        
        // Update map type
        mapView.mapType = mapStyle.toMapType()
        
        // Clear out old overlays & annotations
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        // Display infrared satellite tiles
        if mapDisplayMode == .weather && showInfrared {
            for tile in infraredOverlays {
                mapView.addOverlay(tile, level: .aboveRoads)
            }
        }
        
        // Display radar tiles
        if mapDisplayMode == .weather && showRadar {
            for tile in radarOverlays {
                mapView.addOverlay(tile, level: .aboveRoads)
            }
        }

        // Build a stable, ordered list of pilots → color map
        let uniquePilots = Array(Set(pilotTracks.map { $0.pilotName }))
            .sorted()
        let pilotColorMap = Dictionary(
            uniqueKeysWithValues:
                uniquePilots.enumerated().map { idx, name in
                    (name, pilotColorPalette[idx % pilotColorPalette.count])
                }
        )
        context.coordinator.pilotColorMap = pilotColorMap
        
        // Add wind station annotation markers
        mapView.addAnnotations(weatherAnnotations)
        
        // Determine whether to show all track markers
        let showAllMarkers = zoomLevel > mapShowAllMarkersZoomLevel
        
        // For each pilot, in sorted order:
        for pilotName in uniquePilots {
            // — grab & time-sort their tracks
            let tracksForPilot = pilotTracks
                .filter { $0.pilotName == pilotName }
                .sorted { $0.dateTime < $1.dateTime }
            
            // — extract coords for polyline
            let coords = tracksForPilot.map {
                CLLocationCoordinate2D(latitude: $0.latitude,
                                       longitude: $0.longitude)
            }
            
            // — add line if we have at least two points
            if coords.count > 1 {
                let polyline = MKPolyline(coordinates: coords, count: coords.count)
                polyline.title = pilotName
                mapView.addOverlay(polyline)
                
            }
            
            // — partition into emergency / message / finish / first / normal
            var emergencyTracks: [PilotTrack] = []
            var messageTracks:   [PilotTrack] = []
            var finishTracks:    [PilotTrack] = []
            var firstTracks:     [PilotTrack] = []
            var normalTracks:    [PilotTrack] = []
            
            for (i, track) in tracksForPilot.enumerated() {
                let isFirst   = (i == 0)
                let isLast    = (i == tracksForPilot.count - 1)
                let isEmerg   = track.inEmergency == true
                let hasMsg    = !(track.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                let isNormal  = !isFirst && !isLast && !isEmerg && !hasMsg
                
                // drop normal if zoomed out
                if !showAllMarkers && isNormal { continue }
                
                switch true {
                case isEmerg:
                    emergencyTracks.append(track)
                case hasMsg:
                    messageTracks.append(track)
                case isLast:
                    finishTracks.append(track)
                case isFirst:
                    firstTracks.append(track)
                default:
                    normalTracks.append(track)
                }
            }
            
            // — add track annotations in that priority order
            for group in [emergencyTracks, messageTracks, finishTracks, firstTracks, normalTracks] {
                for track in group {
                    let idx = tracksForPilot.firstIndex { $0.id == track.id } ?? 0
                    let isFirst = idx == 0
                    let isLast  = idx == tracksForPilot.count - 1
                    let isEmerg = track.inEmergency == true
                    let hasMsg  = !(track.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                    
                    let annotation = PilotTrackAnnotation(
                        coordinate: CLLocationCoordinate2D(
                            latitude:  track.latitude,
                            longitude: track.longitude
                        ),
                        title:      pilotName.components(separatedBy: " ").first ?? pilotName,
                        subtitle:   DateFormatter
                            .localizedString(from: track.dateTime,
                                             dateStyle: .none,
                                             timeStyle: .short),
                        annotationType: "pilot",
                        pilotTrack:     track,
                        pilotName:      pilotName,
                        isFirst:        isFirst,
                        isLast:         isLast,
                        isEmergency:    isEmerg,
                        hasMessage:     hasMsg
                    )
                    mapView.addAnnotation(annotation)
                }
            }
            
            // — if zoomed in, draw arrows between each consecutive pair
            if showAllMarkers {
                for i in 0..<coords.count - 1 {
                    let start = coords[i]
                    let end   = coords[i + 1]
                    let mid   = CLLocationCoordinate2D(
                        latitude:  (start.latitude  + end.latitude)  / 2,
                        longitude: (start.longitude + end.longitude) / 2
                    )
                    let angle = bearing(from: start, to: end)
                    let color = pilotColorMap[pilotName] ?? .gray
                    let arrow = ArrowOverlay(center: mid,
                                             angle: CGFloat(angle),
                                             color: color)
                    mapView.addOverlay(arrow)
                }
            }
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        let onPilotSelected: (PilotTrack) -> Void
        let onStationSelected: (WeatherStationAnnotation) -> Void
        var pilotColorMap: [String: UIColor] = [:]
        
        init(parent: MapView,
             onPilotSelected: @escaping (PilotTrack) -> Void,
             onStationSelected: @escaping (WeatherStationAnnotation) -> Void) {
            self.parent = parent
            self.onPilotSelected = onPilotSelected
            self.onStationSelected = onStationSelected
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let newZoom = log2(360 * (Double(mapView.frame.size.width) / 256) / mapView.region.span.longitudeDelta)
            DispatchQueue.main.async {
                self.parent.zoomLevel = newZoom
                
                // Set region to retain setting when user switches map modes
                self.parent.region = mapView.region
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            
            // Tile overlays (radar / infrared satellite)
            if let tile = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tile)
                if tile.urlTemplate?.contains("/satellite/") == true {
                    renderer.alpha = 0.6
                } else if tile.urlTemplate?.contains("/radar/") == true {
                    renderer.alpha = 1.0
                }
                return renderer
            }
            
            // Pilot track lines
            if let polyline = overlay as? MKPolyline,
               let pilotName = polyline.title {
                let r = MKPolylineRenderer(polyline: polyline)
                r.strokeColor = pilotColorMap[pilotName] ?? .gray
                r.lineWidth = mapPilotTrackWidth
                return r
            }
            
            // Arrows between nodes
            if let arrow = overlay as? ArrowOverlay {
                let renderer = ArrowOverlayRenderer(arrow: arrow)
                let zl = log2(360 * (Double(mapView.frame.size.width)/256) / mapView.region.span.longitudeDelta)
                renderer.zoomLevel = zl
                return renderer
            }
            
            // Fallback empty
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            
            // Pilot annotations
            if let pilot = annotation as? PilotTrackAnnotation {
                
                guard let pilotAnnotation = annotation as? PilotTrackAnnotation else { return nil }
                
                let identifier = "PilotAnnotation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                
                view.annotation = annotation
                view.clusteringIdentifier = nil
                view.collisionMode = .circle
                
                // Remove prior views
                view.subviews.forEach { $0.removeFromSuperview() }
                
                // Determing track node annotation type
                var trackNodeType = "normal"
                if pilotAnnotation.isEmergency || pilotAnnotation.hasMessage || pilotAnnotation.isFirst || pilotAnnotation.isLast {
                    trackNodeType = "special"
                }
                
                var annotationSizingFactor: CGFloat = 1
                if trackNodeType != "normal" {
                    annotationSizingFactor = 3
                }
                let dotDiameter: CGFloat = parent.zoomLevel * mapPilotAnnotationZoomScaleFactor * annotationSizingFactor
                let container = UIView()
                container.backgroundColor = .clear
                
                let pilotTrackColor = pilotColorMap[pilotAnnotation.pilotName] ?? .gray
                
                // Dot
                let dot = UIView(frame: CGRect(x: 0, y: 0, width: dotDiameter, height: dotDiameter))
                dot.frame = CGRect(x: 0, y: 0, width: dotDiameter, height: dotDiameter)
                dot.layer.cornerRadius = dotDiameter / 2
                dot.backgroundColor = pilotTrackColor
                dot.center = CGPoint(x: dotDiameter / 2, y: dotDiameter / 2)
                
                // Overlay icon for emergency/message/first/last
                if trackNodeType != "normal" {
                    let imageName: UIImage?
                    var imageSizeFactor: CGFloat = 1.0
                    if pilotAnnotation.isEmergency {
                        imageName = pilotInEmergencyAnnotationImage
                        dot.backgroundColor = UIColor(pilotEmergencyAnnotationColor)
                    } else if pilotAnnotation.hasMessage {
                        imageName = pilotMessageAnnotationImage
                    } else if pilotAnnotation.isFirst {
                        imageName = pilotLaunchAnnotationImage
                    } else {
                        imageName = pilotLatestAnnotationImage
                        imageSizeFactor = 2.5
                    }
                    
                    if let imageName = imageName {
                        let imageView = UIImageView(image: imageName.withRenderingMode(.alwaysTemplate))
                        imageView.tintColor = .white
                        imageView.contentMode = .scaleAspectFit
                        imageView.translatesAutoresizingMaskIntoConstraints = false
                        dot.addSubview(imageView)
                        
                        // calculate the size you want:
                        let baseInset = dotDiameter * 0.15
                        let imageSize = (dotDiameter - (2 * baseInset)) * imageSizeFactor
                        
                        NSLayoutConstraint.activate([
                            imageView.widthAnchor.constraint(equalToConstant: imageSize),
                            imageView.heightAnchor.constraint(equalToConstant: imageSize),
                            imageView.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
                            imageView.centerYAnchor.constraint(equalTo: dot.centerYAnchor),
                        ])                }
                }
                
                // Label
                let label = UILabel()
                label.numberOfLines = 0
                label.textAlignment = .center
                let attributedText = NSMutableAttributedString()
                let span = mapView.region.span
                
                if let name = pilotAnnotation.title {
                    attributedText.append(NSAttributedString(
                        string: name + "\n",
                        attributes: [
                            .foregroundColor: UIColor(pilotLabelNameTextColor),
                            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
                        ]))
                }
                
                if span.latitudeDelta < pilotNodeLabelThreeRowSpan {
                    let pilotTrackNodeDateTime = getFormattedTimefromDate(pilotAnnotation.pilotTrack?.dateTime ?? Date())
                    attributedText.append(NSAttributedString(
                        string: pilotTrackNodeDateTime + "\n",
                        attributes: [
                            .foregroundColor: UIColor(pilotLabelDateTextColor),
                            .font: UIFont.systemFont(ofSize: 9)
                        ]))
                    
                    let pilotTrackNodeAltitude = pilotAnnotation.pilotTrack?.altitude ?? 0
                    let formattedAltitude = formatAltitude(String(pilotTrackNodeAltitude))
                    attributedText.append(NSAttributedString(
                        string: formattedAltitude,
                        attributes: [
                            .foregroundColor: UIColor(pilotLabelAltTextColor),
                            .font: UIFont.systemFont(ofSize: 9)
                        ]))
                }
                
                label.attributedText = attributedText
                label.sizeToFit()
                
                let labelContainer = UIView()
                var labelTopMargin: CGFloat = 2.0
                if span.latitudeDelta < pilotNodeLabelThreeRowSpan {
                    labelContainer.backgroundColor = UIColor(pilotLabelBackgroundColor).withAlphaComponent(0.7)
                    labelContainer.layer.borderColor = pilotTrackColor.cgColor
                    labelContainer.layer.borderWidth = 0.5
                    labelContainer.layer.cornerRadius = 5
                    labelContainer.layer.masksToBounds = true
                    labelTopMargin = 6.0
                }
                
                let padding: CGFloat = 4
                label.frame = CGRect(
                    x: padding,
                    y: padding,
                    width: label.frame.width,
                    height: label.frame.height
                )
                labelContainer.addSubview(label)
                labelContainer.frame = CGRect(
                    x: 0,
                    y: dot.frame.maxY + labelTopMargin,
                    width: label.frame.width + 2 * padding,
                    height: label.frame.height + 2 * padding
                )
                let containerWidth = max(dot.frame.width, labelContainer.frame.width)
                let containerHeight = dot.frame.height + labelTopMargin + labelContainer.frame.height
                
                container.frame = CGRect(x: 0, y: 0, width: containerWidth, height: containerHeight)
                
                // Align subviews
                dot.center = CGPoint(x: containerWidth / 2, y: dot.frame.height / 2)
                labelContainer.center.x = containerWidth / 2  // Only horizontal centering
                
                container.addSubview(dot)
                container.addSubview(labelContainer)
                
                view.addSubview(container)
                view.frame = container.frame
                
                // Anchor the center of the dot to the annotation coordinate
                // Center the dot exactly on the annotation coordinate
                let dotCenterInContainer = dot.center
                let containerCenter = CGPoint(x: container.frame.width / 2, y: container.frame.height / 2)
                let offsetY = dotCenterInContainer.y - containerCenter.y
                view.centerOffset = CGPoint(x: 0, y: -offsetY)
                
                // Handle annotation display/filtering based on type
                if trackNodeType != "normal" {
                    view.displayPriority = .required
                    view.collisionMode = .none
                } else {
                    // Normal nodes: more visible as you zoom in
                    switch span.latitudeDelta {
                    case ..<0.005:
                        // really close in → show everything
                        view.displayPriority = .required
                        view.collisionMode = .none
                    case 0.005..<0.02:
                        // mid-zoom → moderate density
                        view.displayPriority = .defaultHigh
                        view.collisionMode    = .circle
                    default:
                        // zoomed way out → thin them out
                        view.displayPriority = .defaultLow
                        view.collisionMode    = .circle
                    }
                }
                view.canShowCallout = false
                view.clusteringIdentifier = nil
                
                return view
            }
            
            // Wind reading stations
            if let station = annotation as? WeatherStationAnnotation {
                
                // Define separate IDs for each station on the map
                let id = "WeatherStation-\(station.title ?? "")"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                  ?? MKAnnotationView(annotation: station, reuseIdentifier: id)
                view.annotation = station
                
                // Clear old badge from the map
                view.subviews.forEach { $0.removeFromSuperview() }
                
                // Create and add current badge
                let badge = makeStationBadge(for: station)
                view.frame = badge.frame
                view.addSubview(badge)
                view.canShowCallout = false
                
                return view
            }
            
            // Not a recognized annotation type
            return nil
        }
        
        private func makeStationBadge(for station: WeatherStationAnnotation) -> UIView {
            let horizPadding: CGFloat = 5
            let vertPadding: CGFloat = 3
            let badge = UIView()
            badge.backgroundColor    = UIColor.black.withAlphaComponent(0.7)
            badge.layer.cornerRadius = 6
            badge.clipsToBounds      = false  // so rotated arrow can draw past its bounds if needed
            
            // Wind speed label
            let speed = Int(station.windSpeed?.rounded() ?? 0)
            let label = UILabel()
            label.text      = "\(speed)"
            label.font      = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = UIColor(windSpeedColor(windSpeed: speed, siteType: ""))
            label.sizeToFit()
            
            // Arrow container
            let arrowSize = CGSize(width: 11, height: 11)
            let arrow = UIImageView(image: UIImage(systemName: "arrow.up"))
            arrow.tintColor   = .white
            arrow.contentMode = .scaleAspectFit
            
            // Set bounds to keep the logical size constant
            arrow.bounds = CGRect(origin: .zero, size: arrowSize)
            // Reset any old transform before rotating
            arrow.transform = .identity
            if let dir = station.windDirection {
                arrow.transform = CGAffineTransform(rotationAngle: CGFloat((dir - 180) * .pi/180))
            }
            
            // Position both subviews
            label.frame.origin = CGPoint(x: horizPadding, y: vertPadding)
            
            // Place the arrow by center so its bounds don’t change size
            let arrowCenter = CGPoint(
                x: label.frame.maxX + horizPadding + ( arrowSize.width / 2 ),
                y: vertPadding + ( label.frame.height / 2 )
            )
            arrow.center = arrowCenter
            
            // Compute badge size based on unrotated extents
            let badgeWidth  = arrowCenter.x + ( arrowSize.width / 2 ) + horizPadding
            let badgeHeight = max(label.frame.height, arrowSize.height) + ( 2 * vertPadding )
            badge.frame = CGRect(origin: .zero,
                                 size: CGSize(width: badgeWidth,
                                              height: badgeHeight))
            
            // Assemble
            badge.addSubview(label)
            badge.addSubview(arrow)
            return badge
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                switch annotation {
                case let pilot as PilotTrackAnnotation:
                    if let track = pilot.pilotTrack {
                        self.onPilotSelected(track)
                    }
                case let station as WeatherStationAnnotation:
                    self.onStationSelected(station)
                default:
                    break
                }
                mapView.deselectAnnotation(annotation, animated: false)
            }
        }
    }
}
        
func getPilotLabelHeightFromMapSpan(span: MKCoordinateSpan) -> CGFloat {
    if span.latitudeDelta < pilotNodeLabelThreeRowSpan {
        return pilotNodeAnnotationTextThreeRowHeight
    }
    else {
        return pilotNodeAnnotationTextOneRowHeight
    }
}

struct MapContainerView: View {
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodeViewModel
    @EnvironmentObject var siteViewModel: SiteViewModel
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @EnvironmentObject var mapSettingsViewModel: MapSettingsViewModel
    @Environment(\.scenePhase) private var scenePhase

    @StateObject var stationLatestReadingViewModel: StationLatestReadingViewModel
    @StateObject private var pilotTrackViewModel: PilotTrackViewModel
    @StateObject private var stationAnnotationViewModel: StationAnnotationViewModel

    @State private var selectedStation: WeatherStationAnnotation?
    @State private var selectedPilotTrack: PilotTrack?
    @State private var isLayerSheetPresented = false
    @State private var isPlaying = false
    @State private var animationProgress: Double = 0.0
    @State private var currentTime: String = "00:00"
    @State private var isActive = false
    @State private var refreshWorkItem: DispatchWorkItem?
    @State private var radarOverlays: [MKTileOverlay] = []
    @State private var infraredOverlays: [MKTileOverlay] = []
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: mapInitLatitude, longitude: mapInitLongitude),
        span: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan))

    @State private var position = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: mapInitLatitude, longitude: mapInitLongitude),
        span: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan)))

    @State private var lastRegionSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0, longitudeDelta: 0)
    @State private var currentZoomLevel: Double = defaultMapZoomLevel

    private var cancellables = Set<AnyCancellable>()
    
    init(pilotViewModel: PilotViewModel, siteViewModel: SiteViewModel, mapSettingsViewModel: MapSettingsViewModel) {
        let stationVM = StationLatestReadingViewModel(siteViewModel: siteViewModel)
        _pilotTrackViewModel = StateObject(wrappedValue:
            PilotTrackViewModel(pilotViewModel: pilotViewModel))
        _stationLatestReadingViewModel = StateObject(wrappedValue: stationVM)
        _stationAnnotationViewModel = StateObject(wrappedValue:
            StationAnnotationViewModel(
                mapSettingsViewModel: mapSettingsViewModel,
                siteViewModel: siteViewModel,
                stationLatestReadingViewModel: stationVM))
    }
    
    var body: some View {
        VStack {
            ZStack {
                
                // Validate annotation coordinates
                let _ = stationAnnotationViewModel.clusteredStationAnnotations.forEach { annotation in
                    assert(annotation.coordinate.latitude >= -90 && annotation.coordinate.latitude <= 90, "Invalid latitude: \(annotation.coordinate.latitude)")
                    assert(annotation.coordinate.longitude >= -180 && annotation.coordinate.longitude <= 180, "Invalid longitude: \(annotation.coordinate.longitude)")
                }
                
                
                // Get selected pilots (if specified by user)
                let selectedNames = Set(mapSettingsViewModel
                                          .selectedPilots
                                          .map(\.pilotName))

                // Get filteredTracks only if map is in tracking mode
                let filteredTracks: [PilotTrack] = {
                  guard mapSettingsViewModel.isMapTrackingMode else {
                    return []
                  }
                  // if no one is explicitly selected, show all pilots,
                  // otherwise only the selected ones:
                  return selectedNames.isEmpty
                    ? pilotTrackViewModel.pilotTracks
                    : pilotTrackViewModel.pilotTracks.filter { selectedNames.contains($0.pilotName) }
                }()
                
                // Get data for wind stations if map is in weather mode
                let stations: [WeatherStationAnnotation] = {
                    guard mapSettingsViewModel.isMapWeatherMode else {
                        return []
                    }
                    return stationAnnotationViewModel.clusteredStationAnnotations
                        .compactMap { item in
                            WeatherStationAnnotation(
                                lat:        item.coordinate.latitude,
                                lon:        item.coordinate.longitude,
                                name:       item.annotationName,
                                speed:      item.windSpeed,
                                direction:  item.windDirection
                            )
                        }
                }()
                    
                    MapView(
                        region:             $region,
                        zoomLevel:          $currentZoomLevel,
                        mapStyle:           $mapSettingsViewModel.selectedMapType,  // Standard or hybrid
                        mapDisplayMode:     $mapSettingsViewModel.mapDisplayMode,   // Weather or track
                        showRadar:          $mapSettingsViewModel.showRadar,
                        showInfrared:       $mapSettingsViewModel.showInfrared,
                        radarOverlays:      radarOverlays,
                        infraredOverlays:   infraredOverlays,
                        pilotTracks:        filteredTracks,
                        sites:              siteViewModel.sites,
                        weatherAnnotations: stations,
                        onPilotSelected:    { track in selectedPilotTrack = track },
                        onStationSelected:  { station in selectedStation = station }
                    )
                    .cornerRadius(10)
                    .padding(.vertical, 8)
                    
                // Floating Item Bar
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading) {
                            Button(action: { isLayerSheetPresented.toggle() }) {
                                VStack {
                                    Image(systemName: layersImage)
                                        .imageScale(.large)
                                        .foregroundStyle(layersIconColor)
                                        .padding(.bottom, 6)
                                    Text("Settings")
                                        .font(.caption)
                                        .foregroundColor(layersFontColor)
                                }
                            }
                            .sheet(isPresented: $isLayerSheetPresented) {
                                MapSettingsView(
                                    selectedMapType:    $mapSettingsViewModel.selectedMapType,
                                    pilotTrackDays:     $mapSettingsViewModel.pilotTrackDays,
                                    mapDisplayMode:     $mapSettingsViewModel.mapDisplayMode,
                                    showSites:          $mapSettingsViewModel.showSites,
                                    showStations:       $mapSettingsViewModel.showStations,
                                    showRadar:          $mapSettingsViewModel.showRadar,
                                    showInfrared:       $mapSettingsViewModel.showInfrared,
                                    radarColorScheme:   $mapSettingsViewModel.radarColorScheme,
                                    selectedPilots:     $mapSettingsViewModel.selectedPilots
                                )
                                .interactiveDismissDisabled(true) // Disables swipe-to-dismiss (force use of back button)\
                                .environmentObject(pilotViewModel)
                                .environmentObject(pilotTrackViewModel)
                                
                            }
                        }
                        .padding()
                        .background(layersIconBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Spacer()
                        
                        VStack (alignment: .center) {
                            Picker("Display", selection: $mapSettingsViewModel.mapDisplayMode) {
                                Text("Weather").tag(MapDisplayMode.weather)
                                Text("Tracking").tag(MapDisplayMode.tracking)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.bottom, 6)
                            Text ("Map Type")
                                .font(.caption)
                                .foregroundColor(layersFontColor)
                        }
                        .padding(.top, 15)
                        .padding(.trailing, 16)
                        .padding(.leading, 16)
                        .padding(.bottom, 12)
                        .background(layersIconBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 16)
                }
            }
            .onChange(of: MapSettingsState(pilotTrackDays:      mapSettingsViewModel.pilotTrackDays,
                                           mapDisplayMode:      mapSettingsViewModel.mapDisplayMode,
                                           showSites:           mapSettingsViewModel.showSites,
                                           showStations:        mapSettingsViewModel.showStations,
                                           showRadar:           mapSettingsViewModel.showRadar,
                                           showInfrared:        mapSettingsViewModel.showInfrared,
                                           radarColorScheme:    mapSettingsViewModel.radarColorScheme,
                                           scenePhase:          scenePhase,
                                           selectedPilots:      mapSettingsViewModel.selectedPilots
                                          )) {
                // Check all changes together to only execute updateMapAnnotations once
                if scenePhase == .active {
                    
                    // Reload radar and infrared overlays
                    let provider = RainViewerOverlayProvider()
                    provider.getRainViewerOverlays (radarColorScheme: mapSettingsViewModel.radarColorScheme) { radar, infrared in
                        DispatchQueue.main.async {
                            self.radarOverlays = radar
                            self.infraredOverlays = infrared
                        }
                    }

                    // Reload latest pilot tracks
                    if mapSettingsViewModel.isMapTrackingMode {
                        DispatchQueue.main.async {
                            pilotTrackViewModel.getAllPilotTracks(days: mapSettingsViewModel.pilotTrackDays) {}
                        }
                    }
                    
                    // Reload weather readings
                    else {
                        // Reload weather readings
                        DispatchQueue.main.async {
                            stationAnnotationViewModel.mapSettingsViewModel = mapSettingsViewModel
                            stationAnnotationViewModel.siteViewModel = siteViewModel
                        }
                        DispatchQueue.main.async {
                            stationLatestReadingViewModel.getLatestReadingsData (sitesOnly: false) {
                                stationAnnotationViewModel.stationLatestReadingViewModel = stationLatestReadingViewModel
                                stationAnnotationViewModel.updateStationAnnotations {
                                    stationAnnotationViewModel.clusterStationAnnotations(regionSpan: region.span)
                                }
                            }
                        }
                    }
                    startTimer() // Cancels existing timer and restarts
                    isActive = true
                    startMonitoringRegion()
                } else {
                    isActive = false
                }
            }
            
            if devMenuAvailable {
                
                // Pilot track listing
                NavigationLink(destination:
                                PilotTrackView()
                    .environmentObject(pilotViewModel)
                    .environmentObject(pilotTrackViewModel)) {
                        Text("Pilot track list")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    .padding(.bottom)
            }
        }
        
       .onAppear {
           
           let provider = RainViewerOverlayProvider()
           provider.getRainViewerOverlays (radarColorScheme: mapSettingsViewModel.radarColorScheme) { radar, infrared in
               DispatchQueue.main.async {
                   self.radarOverlays = radar
                   self.infraredOverlays = infrared
               }
           }

           if mapSettingsViewModel.isMapTrackingMode {
               // Reload latest pilot tracks
               DispatchQueue.main.async {
                   pilotTrackViewModel.getAllPilotTracks(days: mapSettingsViewModel.pilotTrackDays) {}
               }
           }
           else {
               // Reload weather readings
               DispatchQueue.main.async {
                   stationAnnotationViewModel.mapSettingsViewModel = mapSettingsViewModel
                   stationAnnotationViewModel.siteViewModel = siteViewModel
               }
               DispatchQueue.main.async {
                   stationLatestReadingViewModel.getLatestReadingsData (sitesOnly: false) {
                       stationAnnotationViewModel.stationLatestReadingViewModel = stationLatestReadingViewModel
                       stationAnnotationViewModel.updateStationAnnotations {
                           stationAnnotationViewModel.clusterStationAnnotations(regionSpan: region.span)
                       }
                   }
               }
           }
           
           startTimer() // Cancels existing timer and restarts
           isActive = true
           startMonitoringRegion()
       }
        
       .onDisappear {
           isActive = false
       }
        
       .sheet(item: $selectedStation) { station in
           if let match = stationAnnotationViewModel
               .clusteredStationAnnotations
               .first(where: { $0.annotationName == station.title ?? "" })
           {
               let site = Site(
                   id: UUID(),
                   area: "",
                   siteName: station.title ?? "",
                   readingsNote: "",
                   forecastNote: "",
                   siteType: "",
                   readingsAlt: String(match.altitude),
                   readingsSource: match.readingsSource,
                   readingsStation: match.annotationID,
                   pressureZoneReadingTime: "",
                   siteLat: "\(station.coordinate.latitude)",
                   siteLon: "\(station.coordinate.longitude)",
                   sheetRow: 0
               )

               SiteDetailView(site: site)

           } else {
               Text("No matching site data")
           }
       }
        
       .sheet(item: $selectedPilotTrack) { track in
           PilotTrackNodeView(originalPilotTrack: track)
       }
        
        // Make sure pilot live track view model is published
       .environmentObject(pilotTrackViewModel)
    }
    
    // Timer to reload annotations if page stays active
    private func startTimer() {
        // Cancel any existing timer
        refreshWorkItem?.cancel()
        
        // Create a new work item
        let workItem = DispatchWorkItem {
            if isActive {
                
                // Reload radar and infrared overlays
                let provider = RainViewerOverlayProvider()
                provider.getRainViewerOverlays (radarColorScheme: mapSettingsViewModel.radarColorScheme) { radar, infrared in
                    DispatchQueue.main.async {
                        self.radarOverlays = radar
                        self.infraredOverlays = infrared
                    }
                }

                // Reload latest pilot tracks
                if mapSettingsViewModel.isMapTrackingMode {
                    DispatchQueue.main.async {
                        pilotTrackViewModel.getAllPilotTracks(days: mapSettingsViewModel.pilotTrackDays) {}
                    }
                }
                // Reload weather readings
                else {
                    // Reload weather readings
                    DispatchQueue.main.async {
                        stationAnnotationViewModel.mapSettingsViewModel = mapSettingsViewModel
                        stationAnnotationViewModel.siteViewModel = siteViewModel
                    }
                    DispatchQueue.main.async {
                        stationLatestReadingViewModel.getLatestReadingsData (sitesOnly: false) {
                            stationAnnotationViewModel.stationLatestReadingViewModel = stationLatestReadingViewModel
                            stationAnnotationViewModel.updateStationAnnotations {
                                stationAnnotationViewModel.clusterStationAnnotations(regionSpan: region.span)
                            }
                        }
                    }
                }
            }
        }
        refreshWorkItem = workItem
        
        // Schedule the new timer
        DispatchQueue.main.asyncAfter(deadline: .now() + readingsRefreshInterval, execute: workItem)
    }
    
    private func startMonitoringRegion() {
        if mapSettingsViewModel.isMapTrackingMode {
            // Do nothing; pilot map changes handled elsewhere
        } else {
            Timer.scheduledTimer(withTimeInterval: mapBatchProcessingInterval, repeats: true) { _ in
                let currentSpan = region.span
                if hasRegionSpanChanged(from: lastRegionSpan, to: currentSpan) {
                    lastRegionSpan = currentSpan
                    stationAnnotationViewModel.clusterStationAnnotations(regionSpan: currentSpan)
                }
            }
        }
    }
    
    private func hasRegionSpanChanged(from oldSpan: MKCoordinateSpan, to newSpan: MKCoordinateSpan) -> Bool {
        return abs(oldSpan.latitudeDelta - newSpan.latitudeDelta) > mapScaleChangeTolerance ||
        abs(oldSpan.longitudeDelta - newSpan.longitudeDelta) > mapScaleChangeTolerance
    }
    
}
