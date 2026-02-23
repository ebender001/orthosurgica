//
//  ArticleAIViewModel.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 2/22/26.
//

import Foundation
import Combine

@MainActor
final class ArticleAIViewModel: ObservableObject {

    // MARK: - State
    enum State: Equatable {
        case idle
        case loading
        case loaded(AIInsight)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let service: AIInsightServicing

    init(service: AIInsightServicing = AIInsightService()) {
        self.service = service
    }

    // MARK: - Derived UI Helpers

    var insight: AIInsight? {
        if case .loaded(let insight) = state { return insight }
        return nil
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var errorMessage: String? {
        if case .failed(let message) = state { return message }
        return nil
    }

    // MARK: - Public API

    func generate(for article: Article) async {
        state = .loading

        do {
            let insight = try await service.generateInsight(for: article)
            state = .loaded(insight)
        } catch {
            state = .failed(userFacingMessage(from: error))
        }
    }

    func reset() {
        state = .idle
    }

    // MARK: - Error Handling

    private func userFacingMessage(from error: Error) -> String {
        let nsError = error as NSError
        let rawMessage = nsError.localizedDescription

        #if DEBUG
        print("AI Insight Raw Error:", rawMessage)
        #endif

        // If Cloud Code sent structured JSON { userMessage, debugMessage }
        if let data = rawMessage.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let userMessage = json["userMessage"] as? String {

            if let debug = json["debugMessage"] as? String {
                print("AI Insight Debug:", debug)
            }

            return userMessage
        }

        // Parse / Network common cases
        // Be careful: don't match the generic substring "rate" (it appears in many unrelated words).
        let lower = rawMessage.lowercased()
        if rawMessage.contains("429") || lower.contains("rate limit") || lower.contains("rate_limit") {
            return "AI Insight is temporarily busy. Please try again shortly."
        }

        if rawMessage.contains("403") || rawMessage.lowercased().contains("quota") {
            return "You have reached your AI Insight limit. Please upgrade or try again later."
        }

        if rawMessage.lowercased().contains("network") ||
           rawMessage.lowercased().contains("timed out") {
            return "Network issue while generating AI Insight. Please check your connection and try again."
        }

        if rawMessage.lowercased().contains("invalid_json") ||
           rawMessage.lowercased().contains("non-json") {
            return "AI Insight response could not be processed. Please try again."
        }

        // Safe fallback
        return "We couldn’t generate AI Insight right now. Please try again."
    }
}
