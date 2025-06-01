import SwiftUI
import Combine
import Foundation

// Set development build flags
let devMenuAvailable: Bool = true
let turnOnLogging: Bool = false
let printForecastURL: Bool = false

// Set global constants
enum NavBarSelectedView:Int {
    case site = 0
    case weather = 1
    case map = 2
    case pilotmap = 3
    case webcam = 4
    case link = 5
    case dev = 9
}
let googleSpreadsheetID = "1s72R3YCHxNIJVLVa5nmsTphRpqRsfG2QR2koWxE19ls"
let googleApiKey = "AIzaSyDSro1lDdAQsNEZq06IxwjOlQQP1tip-fs"

let sunriseLatitude: Double = 40.7862                   // SLC airport coordinates
let sunriseLongitude: Double = -111.9801
let mapInitLatitude: Double = 39.72                     // Center point for map on initial opening
let mapInitLongitude: Double = -111.45
let mapInitLatitudeSpan: Double = 7.2                   // Size of map on initial opening
let mapInitLongitudeSpan: Double = 5.2                  //mapInitLatitudeSpan * 1.5
let defaultMapZoomLevel: Double = 6.7
let mapShowAllMarkersZoomLevel: Double = 10
let stationSpacingBaseThreshold: Double = 0.01          // Larger number will reduce the number of stations displayed
let stationSpacingZoomFactor: Double = 700              // Larger number will reduce number of stations displayed
let mapBatchProcessingInterval: Double = 0.2
let mapScaleChangeTolerance: Double = 0.01              // Don't refresh annotation filtering for minor scale changes
let annotationDuplicateTolerance = 0.0001
let mapClusterThresholdFactor = 0.1                     // Initial value was 0.1
let mapEnableRotation: Bool = false
let skewTButtonWidth: CGFloat = 100

let defaultTopOfLiftAltitude = 18000.0                  // Use in lift area graph when top of lift isn't reached in calculations
let pageRefreshInterval: TimeInterval = 150             // Time in seconds to refresh wind readings (300 for 5 min)
let defaultPilotTrackDays: Double = 1.0                 // Default days of live tracking to display
let defaultActiveLayers: Set<MapLayer> = [.pilots]

// HTTP links and APIs
let forecastUSMapLink: String = "https://www.wpc.ncep.noaa.gov/basicwx/92fndfd.gif"
let weatherAlertsAPI: String = "https://api.weather.gov/alerts/active?area=UT"
let weatherAlertsLink: String = "https://www.weather.gov/slc/WWA"
let TFRAPI: String = "https://tfr.faa.gov/tfrapi/exportTfrList"
let forecastDiscussionLink: String = "https://forecast.weather.gov/product.php?site=NWS&issuedby=SLC&product=AFD&format=txt&version=1&glossary=0"
let soaringForecastLink: String = "https://forecast.weather.gov/product.php?site=NWS&product=SRG&issuedby=SLC"
let skewTLink: String = "https://www.weather.gov/zse/ModelSounding?id=kslc&model=hrrr"
// prior skewTLink: String = "https://weather.ral.ucar.edu/upper/displayUpper.php?img=KSLC.png&endDate=-1&endTime=-1&duration=0"
let uDOTCamerasAPI: String = "https://www.udottraffic.utah.gov/api/v2/get/cameras?key=6035b1d6b660471a89c9b0c0804a584b&format=json"
let uDOTCamerasLink: String = "https://www.udottraffic.utah.gov"
let cloudbaseUtahGitLink: String = "https://github.com/WasatchCloudBase/CloudbaseUtah"
let cloudbaseUtahGoogleSheetLink: String = "https://docs.google.com/spreadsheets/d/1s72R3YCHxNIJVLVa5nmsTphRpqRsfG2QR2koWxE19ls/edit?gid=0#gid=0"
let ipCamLink: String = "https://apps.apple.com/us/app/ip-camera-viewer-ipcams/id1045600272"
let UHGPGAcamsLink: String = "https://www.uhgpga.org/webcams"

// Build APIs for Mesowest weather readings
// latestReadings API is header + parameters (stations; can be blank) + trailer + token
let latestReadingsAPIHeader = "https://api.mesowest.net/v2/station/latest?"
let latestReadingsAPITrailer =  "&recent=420&vars=air_temp,altimeter,wind_direction,wind_gust,wind_speed&units=english,speed|mph,temp|F&within=120&obtimezone=local&timeformat=%-I:%M%20%p"
// historyReadings API is header + parameters (station) + trailer + token
let historyReadingsAPIHeader = "https://api.mesowest.net/v2/station/timeseries?"
let historyReadingsAPITrailer = "&recent=420&vars=air_temp,wind_direction,wind_gust,wind_speed&units=english,speed|mph,temp|F&within=120&obtimezone=local&timeformat=%-I:%M %p"
let mesowestAPIToken = "&token=ef3b9f4584b64e6da12d8688f19d9f4a"

// Grid structure sizing parameters
let headingHeight: CGFloat = 16                                 // Day, date, time rows
let imageHeight: CGFloat = 38                                   // Weather skies image
let dataHeight: CGFloat = 22
let labelHeight: CGFloat = 22                                   // Wind, Lift label rows
let doubleHeight: CGFloat = dataHeight * 2                      // Surface wind + gust combined
var areaChartHeight: CGFloat = 0                                // ToL area chart height calculated below
let areaChartPaddingHeight: CGFloat = 0                         // Adjustment to reflect spacing between table rows
let imageScalingFactor: CGFloat = 0.5                           // Weather skies image
let windArrowSpacing: CGFloat = 3                               // Space between wind speed and direction arrow
let dateChangeDividerSize: CGFloat = 1
let areaChartOpacity: CGFloat = 0.5

// Map parameters
let annotationTextWidth: CGFloat = 60
let annotationTextHeight: CGFloat = 4
let stationAnnotationWidth: CGFloat = 40
let stationAnnotationHeight: CGFloat = 22
let defaultAnnotationImageWidth: CGFloat = 50
let pilotNodeAnnotationImageWidth: CGFloat = 20
let pilotLaunchAnnotationImageWidth: CGFloat = 40
let pilotLatestAnnotationImageWidth: CGFloat = 40
let pilotNodeAnnotationTextWidth: CGFloat = 56
let pilotNodeAnnotationTextOneRowHeight: CGFloat = 16
let pilotNodeAnnotationTextThreeRowHeight: CGFloat = pilotNodeAnnotationTextOneRowHeight * 3
let pilotNodeLabelThreeRowSpan: CGFloat = 0.08                   // Map scale that determines when to display time/altitude for each node
