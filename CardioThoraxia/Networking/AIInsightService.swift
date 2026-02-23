//
//  AIInsightService.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 2/22/26.
//

import Foundation
import ParseSwift

protocol AIInsightServicing {
    func generateInsight(for article: Article) async throws -> AIInsight
}

// MARK: - ParseSwift Cloud Function
private struct GenerateAIInsightFunction: ParseCloudable {
    typealias ReturnType = AIInsight

    // Required by ParseCloud
    var functionJobName: String = "generateAIInsight"

    // Parameters sent to your Cloud Function (these become request.params.<name> in Cloud Code)
    var pmid: String
    var title: String
    var journal: String
    var year: Int
    var month: String
    var publicationTypes: [String]
    var meshHeadings: [String]
    var abstractText: String
}

private extension ParseCloudable {
    /// Convenience async wrapper around ParseSwift's callback-based `runFunction`.
    func runFunctionAsync() async throws -> ReturnType {
        try await withCheckedThrowingContinuation { continuation in
            self.runFunction { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct AIInsightService: AIInsightServicing {
    func generateInsight(for article: Article) async throws -> AIInsight {
        // Ensure we never pass optionals into Cloud params
        let function = GenerateAIInsightFunction(
            pmid: article.id,
            title: article.title,
            journal: article.journal ?? "",
            year: article.year ?? 0,
            month: article.month ?? "",
            publicationTypes: article.publicationTypes,
            meshHeadings: article.meshHeadings,
            abstractText: article.abstractText ?? ""
        )

        return try await function.runFunctionAsync()
    }
}
