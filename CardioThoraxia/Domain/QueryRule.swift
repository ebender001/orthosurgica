//
//  QueryRule.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation

public enum QueryRule: Codable, Hashable {
    case mesh(term: String, majorTopic: Bool)
    case keyword(term: String, field: PubMedField)
    case journal(String)
    case author(String)
    case publicationType(String)
    case freeText(term: String)

    // Codable for enum w/ associated values
    private enum CodingKeys: String, CodingKey { case kind, term, majorTopic, field, value }
    private enum Kind: String, Codable { case mesh, keyword, journal, author, publicationType, freeText }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)

        switch kind {
        case .mesh:
            self = .mesh(
                term: try c.decode(String.self, forKey: .term),
                majorTopic: try c.decode(Bool.self, forKey: .majorTopic)
            )
        case .keyword:
            self = .keyword(
                term: try c.decode(String.self, forKey: .term),
                field: try c.decode(PubMedField.self, forKey: .field)
            )
        case .journal:
            self = .journal(try c.decode(String.self, forKey: .value))
        case .author:
            self = .author(try c.decode(String.self, forKey: .value))
        case .publicationType:
            self = .publicationType(try c.decode(String.self, forKey: .value))
        case .freeText:
            self = .freeText(term: try c.decode(String.self, forKey: .term))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .mesh(let term, let majorTopic):
            try c.encode(Kind.mesh, forKey: .kind)
            try c.encode(term, forKey: .term)
            try c.encode(majorTopic, forKey: .majorTopic)

        case .keyword(let term, let field):
            try c.encode(Kind.keyword, forKey: .kind)
            try c.encode(term, forKey: .term)
            try c.encode(field, forKey: .field)

        case .journal(let value):
            try c.encode(Kind.journal, forKey: .kind)
            try c.encode(value, forKey: .value)

        case .author(let value):
            try c.encode(Kind.author, forKey: .kind)
            try c.encode(value, forKey: .value)

        case .publicationType(let value):
            try c.encode(Kind.publicationType, forKey: .kind)
            try c.encode(value, forKey: .value)
            
        case .freeText(let term):
            try c.encode(Kind.freeText, forKey: .kind)
            try c.encode(term, forKey: .term)
        }
    }
}

public enum PubMedField: String, Codable, CaseIterable, Hashable {
    case titleAbstract = "tiab"
    case title = "ti"
    case abstract = "ab"
    case allFields = "all"
    case meshTerms = "mh"
}
