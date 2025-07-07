import SwiftUI
import Combine
import MapKit

// Set to true to print performance execution info for getPilotTracks
let performanceTuningLog: Bool = false

// Pilot live tracking structure
struct PilotTrack: Identifiable, Equatable, Hashable {
    let id: UUID = UUID()
    let pilotName: String
    let dateTime: Date
    let latitude: Double
    let longitude: Double
    let speed: Double
    let altitude: Double
    let heading: Double
    let inEmergency: Bool
    let message: String?
}

// Listing of pilot live tracks by pilot name and date
// used to determine track groupings for line rendering on track
struct PilotTrackKey: Hashable {
    let pilotName: String
    let date: Date
}

// Annotation for pilot tracks to allow polylines as an overlay on map
class PilotTrackAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let annotationType: String
    let pilotTrack: PilotTrack?

    let pilotName: String
    let isFirst: Bool
    let isLast: Bool
    let isEmergency: Bool
    let hasMessage: Bool

    init(coordinate: CLLocationCoordinate2D,
         title: String?,
         subtitle: String?,
         annotationType: String,
         pilotTrack: PilotTrack?,
         pilotName: String,
         isFirst: Bool,
         isLast: Bool,
         isEmergency: Bool,
         hasMessage: Bool
    ) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.annotationType = annotationType
        self.pilotTrack = pilotTrack
        self.pilotName = pilotName
        self.isFirst = isFirst
        self.isLast = isLast
        self.isEmergency = isEmergency
        self.hasMessage = hasMessage
    }
}

@MainActor
class PilotTrackViewModel: ObservableObject {
    @Published private(set) var pilotTracks: [PilotTrack] = []
    @Published var isLoading = false

    private let pilotViewModel: PilotViewModel
    private var cancellables = Set<AnyCancellable>()
    private let session: URLSession

    private let maxConcurrentRequests = 8
    private let maxConnectionsPerHost = 12

    // Midnight-of-last-cache build. When the date rolls past this, clear everything.
    private var cacheDate: Date = Calendar.current.startOfDay(for: Date())

    // Per-pilot cache entry
    private struct CacheEntry {
        var lastFetch: Date
        var lastDays: Double
        var tracks: [PilotTrack]
    }

    // Map from pilotName to cache entry
    private var cache: [String: CacheEntry] = [:]

    init(pilotViewModel: PilotViewModel) {
        self.pilotViewModel = pilotViewModel

        // Tune URLSession
        let cfg = URLSessionConfiguration.default
        cfg.httpMaximumConnectionsPerHost = maxConnectionsPerHost
        self.session = URLSession(configuration: cfg)

        pilotViewModel.$pilots
            .sink { _ in /* no-op: fetch is triggered by view logic */ }
            .store(in: &cancellables)
    }

    // Fetch tracks for the selected pilots, but only refetch what's stale or new.
    func getPilotTracks(
        days: Double,
        selectedPilots: [Pilot],
        completion: @escaping () -> Void
    ) {
        
        // If the calendar date rolled over, clear entire cache
        let today = Calendar.current.startOfDay(for: Date())
        if today > cacheDate {
            cache.removeAll()
            cacheDate = today
        }

        // Determine which pilots to consider
        let pilotsToConsider = selectedPilots.isEmpty
            ? pilotViewModel.pilots
            : selectedPilots

        // Partition into “reuse” vs “to fetch”
        var reuseTracks: [PilotTrack] = []
        var toFetch: [Pilot] = []
        let now = Date()

        for pilot in pilotsToConsider {
            if let entry = cache[pilot.pilotName],
               entry.lastDays == days,
               now.timeIntervalSince(entry.lastFetch) < readingsRefreshInterval
            {
                // PERFORMANCE TUNING
                if performanceTuningLog {
                    print("Skipped refresh for pilot: \(pilot.pilotName)")
                }
                
                // still fresh—reuse cached tracks
                reuseTracks.append(contentsOf: entry.tracks)
                
            } else {
                
                // PERFORMANCE TUNING
                if performanceTuningLog {
                    print("Reloading pilot for pilot: \(pilot.pilotName); days: \(days)")
                }
                
                // new pilot, days changed, or stale
                toFetch.append(pilot)
            }
        }

        // Flip loading state
        isLoading = true
        
        // Kick off async work
        Task { [weak self] in
            guard let self = self else { return }
            
            // Fetch fresh tracks only for the pilots that need it
            let freshTracks = await self.fetchAllTracks(
                pilots: toFetch,
                days: days
            )

            // Update cache entries for those pilots
            let grouped = Dictionary(grouping: freshTracks, by: \.pilotName)
            let fetchTime = Date()

            // Cache pilots with tracks
            for (pilotName, tracks) in grouped {
                self.cache[pilotName] = CacheEntry(
                    lastFetch: fetchTime,
                    lastDays: days,
                    tracks: tracks
                )
            }

            // Cache pilots with *no* tracks (so we don't keep rechecking them)
            let fetchedPilotNames = Set(grouped.keys)
            for pilot in toFetch where !fetchedPilotNames.contains(pilot.pilotName) {
                self.cache[pilot.pilotName] = CacheEntry(
                    lastFetch: fetchTime,
                    lastDays: days,
                    tracks: []
                )
            }
            
            // Merge reused + fresh, sort, and publish
            let all = reuseTracks + freshTracks
            let sorted = all.sorted { $0.dateTime < $1.dateTime }

            self.pilotTracks = sorted
            self.isLoading = false
            completion()
        }
        
    }

    // Throttled parallel fetch of multiple pilots
    private func fetchAllTracks(
        pilots: [Pilot],
        days: Double
    ) async -> [PilotTrack] {
        let semaphore = AsyncSemaphore(value: maxConcurrentRequests)
        
        // PERFORMANCE TUNING
        let startTime: Date = Date()

        return await withTaskGroup(of: [PilotTrack].self) { group in
            for pilot in pilots {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    return await self.fetchTracks(for: pilot, days: days)
                }
            }

            var combined: [PilotTrack] = []
            for await chunk in group {
                combined.append(contentsOf: chunk)
            }
            
            // PERFORMANCE TUNING
            if performanceTuningLog {
                let endTime = Date()
                let duration = (endTime.timeIntervalSince(startTime) * 100).rounded()/100
                print("Total fetchAllTracks execution time: \(duration) seconds")
            }
            
            return combined
        }
        
    }

    // Single-pilot fetch
    private func fetchTracks(
        for pilot: Pilot,
        days: Double
    ) async -> [PilotTrack] {
        guard let url = constructURL(
            trackingURL: pilot.trackingFeedURL,
            days: days
        ) else {
            return []
        }
        
        // PERFORMANCE TUNING
        let startTime = Date()

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
            "AppleWebKit/537.36 (KHTML, like Gecko) " +
            "Chrome/136.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;" +
            "q=0.9,image/avif,image/webp,image/apng,*/*;" +
            "q=0.8,application/signed-exchange;v=b3;q=0.7",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("1", forHTTPHeaderField: "DNT")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("none", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        request.setValue(
            "\"Chromium\";v=\"136\", \"Google Chrome\";v=\"136\", " +
            "\"Not.A/Brand\";v=\"99\"",
            forHTTPHeaderField: "sec-ch-ua"
        )
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")

        do {
            let (data, _) = try await session.data(for: request)
            
            // PERFORMANCE TUNING
            if performanceTuningLog {
                let endTime = Date()
                let duration = (endTime.timeIntervalSince(startTime) * 100).rounded()/100
                print("Total fetchTracks for \(pilot.pilotName) execution time: \(duration) seconds")
                
            }
            return parseKML(pilotName: pilot.pilotName, data: data)
        } catch {
            print("Error fetching tracks for \(pilot.pilotName): \(error)")
            return []
        }
        
    }

    private func constructURL(
        trackingURL: String,
        days: Double
    ) -> URL? {
        let date = getDateForDays(days: days)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let dateString = iso.string(from: date)
        return URL(string: "\(trackingURL)?d1=\(dateString)")
    }

    private func parseKML(
        pilotName: String,
        data: Data
    ) -> [PilotTrack] {
        guard let xml = String(data: data, encoding: .utf8) else {
            return []
        }
        let placemarks = extractAllValues(
            from: xml,
            using: "<Placemark>",
            endTag: "</Placemark>"
        )
        guard !placemarks.isEmpty else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy h:mm:ss a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")

        return placemarks.compactMap { pm in
            guard
                var name = extractValue(
                    from: pm,
                    using: "<Data name=\"Name\">",
                    endTag: "</Data>"
                ),
                let timeStr = extractValue(
                    from: pm,
                    using: "<Data name=\"Time UTC\">",
                    endTag: "</Data>"
                ),
                let latStr = extractValue(
                    from: pm,
                    using: "<Data name=\"Latitude\">",
                    endTag: "</Data>"
                ),
                let lonStr = extractValue(
                    from: pm,
                    using: "<Data name=\"Longitude\">",
                    endTag: "</Data>"
                )
            else {
                return nil
            }

            if name.lowercased() != pilotName.lowercased() {
                name = "\(name) (\(pilotName))"
            }
            let dateTime = formatter.date(from: timeStr) ?? Date()
            let speedKM = extractNumber(
                from: extractValue(
                    from: pm,
                    using: "<Data name=\"Velocity\">",
                    endTag: "</Data>"
                ) ?? ""
            ) ?? 0
            let speed = convertKMToMiles(speedKM).rounded()
            let altM = extractNumber(
                from: extractValue(
                    from: pm,
                    using: "<Data name=\"Elevation\">",
                    endTag: "</Data>"
                ) ?? ""
            ) ?? 0
            let altitude = Double(convertMetersToFeet(altM))
            let course = extractNumber(
                from: extractValue(
                    from: pm,
                    using: "<Data name=\"Course\">",
                    endTag: "</Data>"
                ) ?? ""
            ) ?? 0
            let inEmg = Bool(
                extractValue(
                    from: pm,
                    using: "<Data name=\"In Emergency\">",
                    endTag: "</Data>"
                )?.lowercased() ?? "false"
            ) ?? false
            let message = extractValue(
                from: pm,
                using: "<Data name=\"Text\">",
                endTag: "</Data>"
            )

            return PilotTrack(
                pilotName: name,
                dateTime: dateTime,
                latitude: Double(latStr) ?? 0,
                longitude: Double(lonStr) ?? 0,
                speed: speed,
                altitude: altitude,
                heading: course,
                inEmergency: inEmg,
                message: message
            )
        }
    }

    private func extractAllValues(
        from text: String,
        using startTag: String,
        endTag: String
    ) -> [String] {
        var results: [String] = []
        var searchRange: Range<String.Index>? = text.startIndex..<text.endIndex
        while let start = text.range(of: startTag, range: searchRange),
              let end = text.range(of: endTag, range: start.upperBound..<text.endIndex)
        {
            let snippet = String(text[start.upperBound..<end.lowerBound])
            results.append(snippet)
            searchRange = end.upperBound..<text.endIndex
        }
        return results
    }

    private func extractValue(
        from text: String,
        using startTag: String,
        endTag: String
    ) -> String? {
        guard
            let start = text.range(of: startTag),
            let end = text.range(of: endTag, range: start.upperBound..<text.endIndex)
        else {
            return nil
        }
        let tagContents = String(text[start.upperBound..<end.lowerBound])
        guard
            let vStart = tagContents.range(of: "<value>"),
            let vEnd = tagContents.range(of: "</value>", range: vStart.upperBound..<tagContents.endIndex)
        else {
            return nil
        }
        return String(tagContents[vStart.upperBound..<vEnd.lowerBound])
    }

    // Async semaphore that suspends rather than blocks threads.
    actor AsyncSemaphore {
        private var available: Int
        private var waiters: [CheckedContinuation<Void, Never>] = []

        init(value: Int) {
            self.available = value
        }

        func wait() async {
            if available > 0 {
                available -= 1
            } else {
                await withCheckedContinuation { cont in
                    waiters.append(cont)
                }
            }
        }

        func signal() {
            if let cont = waiters.first {
                waiters.removeFirst()
                cont.resume()
            } else {
                available += 1
            }
        }
    }
}
