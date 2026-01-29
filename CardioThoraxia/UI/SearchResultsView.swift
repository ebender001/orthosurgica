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
                        ForEach(vm.articles, id: \.id) { article in
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
    }
}
