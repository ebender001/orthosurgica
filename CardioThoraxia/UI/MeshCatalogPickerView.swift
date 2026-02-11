//
//  MeshCatalogPickerView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI

/// Topic browser backed by the remotely updateable MeshCatalog.
///
/// User-facing language avoids “MeSH” while still returning canonical PubMed/MeSH headings.
struct MeshCatalogPickerView: View {
    /// Callback when the user taps a topic.
    /// - Parameters:
    ///   - term: The canonical PubMed/MeSH heading string.
    ///   - isPrimary: Whether this topic should be treated as “Primary” (maps to MeSH Major Topic).
    let selectedTopics: Set<String>
    let onSelect: (String, Bool) -> Void

    @EnvironmentObject private var meshManager: MeshCatalogManager

    @State private var majorHeading: String = ""
    @State private var subspecialty: String = ""
    @State private var topicGroup: String = ""

    // Optional: allow user to override the default “Primary topic” setting when adding.
    @State private var overrideEmphasisDefault = false
    @State private var isPrimaryTopic = true

    private var catalog: MeshCatalog {
        meshManager.catalog ?? [:]
    }

    var body: some View {
        Form {
            Section("Browse Topics") {
                if let loadError = meshManager.error {
                    ContentUnavailableView(
                        "Couldn’t load topics",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                } else if catalog.isEmpty {
                    ProgressView(meshManager.status.isEmpty ? "Loading…" : meshManager.status)
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

            if !catalog.isEmpty, meshManager.error == nil {
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
        .onChange(of: meshManager.catalog) { _, newValue in
            guard let loaded = newValue, !loaded.isEmpty else { return }
            initializeSelectionsIfNeeded(using: loaded)
        }
        .onAppear {
            if let loaded = meshManager.catalog, !loaded.isEmpty {
                initializeSelectionsIfNeeded(using: loaded)
            }
        }
        .onChange(of: majorHeading) { _, _ in
            guard !catalog.isEmpty else { return }
            // Reset dependent selections when parent changes
            subspecialty = catalog.subspecialtiesSorted(for: majorHeading).first ?? ""
            topicGroup = catalog.topicGroupsSorted(for: majorHeading, subspecialty: subspecialty).first ?? ""
        }
        .onChange(of: subspecialty) { _, _ in
            guard !catalog.isEmpty else { return }
            topicGroup = catalog.topicGroupsSorted(for: majorHeading, subspecialty: subspecialty).first ?? ""
        }
    }

    private func initializeSelectionsIfNeeded(using loaded: MeshCatalog) {
        if majorHeading.isEmpty || loaded[majorHeading] == nil {
            majorHeading = loaded.majorHeadingsSorted.first ?? ""
        }

        if subspecialty.isEmpty || loaded[majorHeading]?[subspecialty] == nil {
            subspecialty = loaded.subspecialtiesSorted(for: majorHeading).first ?? ""
        }

        if topicGroup.isEmpty || loaded[majorHeading]?[subspecialty]?[topicGroup] == nil {
            topicGroup = loaded.topicGroupsSorted(for: majorHeading, subspecialty: subspecialty).first ?? ""
        }

        // Sensible default for override toggle
        isPrimaryTopic = true
    }
}
