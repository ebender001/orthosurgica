//
//  QueryTermsView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI
import SwiftData
import TipKit

struct QueryTermsView: View {
    @Binding var query: QueryDefinition
    let client: PubMedClient

    @Query(sort: \SearchRecord.createdAt, order: .reverse)
    private var searchHistory: [SearchRecord]
    private let addFirstTopicTip = AddFirstTopicTip()
    private let addAdvancedSearchTip = AddAdvancedSearchTip()
    private let searchHistoryTip = SearchHistoryTip()

    @State private var showingAddTopic = false
    @State private var showingAdvanced = false
    @State private var showResults = false
    @State private var showingHistory = false
    @State private var runSearchPulse = false
    
    @State private var showingClearAllConfirm = false
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("didShowNotificationPrePrompt") private var didShowNotificationPrePrompt = false
    private var queryIsEmpty: Bool {
        // No rules at all -> nothing to clear
        query.groups.allSatisfy { $0.rules.isEmpty }
    }
    
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

    private var badgeTintOpacity: Double { colorScheme == .dark ? 0.28 : 0.14 }
    private var badgeStrokeOpacity: Double { colorScheme == .dark ? 0.32 : 0.25 }

    @ViewBuilder
    private func paletteIcon(_ symbol: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle().fill(tint.opacity(badgeTintOpacity))
                )
                .overlay(
                    Circle().strokeBorder(tint.opacity(badgeStrokeOpacity), lineWidth: 1)
                )
                .frame(width: 28, height: 28)

            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
        }
        .accessibilityHidden(true)
    }

    // MARK: - View Builders (break up body to help the compiler)

    @ViewBuilder
    private var selectedTopicsSection: some View {
        Section("Selected Topics & Criteria") {
            selectedTopicsAndCriteriaContent
            addTopicButton
            advancedSearchButton
            addTopicHint
        }
    }

    @ViewBuilder
    private var selectedTopicsAndCriteriaContent: some View {
        if groupBinding.wrappedValue.rules.isEmpty {
            ContentUnavailableView {
                VStack(spacing: 12) {
                    paletteIcon("list.bullet.rectangle", tint: .indigo)
                        .frame(width: 60, height: 60)

                    Text("Start by adding a topic")
                        .font(.headline)
                }
            } description: {
                Text(
                    "Choose one or more topics to define the focus of your search. " +
                    "You can refine it later with advanced criteria."
                )
            }
        } else {
            topicsAndCriteriaList
        }
    }

    @ViewBuilder
    private var topicsAndCriteriaList: some View {
        let group = groupBinding.wrappedValue

        if topicNames.count >= 2 {
            Picker(
                "Match",
                selection: Binding<GroupOp>(
                    get: { groupBinding.wrappedValue.op },
                    set: { groupBinding.wrappedValue.op = $0 }
                )
            ) {
                Text("All topics").tag(GroupOp.and)
                Text("Any topic").tag(GroupOp.or)
            }
            .pickerStyle(.segmented)

            Text(groupBinding.wrappedValue.op == .and
                 ? "All selected topics must match."
                 : "Any selected topic can match (broader).")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

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
                QueryRuleRow(rule: rule)
            }
        }
        .onDelete { indexSet in
            groupBinding.wrappedValue.rules.remove(atOffsets: indexSet)
        }
    }

    private var addTopicButton: some View {
        Button {
            showingAddTopic = true
        } label: {
            HStack(spacing: 10) {
                paletteIcon("plus", tint: .blue)
                Text(hasTopics ? "Add Another Topic" : "Add First Topic")
            }
        }
        .popoverTip(didShowNotificationPrePrompt ? addFirstTopicTip : nil, arrowEdge: .top)
    }

    private var advancedSearchButton: some View {
        Group {
            if hasTopics {
                Button {
                    showingAdvanced = true
                } label: {
                    HStack(spacing: 10) {
                        paletteIcon("slider.horizontal.3", tint: .teal)
                        Text("Add Advanced Search")
                    }
                }
                .popoverTip(didShowNotificationPrePrompt ? addAdvancedSearchTip : nil, arrowEdge: .top)
            } else {
                Button {
                    showingAdvanced = true
                } label: {
                    HStack(spacing: 10) {
                        paletteIcon("slider.horizontal.3", tint: .secondary)
                        Text("Add Advanced Search")
                    }
                }
                .disabled(true)
                .opacity(0.5)
            }
        }
    }

    @ViewBuilder
    private var addTopicHint: some View {
        if !hasTopics {
            Text("Add a topic first to define the focus of your search.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var howThisWorksSection: some View {
        Section("How this works") {
            Text(reassuranceText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var runSearchSection: some View {
        Section {
            VStack(spacing: 8) {
                Button {
                    showResults = true
                } label: {
                    HStack(spacing: 10) {
                        paletteIcon("magnifyingglass", tint: .indigo)
                            .scaleEffect(hasTopics ? (runSearchPulse ? 1.06 : 1.0) : 0.96)
                        Text("Run Search")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasTopics)
                .scaleEffect(hasTopics ? (runSearchPulse ? 1.03 : 1.0) : 0.985)
                .opacity(hasTopics ? 1.0 : 0.92)
                .animation(.easeInOut(duration: 0.18), value: runSearchPulse)

                if !hasTopics {
                    Text("Add at least one topic to run a search.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    var body: some View {
        Form {
            // Reliable TipKit placement (toolbar popovers can be inconsistent)
            if !searchHistory.isEmpty {
                Section {
                    TipView(searchHistoryTip)
                        .onTapGesture {
                            showingHistory = true
                        }
                }
            }

            selectedTopicsSection
            howThisWorksSection
            runSearchSection
        }
        .tint(.indigo)
        .navigationTitle("CardioThoraxia")
        .navigationSubtitleIfAvailable("Build Your Search")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !searchHistory.isEmpty {
                    Button {
                        showingHistory = true
                    } label: {
                        Label("History", systemImage: "clock")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !queryIsEmpty {
                    Button("Clear All") {
                        showingClearAllConfirm = true
                    }
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: queryIsEmpty)
        .onChange(of: showingAddTopic) { _, isShowing in
            guard !isShowing, hasTopics else { return }
            runSearchPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                runSearchPulse = false
            }
        }
        .onChange(of: hasTopics) { _, newValue in
            // If topics become available while no sheet is covering the view, pulse once.
            guard newValue, !showingAddTopic else { return }
            runSearchPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                runSearchPulse = false
            }
        }
        .alert("Clear all search criteria?", isPresented: $showingClearAllConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                // Reset to an empty topics group (your Binding will keep this consistent)
                query.groups = [QueryGroup(op: .and, rules: [])]
                // Close any in-progress flows
                showResults = false
                showingAddTopic = false
                showingAdvanced = false
                editingTopic = nil
            }
        } message: {
            Text("This will remove all selected topics and any additional criteria.")
        }

        .navigationDestination(isPresented: $showResults) {
            SearchResultsView(query: query, client: client)
        }
        .navigationDestination(isPresented: $showingHistory) {
            SearchHistoryView(client: client)
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
                AdvancedSearchEntryView(
                    baseQuery: PubMedQueryCompiler.compile(query)
                ) { result in
                    switch result.mode {
                    case .appendClause:
                        groupBinding.wrappedValue.rules.append(.freeText(term: result.text))

                    case .editFullQuery:
                        // Replace existing topic rules with a single free-text rule.
                        // This gives power users full control over the PubMed term string.
                        groupBinding.wrappedValue.rules = [.freeText(term: result.text)]
                        groupBinding.wrappedValue.op = .and
                    }

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

extension View {
    @ViewBuilder
    func navigationSubtitleIfAvailable(_ subtitle: String) -> some View {
        if #available(iOS 26.0, *) {
            self.navigationSubtitle(subtitle)
        } else {
            self
        }
    }
}
