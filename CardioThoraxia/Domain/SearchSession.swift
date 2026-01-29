//
//  SearchSession.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation

/// Represents a single ESearch `usehistory=y` result set, used for paging EFetch.
/// Treat as ephemeral: recreate on refresh.
public struct SearchSession: Codable, Hashable {
    public let webEnv: String
    public let queryKey: String
    public let totalCount: Int
    public var nextRetStart: Int
    public let createdAt: Date

    public init(
        webEnv: String,
        queryKey: String,
        totalCount: Int,
        nextRetStart: Int,
        createdAt: Date = .now
    ) {
        self.webEnv = webEnv
        self.queryKey = queryKey
        self.totalCount = totalCount
        self.nextRetStart = nextRetStart
        self.createdAt = createdAt
    }

    public var hasMore: Bool { nextRetStart < totalCount }
}
