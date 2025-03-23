//
//  SiteDetailView.swift
//  CloudbaseUtah
//
//  Created by Brown, Mike on 3/23/25.
//
import SwiftUI

func buildReadingsNote(readingsAlt: String, readingsNote: String) -> String {
    var readingsNoteString: String = ""
    if readingsAlt != "" {
        readingsNoteString = "Readings at \(readingsAlt) ft"
    }
    if readingsNote != "" {
        readingsNoteString = readingsNoteString + " (\(readingsNote))"
    }
    return readingsNoteString
}

struct SiteDetailView: View {
    var site: Site  // Received from parent view
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(toolbarActiveImageColor)
                        Text("Back")
                            .foregroundColor(toolbarActiveFontColor)
                        Spacer()
                        Text(site.siteName)
                            .foregroundColor(sectionHeaderColor)
                            .bold()
                    }
                }
                .padding()
                Spacer()
            }
            .background(toolbarBackgroundColor)
            
            List {
                Section(header: Text("Wind Readings")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    VStack{
                        Text(buildReadingsNote(readingsAlt: site.readingsAlt, readingsNote: site.readingsNote))
                            .font(.footnote)
                            .foregroundColor(infoFontColor)
                        Text("....under construction")
                    }
                }
                Section(header: Text("Forecast")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    Text("Forecast under construction...")
                }

            }
            Spacer() // Push the content to the top of the sheet
        }
    }
}
