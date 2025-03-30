//
//  ThermalParameters.swift
//  CloudbaseUtah
//
//  Created by Brown, Mike on 3/30/25.
//
import SwiftUI
import Combine

struct LiftParameterSource: Codable, Identifiable {
    var id = UUID()
    var parameter: String
    var value: Double
    var notes: String
}
struct LiftParametersResponse: Codable {
    var values: [[String]]
}
struct LiftParameters: Codable {
    var thermalLapseRate: Double
    var thermalVelocityConstant: Double
    var thermalTriggerTempDiff: Double
    var thermalRampDistance: Double
    var thermalRampStartPct: Double
    var cloudbaseLapseRatesDiff: Double
    var thermalGliderSinkRate: Double
}

class LiftParametersViewModel: ObservableObject {
    @Published var liftParameters: LiftParameters?
    
    func fetchLiftParameters() {
        var liftParameters: LiftParameters = .init(thermalLapseRate: 0, thermalVelocityConstant: 0, thermalTriggerTempDiff: 0, thermalRampDistance: 0, thermalRampStartPct: 0, cloudbaseLapseRatesDiff: 0, thermalGliderSinkRate: 0)
        
        let rangeName = "LiftParameters"
        let liftParameterURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(GoogleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(GoogleApiKey)"
        guard let liftParameterURL = URL(string: liftParameterURLString) else { return }
        
        URLSession.shared.dataTask(with: liftParameterURL) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let decodedResponse = try? decoder.decode(LiftParametersResponse.self, from: data) {
                    DispatchQueue.main.async {
                        for row in decodedResponse.values {
                            if row.count >= 2, let value = Double(row[1]) {
                                switch row[0] {
                                case "thermalLapseRate":
                                    liftParameters.thermalLapseRate = value
                                case "thermalVelocityConstant":
                                    liftParameters.thermalVelocityConstant = value
                                case "thermalTriggerTempDiff":
                                    liftParameters.thermalTriggerTempDiff = value
                                case "thermalRampDistance":
                                    liftParameters.thermalRampDistance = value
                                case "thermalRampStartPct":
                                    liftParameters.thermalRampStartPct = value
                                case "cloudbaseLapseRatesDiff":
                                    liftParameters.cloudbaseLapseRatesDiff = value
                                case "thermalGliderSinkRate":
                                    liftParameters.thermalGliderSinkRate = value
                                case "Parameter":
                                    // skip heading row
                                    let headingRow = value
                                default:
                                    break
                                }
                            }
                        }
                        self.liftParameters = liftParameters
                    }
                }
            }
        }.resume()
    }
}
