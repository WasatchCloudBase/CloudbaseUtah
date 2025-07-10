import SwiftUI

struct PilotAppendView: View {
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @State private var pilotName = ""
    @State private var inreachURL: String = "https://share.garmin.com/" // Prefilled with default URL prefix
    @State private var statusMessage = ""
    @State private var showValidationError = false
    @State private var duplicatePilotError = false
    @State private var duplicateShareURLError = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    dismiss()
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
            
            Section(header: Text("Add new pilot")) {
                
                VStack(alignment: .leading) {
                    Text("Pilot name")
                        .font(.subheadline)
                        .padding(.bottom, 0)
                    
                    TextField("Pilot Name", text: $pilotName)
                        .font(.subheadline)
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
                        .font(.subheadline)
                        .padding(.top)
                        .padding(.bottom, 0)
                    
                    TextField("https://share.garmin.com/<pilot id>", text: $inreachURL)
                        .font(.subheadline)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .cornerRadius(8)
                        .padding(.top, 0)
                    
                    if showValidationError && !isValidInreachURL(inreachURL) {
                        Text("URL must be in the format:")
                            .foregroundColor(warningFontColor)
                            .font(.caption)
                        Text("https://share.garmin.com/<pilot ID>")
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
                        if pilotViewModel.pilots.contains(where: { $0.pilotName.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
                            duplicatePilotError = true
                        }
                        
                        if pilotViewModel.pilots.contains(where: { $0.trackingShareURL.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(trimmedURL) == .orderedSame }) {
                            duplicateShareURLError = true
                        }
                        
                        // Return all errors
                        if showValidationError || duplicatePilotError || duplicateShareURLError {
                            return
                        }
                        
                        hideKeyboard()
                        
                        // Add pilot to Google sheets
                        pilotViewModel.addPilot(pilotName: trimmedName,
                                                trackingShareURL: trimmedURL)

                        // Force update to pilot listing
                        pilotViewModel.getPilots {

                            // Dismiss sheet and return to map settings
                            DispatchQueue.main.async {
                                dismiss()
                            }
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
    
}
