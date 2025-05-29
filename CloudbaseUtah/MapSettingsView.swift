import SwiftUI
import MapKit
import Combine
import UIKit

// This view uses temporary variables while the sheet is open, then publishes when the sheet is closed.
// This is done to prevent lag on this sheet each time a view item is changed.
struct MapSettingsView: View {
    @Binding var activeLayers: Set<MapLayer>
    @Binding var selectedMapType: CustomMapStyle
    @Binding var pilotTrackDays: Double
    @Environment(\.presentationMode) var presentationMode

    // Temporary state variables
    @State private var tempActiveLayers: Set<MapLayer>
    @State private var tempSelectedMapType: CustomMapStyle
    @State private var tempPilotTrackDays: Double

    init(activeLayers: Binding<Set<MapLayer>>, selectedMapType: Binding<CustomMapStyle>, pilotTrackDays: Binding<Double>) {
        _activeLayers = activeLayers
        _selectedMapType = selectedMapType
        _pilotTrackDays = pilotTrackDays

        // Initialize temporary states with current values
        _tempActiveLayers = State(initialValue: activeLayers.wrappedValue)
        _tempSelectedMapType = State(initialValue: selectedMapType.wrappedValue)
        _tempPilotTrackDays = State(initialValue: pilotTrackDays.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    // Update the main state variables when the sheet is dismissed
                    activeLayers = tempActiveLayers
                    selectedMapType = tempSelectedMapType
                    pilotTrackDays = tempPilotTrackDays
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
                Section(header: Text("Map Type")) {
                    Picker("Map Type", selection: $tempSelectedMapType) {
                        ForEach(CustomMapStyle.allCases, id: \.self) { style in
                            Text(style.rawValue.capitalized)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Map Layers")) {
                    ForEach(MapLayer.allCases, id: \.self) { layer in
                        VStack {
                            Toggle(isOn: Binding(
                                get: { tempActiveLayers.contains(layer) },
                                set: { isActive in
                                    if isActive {
                                        tempActiveLayers.insert(layer)
                                    } else {
                                        tempActiveLayers.remove(layer)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading) {
                                    Text(layer.name)
                                    Text(layer.description)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            if tempActiveLayers.contains(.pilots) && layer == .pilots {
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
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
