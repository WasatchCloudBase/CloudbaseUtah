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
let buttonBackgroundColor: Color = .darksky2
let buttonTextColor: Color = .white
let buttonWidth: CGFloat = 100

// Table and chart colors
let tableBackgroundColor: Color = .gunmetal //Color(.secondarySystemBackground)   //.darkgray
let tableSectionDividerColor: Color = .grayslime
let tableLabelFontColor: Color = .white  // table data color is white, and changed bsaed on conditional formatting
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
let cameraAnnotationColor: Color = .sky
let cameraAnnotationTextColor: Color = cameraAnnotationColor
//  siteAnnotationColor is not defined here; it is established by the image
let siteAnnotationTextColor: UIColor = UIColor(.pgiconblue)
//  stationAnnotationColor not defined here; it is built dynamically based on wind speed
let stationAnnotationTextColor: UIColor = UIColor(.orangetheme)
//  pilotAnnotationColor is not define here; it is established by the image
let pilotAnnotationTextColor: UIColor = .white
let clusterAnnotationColor: UIColor = stationAnnotationTextColor
let defaultAnnotationColor: UIColor = UIColor(.black)
let defaultAnnotationTextColor: UIColor = UIColor(.white)

// Images
let defaultAnnotationImageWidth: CGFloat = 60
let windArrow: String = "arrow.up"  // options are:  arrowshape.up.fill, arrow.up, arrow.up.circle.fill, arrow.up.circle, arrow.up.circle.dotted, arrowshape.up.circle
let layersImage: String = "square.3.layers.3d"
let playImage: String = "play.fill"
let pauseImage: String = "pause.fill"
let cameraAnnotationImage: String = "camera.circle"
let siteAnnotationUIImage: UIImage = UIImage(named: "roundPGicon")?.scaled(toWidth: defaultAnnotationImageWidth) ?? UIImage(named: "questionmark")!
//  stationAnnotationImage not defined here; it is built dynamically based on wind speed/direction
let pilotAnnotationUIImage: UIImage = UIImage(named: "PGIconNoBorder")?.scaled(toWidth: defaultAnnotationImageWidth) ?? UIImage(named: "questionmark")!
let defaultAnnotationImage: String = "questionmark"
