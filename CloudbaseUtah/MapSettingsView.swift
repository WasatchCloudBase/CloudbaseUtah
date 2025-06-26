import SwiftUI
import MapKit
import Combine
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// This view uses temporary variables while the sheet is open, then publishes when the sheet is closed.
// This is done to prevent lag on this sheet each time a view item is changed.
struct MapSettingsView: View {
    @Binding var selectedMapType: CustomMapStyle
    @Binding var pilotTrackDays: Double
    @Binding var mapDisplayMode: MapDisplayMode
    @Binding var showSites: Bool
    @Binding var showStations: Bool
    @Binding var selectedPilots: [Pilots]
    @EnvironmentObject var pilotsViewModel: PilotsViewModel
    @EnvironmentObject var pilotTracksViewModel: PilotTracksViewModel
    @Environment(\.presentationMode) var presentationMode

    // Temporary state variables
    @State private var tempSelectedMapType: CustomMapStyle
    @State private var tempPilotTrackDays: Double
    @State private var tempMapDisplayMode: MapDisplayMode
    @State private var tempShowSites: Bool
    @State private var tempShowStations: Bool
    
    // Selected pilot list variables
    @State private var selectedPilotIDs: Set<UUID> = []
    @State private var showSelectionError = false
    @State private var didSeed = false

    // Trigger add pilot sheet navigation
    @State private var addPilot = false

    init(selectedMapType: Binding<CustomMapStyle>,
        pilotTrackDays: Binding<Double>,
        mapDisplayMode: Binding<MapDisplayMode>,
        showSites: Binding<Bool>,
        showStations: Binding<Bool>,
         selectedPilots: Binding<[Pilots]>
    ) {
        _selectedMapType = selectedMapType
        _pilotTrackDays = pilotTrackDays
        _mapDisplayMode = mapDisplayMode
        _showSites = showSites
        _showStations = showStations
        _selectedPilots = selectedPilots
        
        // Initialize temporary states with current values
        _tempSelectedMapType = State(initialValue: selectedMapType.wrappedValue)
        _tempPilotTrackDays = State(initialValue: pilotTrackDays.wrappedValue)
        _tempMapDisplayMode = State(initialValue: mapDisplayMode.wrappedValue)
        _tempShowSites = State(initialValue: showSites.wrappedValue)
        _tempShowStations = State(initialValue: showStations.wrappedValue)
    }
    
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    // Validate at least one pilot is selected
                    if selectedPilotIDs.isEmpty {
                        showSelectionError = true
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .padding()
                Spacer()
            }
            .background(Color.blue.opacity(0.2))
            .alert("Select at least one pilot", isPresented: $showSelectionError) {
                            Button("OK", role: .cancel) { }
                        }

            List {
                Section(header: Text("Map type")) {
                    Picker("Map Type", selection: $tempSelectedMapType) {
                        ForEach(CustomMapStyle.allCases, id: \.self) { style in
                            Text(style.rawValue.capitalized)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                /* Map mode on main map screen, so not duplicating here
                Section(header: Text("Map mode")) {
                    Picker("Display", selection: $tempMapDisplayMode) {
                        Text("Weather").tag(MapDisplayMode.weather)
                        Text("Tracking").tag(MapDisplayMode.tracking)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                */

                if $tempMapDisplayMode.wrappedValue == .weather {
                    
                    Section(header: Text("Weather layers")) {
                        Toggle("Show Sites", isOn: $tempShowSites)
                        Toggle("Show Stations", isOn: $tempShowStations)
                    }
                    
                } else {
                    
                    Section(header: Text("Pilot track days")) {
                        VStack(alignment: .trailing) {
                            Slider(value: $tempPilotTrackDays, in: 1.0...3.0, step: 1.0)
                                .onChange(of: tempPilotTrackDays) { oldDays, newDays in
                                    // Refresh tracks for each pilot with the updated days
                                    for pilot in pilotsViewModel.pilots {
                                        pilotTracksViewModel.getPilotTrackingData(
                                            pilotName: pilot.pilotName,
                                            trackingURL: pilot.trackingFeedURL,
                                            days: newDays
                                        ) { }
                                    }
                                }
                            HStack {
                                Text("Today")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("+ Yesterday")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                Text("+ Prior Day")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    
                    Section(header: Text("Pilots to display")) {
                        VStack(spacing: 12) {
                            // Add Pilot Button
                            HStack {
                                Spacer()
                                Button(action: {
                                    addPilot = true
                                }) {
                                    Text("Add Pilot")
                                        .foregroundColor(skewTButtonTextColor)
                                        .padding(8)
                                }
                                .frame(width: skewTButtonWidth)
                                .background(skewTButtonBackgroundColor)
                                .cornerRadius(8)
                                Spacer()
                            }
                            .contentShape(Rectangle()) // Isolate pilot button gesture area
                            
                            Divider()

                            // All / None Buttons
                            HStack {
                                Button(action: {
                                    selectedPilotIDs = Set(pilotsViewModel.pilots.map(\.id))
                                }) {
                                    Text("All")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .contentShape(Rectangle())

                                Button(action: {
                                    selectedPilotIDs.removeAll()
                                }) {
                                    Text("None")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .contentShape(Rectangle())
                            }

                            // Pilot checkboxes
                            ForEach(pilotsViewModel.pilots.sorted { $0.pilotName.localizedCaseInsensitiveCompare($1.pilotName) == .orderedAscending }) { pilot in
                                
                                // determine if this pilot has any tracks
                                let hasTrack = pilotTracksViewModel.pilotTracks.contains { $0.pilotName == pilot.pilotName }
                                                  
                                Button(action: {
                                    if selectedPilotIDs.contains(pilot.id) {
                                        selectedPilotIDs.remove(pilot.id)
                                    } else {
                                        selectedPilotIDs.insert(pilot.id)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: selectedPilotIDs.contains(pilot.id) ? "checkmark.square" : "square")
                                        // gray out if no track
                                            .foregroundColor(hasTrack ? pilotActiveFontColor : pilotInactiveFontColor)
                                        Text(pilot.pilotName)
                                        // gray out if no track
                                            .foregroundColor(hasTrack ? pilotActiveFontColor : pilotInactiveFontColor)

                                        Spacer()
                                    }
                                    .contentShape(Rectangle()) // Ensures only the intended area is tappable
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 0)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        
        .onReceive(pilotsViewModel.$pilots) { pilots in
            // Only seed once, and only when there's at least one pilot
            guard !didSeed, !pilots.isEmpty else { return }
            
            if selectedPilots.isEmpty {
                // Very first time ever: default to all
                selectedPilotIDs = Set(pilots.map(\.id))
            } else {
                // Restore exactly what the parent last saved
                selectedPilotIDs = Set(selectedPilots.map(\.id))
            }
            
            didSeed = true
        }
        
        .onDisappear {
            // Update the main state variables when the sheet is dismissed
            selectedMapType = tempSelectedMapType
            pilotTrackDays = tempPilotTrackDays
            mapDisplayMode = tempMapDisplayMode
            showSites = tempShowSites
            showStations = tempShowStations
            selectedPilots = pilotsViewModel.pilots.filter { selectedPilotIDs.contains($0.id) }
        }
        
        .sheet(isPresented: $addPilot, onDismiss: {
            pilotsViewModel.getPilots() {}
        }) {
            PilotAppendView()
                .interactiveDismissDisabled(true) // ← disables swipe-to-dismiss
        }
        
    }
}

