//
//  SearchRecord.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 2/23/26.
//

import Foundation
import SwiftData

@Model
final class SearchRecord {

    @Attribute(.unique) var id: UUID

    /// The raw query the user entered (free text or structured).
    var queryText: String

    /// Optional human-friendly label (e.g. “Arch renal function papers”).
    var title: String?

    /// When this search was performed.
    var createdAt: Date

    /// Optional JSON string storing filter state
    /// (date ranges, publication types, etc.) so you can
    /// reconstruct the search UI later.
    var filtersJSON: String?

    /// Articles returned for this search (Pattern B relationship).
    ///
    /// Note: The inverse relationship is declared on `ArticleRecord.searches`.
    @Relationship
    var articles: [ArticleRecord]

    init(
        id: UUID = UUID(),
        queryText: String,
        title: String? = nil,
        createdAt: Date = .now,
        filtersJSON: String? = nil,
        articles: [ArticleRecord] = []
    ) {
        self.id = id
        self.queryText = queryText
        self.title = title
        self.createdAt = createdAt
        self.filtersJSON = filtersJSON
        self.articles = articles
    }
}
