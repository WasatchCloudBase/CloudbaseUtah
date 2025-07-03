import SwiftUI
import Combine

// Get lift parameters for common use
struct LiftParameterSource: Codable, Identifiable {
    var id = UUID()
    var parameter: String
    var value: Double
    var notes: String
}
struct LiftParametersResponse: Codable {
    var values: [[String]]
}
// Published view model structure
struct LiftParameters: Codable {
    var thermalLapseRate: Double
    var thermalVelocityConstant: Double
    var initialTriggerTempDiff: Double
    var ongoingTriggerTempDiff: Double
    var thermalRampDistance: Double
    var thermalRampStartPct: Double
    var cloudbaseLapseRatesDiff: Double
    var thermalGliderSinkRate: Double
}
class LiftParametersViewModel: ObservableObject {
    @Published var liftParameters: LiftParameters?
    
    func getLiftParameters(completion: @escaping () -> Void) {
        var liftParameters: LiftParameters = .init(thermalLapseRate: 0, thermalVelocityConstant: 0, initialTriggerTempDiff: 0, ongoingTriggerTempDiff: 0, thermalRampDistance: 0, thermalRampStartPct: 0, cloudbaseLapseRatesDiff: 0, thermalGliderSinkRate: 0)
        let rangeName = "LiftParameters"
        let liftParameterURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(googleApiKey)"
        guard let liftParameterURL = URL(string: liftParameterURLString) else {
            print("invalid URL for thermal lift parameters")
            completion() // Call completion even on error
            return
        }
        URLSession.shared.dataTask(with: liftParameterURL) { [weak self] data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let decodedResponse = try? decoder.decode(LiftParametersResponse.self, from: data) {
                    DispatchQueue.main.async {
                        for row in decodedResponse.values.dropFirst() {
                            guard row.count >= 2 else {
                                print("Skipping malformed row (not enough columns): \(row)")
                                continue
                            }
                            guard let value = Double(row[1]) else {
                                print("Skipping row with non-numeric value: \(row)")
                                continue
                            }
                            switch row[0] {
                            case "thermalLapseRate":
                                liftParameters.thermalLapseRate = value
                            case "thermalVelocityConstant":
                                liftParameters.thermalVelocityConstant = value
                            case "initialTriggerTempDiff":
                                liftParameters.initialTriggerTempDiff = value
                            case "ongoingTriggerTempDiff":
                                liftParameters.ongoingTriggerTempDiff = value
                            case "thermalRampDistance":
                                liftParameters.thermalRampDistance = value
                            case "thermalRampStartPct":
                                liftParameters.thermalRampStartPct = value
                            case "cloudbaseLapseRatesDiff":
                                liftParameters.cloudbaseLapseRatesDiff = value
                            case "thermalGliderSinkRate":
                                liftParameters.thermalGliderSinkRate = value
                            case "Parameter":
                                // skip heading row (should have been dropped above)
                                _ = value
                            default:
                                break
                            }
                        }
                        self?.liftParameters = liftParameters
                        completion() // Call completion after updating
                    }
                    return
                }
            }
            // If decoding fails or data is nil, still call completion
            DispatchQueue.main.async {
                completion()
            }
        }.resume()
    }
}
