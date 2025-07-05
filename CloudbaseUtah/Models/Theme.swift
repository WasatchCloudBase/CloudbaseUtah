import SwiftUI
import UIKit
typealias PlatformColor = UIColor

// Title bar colors
let backgroundColor: Color = .black
let sunImageColor: Color = .sunshine
let sunFontColor: Color = .titanium
let titleFontColor: Color = .white
let titlebarSeparatorColor: Color = .darksky2

// Tool bar colors
let toolbarBackgroundColor: Color = .darksky2
let toolbarImageColor: Color = .sky
let toolbarFontColor: Color = .sky
let toolbarActiveImageColor: Color = .white
let toolbarActiveFontColor: Color = .white

// Navigation bar (e.g., next/back nodes on pilot track detail)
let navigationBackgroundColor: Color = .darksky

// View page colors
let rowHeaderColor: Color = .sky
let sectionHeaderColor: Color = .white
let infoFontColor: Color = .titanium
let warningFontColor: Color = .warning

// Skew-T chart colors
let skewTDALRColor: Color = .moodygray
let skewTDewpointColor: Color = .displayValueGreen
let skewTTempColor: Color = .displayValueRed
let skewTGridBorderColor: Color = .grayslime
let skewTGridLineColor: Color = .grayslime
let skewTAxisLabelColor: Color = .titanium
let skewTButtonBackgroundColor: Color = .darksky2
let skewTButtonTextColor: Color = .white

// Table and chart colors
let tableBackgroundColor: Color = .gunmetal
let tableSectionDividerColor: Color = .grayslime
let tableLabelFontColor: Color = .white  // table data color is white, and changed based on conditional formatting
let tableMajorDividerColor: Color = .titanium
let tableMinorDividerColor: Color = tableBackgroundColor
let chartGradientStartColor: Color = Color(.darkgray)
let chartGradientEndColor: Color = Color(.darkgray)
let chartLineColor: Color = .sky
let chartCurrentNodeColor: Color = .white

// Colors of forecast and reading values
let displayValueWhite: Color = .white
let displayValueBlue: Color = .displayValueBlue
let displayValueTeal: Color = .displayValueTeal
let displayValueGreen: Color = .displayValueGreen
let displayValueYellow: Color = .displayValueYellow
let displayValueOrange: Color = .displayValueOrange
let displayValueRed: Color = .displayValueRed
let repeatDateTimeColor: Color = .titanium

// Map page colors
let layersIconColor: Color = .sky
let layersTextColor: Color = .sky
let layersIconBackgroundColor: Color = .black
let loadingBarBackgroundColor: Color = .gunmetal
let loadingBarTextColor: Color = .titanium
let cameraAnnotationColor: Color = .white
let cameraAnnotationTextColor: Color = cameraAnnotationColor
//  siteAnnotationColor not defined here; it is established by the image
let siteAnnotationTextColor: UIColor = UIColor(.white)
//  pilotNodeAnnotationColor not defined here; it is established by pilot track colors
let pilotLabelNameTextColor: Color = .white
let pilotLabelDateTextColor: Color = .titanium
let pilotLabelAltTextColor: Color = .sky
let pilotEmergencyAnnotationColor: Color = .red
let pilotEmergencyAnnotationTextColor: Color = .poppy
let pilotTrackColor: Color = .white
let defaultAnnotationColor: Color = .black
let defaultAnnotationTextColor: Color = .white

// Pilot listing colors
let pilotActiveFontColor: Color = .white
let pilotInactiveFontColor: Color = .titanium

// Images
let windArrow: String = "arrow.up"
let layersImage: String = "square.3.layers.3d"
let playImage: String = "play.fill"
let pauseImage: String = "pause.fill"
let cameraAnnotationImage: String = "camera.circle"
let defaultAnnotationImage:  String = "questionmark"
let siteAnnotationImage: UIImage = UIImage(imageLiteralResourceName: "roundPGicon")
let pilotLaunchAnnotationImage: UIImage = UIImage(systemName: "play.fill")! // Could use "dot.circle", "paperplane.fill", "arrow.up.right.circle.fill"
let pilotLatestAnnotationImage: UIImage = UIImage(imageLiteralResourceName: "PGIconNoBorder") // Could use systemName: "flag.checkered")!
let pilotMessageAnnotationImage: UIImage = UIImage(systemName: "envelope.fill")! // Could use "bubble.fill"
let pilotInEmergencyAnnotationImage: UIImage = UIImage(systemName: "exclamationmark.triangle.fill")!

// Pilot track log colors
// (assigned dynamically to differentiate pilot tracks on map)
let pilotColorPalette: [PlatformColor] = [
    PlatformColor(.electric),
    PlatformColor(.champion),
    PlatformColor(.apple),
    PlatformColor(.poppy),
    PlatformColor(.periwinkle),
    PlatformColor(.orangetheme),
    PlatformColor(.magentatheme),
    PlatformColor(.bubblegum),
    PlatformColor(.slime),
    PlatformColor(.buttercup),
    PlatformColor(.tealtheme),
    PlatformColor(.jolt),
    PlatformColor(.brightlime),
    PlatformColor(.bluesky),
    PlatformColor(.purplerain),
    PlatformColor(.barbi)
]
