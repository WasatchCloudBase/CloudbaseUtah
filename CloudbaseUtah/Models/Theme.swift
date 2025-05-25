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

// Map page colors and format
let layersIconColor: Color = toolbarImageColor
let layersFontColor: Color = toolbarFontColor
let layersIconBackgroundColor: Color = .black
let cameraAnnotationColor: Color = .sky
let cameraAnnotationTextColor: Color = cameraAnnotationColor
//  siteAnnotationColor not defined here; it is established by the image
let siteAnnotationTextColor: UIColor = UIColor(.white)
let stationAnnotationColor: Color = .gunmetal
let stationAnnotationTextColor: UIColor = UIColor(.gunmetal)
let pilotNodeAnnotationColor: UIColor = UIColor(.white)
let pilotLabelBackgroundColor: UIColor = UIColor.black.withAlphaComponent(0.2)
let pilotLabelNameTextColor: UIColor = UIColor(.white)
let pilotLabelDateTextColor: UIColor = UIColor(.titanium)
let pilotLabelAltTextColor: UIColor = UIColor(.sky)
let pilotEmergencyAnnotationTextColor: UIColor = UIColor(.poppy)
let pilotTrackColor: UIColor = UIColor(.white)
let pilotTrackWidth: CGFloat = 1
let clusterAnnotationColor: UIColor = UIColor(stationAnnotationColor)
let defaultAnnotationColor: UIColor = UIColor(.black)
let defaultAnnotationTextColor: UIColor = UIColor(.white)

// Images
let defaultAnnotationImageWidth: CGFloat = 50
let pilotNodeAnnotationImageWidth: CGFloat = 20
let pilotLaunchAnnotationImageWidth: CGFloat = 40
let pilotLatestAnnotationImageWidth: CGFloat = 40
let windArrow: String = "arrow.up"
let layersImage: String = "square.3.layers.3d"
let playImage: String = "play.fill"
let pauseImage: String = "pause.fill"
let cameraAnnotationImage: String = "camera.circle"
let defaultAnnotationUIImage:  UIImage = UIImage(systemName: "questionmark")!
let siteAnnotationUIImage: UIImage = UIImage(named: "roundPGicon")?.scaled(toWidth: defaultAnnotationImageWidth)
        ?? defaultAnnotationUIImage
let pilotLaunchAnnotationUIImage: UIImage = UIImage(systemName: "arrow.up.right.circle.fill")?.scaled(toWidth: pilotLaunchAnnotationImageWidth)
        ?? defaultAnnotationUIImage
let pilotNodeAnnotationUIImage: UIImage = {
    if let image = UIImage(systemName: "inset.filled.circle")?.withRenderingMode(.alwaysOriginal).scaled(toWidth: pilotNodeAnnotationImageWidth) {
        return tintedImage(image, color: UIColor(.white))
    } else { return defaultAnnotationUIImage } } ()
let pilotLatestAnnotationUIImage: UIImage = UIImage(named: "PGIconNoBorder")?.scaled(toWidth: pilotLatestAnnotationImageWidth)
        ?? defaultAnnotationUIImage
let pilotMessageAnnotationUIImage: UIImage = UIImage(systemName: "bubble.fill")?.scaled(toWidth: defaultAnnotationImageWidth)
        ?? defaultAnnotationUIImage

