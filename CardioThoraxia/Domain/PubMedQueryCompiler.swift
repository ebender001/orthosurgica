//
//  PubMedQueryCompiler.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation

public enum PubMedQueryCompiler {

    /// Compile a structured QueryDefinition into a PubMed `term=` query string.
    ///
    /// Rules inside each group are combined using the group's op (AND/OR).
    /// Groups are combined with OR.
    /// Filters are appended with AND.
    public static func compile(_ q: QueryDefinition) -> String {
        let groupsPart = compileGroups(q.groups)
        let filtersPart = compileFilters(q.filters)

        switch (groupsPart.isEmpty, filtersPart.isEmpty) {
        case (false, false):
            return "\(groupsPart) AND \(filtersPart)"
        case (false, true):
            return groupsPart
        case (true, false):
            return filtersPart
        case (true, true):
            return "" // should not happen for a meaningful query
        }
    }

    // MARK: - Groups

    private static func compileGroups(_ groups: [QueryGroup]) -> String {
        let compiled = groups
            .map { compileGroup($0) }
            .filter { !$0.isEmpty }

        guard !compiled.isEmpty else { return "" }
        if compiled.count == 1 { return compiled[0] }

        // OR across groups
        return compiled.map { "(\($0))" }.joined(separator: " OR ")
    }

    private static func compileGroup(_ group: QueryGroup) -> String {
        let compiledRules = group.rules
            .map { compileRule($0) }
            .filter { !$0.isEmpty }

        guard !compiledRules.isEmpty else { return "" }
        if compiledRules.count == 1 { return compiledRules[0] }

        let joiner = (group.op == .and) ? " AND " : " OR "
        return compiledRules.map { "(\($0))" }.joined(separator: joiner)
    }

    // MARK: - Rules

    private static func compileRule(_ rule: QueryRule) -> String {
        switch rule {
        case .mesh(let term, let majorTopic):
            // Some user-facing “topics” are not valid MeSH descriptors. If we only emit a MeSH tag,
            // PubMed may return 0 results (e.g., "Aortic Root"[MeSH Terms]).
            // To make the UX resilient, include a Title/Abstract keyword fallback.
            //
            // - If majorTopic is true, we still prefer [Majr] but add the fallback.
            // - If majorTopic is false, we use [MeSH Terms] and add the fallback.
            let meshPart = majorTopic
                ? "\(quoteIfNeeded(term))[Majr]"
                : "\(quoteIfNeeded(term))[MeSH Terms]"
            let keywordFallback = "\(quoteIfNeeded(term))[tiab]"
            return "(\(meshPart) OR \(keywordFallback))"

        case .keyword(let term, let field):
            return "\(quoteIfNeeded(term))[\(field.rawValue)]"

        case .journal(let j):
            return "\(quoteIfNeeded(j))[jour]"

        case .author(let a):
            // PubMed author tag is [au]
            return "\(quoteIfNeeded(a))[au]"

        case .publicationType(let pt):
            return "\(quoteAlways(pt))[pt]"
            
        case .freeText(let term):
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "" : "(\(trimmed))"
        }
        
    }

    // MARK: - Filters

    private static func compileFilters(_ f: QueryFilters) -> String {
        var parts: [String] = []

        if let date = f.date {
            parts.append(compileDateFilter(date))
        }
        if f.humansOnly {
            parts.append("humans[MeSH Terms]")
        }
        if f.englishOnly {
            parts.append("english[la]")
        }
        if f.hasAbstractOnly {
            parts.append("hasabstract[text]")
        }
        if !f.publicationTypes.isEmpty {
            let pts = f.publicationTypes
                .map { "\(quoteAlways($0))[pt]" }
                .map { "(\($0))" }
                .joined(separator: " OR ")
            parts.append(partsForORBlock(pts))
        }

        return parts.joined(separator: " AND ")
    }

    private static func partsForORBlock(_ inner: String) -> String {
        // Ensure OR blocks are wrapped once.
        // Caller may already include parentheses; normalize here.
        if inner.hasPrefix("(") && inner.hasSuffix(")") { return inner }
        return "(\(inner))"
    }

    private static func compileDateFilter(_ df: DateFilter) -> String {
        switch df {
        case .lastDays(let days):
            // PubMed supports “last N days” in [dp] with quotes.
            return "\"last \(days) days\"[dp]"

        case .range(let from, let to):
            // Use DP range with YYYY/MM/DD formatting.
            let fromStr = formatDPDate(from)
            let toStr = formatDPDate(to)
            return "(\(quote(fromStr))[dp] : \(quote(toStr))[dp])"
        }
    }

    private static func formatDPDate(_ date: Date) -> String {
        // PubMed is happy with YYYY/MM/DD format for [dp].
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d/%02d/%02d", y, m, d)
    }

    // MARK: - Quoting / Escaping
    
    private static func quoteAlways(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return quote(trimmed)
    }

    private static func quoteIfNeeded(_ s: String) -> String {
        // Always quote if it contains whitespace or punctuation that commonly breaks terms.
        // Safer to quote more often than less with PubMed.
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "\"\"" }

        let needsQuotes = trimmed.contains(where: { $0.isWhitespace }) || trimmed.contains("\"")
        return needsQuotes ? quote(trimmed) : trimmed
    }

    private static func quote(_ s: String) -> String {
        // Escape embedded quotes
        let escaped = s.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
