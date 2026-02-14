//
//  ArticleRecord.swift
//  CardioThoraxia
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

    @Relationship var feed: FeedRecord?

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
        self.feed = feed
    }
}
