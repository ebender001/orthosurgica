//
//  QueryDefinitionTests.swift
//  CardioThoraxiaDomainTests
//
//  Created by Edward Bender on 1/29/26.
//

import XCTest
@testable import CardioThoraxia

@MainActor
final class QueryDefinitionTests: XCTestCase {
    func testQueryDefinition() throws {
        let q = QueryDefinition(groups: [
            QueryGroup(op: .and, rules: [
                .mesh(term: "Aortic Valve", majorTopic: true),
                .keyword(term: "TAVR", field: .titleAbstract),
                .journal("J Thorac Cardiovasc Surg")
            ])
        ], filters: QueryFilters(
            date: .lastDays(30),
            humansOnly: true,
            englishOnly: true,
            hasAbstractOnly: true,
            publicationTypes: ["Clinical Trial", "Review"])
        )
        
        let data = try JSONEncoder().encode(q)
        let decoded = try JSONDecoder().decode(QueryDefinition.self, from: data)
        
        XCTAssertEqual(q, decoded)
    }
    
    func testDateFilter_RangeRoundTrip() throws {
        let from = Date(timeIntervalSince1970: 1_700_000_000)
        let to = Date(timeIntervalSince1970: 1_700_086_400)
        let qf = QueryFilters(date: .range(from: from, to: to))
        
        let data = try JSONEncoder().encode(qf)
        let decoded = try JSONDecoder().decode(QueryFilters.self, from: data)
        
        XCTAssertEqual(qf, decoded)
    }
}

