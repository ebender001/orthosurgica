//
//  FeedRecord.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation
import SwiftData

@Model
final class FeedRecord {
    @Attribute(.unique) var id: UUID

    var title: String
    var categoryPath: [String]
    var sortRaw: String
    var pageSize: Int
    var lastRefreshedAt: Date?

    /// Encoded QueryDefinition (JSON)
    var queryJSON: Data

    @Relationship(deleteRule: .cascade, inverse: \ArticleRecord.feed)
    var articles: [ArticleRecord] = []

    init(
        id: UUID = UUID(),
        title: String,
        categoryPath: [String],
        sortRaw: String,
        pageSize: Int = 50,
        lastRefreshedAt: Date? = nil,
        queryJSON: Data
    ) {
        self.id = id
        self.title = title
        self.categoryPath = categoryPath
        self.sortRaw = sortRaw
        self.pageSize = pageSize
        self.lastRefreshedAt = lastRefreshedAt
        self.queryJSON = queryJSON
    }
}
