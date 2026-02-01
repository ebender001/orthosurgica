//
//  QueryDefinition.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation

public struct QueryDefinition: Codable, Hashable {
    /// OR across groups. (Each group has its own AND/OR operator across rules.)
    public var groups: [QueryGroup]
    public var filters: QueryFilters

    /// True when there are no rules in any group AND filters are at their default values.
    public var isEmpty: Bool {
        groups.allSatisfy { $0.rules.isEmpty } && filters.isDefault
    }

    /// Removes all rules (keeps filter defaults).
    public mutating func clearAll() {
        groups.removeAll()
        filters = .init()
    }

    /// Convenience empty query.
    public static var empty: QueryDefinition {
        QueryDefinition(groups: [], filters: .init())
    }

    public init(groups: [QueryGroup], filters: QueryFilters = .init()) {
        self.groups = groups
        self.filters = filters
    }

    /// Convenience: one default AND-group.
    public static func andGroup(_ rules: [QueryRule], filters: QueryFilters = .init()) -> QueryDefinition {
        QueryDefinition(groups: [QueryGroup(op: .and, rules: rules)], filters: filters)
    }
}

public struct QueryGroup: Identifiable, Codable, Hashable {
    public var id: UUID
    public var op: GroupOp
    public var rules: [QueryRule]

    public init(id: UUID = UUID(), op: GroupOp, rules: [QueryRule]) {
        self.id = id
        self.op = op
        self.rules = rules
    }
}

public enum GroupOp: String, Codable, CaseIterable, Hashable {
    case and, or
}

public struct QueryFilters: Codable, Hashable {
    /// Used to determine whether any filters are actively narrowing the query.
    public var isDefault: Bool {
        date == nil
        && humansOnly == true
        && englishOnly == true
        && hasAbstractOnly == false
        && publicationTypes.isEmpty
    }

    public var date: DateFilter?
    public var humansOnly: Bool
    public var englishOnly: Bool
    public var hasAbstractOnly: Bool
    public var publicationTypes: [String]     // e.g. ["Clinical Trial", "Review"]

    public init(
        date: DateFilter? = nil,
        humansOnly: Bool = true,
        englishOnly: Bool = true,
        hasAbstractOnly: Bool = false,
        publicationTypes: [String] = []
    ) {
        self.date = date
        self.humansOnly = humansOnly
        self.englishOnly = englishOnly
        self.hasAbstractOnly = hasAbstractOnly
        self.publicationTypes = publicationTypes
    }
}

public enum DateFilter: Codable, Hashable {
    case lastDays(Int)
    case range(from: Date, to: Date)

    // Codable for enum w/ associated values
    private enum CodingKeys: String, CodingKey { case kind, days, from, to }
    private enum Kind: String, Codable { case lastDays, range }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .lastDays:
            let days = try c.decode(Int.self, forKey: .days)
            self = .lastDays(days)
        case .range:
            let from = try c.decode(Date.self, forKey: .from)
            let to = try c.decode(Date.self, forKey: .to)
            self = .range(from: from, to: to)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .lastDays(let days):
            try c.encode(Kind.lastDays, forKey: .kind)
            try c.encode(days, forKey: .days)
        case .range(let from, let to):
            try c.encode(Kind.range, forKey: .kind)
            try c.encode(from, forKey: .from)
            try c.encode(to, forKey: .to)
        }
    }
}
