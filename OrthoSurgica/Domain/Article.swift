//
//  Article.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation

public struct Article: Identifiable, Codable, Hashable {
    public var id: String                    // PMID
    public var title: String
    public var abstractText: String?
    public var journal: String?
    public var year: Int?
    public var month: String?
    public var authors: [String]
    public var doi: String?
    public var pmcID: String?
    public var publicationTypes: [String]
    public var meshHeadings: [String]
    public var keywords: [String]

    public init(
        id: String,
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
        keywords: [String] = []
    ) {
        self.id = id
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
    }

    public var pubMedURL: URL {
        URL(string: "https://pubmed.ncbi.nlm.nih.gov/\(id)/")!
    }
}
