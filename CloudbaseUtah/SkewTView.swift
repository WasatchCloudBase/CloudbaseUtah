import SwiftUI
import Foundation

struct SkewTDataPoint: Decodable, CustomStringConvertible {
    var Temp_c: Double
    var Dewpoint_c: Double
    var Altitude_m: Double
    var description: String { "Temp_c: \(Temp_c), Dewpoint_c: \(Dewpoint_c), Altitude_m: \(Altitude_m)" }
}

struct SkewTLiftParameters {
    var tol: Double
    var tolTemp: Double
    var neg3: Double
    var neg3Temp: Double
}

// Array safe access extension (indexing safeguard)
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

class SkewTChartManager: ObservableObject {
    var soaringForecastViewModel: SoaringForecastViewModel?
    @Published var dalrFlag = 0
    let surfaceAlt: Double = 4.229
    let maxAlt: Double = 20
    let dalr: Double = 5.4
    let screenWidth: CGFloat = UIScreen.main.bounds.width
    var proportionalHeight: CGFloat { screenWidth * 0.67 }
    
    var margin: (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat) {
        (top: proportionalHeight * 0.06,
         bottom: proportionalHeight * 0.06,
         left: screenWidth * 0.14,
         right: screenWidth * 0.08)
    }
    
    var width: CGFloat { screenWidth - margin.left - margin.right }
    var height: CGFloat { proportionalHeight - margin.top - margin.bottom }
    
    // Scale functions
    func x(_ value: Double) -> CGFloat {
        // Domain [-10, 110] mapped to range [0, width]
        return CGFloat((value + 10) / 120 * Double(width)) + margin.left
    }
    func y(_ value: Double) -> CGFloat {
        // Domain [surfaceAlt, maxAlt] mapped to range [height, 0]
        return CGFloat(height - ((value - surfaceAlt) / (maxAlt - surfaceAlt) * Double(height))) + margin.top
    }
    
    // Data and lift parameters
    @Published var skewTSoundingData: [SkewTDataPoint] = []
    @Published var skewTLiftParameters: SkewTLiftParameters = SkewTLiftParameters(tol: 0, tolTemp: 0, neg3: 0, neg3Temp: 0)
    @Published var maxTempF: Double = 0
    
    // Draw DALR parameters
    func drawDALRParams(temp: Double, params: SkewTLiftParameters, context: inout GraphicsContext) {
        
        // Max temp for the day DALR line
        var dalrLine = Path()
        dalrLine.move(to: CGPoint(x: x(temp - (maxAlt - surfaceAlt) * dalr), y: y(maxAlt)))
        dalrLine.addLine(to: CGPoint(x: x(temp), y: y(surfaceAlt)))
        context.stroke(dalrLine, with: .color(skewTDALRColor), lineWidth: 1)
        
        // -3 index line
        var neg3Line = Path()
        neg3Line.move(to: CGPoint(x: x((params.neg3Temp * 9 / 5) + 32), y: y(params.neg3 * 3.28084 / 1000)))
        neg3Line.addLine(to: CGPoint(x: x((params.neg3Temp * 9 / 5) + 32 - 5.4), y: y(params.neg3 * 3.28084 / 1000)))
        context.stroke(neg3Line, with: .color(.white), lineWidth: 2)
        let neg3Label = Text("-3")
            .font(.subheadline)
        context.draw(neg3Label, at: CGPoint(x: x((params.neg3Temp * 9 / 5) + 32 + 6), y: y(params.neg3 * 3.284084 / 1000)))
        
        // Top of lift point
        let tolCircleCenter = CGPoint(x: x((params.tolTemp * 9 / 5) + 32), y: y(params.tol * 3.284084 / 1000))
        let tolCircle = Path(ellipseIn: CGRect(x: tolCircleCenter.x - 3, y: tolCircleCenter.y - 3, width: 6, height: 6))
        context.fill(tolCircle, with: .color(.white))
        let tolLabel = Text("ToL")
            .font(.subheadline)
        context.draw(tolLabel, at: CGPoint(x: x((params.tolTemp * 9 / 5) + 32 + 8), y: y(params.tol * 3.284084 / 1000)))
    }
    
    // Read user input and updates chart parameters
    func d3Update(userTemp: Double) {
print("1")
        DispatchQueue.main.async {
print("2")
            if self.skewTSoundingData.count > 1 {
                let threshold = (self.skewTSoundingData[1].Temp_c * 9 / 5) + 32 + 5.4
print("threshold: \(threshold)")
print("userTemp: \(userTemp)")
                if userTemp > threshold && userTemp < 120 {
                    let userSkewTLiftParameters = self.getSkewTLiftParameters(temp: userTemp, data: self.skewTSoundingData)
                    self.dalrFlag = 1
                    self.d3Clear()
                    self.skewTLiftParameters = userSkewTLiftParameters
                    self.dalrFlag = 0
                } else {
                    self.d3Clear()
                }
            }
        }
    }
    
    // Reset dynamic parameters
    func d3Clear() {
        if dalrFlag == 0 {
            skewTLiftParameters = getSkewTLiftParameters(temp: maxTempF, data: skewTSoundingData)
        }
    }
    
    // Calculate SkewT lift parameters
    func getSkewTLiftParameters(temp: Double, data: [SkewTDataPoint], position: Int = 0, raobSlope: Double? = nil, raobYInt: Double? = nil, params: SkewTLiftParameters? = nil) -> SkewTLiftParameters {
        var pos = position
        var skewTLiftParameters = params ?? SkewTLiftParameters(tol: 0, tolTemp: 0, neg3: 0, neg3Temp: 0)
        let tempC = (temp - 32) * 5 / 9
        let surfaceAlt_m = 1289.0
        let dalrSlope = -101.6
        let dalrYInt = surfaceAlt_m - (dalrSlope * tempC)
        
        // Find height of -3 index first
        while pos < data.count && (data[pos].Temp_c - ((data[pos].Altitude_m - dalrYInt) / dalrSlope)) < -3 {
            pos += 1
        }
        var interpolateX1 = data[pos].Temp_c
        var interpolateY1 = data[pos].Altitude_m
        var interpolateX2 = 0.0
        var interpolateY2 = 0.0
        if pos > 0 {
            interpolateX2 = data[pos - 1].Temp_c
            interpolateY2 = data[pos - 1].Altitude_m
        }
        if interpolateX1 != interpolateX2 {
            let computedRaobSlope = (interpolateY1 - interpolateY2) / (interpolateX1 - interpolateX2)
            let computedRaobYInt = interpolateY1 - (computedRaobSlope * interpolateX1)
            let interpolateX = (computedRaobYInt - dalrYInt - (3 * dalrSlope)) / (dalrSlope - computedRaobSlope)
            skewTLiftParameters.neg3 = interpolateY1 + (interpolateX - interpolateX1) * (interpolateY2 - interpolateY1) / (interpolateX2 - interpolateX1)
        } else {
            skewTLiftParameters.neg3 = (interpolateX1 + 3) * dalrSlope + dalrYInt
        }
        skewTLiftParameters.neg3Temp = (skewTLiftParameters.neg3 - dalrYInt) / dalrSlope
        
        // Now find top of lift point (thermal index is 0)
        while pos < data.count && (data[pos].Temp_c - ((data[pos].Altitude_m - dalrYInt) / dalrSlope)) < 0 {
            pos += 1
        }
        interpolateX1 = data[pos].Temp_c
        interpolateY1 = data[pos].Altitude_m
        interpolateX2 = 0.0
        interpolateY2 = 0.0
        if pos > 0 {
            interpolateX2 = data[pos - 1].Temp_c
            interpolateY2 = data[pos - 1].Altitude_m
        }
        if interpolateX1 != interpolateX2 {
            let computedRaobSlope = (interpolateY1 - interpolateY2) / (interpolateX1 - interpolateX2)
            let computedRaobYInt = interpolateY1 - (computedRaobSlope * interpolateX1)
            skewTLiftParameters.tol = ((dalrSlope * computedRaobYInt) - (computedRaobSlope * dalrYInt)) / (dalrSlope - computedRaobSlope)
        } else {
            skewTLiftParameters.tol = (interpolateX1 * dalrSlope) + dalrYInt
        }
        skewTLiftParameters.tolTemp = (skewTLiftParameters.tol - dalrYInt) / dalrSlope
        return skewTLiftParameters
    }
    
    // populateSoaringForecast() async function equivalent using URLSession
    func populateSoaringForecast() {
        
        // Use soaringForecastViewModel to get forecast max temp
        if let forecastMaxTemp = soaringForecastViewModel?.soaringForecast?.forecastMaxTemp {
            self.maxTempF = Double(forecastMaxTemp)
        } else {
            self.maxTempF = 0 // Default value if not available
        }

        // Get sounding data
        let soundingURL = URL(string: "https://storage.googleapis.com/wasatch-wind-static/raob.json")!
        URLSession.shared.dataTask(with: soundingURL) { data2, response2, error2 in
            if let data2 = data2 {
                if let jsonData = try? JSONSerialization.jsonObject(with: data2) as? [[String: Any]] {
                    let decodedData = jsonData.compactMap { dict -> SkewTDataPoint? in
                        if let Temp_c = dict["Temp_c"] as? Double,
                           let Dewpoint_c = dict["Dewpoint_c"] as? Double,
                           let Altitude_m = dict["Altitude_m"] as? Double {
                            return SkewTDataPoint(Temp_c: Temp_c, Dewpoint_c: Dewpoint_c, Altitude_m: Altitude_m)
                        }
                        return nil
                    }
                    DispatchQueue.main.async {
                        self.skewTSoundingData = decodedData
                        self.skewTLiftParameters = self.getSkewTLiftParameters(temp: self.maxTempF, data: decodedData)
                    }
                }
            }
        }.resume()
    }
}

struct SkewTChartView: View {
    @StateObject var manager = SkewTChartManager()
    @ObservedObject private var soaringForecastViewModel = SoaringForecastViewModel()   // Used to get max surface temp for the day
    @State private var userTemp: String = ""
    
    var body: some View {
        VStack {
            
            // Canvas for the skew-T chart drawing
            Canvas { context, size in
                // Set vertical x axis gridlines
                let xAxisTicks = stride(from: -10.0, through: 110.0, by: 5.0)
                for tick in xAxisTicks {
                    var line = Path()
                    let start = CGPoint(x: manager.x(tick), y: manager.y(4.2))
                    let end = CGPoint(x: manager.x(tick), y: 0 )
                    line.move(to: start)
                    line.addLine(to: end)
                    context.stroke(line, with: .color(skewTGridLineColor), lineWidth: 0.5)
                }
                
                // Set horizontal y axis gridlines
                let yAxisTicks = stride(from: manager.surfaceAlt, through: Double(manager.maxAlt + 2), by: 1.0)
                for tick in yAxisTicks {
                    var line = Path()
                    let start = CGPoint(x: manager.x(-10), y: manager.y(tick))
                    let end = CGPoint(x: manager.x(110), y: manager.y(tick))
                    line.move(to: start)
                    line.addLine(to: end)
                    context.stroke(line, with: .color(skewTGridLineColor), lineWidth: 0.5)
                }
                
                // Draw skewed border line
                var skewLine = Path()
                skewLine.move(to: CGPoint(x: manager.x(110), y: manager.y(manager.surfaceAlt)))
                skewLine.addLine(to: CGPoint(x: manager.x(25), y: manager.y(21)))
                context.stroke(skewLine, with: .color(skewTGridBorderColor), lineWidth: 1)
                
                // Plot Temp line
                if !manager.skewTSoundingData.isEmpty {
                    var tempPath = Path()
                    var firstPoint = true
                    for d in manager.skewTSoundingData {
                        let xVal = manager.x((d.Temp_c * 9 / 5) + 32)
                        let yVal = manager.y(d.Altitude_m * 3.28084 / 1000)
                        let point = CGPoint(x: xVal, y: yVal)
                        if firstPoint {
                            tempPath.move(to: point)
                            firstPoint = false
                        } else {
                            tempPath.addLine(to: point)
                        }
                    }
                    context.stroke(tempPath, with: .color(skewTTempColor), lineWidth: 1)
                }
                
                // Plot Dewpoint line
                if !manager.skewTSoundingData.isEmpty {
                    var dewPath = Path()
                    var firstPoint = true
                    for d in manager.skewTSoundingData {
                        let xVal = manager.x((d.Dewpoint_c * 9 / 5) + 32)
                        let yVal = manager.y(d.Altitude_m * 3.28084 / 1000)
                        let point = CGPoint(x: xVal, y: yVal)
                        if firstPoint {
                            dewPath.move(to: point)
                            firstPoint = false
                        } else {
                            dewPath.addLine(to: point)
                        }
                    }
                    context.stroke(dewPath, with: .color(skewTDewpointColor), lineWidth: 1)
                }
                
                // Draw DALR parameters using manager function
                manager.drawDALRParams(temp: manager.maxTempF, params: manager.skewTLiftParameters, context: &context)
                
                // Draw blank rectangle to cover temp and dewpoint lines above chart
                var rectPath = Path()
                 rectPath.addRect(CGRect(x: 0,
                 y: 0,
                 width: manager.width + manager.margin.left + manager.margin.right,
                 height: manager.margin.top - 4))
                context.fill(rectPath, with: .color(tableBackgroundColor))
                
                // Draw blank rectangle to cover temp and dewpoint lines left of chart
                rectPath.addRect(CGRect(x: 0,
                y: 0,
                width: manager.margin.left,
                height: manager.height + manager.margin.top + manager.margin.bottom))
                context.fill(rectPath, with: .color(tableBackgroundColor))
                
                // Draw blank polygon to cover upper right grid
                var polyPath = Path()
                polyPath.move(to: CGPoint(x: manager.x(25), y: 0))
                polyPath.addLine(to: CGPoint(x: manager.margin.left + manager.width, y: manager.y(manager.surfaceAlt)))
                polyPath.addLine(to: CGPoint(x: manager.margin.left + manager.width + manager.margin.right, y: manager.y(manager.surfaceAlt)))
                polyPath.addLine(to: CGPoint(x: manager.margin.left + manager.width + manager.margin.right, y: 0))
                polyPath.closeSubpath()
                context.fill(polyPath, with: .color(tableBackgroundColor))
                
                // Draw x axis
                var xAxis = Path()
                xAxis.move(to: CGPoint(x: manager.x(-10), y: manager.y(manager.surfaceAlt)))
                xAxis.addLine(to: CGPoint(x: manager.x(110), y: manager.y(manager.surfaceAlt)))
                context.stroke(xAxis, with: .color(skewTGridBorderColor), lineWidth: 1)
                // x axis tick labels
                for tick in stride(from: -10.0, through: 110.0, by: 10.0) {
                    let label = Text("\(Int(tick))°")
                        .font(.footnote)
                        .foregroundStyle(skewTAxisLabelColor)
                    context.draw(label, at: CGPoint(x: manager.x(tick), y: manager.y(manager.surfaceAlt) + 10))
                }
                
                // Draw y axis
                var yAxis = Path()
                yAxis.move(to: CGPoint(x: manager.x(-10), y: manager.y(manager.surfaceAlt)))
                yAxis.addLine(to: CGPoint(x: manager.x(-10), y: manager.y(manager.maxAlt)))
                context.stroke(yAxis, with: .color(skewTGridBorderColor), lineWidth: 1)
                // y axis tick labels (adding 2 in order to skip a label through the y-axis and ensure the top of the chart is labelled
                for tick in stride(from: manager.surfaceAlt + 2, through: Double(manager.maxAlt + 2), by: 2.0) {
                    let label = Text("\(Int(tick))k")
                        .font(.footnote)
                        .foregroundStyle(skewTAxisLabelColor)
                    context.draw(label, at: CGPoint(x: manager.x(-10) - 20, y: manager.y(tick))) // Adjust y position
                }
                
            }
            .frame(width: manager.screenWidth, height: manager.proportionalHeight)
            .background(tableBackgroundColor)
            .overlay {
                // Print text in front of Skew-T chart
                VStack (alignment: .trailing) {
                    Text("Top of Lift:  \(convertMetersToFeet(manager.skewTLiftParameters.tol)) ft")
                        .font(.headline)
                    Text("-3 Index: \(convertMetersToFeet(manager.skewTLiftParameters.neg3)) ft")
                        .font(.headline)
                        .padding(.bottom, 2)
                    Text("Forecast max temp: \(String(Int(manager.maxTempF)))°F")
                        .font(.subheadline)
                        .foregroundStyle(infoFontColor)
                        .padding(.bottom, 4)
                    Text("Legend:")
                        .font(.caption)
                        .foregroundStyle(infoFontColor)
                        .padding(.bottom, 0)
                    Text("Dewpoint temp")
                        .font(.caption)
                        .foregroundColor(skewTDewpointColor)
                        .padding(.bottom, 0)
                    Text("Thermal temp")
                        .font(.caption)
                        .foregroundColor(skewTTempColor)
                        .padding(.bottom, 0)
                    Text("DALR")
                        .font(.caption)
                        .foregroundColor(skewTDALRColor)
                        .padding(.bottom, 1)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.vertical, 8)
                .padding(.horizontal, 24)
            }

            // Alternate max temp controls
            Text("Use alternate max temperature:")
                .font(.subheadline)
                .padding(.top)
            HStack (alignment: .center) {
                TextField("Temp", text: $userTemp)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .cornerRadius(8)
                    .frame(width: buttonWidth * 0.7)
                    .keyboardType(.decimalPad)
                    .padding(.trailing, 0)
                    .onSubmit {
                        hideKeyboard()
                    }
                Text("°F ")
                    .font(.subheadline)
                    .padding(.leading, 0)
                Button(action: {
                    hideKeyboard()
                    manager.d3Update(userTemp: Double(userTemp) ?? manager.maxTempF)
                }) {
                    Text("Submit")
                        .foregroundColor(buttonTextColor)
                        .padding(8)
                }
                .frame(width: buttonWidth)
                .background(buttonBackgroundColor)
                .cornerRadius(8)
                Button(action: {
                    userTemp = ""
                    hideKeyboard()
                    manager.d3Update(userTemp: manager.maxTempF)
                }) {
                    Text("Clear")
                        .foregroundColor(buttonTextColor)
                        .padding(8)
                }
                .frame(width: buttonWidth)
                .background(buttonBackgroundColor)
                .cornerRadius(8)
            }
            // Setting buttonStyle to work around a SwiftUI bug where both buttons are actioned when either is pressed
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal)
            .padding(.top, 0)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 0)
        .background(tableBackgroundColor)
        .cornerRadius(8)
        .onAppear {
            manager.soaringForecastViewModel = soaringForecastViewModel
            manager.populateSoaringForecast()
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
