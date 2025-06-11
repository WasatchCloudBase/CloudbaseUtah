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
    let pilotTracks: [PilotTracks]
    let onPilotSelected: (PilotTracks) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, onPilotSelected: onPilotSelected)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.showsUserLocation = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.mapType = mapStyle.toMapType()
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        
        // Update map type in case it was changed
        mapView.mapType = mapStyle.toMapType()
        
        // Clear all prior pilot track node annotations and line overlays
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        // Assign pilot colors
        let uniquePilots = Array(Set(pilotTracks.map { $0.pilotName })).sorted()
        let pilotColorMap = Dictionary(uniqueKeysWithValues: uniquePilots.enumerated().map {
            ($1, pilotColorPalette[$0 % pilotColorPalette.count])
        })
        context.coordinator.pilotColorMap = pilotColorMap

        let calendar = Calendar.current
        let groupedTracks = Dictionary(grouping: pilotTracks) {
            PilotTrackKey(pilotName: $0.pilotName, date: calendar.startOfDay(for: $0.dateTime))
        }

        let showAllMarkers = zoomLevel > mapShowAllMarkersZoomLevel
        var addedTrackIDs = Set<UUID>()

        for (_, tracks) in groupedTracks {
            let sorted = tracks.sorted { $0.dateTime < $1.dateTime }
            let coords = sorted.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

            if coords.count > 1 {
                let polyline = MKPolyline(coordinates: coords, count: coords.count)
                polyline.title = tracks.first?.pilotName
                mapView.addOverlay(polyline)
            }

            // Partition tracks by display priority
            var emergencyTracks: [PilotTracks] = []
            var messageTracks: [PilotTracks] = []
            var finishTracks: [PilotTracks] = []
            var firstTracks: [PilotTracks] = []
            var normalTracks: [PilotTracks] = []

            for (index, track) in sorted.enumerated() {
                guard addedTrackIDs.insert(track.id).inserted else { continue }

                let isFirst = index == 0
                let isLast = index == sorted.count - 1
                let isEmergency = track.inEmergency == true
                let hasMessage = !(track.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                let isNormalNode = !isFirst && !isLast && !isEmergency && !hasMessage

                if !showAllMarkers && isNormalNode { continue }

                if isEmergency {
                    emergencyTracks.append(track)
                } else if hasMessage {
                    messageTracks.append(track)
                } else if isLast {
                    finishTracks.append(track)
                } else if isFirst {
                    firstTracks.append(track)
                } else {
                    normalTracks.append(track)
                }
            }

            // Add annotations in priority order
            for group in [emergencyTracks, messageTracks, finishTracks, firstTracks, normalTracks] {
                for track in group {
                    let index = sorted.firstIndex(where: { $0.id == track.id }) ?? 0
                    let isFirst = index == 0
                    let isLast = index == sorted.count - 1
                    let isEmergency = track.inEmergency == true
                    let hasMessage = !(track.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

                    let annotation = PilotTrackAnnotation(
                        coordinate: CLLocationCoordinate2D(latitude: track.latitude, longitude: track.longitude),
                        title: track.pilotName.components(separatedBy: " ").first ?? track.pilotName,
                        subtitle: DateFormatter.localizedString(from: track.dateTime, dateStyle: .none, timeStyle: .short),
                        annotationType: "pilot",
                        pilotTrack: track,
                        pilotName: track.pilotName,
                        isFirst: isFirst,
                        isLast: isLast,
                        isEmergency: isEmergency,
                        hasMessage: hasMessage
                    )
                    mapView.addAnnotation(annotation)
                }
            }

            // Add arrows between each pair of nodes
            if showAllMarkers {
                for i in 0..<(coords.count - 1) {
                    let start = coords[i]
                    let end = coords[i + 1]
                    let mid = CLLocationCoordinate2D(
                        latitude: (start.latitude + end.latitude) / 2,
                        longitude: (start.longitude + end.longitude) / 2
                    )
                    let angle = bearing(from: start, to: end)
                    let color = pilotColorMap[tracks.first?.pilotName ?? ""] ?? .gray
                    let overlay = ArrowOverlay(center: mid, angle: CGFloat(angle), color: color)
                    mapView.addOverlay(overlay)
                }
            }
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        let onPilotSelected: (PilotTracks) -> Void
        var pilotColorMap: [String: UIColor] = [:]

        init(parent: MapView, onPilotSelected: @escaping (PilotTracks) -> Void) {
            self.parent = parent
            self.onPilotSelected = onPilotSelected
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let newZoom = log2(360 * (Double(mapView.frame.size.width) / 256) / mapView.region.span.longitudeDelta)
            DispatchQueue.main.async {
                self.parent.zoomLevel = newZoom
                
                // Set region to retain region when user switches map modes
                self.parent.region = mapView.region
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline,
               let pilotName = polyline.title {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = pilotColorMap[pilotName] ?? .gray
                renderer.lineWidth = mapPilotTrackWidth
                return renderer
            } else if let arrow = overlay as? ArrowOverlay {
                let renderer = ArrowOverlayRenderer(arrow: arrow)
                let zoomLevel = log2(360 * (Double(mapView.frame.size.width) / 256) / mapView.region.span.longitudeDelta)
                renderer.zoomLevel = zoomLevel
                return renderer
            }
            return MKOverlayRenderer()
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pilotAnnotation = annotation as? PilotTrackAnnotation else { return nil }

            let identifier = "PilotAnnotation"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation
            view.canShowCallout = false
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
                let symbolName: String?
                if pilotAnnotation.isEmergency {
                    symbolName = pilotInEmergencyAnnotationImage
                    dot.backgroundColor = UIColor(pilotEmergencyAnnotationColor)
                } else if pilotAnnotation.hasMessage {
                    symbolName = pilotMessageAnnotationImage
                } else if pilotAnnotation.isFirst {
                    symbolName = pilotLaunchAnnotationImage
                } else {
                    symbolName = pilotLatestAnnotationImage
                }

                if let symbolName = symbolName, let image = UIImage(systemName: symbolName) {
                    let imageView = UIImageView(image: image)
                    imageView.tintColor = .white
                    imageView.contentMode = .scaleAspectFit
                    let imageInset: CGFloat = dotDiameter * 0.15
                    let imageSize = dotDiameter - 2 * imageInset
                    imageView.frame = CGRect(x: imageInset, y: imageInset, width: imageSize, height: imageSize)
                    dot.addSubview(imageView)
                }
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
            } else {
                view.displayPriority = .defaultLow
            }
            view.canShowCallout = false
            view.clusteringIdentifier = nil
            
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard
                let annotation = view.annotation as? PilotTrackAnnotation,
                let track = annotation.pilotTrack
            else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.onPilotSelected(track)
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
    @EnvironmentObject var weatherCodesViewModel: WeatherCodesViewModel
    @EnvironmentObject var sitesViewModel: SitesViewModel
    @EnvironmentObject var pilotsViewModel: PilotsViewModel
    @EnvironmentObject var mapSettingsViewModel: MapSettingsViewModel
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var stationLatestReadingsViewModel: StationLatestReadingsViewModel
    @StateObject private var pilotTracksViewModel = PilotTracksViewModel()
    @StateObject private var annotationSourceItemsViewModel: AnnotationSourceItemsViewModel

    @State private var selectedSite: Sites?
    @State private var selectedPilotTrack: PilotTracks?
    @State private var isLayerSheetPresented = false
    @State private var isPlaying = false
    @State private var animationProgress: Double = 0.0
    @State private var currentTime: String = "00:00"
    @State private var annotationSourceItems: [AnnotationSourceItem] = []
    @State private var isActive = false
    @State private var refreshWorkItem: DispatchWorkItem?

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: mapInitLatitude, longitude: mapInitLongitude),
        span: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan))

    @State private var position = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: mapInitLatitude, longitude: mapInitLongitude),
        span: MKCoordinateSpan(latitudeDelta: mapInitLatitudeSpan, longitudeDelta: mapInitLongitudeSpan)))

    @State private var lastRegionSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0, longitudeDelta: 0)
    @State private var currentZoomLevel: Double = defaultMapZoomLevel

    private var cancellables = Set<AnyCancellable>()

    init(sitesViewModel: SitesViewModel, mapSettingsViewModel: MapSettingsViewModel) {
        let stationVM = StationLatestReadingsViewModel(viewModel: sitesViewModel)
        _stationLatestReadingsViewModel = StateObject(wrappedValue: stationVM)
        _annotationSourceItemsViewModel = StateObject(wrappedValue:
            AnnotationSourceItemsViewModel(
                mapSettingsViewModel: mapSettingsViewModel,
                sitesViewModel: sitesViewModel,
                stationLatestReadingsViewModel: stationVM
            )
        )
    }
    
    var body: some View {
        ZStack {
            
            // Validate annotation coordinates
            let _ = annotationSourceItemsViewModel.clusteredAnnotationSourceItems.forEach { annotation in
                assert(annotation.coordinates.latitude >= -90 && annotation.coordinates.latitude <= 90, "Invalid latitude: \(annotation.coordinates.latitude)")
                assert(annotation.coordinates.longitude >= -180 && annotation.coordinates.longitude <= 180, "Invalid longitude: \(annotation.coordinates.longitude)")
            }
            
            // Create map for pilot tracks
            if mapSettingsViewModel.isMapTrackingMode {
                MapView(
                    region: $region,
                    zoomLevel: $currentZoomLevel,
                    mapStyle: $mapSettingsViewModel.selectedMapType,
                    pilotTracks: pilotTracksViewModel.pilotTracks,
                    onPilotSelected: { track in
                        selectedPilotTrack = track
                    }
                )                .cornerRadius(10)
                .padding(.vertical, 8)
                
            // Create map for weather
            } else if mapSettingsViewModel.isMapWeatherMode {
                Map(coordinateRegion: $region,
                    interactionModes: .all,
                    showsUserLocation: false,
                    annotationItems: annotationSourceItemsViewModel.clusteredAnnotationSourceItems)
                { annotation in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: annotation.coordinates.latitude, longitude: annotation.coordinates.longitude)) {
                        
                        Button(action: {
                            switch annotation.annotationType {
                                
                            case "site":
                                DispatchQueue.main.async {
                                    selectedSite = sitesViewModel.sites.first(where: { $0.siteName == annotation.annotationID })
                                    return
                                }
                            case "station":
                                DispatchQueue.main.async {
                                    selectedSite = Sites(
                                        id: UUID(),
                                        area: "",
                                        siteName: annotation.annotationName,
                                        readingsNote: "",
                                        forecastNote: "",
                                        siteType: "",
                                        readingsAlt: String(annotation.altitude),
                                        readingsSource: annotation.readingsSource,
                                        readingsStation: annotation.annotationID,
                                        pressureZoneReadingTime: "",
                                        siteLat: "\(annotation.coordinates.latitude)",
                                        siteLon: "\(annotation.coordinates.longitude)",
                                        sheetRow: 0
                                    )
                                    return
                                }
                            default:
                                return
                            }
                        }) {
                            switch annotation.annotationType {
                                
                            case "site" :
                                VStack (spacing: 0) {
                                    Image(siteAnnotationImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: defaultAnnotationImageWidth)
                                    Text(annotation.annotationName)
                                        .font(.footnote)
                                        .foregroundColor(siteAnnotationTextColor)
                                        .frame(width: annotationTextWidth, height: annotationTextHeight)
                                }
                                
                            case "station" :
                                HStack (spacing: 1) {
                                    Text(String(Int(annotation.windSpeed?.rounded() ?? 0)))
                                        .font(.caption)
                                        .foregroundStyle(windSpeedColor(windSpeed: Int(annotation.windSpeed?.rounded() ?? 0), siteType: ""))
                                        .bold()
                                    /* Not displaying gusts
                                     Text("g")
                                     .font(.caption2)
                                     Text(String(Int(customAnnotation.windGust?.rounded() ?? 0)))
                                     .font(.caption)
                                     .foregroundStyle(windSpeedColor(windSpeed: Int(customAnnotation.windGust?.rounded() ?? 0), siteType: ""))
                                     .bold()
                                     */
                                    Image(systemName: windArrow)
                                        .rotationEffect(.degrees((Double(annotation.windDirection ?? 180)) - 180))
                                        .font(.footnote)
                                }
                                .padding (4)
                                .frame(width: stationAnnotationWidth, height: stationAnnotationHeight)
                                .background(stationAnnotationColor)
                                .cornerRadius(5)
                                
                            default:
                                VStack (spacing: 0) {
                                    Image(systemName: defaultAnnotationImage)
                                        .foregroundColor(defaultAnnotationColor)
                                    Text(annotation.annotationName)
                                        .font(.footnote)
                                        .foregroundColor(defaultAnnotationTextColor)
                                        .frame(width: annotationTextWidth, height: annotationTextHeight)
                                }
                            }
                        }
                    }
                }
                .mapStyle(mapSettingsViewModel.selectedMapType.toMapStyle())
                .cornerRadius(10)
                .padding(.vertical, 8)

            } else {
                Text("Map not in a valid mode (weather, tracking")
            }

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
                                selectedMapType: $mapSettingsViewModel.selectedMapType,
                                pilotTrackDays: $mapSettingsViewModel.pilotTrackDays,
                                mapDisplayMode: $mapSettingsViewModel.mapDisplayMode,
                                showSites: $mapSettingsViewModel.showSites,
                                showStations: $mapSettingsViewModel.showStations
                            )
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
                    
                    VStack(alignment: .trailing) {
                        
                        
                        /*
                         if mapSettingsViewModel.activeLayers.contains(.precipitation) ||
                         mapSettingsViewModel.activeLayers.contains(.cloudCover) {
                         VStack(alignment: .trailing) {
                         HStack(alignment: .center) {
                         Button(action: { isPlaying.toggle() }) {
                         Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                         .imageScale(.large)
                         }
                         .padding(.horizontal, 8)
                         ProgressView(value: animationProgress)
                         .frame(width: 100)
                         Text(currentTime)
                         .font(.headline)
                         .padding(.horizontal, 8)
                         }
                         }
                         .padding()
                         .background(.thinMaterial)
                         .clipShape(RoundedRectangle(cornerRadius: 12))
                         }
                         */
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .onChange(of: MapSettingsState(pilotTrackDays: mapSettingsViewModel.pilotTrackDays,
                                       mapDisplayMode: mapSettingsViewModel.mapDisplayMode,
                                       showSites: mapSettingsViewModel.showSites,
                                       showStations: mapSettingsViewModel.showStations,
                                       scenePhase: scenePhase
                                      )) {
            // Check all changes together to only execute updateMapAnnotations once
            if scenePhase == .active {
                // Reload latest pilot tracks
                if mapSettingsViewModel.isMapTrackingMode {
                    for pilot in pilotsViewModel.pilots {
                        pilotTracksViewModel.getPilotTrackingData(pilotName: pilot.pilotName, trackingURL: pilot.trackingFeedURL, days: mapSettingsViewModel.pilotTrackDays) {}
                    }
                }
                
                // Reload weather readings
                else {
                    annotationSourceItemsViewModel.mapSettingsViewModel = mapSettingsViewModel
                    annotationSourceItemsViewModel.sitesViewModel = sitesViewModel
                    stationLatestReadingsViewModel.getLatestReadingsData {
                        annotationSourceItemsViewModel.stationLatestReadingsViewModel = stationLatestReadingsViewModel
                        annotationSourceItemsViewModel.updateAnnotationSourceItems {
                            annotationSourceItemsViewModel.clusterAnnotationSourceItems(regionSpan: region.span)
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
       .onAppear {
           // Reload latest pilot tracks
           if mapSettingsViewModel.isMapTrackingMode {
               DispatchQueue.main.async {
                   for pilot in pilotsViewModel.pilots {
                       pilotTracksViewModel.getPilotTrackingData(pilotName: pilot.pilotName, trackingURL: pilot.trackingFeedURL, days: mapSettingsViewModel.pilotTrackDays) {}
                   }
               }
           }
           // Reload weather readings
           else {
               
               annotationSourceItemsViewModel.mapSettingsViewModel = mapSettingsViewModel
               annotationSourceItemsViewModel.sitesViewModel = sitesViewModel
               stationLatestReadingsViewModel.getLatestReadingsData {
                   annotationSourceItemsViewModel.stationLatestReadingsViewModel = stationLatestReadingsViewModel
                   annotationSourceItemsViewModel.updateAnnotationSourceItems {
                       annotationSourceItemsViewModel.clusterAnnotationSourceItems(regionSpan: region.span)
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
       .sheet(item: $selectedSite) { site in
           SiteDetailView(site: site)
       }
        
       .sheet(item: $selectedPilotTrack) { track in
           PilotTrackNodeView(originalPilotTrack: track)
       }
        
        // Make sure pilot live track view model is published
       .environmentObject(pilotTracksViewModel)
    }
    
    // Timer to reload annotations if page stays active
    private func startTimer() {
        // Cancel any existing timer
        refreshWorkItem?.cancel()
        
        // Create a new work item
        let workItem = DispatchWorkItem {
            if isActive {
                // Reload latest pilot tracks
                if mapSettingsViewModel.isMapTrackingMode {
                    for pilot in pilotsViewModel.pilots {
                        pilotTracksViewModel.getPilotTrackingData(pilotName: pilot.pilotName, trackingURL: pilot.trackingFeedURL, days: mapSettingsViewModel.pilotTrackDays) {}
                    }
                }
                // Reload weather readings
                else {
                    DispatchQueue.main.async {
                        annotationSourceItemsViewModel.mapSettingsViewModel = mapSettingsViewModel
                        annotationSourceItemsViewModel.sitesViewModel = sitesViewModel
                    }
                    DispatchQueue.main.async {
                        annotationSourceItemsViewModel.stationLatestReadingsViewModel = stationLatestReadingsViewModel
                    }
                    DispatchQueue.main.async {
                        annotationSourceItemsViewModel.updateAnnotationSourceItems {
                            annotationSourceItemsViewModel.clusterAnnotationSourceItems(regionSpan: region.span)
                        }
                    }
                }
            }
        }
        refreshWorkItem = workItem
        
        // Schedule the new timer
        DispatchQueue.main.asyncAfter(deadline: .now() + pageRefreshInterval, execute: workItem)
    }
    
    private func startMonitoringRegion() {
        if mapSettingsViewModel.isMapTrackingMode {
            // Do nothing; pilot map changes handled elsewhere
        } else {
            Timer.scheduledTimer(withTimeInterval: mapBatchProcessingInterval, repeats: true) { _ in
                let currentSpan = region.span
                if hasRegionSpanChanged(from: lastRegionSpan, to: currentSpan) {
                    lastRegionSpan = currentSpan
                    annotationSourceItemsViewModel.clusterAnnotationSourceItems(regionSpan: currentSpan)
                }
            }
        }
    }
    
    private func hasRegionSpanChanged(from oldSpan: MKCoordinateSpan, to newSpan: MKCoordinateSpan) -> Bool {
        return abs(oldSpan.latitudeDelta - newSpan.latitudeDelta) > mapScaleChangeTolerance ||
        abs(oldSpan.longitudeDelta - newSpan.longitudeDelta) > mapScaleChangeTolerance
    }
    
}
