//
//  SwiftDataMapping.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation

enum QueryCodec {
    static func encode(_ q: QueryDefinition) throws -> Data {
        try JSONEncoder().encode(q)
    }
    static func decode(_ data: Data) throws -> QueryDefinition {
        try JSONDecoder().decode(QueryDefinition.self, from: data)
    }
}

extension FeedRecord {
    func toDomain() throws -> Feed {
        Feed(
            id: id,
            title: title,
            categoryPath: categoryPath,
            query: try QueryCodec.decode(queryJSON),
            sort: PubMedSort(rawValue: sortRaw) ?? .pubDate,
            pageSize: pageSize,
            lastRefreshedAt: lastRefreshedAt
        )
    }

    static func fromDomain(_ feed: Feed) throws -> FeedRecord {
        FeedRecord(
            id: feed.id,
            title: feed.title,
            categoryPath: feed.categoryPath,
            sortRaw: feed.sort.rawValue,
            pageSize: feed.pageSize,
            lastRefreshedAt: feed.lastRefreshedAt,
            queryJSON: try QueryCodec.encode(feed.query)
        )
    }
}

extension ArticleRecord {
    func toDomain() -> Article {
        Article(
            id: pmid,
            title: title,
            abstractText: abstractText,
            journal: journal,
            year: year,
            month: month,
            authors: authors,
            doi: doi,
            pmcID: pmcID,
            publicationTypes: publicationTypes,
            meshHeadings: meshHeadings,
            keywords: keywords
        )
    }

    static func fromDomain(_ a: Article, feed: FeedRecord) -> ArticleRecord {
        ArticleRecord(
            pmid: a.id,
            title: a.title,
            abstractText: a.abstractText,
            journal: a.journal,
            year: a.year,
            month: a.month,
            authors: a.authors,
            doi: a.doi,
            pmcID: a.pmcID,
            publicationTypes: a.publicationTypes,
            meshHeadings: a.meshHeadings,
            keywords: a.keywords,
            fetchedAt: .now,
            feed: feed
        )
    }
}
