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

    /// Prevents duplicate concurrent generations (e.g., double-tap) and allows cancellation.
    private var generateTask: Task<Void, Never>?

    // Track which article this VM is currently representing.
    private(set) var activeArticleId: String?

    /// Call when an article detail view appears.
    /// If the article changes, clear prior insight/loading/error state so we don't show the previous article's insight.
    func setActiveArticle(_ id: String) {
        if activeArticleId != id {
            activeArticleId = id
            generateTask?.cancel()
            generateTask = nil
            gateAction = nil
            state = .idle
        }
    }
    
    private let localGuestQuotaKey = "localGuestAIInsightsRemaining"
    private let localGuestQuotaDefault = 3

    // MARK: - CTA (AI button)

    struct AIQuotaSnapshot: Equatable {
        /// Remaining guest complimentary insights (nil if unknown).
        var guestRemaining: Int?
        /// Remaining signed-in complimentary insights (nil if unknown).
        var userRemaining: Int?
        /// Whether the user is signed in (e.g., Parse user present / SIWA completed).
        var isSignedIn: Bool

        static let unknown = AIQuotaSnapshot(guestRemaining: nil, userRemaining: nil, isSignedIn: false)
    }

    @Published private(set) var ctaState: AIInsightCTAState = .loading

    enum GateAction: Equatable {
        case signInRequired
        case subscriptionRequired
        case updateRequired
    }

    /// One-shot UI signal. The view can observe this and present SIWA / Paywall.
    @Published var gateAction: GateAction? = nil

    @Published var quota: AIQuotaSnapshot = .unknown {
        didSet { recomputeCTAIfPossible() }
    }

    /// StoreKit subscription state (injected from outside; kept optional so this VM compiles even before wiring).
    private var entitlement: SubscriptionManager.EntitlementState = .unknown {
        didSet { recomputeCTAIfPossible() }
    }

    private let service: AIInsightServicing

    init(service: AIInsightServicing = AIInsightService()) {
        self.service = service
        
        let guest = loadLocalGuestRemaining()
        quota = AIQuotaSnapshot(guestRemaining: guest, userRemaining: nil, isSignedIn: false)
        recomputeCTAIfPossible()
    }
    
    private func loadLocalGuestRemaining() -> Int {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: localGuestQuotaKey) == nil {
            defaults.set(localGuestQuotaDefault, forKey: localGuestQuotaKey)
        }
        return defaults.integer(forKey: localGuestQuotaKey)
    }

    private func setLocalGuestRemaining(_ value: Int) {
        UserDefaults.standard.set(max(0, value), forKey: localGuestQuotaKey)
    }

    /// Call this from the view whenever subscription state changes (e.g., `.onAppear` and `.onChange`).
    func updateEntitlement(_ entitlement: SubscriptionManager.EntitlementState) {
        self.entitlement = entitlement
    }
    

    /// Call this from the view whenever auth/quota changes.
    /// IMPORTANT: `nil` means “unknown / do not overwrite”. This prevents views from
    /// resetting an already-decremented local quota back to unknown on navigation.
    func updateQuota(guestRemaining: Int?, userRemaining: Int?, isSignedIn: Bool) {
        let mergedGuest = guestRemaining ?? self.quota.guestRemaining
        let mergedUser  = userRemaining  ?? self.quota.userRemaining

        // Persist guest quota locally so it survives relaunch.
        if isSignedIn == false, let r = mergedGuest {
            setLocalGuestRemaining(r)
        }

        self.quota = AIQuotaSnapshot(guestRemaining: mergedGuest, userRemaining: mergedUser, isSignedIn: isSignedIn)
    }

    private func recomputeCTAIfPossible() {
        // Compute CTA from subscription + quota. Loading state is handled by the view via `.disabled(isLoading)`.
        // IMPORTANT: when signed in, use the signed-in complimentary bucket; otherwise use the guest bucket.
        let freeRemaining = quota.isSignedIn ? quota.userRemaining : quota.guestRemaining

        ctaState = AIInsightCTAState.resolve(
            entitlement: entitlement,
            isSignedIn: quota.isSignedIn,
            guestFreeRemaining: freeRemaining
        )
    }

    private func decrementComplimentaryIfKnown() {
        if quota.isSignedIn {
            if let r = quota.userRemaining {
                quota = AIQuotaSnapshot(
                    guestRemaining: quota.guestRemaining,
                    userRemaining: max(0, r - 1),
                    isSignedIn: quota.isSignedIn
                )
            }
        } else {
            if let r = quota.guestRemaining {
                let newRemaining = max(0, r - 1)
                setLocalGuestRemaining(newRemaining)

                quota = AIQuotaSnapshot(
                    guestRemaining: newRemaining,
                    userRemaining: quota.userRemaining,
                    isSignedIn: quota.isSignedIn
                )
            }
        }
        // `quota` didSet will recompute CTA.
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

    var isGenerateButtonDisabled: Bool {
        // Disable while loading or once an insight has already been generated.
        if case .loaded = state { return true }
        return isLoading
    }

    var errorMessage: String? {
        if case .failed(let message) = state { return message }
        return nil
    }

// MARK: - Public API
    func refreshGuestQuota(force: Bool = false) async {
        // Guest quota is purely local.
        guard quota.isSignedIn == false else { return }

        if !force, quota.guestRemaining != nil { return }

        let remaining = loadLocalGuestRemaining()
        updateQuota(guestRemaining: remaining, userRemaining: nil, isSignedIn: false)
    }

    func generate(for article: Article) async {
        setActiveArticle(article.id)
        // Re-entrancy guard: ignore if already generating.
        guard !isLoading else { return }

        // If an insight already exists for this article, don't regenerate.
        if case .loaded = state { return }

        // Cancel any prior in-flight task defensively.
        generateTask?.cancel()

        state = .loading
        recomputeCTAIfPossible()

        generateTask = Task { [weak self] in
            guard let self else { return }

            do {
                let insight = try await self.service.generateInsight(for: article)

                // If canceled, don't update UI.
                guard !Task.isCancelled else { return }

                self.state = .loaded(insight)
                // Decrement complimentary quota locally so the UI and gating reflect usage immediately.
                self.decrementComplimentaryIfKnown()
                self.recomputeCTAIfPossible()
            } catch {
                guard !Task.isCancelled else { return }

                // If Cloud Code sent a structured payload (quota gates, etc.),
                // treat it as a CTA state transition rather than a generic failure.
                if let payload = self.decodeAIInsightServerPayload(from: error) {
                    #if DEBUG
                    if let debug = payload.debugMessage {
                        print("AI Insight Debug:", debug)
                    }
                    #endif

                    if payload.requiresUpdate == true {
                        // Guide via UI (e.g., show an update sheet) rather than a generic red error.
                        self.state = .idle
                        self.gateAction = .updateRequired
                        return
                    }

                    if payload.requiresSignIn == true {
                        // Guest free quota exhausted.
                        self.state = .idle
                        // Persist and force CTA to transition to sign-in.
                        self.setLocalGuestRemaining(0)
                        self.quota = AIQuotaSnapshot(
                            guestRemaining: 0,
                            userRemaining: self.quota.userRemaining,
                            isSignedIn: false
                        )
                        self.gateAction = .signInRequired
                        self.recomputeCTAIfPossible()
                        return
                    }

                    if payload.requiresSubscription == true {
                        // Signed-in free quota exhausted OR subscription required.
                        self.state = .idle
                        // Force CTA to transition to subscription by updating quota.
                        self.quota = AIQuotaSnapshot(
                            guestRemaining: self.quota.guestRemaining,
                            userRemaining: 0,
                            isSignedIn: self.quota.isSignedIn
                        )
                        self.gateAction = .subscriptionRequired
                        self.recomputeCTAIfPossible()
                        return
                    }

                    // Non-gating server message: show it.
                    if let msg = payload.userMessage, !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.state = .failed(msg)
                    } else {
                        self.state = .failed(self.userFacingMessage(from: error))
                    }

                    self.recomputeCTAIfPossible()
                    return
                }

                // Non-JSON / networking / parsing error
                self.state = .failed(self.userFacingMessage(from: error))
                self.recomputeCTAIfPossible()
            }
        }

        // Await completion so callers that `await` this method still behave predictably.
        await generateTask?.value
        generateTask = nil
    }

    func reset() {
        generateTask?.cancel()
        generateTask = nil
        gateAction = nil
        state = .idle
        recomputeCTAIfPossible()
    }

    // MARK: - Error Handling

    private func userFacingMessage(from error: Error) -> String {
        let nsError = error as NSError
        let rawMessage = nsError.localizedDescription

        #if DEBUG
        print("AI Insight Raw Error:", rawMessage)
        #endif

        // Parse / Network common cases
        // Be careful: don't match the generic substring "rate" (it appears in many unrelated words).
        let lower = rawMessage.lowercased()
        if rawMessage.contains("429") || lower.contains("rate limit") || lower.contains("rate_limit") {
            return "AI Insight is temporarily busy. Please try again shortly."
        }

        if rawMessage.contains("403") || lower.contains("quota") {
            return "You have reached your AI Insight limit. Please upgrade to continue."
        }

        if lower.contains("network") || lower.contains("timed out") {
            return "Network issue while generating AI Insight. Please check your connection and try again."
        }

        if lower.contains("invalid_json") || lower.contains("non-json") {
            return "AI Insight response could not be processed. Please try again."
        }

        // Safe fallback
        return "We couldn’t generate AI Insight right now. Please try again."
    }

    // MARK: - Server Error Payload (Cloud Code JSON)

    private struct AIInsightServerErrorPayload: Decodable {
        let userMessage: String?
        let debugMessage: String?
        let requiresSignIn: Bool?
        let requiresSubscription: Bool?
        let requiresUpdate: Bool?
    }

    private func decodeAIInsightServerPayload(from error: Error) -> AIInsightServerErrorPayload? {
        // ParseSwift/Parse often wraps the server message, so the JSON may be embedded inside other text.
        let candidates: [String] = [
            (error as NSError).localizedDescription,
            String(describing: error)
        ]

        for s in candidates {
            // Fast path
            if let data = s.data(using: .utf8), let payload = try? JSONDecoder().decode(AIInsightServerErrorPayload.self, from: data) {
                return payload
            }

            // Embedded JSON path: extract the substring between the first '{' and the last '}'.
            guard let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}") , first < last else {
                continue
            }

            let jsonSubstring = String(s[first...last])
            guard let data = jsonSubstring.data(using: .utf8) else { continue }

            if let payload = try? JSONDecoder().decode(AIInsightServerErrorPayload.self, from: data) {
                return payload
            }
        }

        return nil
    }
}
