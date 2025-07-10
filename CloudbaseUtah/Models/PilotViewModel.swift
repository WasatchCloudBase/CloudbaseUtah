import SwiftUI
import Combine
import SwiftJWT

// Get pilots for live tracking
struct Pilot: Codable, Identifiable, Equatable {
    var id = UUID()
    var pilotName: String
    var inactive: Bool
    var trackingShareURL: String
    var trackingFeedURL: String
}

struct PilotsResponse: Codable {
    let values: [[String]]
}

class PilotViewModel: ObservableObject {
    @Published var pilots: [Pilot] = []
    private var cancellables = Set<AnyCancellable>()
    
    func getPilots(completion: @escaping () -> Void) {
        let rangeName = "Pilots"
        let sitesURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(rangeName)?alt=json&key=\(googleApiKey)"
        guard let url = URL(string: sitesURLString) else {
            print("Invalid URL")
            DispatchQueue.main.async { completion() }
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: PilotsResponse.self, decoder: JSONDecoder())
            .map { response in
                response.values.dropFirst().compactMap { row -> Pilot? in
                    // Skip row if data missing
                    guard row.count >= 2 else {
                        print("Skipping malformed pilot row: \(row)")
                        return nil
                    }
                    
                    let pilotName = row[0]
                    let trackingShareURL = row[1]
                    
                    // Set inactive to true if inactive column is populated
                    let inactive = (row.count > 2 && row[2].lowercased() == "yes")
                    
                    // Check for a valid share URL format
                    guard trackingShareURL.contains("https://share.garmin.com/") else {
                        print("Skipping malformed InReach share URL for row: \(row)")
                        return nil
                    }
                    
                    // Extract pilot name from the share URL
                    let pilotNameFromURL = trackingShareURL.components(separatedBy: "/").last ?? ""
                    let trackingFeedURL = "https://share.garmin.com/Feed/Share/\(pilotNameFromURL)"
                    
                    return Pilot(
                        pilotName: pilotName,
                        inactive: inactive,
                        trackingShareURL: trackingShareURL,
                        trackingFeedURL: trackingFeedURL
                    )
                }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { [weak self] pilots in
                self?.pilots = pilots
            }, receiveCompletion: { _ in
                completion()
            })
            .sink { _ in }
            .store(in: &cancellables)
    }
    
    func trackingShareURL(for pilotName: String) -> String? {
        return pilots.first(where: { $0.pilotName == pilotName })?.trackingShareURL
    }

    func addPilot(pilotName: String, trackingShareURL: String) {
        
        // Get an OAuth token
        fetchAccessToken { token in
            guard let token = token else {
                DispatchQueue.main.async {
                    print("Failed to get access token")
                }
                return
            }
            
            // Construct append URL
            let range = "Pilots"
            let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(range):append?valueInputOption=RAW"
            guard let url = URL(string: urlString) else {
                print("Invalid URL for API to append pilot")
                return
            }
            
            // Construct append data
            let values = [[ pilotName, trackingShareURL ]]
            let body: [String: Any] = ["values": values]
            let jsonData = try! JSONSerialization.data(withJSONObject: body)
            
            // Structure API call
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            // Perform API call
            URLSession.shared.dataTask(with: request) { _, resp, err in
                DispatchQueue.main.async {
                    if let err = err {
                        print("Error: \(err.localizedDescription)")
                    } else if let code = (resp as? HTTPURLResponse)?.statusCode, code == 200 {
                        // Pilot added successfully
                    } else {
                        print("Failed to add pilot")
                    }
                }
            }.resume()
        }
    }
    
    func setPilotActiveStatus(pilot: Pilot, isInactive: Bool) {
        
        // Get an OAuth token
        fetchAccessToken { token in
            guard let token = token else {
                DispatchQueue.main.async {
                    print("Failed to get access token")
                }
                return
            }

            // Read the existing Pilots sheet to find the row index
            let readRange = "Pilots"
            let readURLstr = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(readRange)"
            guard let readURL = URL(string: readURLstr) else { return }

            var readReq = URLRequest(url: readURL)
            readReq.httpMethod = "GET"
            readReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: readReq) { data, resp, err in
                guard err == nil,
                      let data = data,
                      let http = resp as? HTTPURLResponse, http.statusCode == 200
                else {
                    DispatchQueue.main.async { print("Failed to read sheet: \(err?.localizedDescription ?? "HTTP \( (resp as? HTTPURLResponse)?.statusCode ?? -1 )")") }
                    return
                }

                // Decode into a simple ValuesResponse
                struct ValuesResponse: Decodable { let values: [[String]] }
                guard let sheet = try? JSONDecoder().decode(ValuesResponse.self, from: data) else {
                    DispatchQueue.main.async { print("Couldn't decode sheet values") }
                    return
                }

                // Find the one row where column A matches the pilot name
                if let rowIndex = sheet.values.firstIndex(where: { $0.first == pilot.pilotName }) {
                    let sheetRow = rowIndex + 1      // +1 because Sheets rows are 1-based

                    // Update column C ("Inactive") of that row
                    let updateRange = "Pilots!C\(sheetRow)"   // column C = row[2]
                    let updateURLstr = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(updateRange)?valueInputOption=RAW"
                    guard let updateURL = URL(string: updateURLstr) else { return }

                    // Set inactive status to "Yes" or empty (cleared out)
                    var body: [String: Any] = ["values": [[""]]]    // a single empty string to clear
                    if isInactive {
                        body = ["values": [["Yes"]]]
                    }
                    
                    let jsonData = try! JSONSerialization.data(withJSONObject: body, options: [])

                    var updateReq = URLRequest(url: updateURL)
                    updateReq.httpMethod = "PUT"   // use PUT for updates
                    updateReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    updateReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    updateReq.httpBody = jsonData

                    URLSession.shared.dataTask(with: updateReq) { _, resp2, err2 in
                        DispatchQueue.main.async {
                            if let err2 = err2 {
                                print("Error updating pilot inactive status: \(err2)")
                            } else if let code = (resp2 as? HTTPURLResponse)?.statusCode, code == 200 {
                                print("Pilot \(pilot.pilotName) inactive status updated")
                            } else {
                                print("Failed to update pilot inactive status row: HTTP \((resp2 as? HTTPURLResponse)?.statusCode ?? -1)")
                            }
                        }
                    }
                    .resume()

                } else {
                    DispatchQueue.main.async {
                        print("Pilot “\(pilot.pilotName)” not found in sheet.")
                    }
                }
            }
            .resume()
        }
    }
    
    // OAuth2 via service accounting using SwiftJWT
    func fetchAccessToken(completion: @escaping (String?) -> Void) {
        guard let sa = loadServiceAccount() else {
            print("Could not load service account")
            return completion(nil)
        }
        
        guard let jwt = makeJWT(serviceAccount: sa) else {
            print("JWT creation failed")
            return completion(nil)
        }
        
        guard let url = URL(string: sa.token_uri) else {
            print("Invalid token URI")
            return completion(nil)
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let bodyString = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=\(jwt)"
        req.httpBody = bodyString.data(using: .utf8)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                print("HTTP error:", err)
                return completion(nil)
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                  let token = json["access_token"] as? String else {
                print("Invalid token response:", String(data: data ?? Data(), encoding: .utf8) ?? "")
                return completion(nil)
            }
            completion(token)
        }.resume()
    }
    
    func makeJWT(serviceAccount sa: ServiceAccount) -> String? {
        struct GoogleClaims: Claims {
            let iss: String
            let scope: String
            let aud: String
            let iat: Date
            let exp: Date
        }
        
        let now = Date()
        let claims = GoogleClaims(
            iss: sa.client_email,
            scope: "https://www.googleapis.com/auth/spreadsheets",
            aud: sa.token_uri,
            iat: now,
            exp: now.addingTimeInterval(3600)
        )
        
        var jwt = JWT(header: Header(), claims: claims)
        
        // Convert PEM string to Data
        let pemData = Data(sa.private_key.utf8)
        
        // Create a JWTSigner (SwiftJWT 3.x API)
        let signer = JWTSigner.rs256(privateKey: pemData)
        
        // Sign
        return try? jwt.sign(using: signer)
    }
    
    func loadServiceAccount() -> ServiceAccount? {
        guard let url = Bundle.main.url(forResource: "service-account", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let sa = try? JSONDecoder().decode(ServiceAccount.self, from: data)
        else {
            print("Could not load/parse service-account.json")
            return nil
        }
        return sa
    }
}

struct ServiceAccount: Decodable {
    let client_email: String
    let private_key: String
    let token_uri: String
}

