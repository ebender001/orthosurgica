//
//  ArticleKind.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 2/14/26.
//

import SwiftUI

public enum ArticleKind: String, Codable, Hashable {
    case metaAnalysis
    case systematicReview
    case review
    case guideline
    case randomizedTrial
    case clinicalTrial
    case caseReport
    case editorial
    case technique
    case originalResearch
    case other

    public var tint: Color {
        switch self {
        case .metaAnalysis:      return .purple
        case .systematicReview:  return .purple
        case .review:            return .teal
        case .guideline:         return .green
        case .randomizedTrial:   return .blue
        case .clinicalTrial:     return .blue
        case .caseReport:        return .orange
        case .editorial:         return .gray
        case .technique:         return .red
        case .originalResearch:  return .indigo
        case .other:             return .secondary
        }
    }

    public var accessibilityLabel: String {
        switch self {
        case .metaAnalysis: return "Meta-analysis"
        case .systematicReview: return "Systematic review"
        case .review: return "Review"
        case .guideline: return "Guideline"
        case .randomizedTrial: return "Randomized trial"
        case .clinicalTrial: return "Clinical trial"
        case .caseReport: return "Case report"
        case .editorial: return "Editorial"
        case .technique: return "Technique"
        case .originalResearch: return "Original research"
        case .other: return "Article"
        }
    }
}

public extension Article {
    /// Collapses PubMed `publicationTypes` into a stable UI category.
    var kind: ArticleKind {
        let types = publicationTypes
            .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }

        func has(_ needle: String) -> Bool {
            types.contains(where: { $0.contains(needle) })
        }

        // Highest-signal first
        if has("meta-analysis") { return .metaAnalysis }
        if has("systematic review") { return .systematicReview }

        // Guidelines / consensus
        if has("practice guideline") || has("guideline") || has("consensus") || has("position paper") {
            return .guideline
        }

        // Reviews
        if has("review") { return .review }

        // Trials
        if has("randomized controlled trial") || has("randomised controlled trial") {
            return .randomizedTrial
        }
        if has("clinical trial") { return .clinicalTrial }

        // Case reports
        if has("case report") || has("case reports") { return .caseReport }

        // Editorials / comments / letters
        if has("editorial") || has("comment") || has("letter") { return .editorial }

        // Technique / methods (PubMed types vary; this is intentionally broad)
        if has("technical") || has("technique") || has("methods") || has("surgical") {
            return .technique
        }

        // Most primary research shows up as "journal article"
        if has("journal article") { return .originalResearch }

        return .other
    }
}

extension ArticleKind: CaseIterable {
    public static var allCases: [ArticleKind] {
        [.metaAnalysis, .systematicReview, .review, .guideline, .randomizedTrial, .clinicalTrial, .caseReport, .editorial, .technique, .originalResearch, .other]
    }
}

extension ArticleKind {
    var displayName: String { accessibilityLabel } // reuse what you already have
}
