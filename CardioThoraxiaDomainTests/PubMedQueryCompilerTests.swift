//
//  PubMedQueryCompilerTests.swift
//  CardioThoraxiaDomainTests
//
//  Created by Edward Bender on 1/29/26.
//

import XCTest
@testable import CardioThoraxia

final class PubMedQueryCompilerTests: XCTestCase {

    func testANDGroupWithFilters() throws {
        let q = QueryDefinition(
            groups: [
                QueryGroup(op: .and, rules: [
                    .mesh(term: "Aortic Valve", majorTopic: true),
                    .keyword(term: "TAVR", field: .titleAbstract),
                    .journal("J Thorac Cardiovasc Surg")
                ])
            ],
            filters: QueryFilters(
                date: .lastDays(30),
                humansOnly: true,
                englishOnly: true,
                hasAbstractOnly: true,
                publicationTypes: ["Clinical Trial", "Review"]
            )
        )

        let term = PubMedQueryCompiler.compile(q)

        XCTAssertTrue(term.contains("\"Aortic Valve\"[Majr]"))
        XCTAssertTrue(term.contains("TAVR[tiab]"))
        XCTAssertTrue(term.contains("\"J Thorac Cardiovasc Surg\"[jour]"))

        XCTAssertTrue(term.contains("english[la]"))
        XCTAssertTrue(term.contains("humans[MeSH Terms]"))
        XCTAssertTrue(term.contains("hasabstract[text]"))

        XCTAssertTrue(term.contains("\"Clinical Trial\"[pt]"))
        XCTAssertTrue(term.contains("\"Review\"[pt]"))

        // We choose a simple, PubMed-friendly date syntax for last-days.
        XCTAssertTrue(term.contains("\"last 30 days\"[dp]"))
    }

    func testMultipleGroupsAreORed() throws {
        let q = QueryDefinition(
            groups: [
                QueryGroup(op: .and, rules: [
                    .keyword(term: "lobectomy", field: .titleAbstract),
                    .keyword(term: "robotic", field: .titleAbstract)
                ]),
                QueryGroup(op: .and, rules: [
                    .keyword(term: "segmentectomy", field: .titleAbstract),
                    .keyword(term: "robotic", field: .titleAbstract)
                ])
            ],
            filters: .init()
        )

        let term = PubMedQueryCompiler.compile(q)

        // Expect "(group1) OR (group2)" structure
        XCTAssertTrue(term.contains("lobectomy[tiab]"))
        XCTAssertTrue(term.contains("segmentectomy[tiab]"))
        XCTAssertTrue(term.contains(" OR "))
    }

    func testRangeDateFilterCompilesToDPRange() throws {
        // Use fixed dates to make the test stable.
        let from = Date(timeIntervalSince1970: 1_700_000_000) // ~2023
        let to   = Date(timeIntervalSince1970: 1_700_086_400) // +1 day

        let q = QueryDefinition.andGroup(
            [.keyword(term: "esophagectomy", field: .titleAbstract)],
            filters: QueryFilters(date: .range(from: from, to: to))
        )

        let term = PubMedQueryCompiler.compile(q)

        // Format: ("YYYY/MM/DD"[dp] : "YYYY/MM/DD"[dp])
        XCTAssertTrue(term.contains("[dp] : "))
        XCTAssertTrue(term.contains("esophagectomy[tiab]"))
    }

    func testEscapesQuotesInsideTerms() throws {
        let q = QueryDefinition.andGroup([
            .keyword(term: #"SAVR "vs" TAVR"#, field: .titleAbstract)
        ])

        let term = PubMedQueryCompiler.compile(q)
        // Internal quotes should be escaped inside the generated quotes.
        XCTAssertTrue(term.contains(#""SAVR \"vs\" TAVR"[tiab]"#))
    }
}
