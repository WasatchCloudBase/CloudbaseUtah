import SwiftUI
import Foundation

// Set thermal calc logging for development
let turnOnLogging: Bool = true
let printForecastURL: Bool = false

// Forecast logging to optimize thermal calculations
struct LogData: Codable {
    // Core data based on site and forecast API call results
    var site: String
    var date: String
    var time: String
    var surfaceAltitude: Double
    var surfaceTemp: Double
    // Forecast API call results for a specific pressure altitude
    var altitude: Double
    var ambientTemp: Double
    var ambientDPTemp: Double
    // Data calculated within forecast functions
    var liftRate: Double
    var thermalTriggerReachedForDay: Bool
    var topOfLiftAltitude: Double
    var cloudbaseAltitude: Double
    var adjustedPriorAltitude: Double
    var altitudeChange: Double
    var topOfLiftRatio: Double
    var cloudbaseRatio: Double
    var priorAmbientDPTemp: Double
    var thermalDPTemp: Double
    var priorThermalDPTemp: Double
    var thermalDPTempToAmbientDPTempDiff: Double
    var ambientTempToAmbientDPTempDiff: Double
    var ambientDPTempDiff: Double
    var priorThermalDPTempToAmbientDPTempDiff: Double
    var priorAmbientDPTempToAmbientTempDiff: Double
    var thermalRampTop: Double
    var rampImpactAltitude: Double
    var rampImpactPortion: Double
    var rampReductionFactor: Double
    // Thermal parameters captured when app is started
    var thermalLapseRate: Double
    var thermalVelocityConstant: Double
    var initialTriggerTempDiff: Double
    var ongoingTriggerTempDiff: Double
    var thermalRampDistance: Double
    var thermalRampStartPct: Double
    var cloudbaseLapseRatesDiff: Double
    var thermalGliderSinkRate: Double
}

// For development logging
// Format to call logging:
//                          logToFile("Text to output")
func deleteLogFile() {
    let fileURL = getLogFileURL()
    
    if FileManager.default.fileExists(atPath: fileURL.path) {
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("Log file deleted successfully.")
        } catch {
            print("Failed to delete log file: \(error)")
        }
    }
}

func logToFile(_ message: String) {
    let fileURL = getLogFileURL()
    
    do {
        let timestamp = Date().description(with: .current)
        let logMessage = "[\(timestamp)] \(message)\n"
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let fileHandle = try FileHandle(forWritingTo: fileURL)
            fileHandle.seekToEndOfFile()
            if let data = logMessage.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            try logMessage.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    } catch {
        print("Failed to write to log file: \(error)")
    }
}

func getLogFileURL() -> URL {
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    let documentDirectory = urls[0]
    return documentDirectory.appendingPathComponent("app.log")
}

// Call this function when the app launches
func initializeLoggingFile() {
    
    deleteLogFile()

    // If logging is turned on, write header row for thermal calc troubleshooting
    if turnOnLogging {
        logToFile(  "site, " +
                    "date, " +
                    "time," +
                    "surface Altitude," +
                    "surface Temp," +
                    "altitude," +
                    "ambient Temp," +
                    "ambient DP Temp," +
                    "lift Rate," +
                    "thermal Trigger Reached For Day, " +
                    "top Of Lift Altitude," +
                    "cloudbase Altitude," +
                    "adjusted Prior Altitude," +
                    "altitude Change," +
                    "top Of Lift Ratio," +
                    "cloudbase Ratio," +
                    "prior Ambient DP Temp," +
                    "thermal DP Temp," +
                    "prior Thermal DP Temp," +
                    "thermal DP Temp To Ambient DP Temp Diff," +
                    "ambient Temp To Ambient DP Temp Diff," +
                    "ambient DP Temp Diff," +
                    "prior Thermal DP Temp To Ambient DP Temp Diff," +
                    "prior Ambient DP Temp To Ambient Temp Diff," +
                    "thermal Ramp Top," +
                    "ramp Impact Altitude," +
                    "ramp Impact Portion," +
                    "ramp Reduction Factor," +
                    "thermal Lapse Rate," +
                    "thermal Velocity Constant," +
                    "initial Trigger Temp Diff," +
                    "ongoing Trigger Temp Diff," +
                    "thermal Ramp Distance," +
                    "thermal Ramp Start Pct," +
                    "cloudbase Lapse Rates Diff," +
                    "thermal Glider Sink Rate"
                    )
    }
}
