//
//  EditTopicView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI

struct EditTopicView: View {
    let term: String
    @State var isPrimary: Bool
    let onSave: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                Toggle("Primary Topic", isOn: $isPrimary)
            } footer: {
                Text("Primary topics focus on articles where this subject is a main focus rather than a secondary mention.")
            }

            Section {
                Button("Save Changes") {
                    onSave(isPrimary)
                    dismiss()
                }
            }
        }
        .navigationTitle(term)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
