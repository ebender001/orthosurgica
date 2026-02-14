//
//  SearchResultsView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI

struct SearchResultsView: View {
    let query: QueryDefinition
    let client: PubMedClient

    @StateObject private var vm: SearchResultsViewModel
    @State private var didAutoRun = false
    @State private var selectedKinds: Set<ArticleKind> = []
    
    var filteredArticles: [Article] {
        guard !selectedKinds.isEmpty else { return vm.articles }
        return vm.articles.filter { selectedKinds.contains($0.kind) }
    }

    init(query: QueryDefinition, client: PubMedClient) {
        self.query = query
        self.client = client
        _vm = StateObject(wrappedValue: SearchResultsViewModel(client: client))
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
            await vm.refresh(query: query, retMax: 20)
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
