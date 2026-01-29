//
//  ArticleRow.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI

struct ArticleRow: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(article.title)
                .font(.headline)
                .lineLimit(2)

            if let journal = article.journal, !journal.isEmpty {
                Text(journal)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let year = article.year {
                Text("\(year) • PMID \(article.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("PMID \(article.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
