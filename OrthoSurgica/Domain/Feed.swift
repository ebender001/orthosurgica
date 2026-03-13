//
//  Feed.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 1/28/26.
//

import Foundation

public struct Feed: Identifiable, Codable, Hashable {
    public var id: UUID
    public var title: String                  // e.g. "Aortic Valve"
    public var categoryPath: [String]         // e.g. ["Cardiac Surgery", "Aortic Valve"]
    public var query: QueryDefinition
    public var sort: PubMedSort
    public var pageSize: Int                  // e.g. 25, 50, 100
    public var lastRefreshedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        categoryPath: [String],
        query: QueryDefinition,
        sort: PubMedSort = .pubDate,
        pageSize: Int = 50,
        lastRefreshedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.categoryPath = categoryPath
        self.query = query
        self.sort = sort
        self.pageSize = pageSize
        self.lastRefreshedAt = lastRefreshedAt
    }
}

public enum PubMedSort: String, Codable, CaseIterable, Hashable {
    case pubDate = "pub+date"
    case relevance = "relevance"
}
