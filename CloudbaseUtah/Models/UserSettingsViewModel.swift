import SwiftUI
import Combine
import MapKit

enum MapDisplayMode {
    case weather
    case tracking
}

// Custom Map Style
enum CustomMapStyle: String, CaseIterable {
    case standard, hybrid

    // Conversion to Maptype (for MKMapView)
    func toMapType() -> MKMapType {
        switch self {
        case .standard:
            return .standard
        case .hybrid:
            return .hybrid
        }
    }
}

struct UserFavoriteSite: Identifiable, Equatable {
    let id = UUID()
    let favoriteType: String    // Station or Site
    let favoriteID: String      // site name or station name
    let favoriteName: String    // User specified
    let readingsSource: String  // for stations only (used to build mock site for favorites)
    let stationID: String       // for stations only
    let readingsAlt: String     // for stations only
    var siteLat: String         // for stations only
    var siteLon: String         // for stations only
    let sortSequence: Int       // allows user to re-sort favorites
}

class UserSettingsViewModel: ObservableObject {
    @Published var region: MKCoordinateRegion
    @Published var selectedMapType: CustomMapStyle
    @Published var pilotTrackDays: Double
    @Published var mapDisplayMode: MapDisplayMode
    @Published var showSites: Bool
    @Published var showStations: Bool
    @Published var showRadar: Bool
    @Published var showInfrared: Bool
    @Published var radarColorScheme: Int
    @Published var selectedPilots: [Pilot]
    @Published var userFavoriteSites: [UserFavoriteSite]
    
    init(region: MKCoordinateRegion,
         selectedMapType: CustomMapStyle = defaultmapType,
         pilotTrackDays: Double = defaultPilotTrackDays,
         mapDisplayMode: MapDisplayMode = defaultmapDisplayMode,
         showSites: Bool = defaultShowSites,
         showStations: Bool = defaultShowStations,
         showRadar: Bool = defaultShowRadar,
         showInfrared: Bool = defaultShowInfrared,
         radarColorSchme: Int = defaultRadarColorScheme,
         selectedPilots: [Pilot] = [],
         userFavoriteSites: [UserFavoriteSite] = []
    ) {
        self.region = region
        self.selectedMapType = selectedMapType
        self.pilotTrackDays = pilotTrackDays
        self.mapDisplayMode = mapDisplayMode
        self.showSites = showSites
        self.showStations = showStations
        self.showRadar = showRadar
        self.showInfrared = showInfrared
        self.radarColorScheme = radarColorSchme
        self.selectedPilots = selectedPilots
        self.userFavoriteSites = userFavoriteSites
    }
    
    var isMapWeatherMode: Bool { mapDisplayMode == .weather }
    var isMapTrackingMode: Bool { mapDisplayMode == .tracking }
    var isMapDisplayingSites: Bool { mapDisplayMode == .weather && showSites }
    var isMapDisplayingStations: Bool { mapDisplayMode == .weather && showStations }
    var isMapDisplayingRadar: Bool { mapDisplayMode == .weather && showRadar }
    var isMapDisplayingInfrared: Bool { mapDisplayMode == .weather && showInfrared }
    
    // Functions to manage favorites
    
    enum FavoriteSiteError: Error, LocalizedError {
        case alreadyExists
        case notFound
        
        var errorDescription: String? {
            switch self {
            case .alreadyExists: return "Favorite already exists."
            case .notFound: return "Favorite not found."
            }
        }
    }
    
    func addFavorite(
        favoriteType: String,
        favoriteID: String,
        favoriteName: String,
        readingsSource: String,
        stationID: String,
        readingsAlt: String,
        siteLat: String,
        siteLon: String
    ) throws {
        // Check for duplicates
        if userFavoriteSites.contains(where: {
            $0.favoriteType == favoriteType && $0.favoriteID == favoriteID
        }) {
            throw FavoriteSiteError.alreadyExists
        }
        
        // Compute the next sortSequence
        let nextSequence = (userFavoriteSites.map { $0.sortSequence }.max() ?? 0) + 1
        
        // Build and append the new favorite
        let newFavorite = UserFavoriteSite(
            favoriteType:   favoriteType,
            favoriteID:     favoriteID,
            favoriteName:   favoriteName,
            readingsSource: readingsSource,
            stationID:      stationID,
            readingsAlt:    readingsAlt,
            siteLat:        siteLat,
            siteLon:        siteLon,
            sortSequence:   nextSequence
        )
        userFavoriteSites.append(newFavorite)
    }
    func removeFavorite(favoriteType: String, favoriteID: String) throws {
        guard let index = userFavoriteSites.firstIndex(where: {
            $0.favoriteType == favoriteType && $0.favoriteID == favoriteID
        }) else {
            throw FavoriteSiteError.notFound
        }
        
        userFavoriteSites.remove(at: index)
    }
    
    func updateFavorite(
        favoriteType: String,
        favoriteID: String,
        favoriteName: String,
        readingsSource: String,
        stationID: String,
        readingsAlt: String,
        siteLat: String,
        siteLon: String,
        sortSequence newSequence: Int
    ) throws {
        // Locate the existing favorite
        guard let oldIndex = userFavoriteSites.firstIndex(where: {
            $0.favoriteType == favoriteType && $0.favoriteID == favoriteID
        }) else {
            throw FavoriteSiteError.notFound
        }
        
        // Remove it from the list temporarily
        _ = userFavoriteSites.remove(at: oldIndex)
        
        // Shift all favorites whose sequence is ≥ newSequence
        userFavoriteSites = userFavoriteSites.map { fav in
            if fav.sortSequence >= newSequence {
                // bump them up by one
                return UserFavoriteSite(
                    favoriteType:   fav.favoriteType,
                    favoriteID:     fav.favoriteID,
                    favoriteName:   fav.favoriteName,
                    readingsSource: fav.readingsSource,
                    stationID:      fav.stationID,
                    readingsAlt:    fav.readingsAlt,
                    siteLat:        fav.siteLat,
                    siteLon:        fav.siteLon,
                    sortSequence:   fav.sortSequence + 1
                )
            } else {
                return fav
            }
        }
        
        // Build the updated favorite at its new sequence
        let updatedFavorite = UserFavoriteSite(
            favoriteType:   favoriteType,
            favoriteID:     favoriteID,
            favoriteName:   favoriteName,
            readingsSource: readingsSource,
            stationID:      stationID,
            readingsAlt:    readingsAlt,
            siteLat:        siteLat,
            siteLon:        siteLon,
            sortSequence:   newSequence
        )
        
        // Re-insert it
        userFavoriteSites.append(updatedFavorite)
        
        // Sort array by sortSequence so in-memory order matches
        userFavoriteSites.sort { $0.sortSequence < $1.sortSequence }
    }
}

// Composite structure to check for all map settings and view changes together
// and only rebuild annotations once if there are multiple changes
struct MapSettingsState: Equatable {
    let pilotTrackDays: Double
    let mapDisplayMode: MapDisplayMode
    let showSites: Bool
    let showStations: Bool
    let showRadar: Bool
    let showInfrared: Bool
    let radarColorScheme: Int
    let scenePhase: ScenePhase
    let selectedPilots: [Pilot]
}
