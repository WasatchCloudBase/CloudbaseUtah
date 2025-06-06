import SwiftUI
import MapKit
import Combine
import UIKit

// This view uses temporary variables while the sheet is open, then publishes when the sheet is closed.
// This is done to prevent lag on this sheet each time a view item is changed.
struct MapSettingsView: View {
    @Binding var selectedMapType: CustomMapStyle
    @Binding var pilotTrackDays: Double
    @Binding var mapDisplayMode: MapDisplayMode
    @Binding var showSites: Bool
    @Binding var showStations: Bool
    @Environment(\.presentationMode) var presentationMode

    // Temporary state variables
    @State private var tempSelectedMapType: CustomMapStyle
    @State private var tempPilotTrackDays: Double
    @State private var tempMapDisplayMode: MapDisplayMode
    @State private var tempShowSites: Bool
    @State private var tempShowStations: Bool

    init(selectedMapType: Binding<CustomMapStyle>,
        pilotTrackDays: Binding<Double>,
        mapDisplayMode: Binding<MapDisplayMode>,
        showSites: Binding<Bool>,
        showStations: Binding<Bool>
    ) {
        _selectedMapType = selectedMapType
        _pilotTrackDays = pilotTrackDays
        _mapDisplayMode = mapDisplayMode
        _showSites = showSites
        _showStations = showStations

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
                    presentationMode.wrappedValue.dismiss()
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

                Section(header: Text("Weather layers")) {
                    Toggle("Show Sites", isOn: $tempShowSites)
                    Toggle("Show Stations", isOn: $tempShowStations)
                }

                Section(header: Text("Pilot track days")) {
                    VStack(alignment: .trailing) {
                        Slider(value: $tempPilotTrackDays, in: 1.0...3.0, step: 1.0)
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
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onDisappear {
            // Update the main state variables when the sheet is dismissed
            selectedMapType = tempSelectedMapType
            pilotTrackDays = tempPilotTrackDays
            mapDisplayMode = tempMapDisplayMode
            showSites = tempShowSites
            showStations = tempShowStations
        }
    }
}

