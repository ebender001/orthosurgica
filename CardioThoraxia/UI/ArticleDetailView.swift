//
//  ArticleDetailView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI

struct ArticleDetailView: View {
    let article: Article

    private struct SharePayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    @State private var sharePayload: SharePayload?

    private var pubmedURL: URL {
        URL(string: "https://pubmed.ncbi.nlm.nih.gov/\(article.id)/")!
    }

    private var tweetText: String {
        // Keep it simple and reliable; you can expand later with AI takeaways, hashtags, etc.
        var parts: [String] = []
        parts.append("🫀 \(article.title)")
        if let journal = article.journal, !journal.isEmpty {
            parts.append("(\(journal))")
        }
        parts.append(pubmedURL.absoluteString)
        parts.append("#CTSurgery")

        var tweet = parts.joined(separator: " ")
        // Safety cap for share text (simple truncation)
        if tweet.count > 280 {
            tweet = String(tweet.prefix(279)) + "…"
        }
        return tweet
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(article.title)
                    .font(.title3)
                    .bold()

                if let journal = article.journal, !journal.isEmpty {
                    Text(journal).foregroundStyle(.secondary)
                }

                if let abstract = article.abstractText, !abstract.isEmpty {
                    Divider()
                    Text("Abstract").font(.headline)
                    Text(abstract).textSelection(.enabled)
                }

                Divider()
                Link("View on PubMed", destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/\(article.id)/")!)
            }
            .padding()
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Share as text + URL (works well with the system share sheet)
                    sharePayload = SharePayload(items: [tweetText, pubmedURL])
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
    }
}
