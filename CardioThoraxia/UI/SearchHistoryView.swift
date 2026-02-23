//
//  SearchHistoryView.swift
//  CardioThoraxia
//

import SwiftUI
import SwiftData

// MARK: - Search History Root

struct SearchHistoryView: View {
    let client: PubMedClient

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SearchRecord.createdAt, order: .reverse)
    private var searches: [SearchRecord]

    var body: some View {
        List {
            if searches.isEmpty {
                ContentUnavailableView(
                    "No search history",
                    systemImage: "clock",
                    description: Text("Run a search to save it here for quick access later.")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(searches) { search in
                    NavigationLink {
                        SearchHistoryResultsView(search: search, client: client)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(search.title ?? "Search")
                                .font(.headline)

                            Text(search.queryText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)

                            HStack(spacing: 10) {
                                Text(search.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("\(search.articles.count) articles")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteSearches)
            }
        }
        .navigationTitle("Search History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func deleteSearches(at offsets: IndexSet) {
        for idx in offsets {
            modelContext.delete(searches[idx])
        }
        try? modelContext.save()
    }
}

// MARK: - Saved Results View

private struct SearchHistoryResultsView: View {
    let search: SearchRecord
    let client: PubMedClient

    var body: some View {
        List {
            if search.articles.isEmpty {
                ContentUnavailableView(
                    "No saved articles",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("This search has no persisted articles yet.")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(search.articles) { record in
                    NavigationLink {
                        ArticleDetailView(article: record.asArticle)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.title)
                                .font(.headline)
                                .lineLimit(3)

                            if let journal = record.journal, !journal.isEmpty {
                                Text(journal)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            HStack(spacing: 10) {
                                if let year = record.year {
                                    Text(String(year))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let month = record.month {
                                    let m = String(describing: month)
                                    if !m.isEmpty {
                                        Text(m)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .contextMenu {
                        if let url = URL(string: "https://pubmed.ncbi.nlm.nih.gov/\(record.pmid)/") {
                            Link("Open in PubMed", destination: url)
                        }
                    }
                }
            }
        }
        .navigationTitle(search.title ?? "Search")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ArticleRecord -> Article

private extension ArticleRecord {
    var asArticle: Article {
        // NOTE: Adjust this initializer if your `Article` model differs.
        // This mapping is intentionally conservative and only uses fields your UI already stores.
        return Article(
            id: self.pmid,
            title: self.title,
            abstractText: self.abstractText,
            journal: self.journal,
            year: self.year,
            month: self.month,
            authors: self.authors,
            doi: self.doi,
            pmcID: self.pmcID,
            publicationTypes: self.publicationTypes,
            meshHeadings: self.meshHeadings,
            keywords: self.keywords
        )
    }
}
