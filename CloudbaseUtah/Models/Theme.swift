import SwiftUI

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
let chartGradientStartColor: Color = Color(.tertiarySystemBackground)
let chartGradientEndColor: Color = Color(.tertiarySystemBackground)
let chartLineColor: Color = .sky

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
let layersIconColor: Color = toolbarImageColor
let layersFontColor: Color = toolbarFontColor
let layersIconBackgroundColor: Color = .black
let cameraAnnotationColor: Color = .white
let cameraAnnotationTextColor: Color = cameraAnnotationColor
//  siteAnnotationColor not defined here; it is established by the image
let siteAnnotationTextColor: Color = .white
let stationAnnotationColor: Color = .gunmetal
let stationAnnotationTextColor: Color = .gunmetal
let pilotNodeAnnotationColor: Color = .white
let pilotLabelBackgroundColor: Color = .black //.withAlphaComponent(0.2)
let pilotLabelNameTextColor: Color = .white
let pilotLabelDateTextColor: Color = .titanium
let pilotLabelAltTextColor: Color = .sky
let pilotEmergencyAnnotationColor: Color = .red
let pilotEmergencyAnnotationTextColor: Color = .poppy
let pilotTrackColor: Color = .white
let defaultAnnotationColor: Color = .black
let defaultAnnotationTextColor: Color = .white

// Images
let windArrow: String = "arrow.up"
let layersImage: String = "square.3.layers.3d"
let playImage: String = "play.fill"
let pauseImage: String = "pause.fill"
let cameraAnnotationImage: String = "camera.circle"
let defaultAnnotationImage:  String = "questionmark"
let siteAnnotationImage: String = "roundPGicon"
let pilotLaunchAnnotationImage: String = "paperplane.fill" // Could use arrow.up.right.circle.fill"
let pilotLatestAnnotationImage: String = "flag.checkered"  // Needs to be system image based on current code.  "PGIconNoBorder"
let pilotMessageAnnotationImage: String = "envelope.fill"  // Could use "bubble.fill"
let pilotInEmergencyAnnotationImage: String = "exclamationmark.triangle.fill"

// Pilot track log colors
// (assigned dynamically to differentiate pilot tracks on map)
let pilotColorPalette: [UIColor] = [
    UIColor(.electric),
    UIColor(.champion),
    UIColor(.bubblegum),
    UIColor(.poppy),
    UIColor(.periwinkle),
    UIColor(.orangetheme),
    UIColor(.magentatheme),
    UIColor(.slime),
    UIColor(.darkgray)
]
