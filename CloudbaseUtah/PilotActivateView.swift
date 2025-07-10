import SwiftUI

struct PilotActivateView: View {
    var pilot: Pilot
    
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @State private var statusMessage = ""
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
                Text(pilot.pilotName)
                    .foregroundColor(sectionHeaderColor)
                    .bold()
            }
            .padding()
            .background(toolbarBackgroundColor)
            
            List {
                
                Section(header: Text("Inactive Pilots")) {
                    
                    VStack (alignment: .leading) {
                        
                        Text("To reduce time loading tracks, pilots are periodically deactivated in this app when they have empty track feeds.")
                            .font(.subheadline)
                        Text("This occurs when either:")
                            .font(.subheadline)
                        Text(" - The inReach has not be used for a year")
                            .font(.subheadline)
                        Text(" - The inReach share is currently set to private")
                            .font(.subheadline)
                        Text("")
                            .font(.subheadline)
                        Text("If the inReach is now being used and share is set to public, use the button below to re-activate a pilot in this app")
                            .font(.subheadline)
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                
                                // Update Google sheets to activate pilot
                                pilotViewModel.setPilotActiveStatus(pilot: pilot, isInactive: false)

                                // Force update to pilot listing
                                pilotViewModel.getPilots {

                                    // Dismiss sheet and return to map settings
                                    DispatchQueue.main.async {
                                        dismiss()
                                    }
                                }
                            }) {
                                Text("Activate Pilot")
                                    .foregroundColor(skewTButtonTextColor)
                                    .padding(8)
                            }
                            .frame(width: skewTButtonWidth * 2)
                            .background(skewTButtonBackgroundColor)
                            .cornerRadius(8)
                            .padding(.vertical)

                            Spacer()
                            
                        }
                    }
                    
                }
            }
            Spacer()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
}
