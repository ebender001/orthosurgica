//
//  AdvancedSearchEntryView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI

struct AdvancedSearchEntryView: View {
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""

    var body: some View {
        Form {
            Section("Advanced Search") {
                Text("Use PubMed operators (AND/OR/NOT), parentheses, and field tags like [tiab], [mh], [pt].")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .frame(minHeight: 140)
            }

            Section {
                Button("Add") {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    onAdd(trimmed)
                    dismiss()
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Add Advanced Search")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
