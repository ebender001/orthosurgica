//
//  ArticleDetailView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI

struct ArticleDetailView: View {
    let article: Article

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
    }
}
