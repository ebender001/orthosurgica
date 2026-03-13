//
//  ArticleRecord.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation
import SwiftData

@Model
final class ArticleRecord {
    @Attribute(.unique) var id: UUID

    /// PMID
    var pmid: String

    var title: String
    var abstractText: String?
    var journal: String?
    var year: Int?
    var month: String?

    var authors: [String]
    var doi: String?
    var pmcID: String?

    var publicationTypes: [String]
    var meshHeadings: [String]
    var keywords: [String]

    var fetchedAt: Date

    // MARK: - AI Insight (offline cache)
    /// The most recent AI Insight payload as raw JSON (matches your server schema).
    var aiInsightJSON: String?

    /// Metadata to help you know if the cached insight is stale.
    var aiInsightGeneratedAt: Date?
    var aiInsightModel: String?
    var aiInsightPromptVersion: Int?

    /// True if this insight was returned from the server cache.
    var aiInsightCacheHit: Bool?

    /// When the client last fetched an insight (cached or generated).
    var aiInsightFetchedAt: Date?

    @Relationship var feed: FeedRecord?
    
    @Relationship(inverse: \SearchRecord.articles)
    var searches: [SearchRecord] = []

    init(
        id: UUID = UUID(),
        pmid: String,
        title: String,
        abstractText: String? = nil,
        journal: String? = nil,
        year: Int? = nil,
        month: String? = nil,
        authors: [String] = [],
        doi: String? = nil,
        pmcID: String? = nil,
        publicationTypes: [String] = [],
        meshHeadings: [String] = [],
        keywords: [String] = [],
        fetchedAt: Date = .now,
        aiInsightJSON: String? = nil,
        aiInsightGeneratedAt: Date? = nil,
        aiInsightModel: String? = nil,
        aiInsightPromptVersion: Int? = nil,
        aiInsightCacheHit: Bool? = nil,
        aiInsightFetchedAt: Date? = nil,
        feed: FeedRecord? = nil
    ) {
        self.id = id
        self.pmid = pmid
        self.title = title
        self.abstractText = abstractText
        self.journal = journal
        self.year = year
        self.month = month
        self.authors = authors
        self.doi = doi
        self.pmcID = pmcID
        self.publicationTypes = publicationTypes
        self.meshHeadings = meshHeadings
        self.keywords = keywords
        self.fetchedAt = fetchedAt
        self.aiInsightJSON = aiInsightJSON
        self.aiInsightGeneratedAt = aiInsightGeneratedAt
        self.aiInsightModel = aiInsightModel
        self.aiInsightPromptVersion = aiInsightPromptVersion
        self.aiInsightCacheHit = aiInsightCacheHit
        self.aiInsightFetchedAt = aiInsightFetchedAt
        self.feed = feed
    }
}

// MARK: - Upsert from network Article

extension ArticleRecord {

    /// Creates or updates an `ArticleRecord` for the given `Article` (network model).
    /// - Returns: The upserted `ArticleRecord`.
    @MainActor
    static func upsert(from article: Article, in context: ModelContext) throws -> ArticleRecord {
        // We treat PMID as the logical unique key.
        let pmid = article.id

        let descriptor = FetchDescriptor<ArticleRecord>(
            predicate: #Predicate { $0.pmid == pmid },
            sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
        )

        let matches = try context.fetch(descriptor)

        // If duplicates exist, keep the newest and delete the rest.
        let record: ArticleRecord
        if let existing = matches.first {
            record = existing
            if matches.count > 1 {
                for dup in matches.dropFirst() {
                    context.delete(dup)
                }
            }
        } else {
            record = ArticleRecord(pmid: pmid, title: article.title)
            context.insert(record)
        }

        // Update fields from the network model.
        record.title = article.title
        record.abstractText = article.abstractText
        record.journal = article.journal
        record.year = article.year
        record.month = article.month
        record.authors = article.authors
        record.doi = article.doi
        record.pmcID = article.pmcID
        record.publicationTypes = article.publicationTypes
        record.meshHeadings = article.meshHeadings
        record.keywords = article.keywords
        record.fetchedAt = .now

        // NOTE: We intentionally do NOT overwrite the AI Insight cache fields here.
        // Those should be updated only when an insight is generated/fetched.

        try context.save()
        return record
    }
}
