//
//  PubMedClient.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation

// MARK: - URLSessionProtocol (for unit testing)

public protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}


// MARK: - PubMedClient

public actor PubMedClient {

    public struct Configuration: Sendable {
        public var baseURL: URL = URL(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/")!

        /// Optional: include your contact email per NCBI recommendations.
        public var email: String?

        /// Optional: identify the tool/app making requests.
        public var tool: String?

        /// Optional API key (if you choose to support it).
        public var apiKey: String?

        /// Throttle interval between requests (seconds).
        /// Keep conservative by default; you can tune later.
        public var minSecondsBetweenRequests: TimeInterval = 0.34

        public init() {}
    }

    public enum PubMedError: Error, LocalizedError {
        case invalidURL
        case httpStatus(Int)
        case decodingFailed
        case missingHistoryTokens
        case unexpectedResponse

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Failed to build PubMed request URL."
            case .httpStatus(let code): return "PubMed request failed with HTTP status \(code)."
            case .decodingFailed: return "Failed to decode PubMed JSON response."
            case .missingHistoryTokens: return "ESearch response missing WebEnv/query_key (did you set usehistory=y?)."
            case .unexpectedResponse: return "Unexpected PubMed response."
            }
        }
    }

    private let session: URLSessionProtocol
    private var config: Configuration
    private var lastRequestAt: Date?

    public init(session: URLSessionProtocol = URLSession.shared, config: Configuration = .init()) {
        self.session = session
        self.config = config
    }

    public func updateConfig(_ mutate: (inout Configuration) -> Void) {
        mutate(&config)
    }

    // MARK: - ESearch

    /// Runs ESearch with `usehistory=y`, returning a SearchSession (WebEnv/queryKey) for paging EFetch.
    ///
    /// - Parameters:
    ///   - q: Structured domain query definition (compiled using PubMedQueryCompiler).
    ///   - sort: PubMed sort option (e.g. pub+date).
    ///   - retStart: paging start index
    ///   - retMax: number of IDs to return
    ///
    /// - Returns:
    ///   - session: SearchSession for subsequent EFetch calls
    ///   - pmids: optional PMID list (useful for debugging/UI, but paging is via history)
    public func esearch(
        query q: QueryDefinition,
        sort: PubMedSort = .pubDate,
        retStart: Int = 0,
        retMax: Int = 50
    ) async throws -> (session: SearchSession, pmids: [String]) {

        let term = PubMedQueryCompiler.compile(q)

        let url = try buildURL(
            endpoint: "esearch.fcgi",
            queryItems: [
                URLQueryItem(name: "db", value: "pubmed"),
                URLQueryItem(name: "term", value: term),
                URLQueryItem(name: "retmode", value: "json"),
                URLQueryItem(name: "usehistory", value: "y"),
                URLQueryItem(name: "sort", value: sort.rawValue),
                URLQueryItem(name: "retstart", value: String(retStart)),
                URLQueryItem(name: "retmax", value: String(retMax))
            ]
        )

        let data = try await fetch(url: url)
        let decoded: ESearchResponse
        do {
            decoded = try JSONDecoder().decode(ESearchResponse.self, from: data)
        } catch {
            throw PubMedError.decodingFailed
        }

        let result = decoded.esearchresult

        guard
            let webEnv = result.webenv,
            let queryKey = result.querykey
        else {
            throw PubMedError.missingHistoryTokens
        }

        let totalCount = Int(result.count) ?? 0
        let pmids = result.idlist ?? []
        let next = retStart + retMax

        let session = SearchSession(
            webEnv: webEnv,
            queryKey: queryKey,
            totalCount: totalCount,
            nextRetStart: next,
            createdAt: .now
        )

        return (session, pmids)
    }

    // MARK: - EFetch

    /// Runs EFetch using a SearchSession to retrieve detailed article data in XML.
    ///
    /// - Parameters:
    ///   - session: SearchSession returned from ESearch
    ///   - retStart: paging start index
    ///   - retMax: number of articles to return
    ///
    /// - Returns:
    ///   - [Article]: parsed articles
    public func efetch(session: SearchSession, retStart: Int = 0, retMax: Int = 50) async throws -> [Article] {
        let url = try buildURL(
            endpoint: "efetch.fcgi",
            queryItems: [
                URLQueryItem(name: "db", value: "pubmed"),
                URLQueryItem(name: "query_key", value: session.queryKey),
                URLQueryItem(name: "WebEnv", value: session.webEnv),
                URLQueryItem(name: "retmode", value: "xml"),
                URLQueryItem(name: "retstart", value: String(retStart)),
                URLQueryItem(name: "retmax", value: String(retMax))
            ]
        )
        let data = try await fetch(url: url)
        let articles = try PubMedArticleXMLParser.parse(data: data)
        return articles
    }

    // MARK: - Networking helpers

    private func fetch(url: URL) async throws -> Data {
        try await throttleIfNeeded()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PubMedError.unexpectedResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw PubMedError.httpStatus(http.statusCode)
        }
        return data
    }

    private func throttleIfNeeded() async throws {
        guard let last = lastRequestAt else {
            lastRequestAt = Date()
            return
        }
        let elapsed = Date().timeIntervalSince(last)
        let wait = config.minSecondsBetweenRequests - elapsed
        if wait > 0 {
            let ns = UInt64(wait * 1_000_000_000)
            try await Task.sleep(nanoseconds: ns)
        }
        lastRequestAt = Date()
    }

    private func buildURL(endpoint: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents(url: config.baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false)
        var items = queryItems

        if let email = config.email, !email.isEmpty {
            items.append(URLQueryItem(name: "email", value: email))
        }
        if let tool = config.tool, !tool.isEmpty {
            items.append(URLQueryItem(name: "tool", value: tool))
        }
        if let apiKey = config.apiKey, !apiKey.isEmpty {
            items.append(URLQueryItem(name: "api_key", value: apiKey))
        }

        components?.queryItems = items
        guard let url = components?.url else { throw PubMedError.invalidURL }
        return url
    }
}


// MARK: - ESearch DTOs (JSON)

private struct ESearchResponse: Decodable {
    let esearchresult: ESearchResult
}

private struct ESearchResult: Decodable {
    let count: String
    let retstart: String?
    let retmax: String?
    let querykey: String?
    let webenv: String?
    let idlist: [String]?
}


// MARK: - EFetch XML Parsing

private enum PubMedArticleXMLParseError: Error {
    case invalidXML
}

private final class PubMedArticleXMLParser: NSObject, XMLParserDelegate {

    private var articles: [Article] = []

    private var currentPMID: String?
    private var currentTitle: String?
    private var currentAbstractParts: [String] = []
    private var currentJournal: String?
    private var currentYear: Int?
    private var currentMonth: String?
    private var currentAuthors: [String] = []
    private var currentDOI: String?
    private var currentPMCID: String?
    private var currentPublicationTypes: [String] = []
    private var currentMesh: [String] = []
    private var currentKeywords: [String] = []

    private var currentElementText: String = ""
    private var currentArticleIdType: String?

    private var insidePubmedArticle = false

    // To accumulate multiple AbstractText elements
    private var insideAbstractText = false

    // To accumulate multiple Author elements
    private var insideAuthor = false
    private var currentAuthorLastName: String?
    private var currentAuthorForeName: String?
    private var currentAuthorInitials: String?

    // For parsing PubDate or MedlineDate year
    private var insidePubDate = false
    private var insideMedlineDate = false

    static func parse(data: Data) throws -> [Article] {
        let parser = PubMedArticleXMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.shouldResolveExternalEntities = false
        xmlParser.delegate = parser
        if !xmlParser.parse() {
            if let error = xmlParser.parserError {
                throw error
            } else {
                throw PubMedArticleXMLParseError.invalidXML
            }
        }
        return parser.articles
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElementText = ""

        switch elementName {
        case "PubmedArticle":
            insidePubmedArticle = true
            resetCurrentArticleState()
        case "AbstractText":
            insideAbstractText = true
        case "Author":
            insideAuthor = true
            currentAuthorLastName = nil
            currentAuthorForeName = nil
            currentAuthorInitials = nil
        case "ArticleId":
            currentArticleIdType = attributeDict["IdType"]
        case "PubDate":
            insidePubDate = true
        case "MedlineDate":
            insideMedlineDate = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentElementText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmedText = currentElementText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard insidePubmedArticle else {
            currentElementText = ""
            return
        }

        switch elementName {
        case "PMID":
            if currentPMID == nil {
                currentPMID = trimmedText
            }
        case "ArticleTitle":
            currentTitle = trimmedText
        case "AbstractText":
            if insideAbstractText {
                if !trimmedText.isEmpty {
                    currentAbstractParts.append(trimmedText)
                }
                insideAbstractText = false
            }
        case "Title":
            // Journal Title is inside Journal/Title, so check parent context by element path is complicated,
            // but we can assume if insidePubmedArticle and not inside Author or Abstract, this is journal title.
            // We'll assign journal title only if currentJournal is nil or empty to avoid overwriting.
            if currentJournal == nil || currentJournal?.isEmpty == true {
                currentJournal = trimmedText
            }
        case "Year":
            if insidePubDate {
                if let yearInt = Int(trimmedText) {
                    currentYear = yearInt
                }
            }
        case "Month":
            if insidePubDate, currentMonth == nil {
                let normalized = normalizeMonth(trimmedText)
                if !normalized.isEmpty {
                    currentMonth = normalized
                }
            }
        case "MedlineDate":
            if insideMedlineDate {
                // try to parse first 4 digits as year
                if currentYear == nil {
                    let prefix = trimmedText.prefix(4)
                    if let yearInt = Int(prefix) {
                        currentYear = yearInt
                    }
                }

                // try to parse a month token if we don't already have one
                if currentMonth == nil {
                    // examples: "2026 Jan-Feb", "2026 Feb 12", "2026 Spring"
                    let afterYear = trimmedText.count > 4 ? String(trimmedText.dropFirst(4)) : ""
                    let cleaned = afterYear.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        // take the first token, stripping common range separators
                        let token = cleaned
                            .split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "/" })
                            .first
                            .map(String.init) ?? ""
                        let normalized = normalizeMonth(token)
                        if !normalized.isEmpty {
                            currentMonth = normalized
                        }
                    }
                }
            }
            insideMedlineDate = false
        case "PubDate":
            insidePubDate = false
        case "LastName":
            if insideAuthor {
                currentAuthorLastName = trimmedText
            }
        case "ForeName":
            if insideAuthor {
                currentAuthorForeName = trimmedText
            }
        case "Initials":
            if insideAuthor {
                currentAuthorInitials = trimmedText
            }
        case "Author":
            if insideAuthor {
                // Compose author name
                var authorName: String? = nil
                if let last = currentAuthorLastName, !last.isEmpty {
                    if let initials = currentAuthorInitials, !initials.isEmpty {
                        authorName = "\(last) \(initials)"
                    } else {
                        authorName = last
                    }
                } else if let fore = currentAuthorForeName, !fore.isEmpty {
                    authorName = fore
                }
                if let name = authorName, !name.isEmpty {
                    currentAuthors.append(name)
                }
                insideAuthor = false
                currentAuthorLastName = nil
                currentAuthorForeName = nil
                currentAuthorInitials = nil
            }
        case "ArticleId":
            if let idType = currentArticleIdType {
                switch idType.lowercased() {
                case "doi":
                    currentDOI = trimmedText
                case "pmc":
                    currentPMCID = trimmedText
                default:
                    break
                }
            }
            currentArticleIdType = nil
        case "PublicationType":
            if !trimmedText.isEmpty {
                currentPublicationTypes.append(trimmedText)
            }
        case "DescriptorName":
            if !trimmedText.isEmpty {
                currentMesh.append(trimmedText)
            }
        case "Keyword":
            if !trimmedText.isEmpty {
                currentKeywords.append(trimmedText)
            }
        case "PubmedArticle":
            // End of article, create Article if possible
            if let pmid = currentPMID, !pmid.isEmpty,
               let title = currentTitle, !title.isEmpty {
                let abstractJoined = currentAbstractParts.isEmpty ? nil : currentAbstractParts.joined(separator: "\n\n")
                let article = Article(
                    id: pmid,
                    title: title,
                    abstractText: abstractJoined,
                    journal: currentJournal,
                    year: currentYear,
                    month: currentMonth,
                    authors: currentAuthors,
                    doi: currentDOI,
                    pmcID: currentPMCID,
                    publicationTypes: currentPublicationTypes,
                    meshHeadings: currentMesh,
                    keywords: currentKeywords
                )
                articles.append(article)
            }
            insidePubmedArticle = false
            resetCurrentArticleState()
        default:
            break
        }
        currentElementText = ""
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        // No-op
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // No-op, error will be thrown by parse method
    }

    // MARK: - Helpers

    private func resetCurrentArticleState() {
        currentPMID = nil
        currentTitle = nil
        currentAbstractParts = []
        currentJournal = nil
        currentYear = nil
        currentMonth = nil
        currentAuthors = []
        currentDOI = nil
        currentPMCID = nil
        currentPublicationTypes = []
        currentMesh = []
        currentKeywords = []
        currentElementText = ""
        currentArticleIdType = nil
        insideAbstractText = false
        insideAuthor = false
        currentAuthorLastName = nil
        currentAuthorForeName = nil
        currentAuthorInitials = nil
        insidePubDate = false
        insideMedlineDate = false
    }

    private func normalizeMonth(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }

        // If PubMed provides a range like "May-Jun", keep the first month.
        let firstPart = t.split(whereSeparator: { $0 == "-" || $0 == "/" }).first.map(String.init) ?? t
        let s = firstPart.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }

        // Numeric months (e.g., "03")
        if let n = Int(s), (1...12).contains(n) {
            return ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][n - 1]
        }

        // Text months: accept common abbreviations/full names, return 3-letter form.
        let lower = s.lowercased()
        let map: [(String, String)] = [
            ("january","Jan"), ("jan","Jan"),
            ("february","Feb"), ("feb","Feb"),
            ("march","Mar"), ("mar","Mar"),
            ("april","Apr"), ("apr","Apr"),
            ("may","May"),
            ("june","Jun"), ("jun","Jun"),
            ("july","Jul"), ("jul","Jul"),
            ("august","Aug"), ("aug","Aug"),
            ("september","Sep"), ("sep","Sep"), ("sept","Sep"),
            ("october","Oct"), ("oct","Oct"),
            ("november","Nov"), ("nov","Nov"),
            ("december","Dec"), ("dec","Dec")
        ]

        for (key, val) in map where lower.hasPrefix(key) {
            return val
        }

        // Seasonal/other tokens (e.g., "Spring") — return as-is to avoid losing info
        return s
    }
}
