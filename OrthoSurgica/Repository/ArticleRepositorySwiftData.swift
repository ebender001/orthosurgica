//
//  ArticleRepositorySwiftData.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation
import SwiftData

/// Simple v1: cache articles per-feed (duplicates across feeds).
final class ArticleRepositorySwiftData {

    private let client: PubMedClient
    private let maxCachedArticlesPerFeed: Int

    init(client: PubMedClient = AppEnvironment.shared.pubMedClient,
         maxCachedArticlesPerFeed: Int = 500) {
        self.client = client
        self.maxCachedArticlesPerFeed = maxCachedArticlesPerFeed
    }

    /// Load cached articles for a feed (fast, offline).
    func loadCachedArticles(feedID: UUID, context: ModelContext) throws -> [Article] {
        let feed = try fetchFeedRecord(feedID: feedID, context: context)

        // Sort by fetchedAt desc (you can choose a different sort later)
        let sorted = feed.articles.sorted { $0.fetchedAt > $1.fetchedAt }
        return sorted.map { $0.toDomain() }
    }

    /// Refresh: ESearch + EFetch + store
    @MainActor
    func refresh(feedID: UUID, context: ModelContext) async throws -> [Article] {
        let feedRecord = try fetchFeedRecord(feedID: feedID, context: context)
        let feed = try feedRecord.toDomain()

        let (session, _) = try await client.esearch(
            query: feed.query,
            sort: feed.sort,
            retStart: 0,
            retMax: feed.pageSize
        )

        let articles = try await client.efetch(
            session: session,
            retStart: 0,
            retMax: feed.pageSize
        )

        // Replace cached page (simple) OR upsert (better). We'll do upsert-per-feed by PMID.
        try upsert(articles: articles, into: feedRecord, context: context)

        feedRecord.lastRefreshedAt = .now
        try evictIfNeeded(feedRecord: feedRecord, context: context)

        try context.save()

        // Return freshly stored (sorted)
        return feedRecord.articles
            .sorted { $0.fetchedAt > $1.fetchedAt }
            .map { $0.toDomain() }
    }

    // MARK: - Internals

    private func fetchFeedRecord(feedID: UUID, context: ModelContext) throws -> FeedRecord {
        let descriptor = FetchDescriptor<FeedRecord>(
            predicate: #Predicate { $0.id == feedID }
        )
        guard let feed = try context.fetch(descriptor).first else {
            throw NSError(domain: "FeedRecord", code: 404, userInfo: [NSLocalizedDescriptionKey: "Feed not found"])
        }
        return feed
    }

    private func upsert(articles: [Article], into feed: FeedRecord, context: ModelContext) throws {
        // Build a lookup of existing articles by PMID for this feed
        var existingByPMID: [String: ArticleRecord] = [:]
        for record in feed.articles {
            existingByPMID[record.pmid] = record
        }

        for a in articles {
            if let existing = existingByPMID[a.id] {
                // Update fields
                existing.title = a.title
                existing.abstractText = a.abstractText
                existing.journal = a.journal
                existing.year = a.year
                existing.authors = a.authors
                existing.doi = a.doi
                existing.pmcID = a.pmcID
                existing.publicationTypes = a.publicationTypes
                existing.meshHeadings = a.meshHeadings
                existing.keywords = a.keywords
                existing.fetchedAt = .now
            } else {
                let rec = ArticleRecord.fromDomain(a, feed: feed)
                feed.articles.append(rec)
                context.insert(rec)
            }
        }
    }

    private func evictIfNeeded(feedRecord: FeedRecord, context: ModelContext) throws {
        guard feedRecord.articles.count > maxCachedArticlesPerFeed else { return }

        let sortedOldestFirst = feedRecord.articles.sorted { $0.fetchedAt < $1.fetchedAt }
        let extra = feedRecord.articles.count - maxCachedArticlesPerFeed
        let toDelete = sortedOldestFirst.prefix(extra)

        for rec in toDelete {
            // Remove from relationship
            feedRecord.articles.removeAll { $0.id == rec.id }
            context.delete(rec)
        }
    }
}
