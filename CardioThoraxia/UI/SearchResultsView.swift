//
//  SearchResultsView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI
import SwiftData

struct SearchResultsView: View {
    let query: QueryDefinition
    let client: PubMedClient

    @Environment(\.modelContext) private var modelContext

    @StateObject private var vm: SearchResultsViewModel
    init(query: QueryDefinition, client: PubMedClient) {
        self.query = query
        self.client = client
        _vm = StateObject(wrappedValue: SearchResultsViewModel(client: client))
    }
    @State private var didAutoRun = false
    @State private var didSaveSearchRecord = false
    @State private var selectedKinds: Set<ArticleKind> = []
    
    var filteredArticles: [Article] {
        guard !selectedKinds.isEmpty else { return vm.articles }
        return vm.articles.filter { selectedKinds.contains($0.kind) }
    }

    // MARK: - Search History (human-friendly)

    private var historyTopicTerms: [String] {
        // Extract user-selected MeSH topics from the query builder.
        // Assumes your rules include: `.mesh(term, isPrimary)`.
        var terms: [String] = []
        for group in query.groups {
            for rule in group.rules {
                if case .mesh(let term, _) = rule {
                    terms.append(term)
                }
            }
        }

        // De-duplicate while preserving order.
        var seen = Set<String>()
        var unique: [String] = []
        unique.reserveCapacity(terms.count)
        for t in terms {
            if !seen.contains(t) {
                unique.append(t)
                seen.insert(t)
            }
        }
        return unique
    }

    private var historyAdvancedRuleCount: Int {
        // Count non-topic rules (advanced criteria).
        var count = 0
        for group in query.groups {
            for rule in group.rules {
                switch rule {
                case .mesh:
                    continue
                default:
                    count += 1
                }
            }
        }
        return count
    }

    private var historyMatchLabel: String {
        // Use the first group's op to describe match behavior.
        guard let first = query.groups.first else { return "" }
        switch first.op {
        case .and: return "All topics"
        case .or: return "Any topic"
        }
    }

    private var titleForHistory: String {
        let terms = historyTopicTerms
        guard !terms.isEmpty else { return "Search" }
        if terms.count <= 2 {
            return terms.joined(separator: ", ")
        }
        return "\(terms.prefix(2).joined(separator: ", ")) +\(terms.count - 2)"
    }

    private var queryTextForHistory: String {
        let terms = historyTopicTerms
        let topicsPart = terms.isEmpty ? "Topics: (none)" : "Topics: \(terms.joined(separator: "; "))"

        var parts: [String] = [topicsPart]

        if !historyMatchLabel.isEmpty {
            parts.append("Match: \(historyMatchLabel)")
        }

        if historyAdvancedRuleCount > 0 {
            parts.append("Advanced: \(historyAdvancedRuleCount) filter\(historyAdvancedRuleCount == 1 ? "" : "s")")
        }

        return parts.joined(separator: " • ")
    }

    private func filtersJSONForHistory() -> String? {
        // Store minimal info now; you can expand later (date ranges, PubMed params, etc.).
        // We also include any UI filters currently applied.
        let payload: [String: Any] = [
            "selectedKinds": selectedKinds.map { $0.displayName }.sorted(),
            "match": historyMatchLabel,
            "topics": historyTopicTerms,
            "advancedRuleCount": historyAdvancedRuleCount
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading:
                ProgressView("Searching…")

            case .failed(let message):
                ContentUnavailableView(
                    "Search failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )

            case .loaded:
                if vm.articles.isEmpty {
                    ContentUnavailableView(
                        "No results",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Try adding another topic or loosening criteria.")
                    )
                } else {
                    List {
                        ForEach(filteredArticles, id: \.id) { article in
                            NavigationLink {
                                ArticleDetailView(article: article)
                            } label: {
                                ArticleRow(article: article)
                            }
                        }

                        if vm.totalCount == 0 || vm.articles.count < vm.totalCount {
                            HStack {
                                Spacer()
                                if vm.isLoadingMore {
                                    ProgressView()
                                } else {
                                    Button("Load more") {
                                        Task { await vm.loadMore(retMax: 20) }
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .task {
            guard !didAutoRun else { return }
            didAutoRun = true
            await vm.run(query: query, retMax: 20)
        }
        .refreshable {
            didSaveSearchRecord = false
            await vm.refresh(query: query, retMax: 20)
        }
        .onChange(of: vm.state) { _, newState in
            guard !didSaveSearchRecord else { return }
            guard case .loaded = newState else { return }
            guard !vm.articles.isEmpty else { return }

            // Create/Update ArticleRecord rows for offline access and link them to a SearchRecord.
            var articleRecords: [ArticleRecord] = []
            articleRecords.reserveCapacity(vm.articles.count)

            do {
                for article in vm.articles {
                    let rec = try ArticleRecord.upsert(from: article, in: modelContext)
                    articleRecords.append(rec)
                }

                let record = SearchRecord(
                    queryText: queryTextForHistory,
                    title: titleForHistory,
                    createdAt: .now,
                    filtersJSON: filtersJSONForHistory(),
                    articles: articleRecords
                )

                modelContext.insert(record)
                try modelContext.save()
                didSaveSearchRecord = true
            } catch {
                // Non-fatal; avoid blocking UI.
                print("Failed to save SearchRecord / ArticleRecords:", error.localizedDescription)
            }
        }
        .navigationTitle("Results")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Clear Filter") { selectedKinds.removeAll() }

                    Divider()

                    ForEach(ArticleKind.allCases, id: \.self) { kind in
                        Button {
                            if selectedKinds.contains(kind) {
                                selectedKinds.remove(kind)
                            } else {
                                selectedKinds.insert(kind)
                            }
                        } label: {
                            Label(
                                kind.displayName,
                                systemImage: selectedKinds.contains(kind) ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    }
                } label: {
                    Image(systemName: selectedKinds.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel("Filter publication type")
            }
        }
    }
}
