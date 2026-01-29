//
//  QueryTermsView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI

struct QueryTermsView: View {
    @Binding var query: QueryDefinition
    let client: PubMedClient

    @State private var showingAddTopic = false
    @State private var showingAdvanced = false

    @State private var showResults = false
    
    private struct EditingTopic: Identifiable {
        let id = UUID()
        let index: Int
        let term: String
        let isPrimary: Bool
    }

    @State private var editingTopic: EditingTopic?

    private var groupBinding: Binding<QueryGroup> {
        Binding(
            get: {
                // Keep builder simple: always one AND group for now
                if query.groups.isEmpty {
                    query.groups = [QueryGroup(op: .and, rules: [])]
                }
                return query.groups[0]
            },
            set: { newValue in
                if query.groups.isEmpty { query.groups = [newValue] }
                else { query.groups[0] = newValue }
            }
        )
    }
    
    private var hasTopics: Bool {
        query.groups
            .flatMap(\.rules)
            .contains {
                if case .mesh = $0 { return true }
                return false
            }
    }
    
    private var topicNames: [String] {
        query.groups
            .flatMap(\.rules)
            .compactMap {
                if case .mesh(let term, _) = $0 {
                    return term
                }
                return nil
            }
    }
    
    private var reassuranceText: String {
        switch topicNames.count {
        case 0:
            return "Start by choosing a topic to define the focus of your search."
        case 1:
            return "Focused on: \(topicNames[0]). You can add more topics or refine the search with advanced criteria."
        case 2...3:
            return "Focused on: \(topicNames.joined(separator: ", ")). Add more topics or refine with advanced criteria."
        default:
            return "Focused on \(topicNames.count) topics. You can add more or refine with advanced criteria."
        }
    }
    
    private var selectedTopicSet: Set<String> {
        Set(query.groups.flatMap(\.rules).compactMap {
            if case .mesh(let term, _) = $0 { return term }
            return nil
        })
    }
    
    private func topicAlreadyAdded(_ term: String) -> Bool {
        query.groups
            .flatMap(\.rules)
            .contains {
                if case .mesh(let existingTerm, _) = $0 {
                    return existingTerm == term
                }
                return false
            }
    }

    var body: some View {
        Form {
            Section("Selected Topics & Criteria") {
                if groupBinding.wrappedValue.rules.isEmpty {
                    ContentUnavailableView(
                        "Start by adding a topic",
                        systemImage: "list.bullet.rectangle",
                        description: Text(
                            "Choose one or more topics to define the focus of your search. " +
                            "You can refine it later with advanced criteria."
                        )
                    )
                } else {
                    let group = groupBinding.wrappedValue

                    ForEach(group.rules.indices, id: \.self) { index in
                        let rule = group.rules[index]

                        switch rule {
                        case .mesh(let term, let isPrimary):
                            Button {
                                if case .mesh(let term, let isPrimary) = groupBinding.wrappedValue.rules[index] {
                                    editingTopic = EditingTopic(
                                        index: index,
                                        term: term,
                                        isPrimary: isPrimary
                                    )
                                }
                            } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Topic")
                                            .font(.headline)

                                        Text(isPrimary ? "\(term) (Primary)" : term)
                                            .foregroundStyle(.secondary)

                                        Text("Tap to edit or swipe left to delete")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                        default:
                            // Keep showing non-topic rules as normal rows for now
                            QueryRuleRow(rule: rule)
                        }
                    }
                    .onDelete { indexSet in
                        groupBinding.wrappedValue.rules.remove(atOffsets: indexSet)
                    }
                    
                }

                Button {
                    showingAddTopic = true
                } label: {
                    Label(
                        hasTopics ? "Add Another Topic" : "Add First Topic",
                        systemImage: "plus.circle"
                    )
                }
                
                Button {
                    showingAdvanced = true
                } label: {
                    Label("Add Advanced Search", systemImage: "plus.circle")
                }
                .disabled(!hasTopics)
                .opacity(hasTopics ? 1.0 : 0.5)
                
                if !hasTopics {
                    Text("Add a topic first to define the focus of your search.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("How this works") {
                Text(reassuranceText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    showResults = true
                } label: {
                    Text("Run Search")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasTopics)

                if !hasTopics {
                    Text("Add at least one topic to run a search.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("CardioThoraxia")
        .navigationSubtitle("Build Your Search")

        .navigationDestination(isPresented: $showResults) {
            SearchResultsView(query: query, client: client)
        }
        .sheet(isPresented: $showingAddTopic) {
            NavigationStack {
                MeshCatalogPickerView(selectedTopics: selectedTopicSet) { term, isPrimary in
                            // still keep the guard here (defense in depth)
                            guard !selectedTopicSet.contains(term) else { return }
                            groupBinding.wrappedValue.rules.append(.mesh(term: term, majorTopic: isPrimary))
                            showingAddTopic = false
                        }
            }
        }
        .sheet(isPresented: $showingAdvanced) {
            NavigationStack {
                AdvancedSearchEntryView { raw in
                    groupBinding.wrappedValue.rules.append(.freeText(term: raw))
                    showingAdvanced = false
                }
            }
        }
        .sheet(item: $editingTopic) { editing in
            NavigationStack {
                EditTopicView(
                    term: editing.term,
                    isPrimary: editing.isPrimary
                ) { newIsPrimary in
                    guard groupBinding.wrappedValue.rules.indices.contains(editing.index) else { return }

                    if case .mesh(let term, _) = groupBinding.wrappedValue.rules[editing.index] {
                        groupBinding.wrappedValue.rules[editing.index] = .mesh(
                            term: term,
                            majorTopic: newIsPrimary
                        )
                    }
                }
            }
        }
    }
}
