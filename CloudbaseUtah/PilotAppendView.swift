import SwiftUI
import SwiftJWT

struct PilotAppendView: View {
    @EnvironmentObject var pilotsViewModel: PilotsViewModel
    @State private var pilotName = ""
    @State private var inreachURL: String = "https://share.garmin.com/" // Prefilled with default URL prefix
    @State private var statusMessage = ""
    @State private var showValidationError = false
    @State private var duplicatePilotError = false
    @State private var duplicateShareURLError = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                        Spacer()
                    }
                }
                .padding()
                Spacer()
            }
            .background(Color.blue.opacity(0.2))
        }
 
        List {
            
            Section(header: Text("Add new pilot")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold()) {
                    
                    VStack(alignment: .leading) {
                        Text("Pilot name")
                            .padding(.bottom, 0)
                        
                        TextField("Pilot Name", text: $pilotName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .cornerRadius(8)
                            .padding(.top, 0)
                        
                        if showValidationError && pilotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Pilot name is required")
                                .foregroundColor(warningFontColor)
                                .font(.caption)
                        }
                        
                        // Display error for duplicate pilot name
                        if duplicatePilotError {
                            Text("A pilot with this name already exists")
                                .foregroundColor(warningFontColor)
                                .font(.caption)
                        }
                        
                        Text("InReach Share URL")
                            .padding(.top)
                            .padding(.bottom, 0)
                        
                        TextField("https://share.garmin.com/<pilot id>", text: $inreachURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .cornerRadius(8)
                            .padding(.top, 0)
                        
                        if showValidationError && !isValidInreachURL(inreachURL) {
                            Text("URL must be in the format: https://share.garmin.com/<pilot iD>")
                                .foregroundColor(warningFontColor)
                                .font(.caption)
                        }
                        
                        // Display error for duplicate pilot share URL
                        if duplicateShareURLError {
                            Text("A pilot with this share URL already exists")
                                .foregroundColor(warningFontColor)
                                .font(.caption)
                        }
                        
                        Button(action: {
                            // Clear prior errors
                            statusMessage = ""
                            showValidationError = false
                            duplicatePilotError = false
                            duplicateShareURLError = false

                            // Validate required fields
                            let trimmedName = pilotName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedURL = inreachURL.trimmingCharacters(in: .whitespacesAndNewlines)

                            if trimmedName.isEmpty || !isValidInreachURL(trimmedURL) {
                                showValidationError = true
                            }

                            // Check for duplicates
                            if pilotsViewModel.pilots.contains(where: { $0.pilotName.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
                                duplicatePilotError = true
                            }

                            if pilotsViewModel.pilots.contains(where: { $0.trackingShareURL.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(trimmedURL) == .orderedSame }) {
                                duplicateShareURLError = true
                            }

                            // Return all errors
                            if showValidationError || duplicatePilotError || duplicateShareURLError {
                                return
                            }
                            
                            hideKeyboard()
                            statusMessage = "Authenticating..."

                            fetchAccessToken { token in
                                guard let token = token else {
                                    DispatchQueue.main.async {
                                        statusMessage = "Failed to get access token"
                                    }
                                    return
                                }
                                submitPilot(accessToken: token)
                            }
                        }) {
                            Text("Submit")
                                .foregroundColor(skewTButtonTextColor)
                                .padding(8)
                        }
                        .frame(width: skewTButtonWidth)
                        .background(skewTButtonBackgroundColor)
                        .cornerRadius(8)
                        .padding(.vertical)
                        
                        if statusMessage != "" {
                            Text(statusMessage)
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                }
            
        }
        Spacer()
    }
    
    func isValidInreachURL(_ url: String) -> Bool {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "https://share.garmin.com/"
        return trimmed.hasPrefix(prefix) && trimmed.count > prefix.count
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // Google sheets submission
    func submitPilot(accessToken: String) {
        let range = "Pilots"
        let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(googleSpreadsheetID)/values/\(range):append?valueInputOption=RAW"
        guard let url = URL(string: urlString) else {
            statusMessage = "Invalid URL"
            return
        }
        
        let values = [[ pilotName, inreachURL ]]
        let body: [String: Any] = ["values": values]
        let jsonData = try! JSONSerialization.data(withJSONObject: body)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { _, resp, err in
            DispatchQueue.main.async {
                if let err = err {
                    statusMessage = "Error: \(err.localizedDescription)"
                } else if let code = (resp as? HTTPURLResponse)?.statusCode, code == 200 {
                    statusMessage = "Pilot added successfully"
                    pilotName = ""
                    inreachURL = "https://share.garmin.com/"
                    
                    // Force refresh of PilotsView
                    pilotsViewModel.getPilots() {}
                } else {
                    statusMessage = "Failed to add pilot"
                }
            }
        }.resume()
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
