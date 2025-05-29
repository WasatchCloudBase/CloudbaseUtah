import SwiftUI
import Combine
import Charts

struct ReadingsData: Codable {
    let STATION: [Station]
}

struct Station: Codable {
    let OBSERVATIONS: Observations
}

struct Observations: Codable {
    let date_time: [String]
    let wind_speed_set_1: [Double?]
    let wind_gust_set_1: [Double?]?
    let wind_direction_set_1: [Double]
}

struct ReadingsHistoryData {
    var times: [String]
    var windSpeed: [Double]
    var windGust: [Double?]
    var windDirection: [Double]
    var errorMessage: String?
}

class StationReadingsHistoryDataModel: ObservableObject {
    @Published var readingsHistoryData = ReadingsHistoryData(
        times: [],
        windSpeed: [],
        windGust: [],
        windDirection: [],
        errorMessage: nil
    )
    private var cancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    func GetReadingsHistoryData(stationID: String, readingsSource: String) {
        switch readingsSource {
        case "Mesonet":
            let parameters = "&stid=\(stationID)"
            let urlString = historyReadingsAPIHeader + parameters + historyReadingsAPITrailer + mesowestAPIToken
            let url = URL(string: urlString)!
            cancellable = URLSession.shared.dataTaskPublisher(for: url)
                .map { $0.data }
                .map { data in
                    // Convert data to string, replace "null" with "0.0", and convert back to data
                    if var jsonString = String(data: data, encoding: .utf8) {
                        jsonString = jsonString.replacingOccurrences(of: "null", with: "0.0")
                        return Data(jsonString.utf8)
                    }
                    return data
                }
                .decode(type: ReadingsData.self, decoder: JSONDecoder())
                .replaceError(with: ReadingsData(STATION: []))
                .receive(on: DispatchQueue.main)
                .sink { [weak self] data in
                    guard let self = self, let station = data.STATION.first else {
                        print("No valid data found for station: \(stationID)")
                        self?.readingsHistoryData.errorMessage = "No valid data found for station: \(stationID)"
                        return
                    }
                    let recentTimes = Array(station.OBSERVATIONS.date_time.suffix(8))
                    let recentWindSpeed = Array(station.OBSERVATIONS.wind_speed_set_1.suffix(8)).map { $0 ?? 0.0 }
                    let recentWindGust = station.OBSERVATIONS.wind_gust_set_1?.suffix(8).map { $0 ?? 0.0 } ?? Array(repeating: nil, count: 8)
                    let recentWindDirection = Array(station.OBSERVATIONS.wind_direction_set_1.suffix(8))
                    if let latestTimeString = recentTimes.last,
                       let latestTime = ISO8601DateFormatter().date(from: latestTimeString),
                       Date().timeIntervalSince(latestTime) > 2 * 60 * 60 {
                        self.readingsHistoryData.errorMessage = "Station \(stationID) has not updated in the past 2 hours"
                        print("Station \(stationID) has not updated in the past 2 hours")
                    } else {
                        self.readingsHistoryData.times = recentTimes
                        self.readingsHistoryData.windSpeed = recentWindSpeed
                        self.readingsHistoryData.windGust = recentWindGust
                        self.readingsHistoryData.windDirection = recentWindDirection
                        self.readingsHistoryData.errorMessage = nil
                    }
                }
            // end of let url...URLSession... section
        case "CUASA":
            let readingInterval: Double = 5 * 60 // 5 minutes in seconds
            let readingEnd = Date().timeIntervalSince1970 // current timestamp in seconds
            let readingStart = readingEnd - (readingInterval * 10) // to ensure >= 8 readings
            let urlString = "https://sierragliding.us/api/station/" + stationID + "/data?start=" + String(readingStart) + "&end=" + String(readingEnd) + "&sample=" + String(readingInterval)
            guard let url = URL(string: urlString) else {
                self.readingsHistoryData.errorMessage = "Invalid CUASA readings URL"
                print("Invalid CUASA readings URL")
                return
            }
            URLSession.shared.dataTaskPublisher(for: url)
                .map { $0.data }
                .decode(type: [CUASAReadingsData].self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        self.readingsHistoryData.errorMessage = error.localizedDescription
                        print("Error fetching CUASA data: \(error.localizedDescription)")
                    case .finished:
                        break
                    }
                }, receiveValue: { [weak self] readingsHistoryDataArray in
                    self?.processCUASAReadingsHistoryData(readingsHistoryDataArray)
                })
                .store(in: &cancellables)
            // end of let url...URLSession... section
        default:
            print("Invalid readings source for station: \(stationID)")
        }
    }
    
    private func processCUASAReadingsHistoryData(_ readingsHistoryDataArray: [CUASAReadingsData]) {
        guard let latestEntry = readingsHistoryDataArray.last else {
            self.readingsHistoryData.errorMessage = "No data available"
            print("No data available from CUASA")
            return
        }
        let currentTime = Date().timeIntervalSince1970
        let twoHoursInSeconds: Double = 2 * 60 * 60
        if currentTime - latestEntry.timestamp > twoHoursInSeconds {
            self.readingsHistoryData.errorMessage = "Station has not updated in the past 2 hours"
            print("Station has not updated in the past 2 hours")
            return
        }
        let recentEntries = Array(readingsHistoryDataArray.suffix(8))
        updateCUASAReadingsHistory(with: recentEntries)
    }
    
    private func updateCUASAReadingsHistory(with readingsHistoryDataArray: [CUASAReadingsData]) {
        var times = [String]()
        var windSpeed = [Double]()
        var windGust = [Double?]()
        var windDirection = [Double]()
        for data in readingsHistoryDataArray {
            let date = Date(timeIntervalSince1970: data.timestamp)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "H:mm"
            times.append(dateFormatter.string(from: date))
            windSpeed.append(convertKMToMiles(data.windspeed_avg))
            windGust.append(convertKMToMiles(data.windspeed_max))
            windDirection.append(data.wind_direction_avg)
        }
        self.readingsHistoryData = ReadingsHistoryData(
            times: times,
            windSpeed: windSpeed,
            windGust: windGust,
            windDirection: windDirection,
            errorMessage: nil
        )
    }
}
