//
//  ArticleRow.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI

struct ArticleRow: View {
    let article: Article
    @State private var showTypeHint = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // Always-visible soft glass disk
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle().fill(article.kind.tint.opacity(colorScheme == .dark ? 0.28 : 0.14))
                )
                .overlay(
                    Circle().strokeBorder(article.kind.tint.opacity(0.25), lineWidth: 1)
                )
                .frame(width: 18, height: 18)
                .shadow(radius: 1, y: 1)
                .padding(.top, 4)
                .accessibilityLabel(article.kind.accessibilityLabel)

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
        }
        .padding(.vertical, 6)

        // Tooltip
        .overlay(alignment: .topLeading) {
            if showTypeHint {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle().fill(article.kind.tint.opacity(colorScheme == .dark ? 0.28 : 0.14))
                        )
                        .overlay(
                            Circle().strokeBorder(article.kind.tint.opacity(0.25), lineWidth: 0.8)
                        )
                        .frame(width: 10, height: 10)

                    Text(article.kind.accessibilityLabel)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(.secondary.opacity(0.25), lineWidth: 1)
                )
                .shadow(radius: 3, y: 2)
                .offset(x: 28, y: -8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }

        .contentShape(Rectangle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.25)
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showTypeHint = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showTypeHint = false
                        }
                    }
                }
        )
    }
}
