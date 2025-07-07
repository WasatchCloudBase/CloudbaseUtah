import SwiftUI
import MapKit
import Combine
import UIKit

struct RadarColorScheme: Identifiable {
    let id: Int
    let title: String
}

// This view uses temporary variables while the sheet is open, then publishes when the sheet is closed.
// This is done to prevent lag on this sheet each time a view item is changed.
struct MapSettingsView: View {
    @Binding var selectedMapType: CustomMapStyle
    @Binding var pilotTrackDays: Double
    @Binding var mapDisplayMode: MapDisplayMode
    @Binding var showSites: Bool
    @Binding var showStations: Bool
    @Binding var showRadar: Bool
    @Binding var showInfrared: Bool
    @Binding var radarColorScheme: Int
    @Binding var selectedPilots: [Pilot]
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @EnvironmentObject var pilotTrackViewModel: PilotTrackViewModel
    @Environment(\.presentationMode) var presentationMode

    // Temporary state variables
    @State private var tempSelectedMapType: CustomMapStyle
    @State private var tempPilotTrackDays: Double
    @State private var tempMapDisplayMode: MapDisplayMode
    @State private var tempShowSites: Bool
    @State private var tempShowStations: Bool
    @State private var tempShowRadar: Bool
    @State private var tempShowInfrared: Bool
    @State private var tempRadarColorScheme: Int
    
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
         showRadar: Binding<Bool>,
         showInfrared: Binding<Bool>,
         radarColorScheme: Binding<Int>,
         selectedPilots: Binding<[Pilot]>
    ) {
        _selectedMapType = selectedMapType
        _pilotTrackDays = pilotTrackDays
        _mapDisplayMode = mapDisplayMode
        _showSites = showSites
        _showStations = showStations
        _showRadar = showRadar
        _showInfrared = showInfrared
        _radarColorScheme = radarColorScheme
        _selectedPilots = selectedPilots
        
        // Initialize temporary states with current values
        _tempSelectedMapType = State(initialValue: selectedMapType.wrappedValue)
        _tempPilotTrackDays = State(initialValue: pilotTrackDays.wrappedValue)
        _tempMapDisplayMode = State(initialValue: mapDisplayMode.wrappedValue)
        _tempShowSites = State(initialValue: showSites.wrappedValue)
        _tempShowStations = State(initialValue: showStations.wrappedValue)
        _tempShowRadar = State(initialValue: showRadar.wrappedValue)
        _tempShowInfrared = State(initialValue: showInfrared.wrappedValue)
        _tempRadarColorScheme = State(initialValue: radarColorScheme.wrappedValue)
    }
    
    // Rainviewer color schemes for radar overlay
    let radarColorSchemes: [RadarColorScheme] = [
//        .init(id: 0, title: "0 – BW Black and White: dBZ values"),
        .init(id: 1, title: "Original"),
        .init(id: 2, title: "Universal Blue"),
        .init(id: 3, title: "TITAN"),
        .init(id: 4, title: "Weather Channel"),
        .init(id: 5, title: "Meteored"),
        .init(id: 6, title: "NEXRAD Level III"),
        .init(id: 7, title: "Rainbow @ SELEX-IS"),
        .init(id: 8, title: "Dark Sky")
    ]
    
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

                if $tempMapDisplayMode.wrappedValue == .weather {
                    Section(header: Text("Display layers")) {
                        Toggle("Sites", isOn: $tempShowSites)
                        Toggle("Stations", isOn: $tempShowStations)
                        Toggle("Radar (precip)", isOn: $tempShowRadar)
                        Toggle("Satellite (clouds)", isOn: $tempShowInfrared)
                    }
                    
                    if tempShowRadar {
                        Section(header: Text("Radar Color Scheme")) {
                            Picker("Radar colors", selection: $tempRadarColorScheme) {
                                ForEach(radarColorSchemes) { radarColorScheme in
                                    Text(radarColorScheme.title)
                                        .tag(radarColorScheme.id)
                                }
                            }
                            .pickerStyle(.inline)
                        }
                    }

                }
                
                if $tempMapDisplayMode.wrappedValue == .tracking {
                    
                    Section(header: Text("Pilot track days")) {
                        HStack {
                            Text("Days:")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Picker("Days", selection: $tempPilotTrackDays) {
                                ForEach(1...3, id: \.self) { day in
                                    Text("\(day)")
                                        .tag(Double(day))
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .disabled(pilotTrackViewModel.isLoading)              // block while loading
                            .opacity(pilotTrackViewModel.isLoading ? 0.5 : 1)     // grey‐out
                        }
                        .padding(.vertical, 8)
                        .onChange(of: tempPilotTrackDays) { oldDays, newDays in
                            // Build an array of the currently‐selected Pilot objects
                            let selected = pilotViewModel.pilots
                                .filter { selectedPilotIDs.contains($0.id) }
                            
                            // Fire off the reload
                            pilotTrackViewModel.getPilotTracks(
                                days: newDays,
                                selectedPilots: selected
                            ) {}
                        }
                        if pilotTrackViewModel.isLoading {
                            HStack(spacing: 8) {
                                Spacer()
                                Text("Updating pilot track data")
                                    .font(.subheadline)
                                    .foregroundStyle(loadingBarTextColor)

                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.75)
                                    .padding(.horizontal, 8)
                                    // force a fresh ProgressView each time `isLoading` toggles:
                                    .id(UUID())
                            }
                            .padding(.vertical, 4)
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
                                    selectedPilotIDs = Set(pilotViewModel.pilots.map(\.id))
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
                            ForEach(pilotViewModel.pilots.sorted { $0.pilotName.localizedCaseInsensitiveCompare($1.pilotName) == .orderedAscending }) { pilot in
                                
                                // determine if this pilot has any tracks
                                let hasTrack = pilotTrackViewModel.pilotTracks.contains { $0.pilotName == pilot.pilotName }
                                                  
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
                    VStack (alignment: .leading) {
                        Text("Readings data aggregated by Synoptic")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                        Text("https://synopticdata.com")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                            .padding(.bottom, 8)
                        Text("Radar/satellite data provided by Rain Viewer")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                        Text("https://www.rainviewer.com")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                    }

                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        
        .onReceive(pilotViewModel.$pilots) { pilots in
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
        
        .onAppear() {
            
            if $tempMapDisplayMode.wrappedValue == .tracking {
                // Reload pilot list with all available tracks (in case user had previously selected pilots,
                // which would have created a filtered list)
                pilotTrackViewModel.getPilotTracks(days: pilotTrackDays,
                                                   selectedPilots: []) {}
            }
        }
        
        .onDisappear {
            // Update the main state variables when the sheet is dismissed
            selectedMapType = tempSelectedMapType
            pilotTrackDays = tempPilotTrackDays
            mapDisplayMode = tempMapDisplayMode
            showSites = tempShowSites
            showStations = tempShowStations
            showRadar = tempShowRadar
            showInfrared = tempShowInfrared
            radarColorScheme = tempRadarColorScheme
            selectedPilots = pilotViewModel.pilots.filter { selectedPilotIDs.contains($0.id) }
            
        }
        
        .sheet(isPresented: $addPilot, onDismiss: {
            pilotViewModel.getPilots() {}
        }) {
            PilotAppendView()
                .interactiveDismissDisabled(true) // ← disables swipe-to-dismiss
        }
        
    }
}

