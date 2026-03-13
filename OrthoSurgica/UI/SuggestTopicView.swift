//
//  SuggestTopicView.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 2/12/26.
//

import SwiftUI
import ParseSwift

struct SuggestTopicView: View {
    let categoryPath: String
    var onSubmitted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var suggestedTerm = ""
    @State private var suggestionType = "new_term"
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var error: String?

    private let suggestionTypes: [(String, String)] = [
        ("new_term", "Add a term"),
        ("new_group", "Add a topic group")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Where you were browsing") {
                    Text(categoryPath)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("This shows the area of the catalog you were viewing when you tapped Suggest. We use this to help route your request to the correct section.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                Section("Suggestion") {
                    TextField("Suggested term here (e.g., LV thrombus)", text: $suggestedTerm)
                        .textInputAutocapitalization(.words)

                    Picker("Type", selection: $suggestionType) {
                        ForEach(suggestionTypes, id: \.0) { item in
                            Text(item.1).tag(item.0)
                        }
                    }

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...8)

                    Text("""
                    Enter what you’d like added to the catalog.

                    • Add a term = Add a new topic (a single MeSH / PubMed heading) within the section shown above.
                    • Add a topic group = Create a new grouping name under the section shown above (we’ll place the new terms inside it later).

                    Use Notes (optional) to clarify placement or include related terms you think should live in the new group.
                    """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Suggest a topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Submitting…" : "Submit") {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting || suggestedTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    @MainActor
    private func submit() async {
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }

        let term = suggestedTerm.trimmingCharacters(in: .whitespacesAndNewlines)

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        let s = TopicSuggestion(
            suggestedTerm: term,
            suggestionType: suggestionType,
            categoryPath: categoryPath,
            notes: notes,
            appVersion: appVersion
        )

        do {
            _ = try await s.save()
            onSubmitted?()
            dismiss()
        } catch {
            self.error = "Couldn’t submit. Please try again."
        }
    }
}
