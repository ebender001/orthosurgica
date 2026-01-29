//
//  MeshCatalogPickerView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI

/// Topic browser backed by `MeshCatalog.v1.json`.
///
/// User-facing language avoids “MeSH” while still returning canonical MeSH headings.
struct MeshCatalogPickerView: View {
    /// Callback when the user taps a topic.
    /// - Parameters:
    ///   - term: The canonical PubMed/MeSH heading string.
    ///   - isPrimary: Whether this topic should be treated as “Primary” (maps to MeSH Major Topic).
    ///
    let selectedTopics: Set<String>
    let onSelect: (String, Bool) -> Void

    @State private var catalog: MeshCatalog = [:]
    @State private var loadError: String?

    @State private var majorHeading: String = ""
    @State private var subspecialty: String = ""
    @State private var topicGroup: String = ""

    // Optional: allow user to override the default “Primary topic” setting when adding.
    @State private var overrideEmphasisDefault = false
    @State private var isPrimaryTopic = true

    var body: some View {
        Form {
            Section("Browse Topics") {
                if let loadError {
                    ContentUnavailableView(
                        "Couldn’t load topics",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                } else if catalog.isEmpty {
                    ProgressView("Loading…")
                } else {
                    Picker("Major heading", selection: $majorHeading) {
                        ForEach(catalog.majorHeadingsSorted, id: \.self) { Text($0) }
                    }

                    Picker("Subspecialty", selection: $subspecialty) {
                        ForEach(catalog.subspecialtiesSorted(for: majorHeading), id: \.self) { Text($0) }
                    }

                    Picker("Topic", selection: $topicGroup) {
                        ForEach(catalog.topicGroupsSorted(for: majorHeading, subspecialty: subspecialty), id: \.self) { Text($0) }
                    }
                }
            }

            if !catalog.isEmpty, loadError == nil {
                let terms = catalog.terms(for: majorHeading, subspecialty: subspecialty, topicGroup: topicGroup)

                Section("Available Topics") {
                    if terms.isEmpty {
                        ContentUnavailableView(
                            "No topics found",
                            systemImage: "magnifyingglass",
                            description: Text("Choose a different topic.")
                        )
                    } else {
                        Toggle("Customize topic emphasis", isOn: $overrideEmphasisDefault)

                        if overrideEmphasisDefault {
                            Text("Primary topics focus on articles where this subject is a main focus rather than a secondary mention.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Toggle("Primary Topic", isOn: $isPrimaryTopic)
                        }
                        
                        ForEach(terms, id: \.term) { t in
                            let isAlreadyAdded = selectedTopics.contains(t.term)
                            Button {
                                let primary = overrideEmphasisDefault ? isPrimaryTopic : t.majorTopicDefault
                                onSelect(t.term, primary)
                            } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(t.term)
                                            .font(.body)
                                        
                                        let effectivePrimary = overrideEmphasisDefault ? isPrimaryTopic : t.majorTopicDefault

                                        Text(overrideEmphasisDefault
                                             ? (effectivePrimary ? "Will be added as: Primary topic" : "Will be added as: Standard topic")
                                             : (t.majorTopicDefault ? "Default: Primary topic" : "Default: Standard topic"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        if overrideEmphasisDefault {
                                            Text(t.majorTopicDefault ? "Default: Primary" : "Default: Standard")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: isAlreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(isAlreadyAdded ? .secondary : .primary)
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isAlreadyAdded)
                            .opacity(isAlreadyAdded ? 0.55 : 1.0)
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Topic")
        .onAppear {
            loadCatalogIfNeeded()
        }
        .onChange(of: majorHeading) { _, _ in
            // Reset dependent selections when parent changes
            subspecialty = catalog.subspecialtiesSorted(for: majorHeading).first ?? ""
            topicGroup = catalog.topicGroupsSorted(for: majorHeading, subspecialty: subspecialty).first ?? ""
        }
        .onChange(of: subspecialty) { _, _ in
            topicGroup = catalog.topicGroupsSorted(for: majorHeading, subspecialty: subspecialty).first ?? ""
        }
    }

    private func loadCatalogIfNeeded() {
        guard catalog.isEmpty, loadError == nil else { return }

        do {
            let loaded = try MeshCatalogLoader.load()
            catalog = loaded

            // Initialize selections to first available path
            majorHeading = loaded.majorHeadingsSorted.first ?? ""
            subspecialty = loaded.subspecialtiesSorted(for: majorHeading).first ?? ""
            topicGroup = loaded.topicGroupsSorted(for: majorHeading, subspecialty: subspecialty).first ?? ""

            // Sensible default for override toggle
            isPrimaryTopic = true
        } catch {
            loadError = error.localizedDescription
        }
    }
}
