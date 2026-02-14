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
    @Environment(\.colorScheme) private var colorScheme

    private var pubmedURL: URL {
        URL(string: "https://pubmed.ncbi.nlm.nih.gov/\(article.id)/")!
    }

    private var badgeTintOpacity: Double { colorScheme == .dark ? 0.28 : 0.14 }
    private var badgeStrokeOpacity: Double { colorScheme == .dark ? 0.32 : 0.25 }

    private func scholarlyTitleCase(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return input }

        // Words typically lowercased in scholarly/AMA-style title case unless first/last.
        let minorWords: Set<String> = [
            "a","an","and","as","at","but","by","for","from","in","nor","of","on","or","per","the","to","via","with","without"
        ]

        // Split on spaces while preserving simple punctuation inside tokens.
        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !parts.isEmpty else { return trimmed }

        func capitalizeToken(_ token: String) -> String {
            // If token contains letters, capitalize first letter and lowercase the rest.
            // Preserve leading/trailing punctuation.
            let leadingSub = token.prefix { !$0.isLetter && !$0.isNumber }
            let trailingSub = token.reversed().prefix { !$0.isLetter && !$0.isNumber }.reversed()
            let leading = String(leadingSub)
            let trailing = String(trailingSub)
            let coreStart = token.index(token.startIndex, offsetBy: leading.count)
            let coreEnd = token.index(token.endIndex, offsetBy: -trailing.count)
            let core = coreStart <= coreEnd ? String(token[coreStart..<coreEnd]) : ""

            guard !core.isEmpty else { return token }

            // Handle hyphenated words: "endovascular-therapy" => "Endovascular-Therapy"
            let hyphenated = core.split(separator: "-", omittingEmptySubsequences: false).map { part -> String in
                let s = String(part)
                guard let first = s.first else { return s }
                return String(first).uppercased() + s.dropFirst().lowercased()
            }.joined(separator: "-")

            return "\(leading)\(hyphenated)\(trailing)"
        }

        var output: [String] = []

        for (idx, token) in parts.enumerated() {

            // Keep all-caps abbreviations (e.g., "JAMA", "CTS") as-is.
            let letters = token.filter { $0.isLetter }
            let isAllCapsAbbrev = !letters.isEmpty && letters == letters.uppercased() && letters.count <= 6

            if isAllCapsAbbrev {
                output.append(token)
                continue
            }

            let isFirst = idx == 0
            let isLast = idx == parts.count - 1

            // Compare minor-word status on the core token (strip punctuation for check).
            let coreLower = token.trimmingCharacters(in: CharacterSet.punctuationCharacters).lowercased()

            if !isFirst && !isLast && minorWords.contains(coreLower) {
                // Lowercase minor words, preserve punctuation.
                // Simple approach: lowercase the whole token except keep punctuation as-is.
                // Then capitalize if the token is something like "of," => "of,"
                output.append(token.lowercased())
            } else {
                output.append(capitalizeToken(token))
            }
        }

        return output.joined(separator: " ")
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

    private var authorsDisplayText: String? {
        guard !article.authors.isEmpty else { return nil }
        if article.authors.count > 4 {
            let firstFour = article.authors.prefix(4).joined(separator: ", ")
            return firstFour + ", et al."
        } else {
            return article.authors.joined(separator: ", ")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle().fill(article.kind.tint.opacity(badgeTintOpacity))
                        )
                        .overlay(
                            Circle().strokeBorder(article.kind.tint.opacity(badgeStrokeOpacity), lineWidth: 1)
                        )
                        .frame(width: 18, height: 18)
                        .shadow(radius: 1, y: 1)
                        .padding(.top, 4)
                        .accessibilityLabel(article.kind.accessibilityLabel)

                    Text(article.title)
                        .font(.title3)
                        .bold()
                }

                if let journal = article.journal, !journal.isEmpty {
                    let cleanJournal = journal.split(separator: ":").first.map(String.init) ?? journal
                    let formattedJournal = scholarlyTitleCase(cleanJournal)

                    Text(formattedJournal)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if let authorsText = authorsDisplayText {
                    Text(authorsText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let year = article.year {
                    let yearText = year.formatted(.number.grouping(.never))
                    if let month = article.month, !month.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("\(month) \(yearText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(yearText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
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
