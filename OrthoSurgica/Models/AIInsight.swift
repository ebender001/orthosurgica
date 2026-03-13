//
//  AIInsight.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 2/22/26.
//

import Foundation

struct AIInsight: Codable, Equatable {
    let pmid: String
    let source_scope: String
    let one_sentence_takeaway: String
    let study_type: String
    let population: String
    let intervention_or_exposure: String
    let comparator: String
    let outcomes_reported: [String]
    let key_findings: [String]
    let limitations: [String]
    let ct_surgery_implications: [String]
    let should_change_practice: ShouldChangePractice
    let evidence_notes: [String]

    let prompt_version: Int?
    let model: String?
    let generated_at: String?

    struct ShouldChangePractice: Codable, Equatable {
        let conclusion: String
        let rationale: [String]
        let confidence: String
    }
}
