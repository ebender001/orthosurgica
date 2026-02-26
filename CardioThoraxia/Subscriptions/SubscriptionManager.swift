//
//  SubscriptionManager.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 2/23/26.
//

import Foundation
import StoreKit
import Combine
import ParseSwift

// A Decodable "empty" return type for Cloud Code functions that return `{}` or nothing meaningful.
struct EmptyCloudResponse: Decodable {}

struct SetSubscriptionActiveCloud: ParseCloudable {
    var functionJobName: String = "setSubscriptionActive"
    
    typealias ReturnType = EmptyCloudResponse

    // Must match request.params keys in Cloud Code
    let activeUntilISO: String
    let productId: String
}

@MainActor
final class SubscriptionManager: ObservableObject {
    // MARK: - Server Sync (Option A)

    private let subscriptionSyncKey = "subscriptionSync.last"
    private let isoFormatter = ISO8601DateFormatter()
    struct ActiveSubscription: Equatable {
        let productID: String
        let expiresDate: Date?
    }

    enum EntitlementState: Equatable {
        case unknown
        case inactive
        case active(ActiveSubscription)

        var isActive: Bool {
            if case .active = self { return true }
            return false
        }

        var activeProductID: String? {
            switch self {
            case .active(let sub): return sub.productID
            default: return nil
            }
        }

        var activeExpiresDate: Date? {
            switch self {
            case .active(let sub): return sub.expiresDate
            default: return nil
            }
        }
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var entitlement: EntitlementState = .unknown
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isRestoring = false

    // Your two product IDs
    let productIDs: Set<String> = [
        "com.cvoffice.cardiothoraxia.ai.monthly",
        "com.cvoffice.cardiothoraxia.ai.annual"
    ]

    private var updatesTask: Task<Void, Never>?

    func start() {
        // Call once on app launch
        updatesTask?.cancel()
        updatesTask = Task { await listenForTransactions() }
        Task { await refreshProductsAndEntitlement() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refreshProductsAndEntitlement() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(for: Array(productIDs))
                .sorted { $0.displayPrice < $1.displayPrice } // purely cosmetic

            await refreshEntitlement()
            await syncSubscriptionToServerIfNeeded()
        } catch {
            lastErrorMessage = "Unable to load subscriptions. Please try again."
        }
        
        print("Loaded products:", products.map { "\($0.id) \($0.displayPrice)" })
    }

    func purchase(_ product: Product) async {
        lastErrorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try verify(verification)
                await transaction.finish()
                await refreshEntitlement()
                await syncSubscriptionToServerIfNeeded()

            case .userCancelled:
                break

            case .pending:
                lastErrorMessage = "Purchase pending approval."

            @unknown default:
                lastErrorMessage = "Purchase failed. Please try again."
            }
        } catch {
            lastErrorMessage = "Purchase failed. Please try again."
        }
    }
    
    func restorePurchases() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        lastErrorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            await syncSubscriptionToServerIfNeeded()
        } catch {
            lastErrorMessage = "Restore failed. Please try again."
        }
    }

    // MARK: - Entitlement

    var hasActiveSubscription: Bool {
        entitlement.isActive
    }

    @MainActor
    func refreshEntitlement() async {
        // Most robust approach: determine if ANY of your subscription products currently entitles the user.
        var best: (productID: String, expires: Date?)? = nil

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard productIDs.contains(transaction.productID) else { continue }

            // For subscriptions, an entitlement exists if it's currently active.
            // If it’s expired, it generally won’t appear in currentEntitlements.
            let expires = transaction.expirationDate

            // Choose the entitlement with the latest expiration date (if available).
            if let current = best {
                let currentExp = current.expires ?? .distantPast
                let newExp = expires ?? .distantFuture // treat nil as “non-expiring” (rare)
                if newExp > currentExp {
                    best = (transaction.productID, expires)
                }
            } else {
                best = (transaction.productID, expires)
            }
        }

        if let best {
            entitlement = .active(.init(productID: best.productID, expiresDate: best.expires))
        } else {
            entitlement = .inactive
        }
    }

    // MARK: - Option A: sync entitlement to Back4App

    /// Pushes the current active subscription window to Cloud Code so server can bypass quota.
    /// This is a Phase-1 "trust the client" bridge until you implement server-side receipt verification.
    private func syncSubscriptionToServerIfNeeded() async {
        // Only meaningful if we have an active entitlement.
        guard case .active(let active) = entitlement else { return }

        // Must be signed in (Parse session required for Cloud Code to attach to user).
        guard let _ = User.current else { return }

        // If StoreKit didn't give an expiry (rare), choose a conservative fallback.
        let activeUntil: Date = active.expiresDate ?? Date().addingTimeInterval(60 * 60 * 24 * 30)
        let productId = active.productID

        // Avoid repeated writes for the same (productId, activeUntil).
        let stamp = "\(productId)|\(Int(activeUntil.timeIntervalSince1970))"
        if UserDefaults.standard.string(forKey: subscriptionSyncKey) == stamp {
            return
        }

        do {
            // Cloud Function: setSubscriptionActive(activeUntilISO, productId)
            let payload = SetSubscriptionActiveCloud(
                activeUntilISO: isoFormatter.string(from: activeUntil),
                productId: productId
            )

            _ = try await payload.runFunction()

            UserDefaults.standard.set(stamp, forKey: subscriptionSyncKey)
        } catch {
            // Don't block the app experience if sync fails.
            #if DEBUG
            print("setSubscriptionActive failed:", error)
            #endif
        }
    }

    // MARK: - Transaction Updates

    private func listenForTransactions() async {
        // This updates entitlement if something changes outside the app (renewal, cancellation, etc.)
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            guard productIDs.contains(transaction.productID) else { continue }

            await transaction.finish()
            await refreshEntitlement()
            await syncSubscriptionToServerIfNeeded()
        }
    }

    // MARK: - Verification

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreKitError.notEntitled
        }
    }
}

// MARK: - AI Insight CTA

/// UI-facing state for the AI Insight button.
///
/// This is intentionally separate from `SubscriptionManager.EntitlementState` so that:
/// - Subscription status stays StoreKit-focused
/// - UI can express the next action (free, sign-in, subscribe)
/// - The mapping remains explicit and easy to test
enum AIInsightCTAState: Equatable {
    /// Still determining eligibility (e.g., loading products/entitlement or waiting for a quota check).
    case loading

    /// The user can generate AI Insight now.
    ///
    /// - remaining: Optional remaining complimentary insights to display. If `nil`, UI should omit the number.
    case freeRemaining(remaining: Int?)

    /// Complimentary quota is exhausted for guest mode; prompt Sign in with Apple.
    case needsSignIn

    /// Signed in but no active subscription and no remaining complimentary quota.
    case needsSubscription

    /// Active subscription present.
    case subscribed

    var buttonTitle: String {
        switch self {
        case .loading:
            return "Loading…"
        case .freeRemaining:
            return "Generate AI Insight"
        case .needsSignIn:
            return "Sign in with Apple to continue"
        case .needsSubscription:
            return "Upgrade for AI Insight"
        case .subscribed:
            return "Generate AI Insight"
        }
    }

    var isButtonEnabled: Bool {
        switch self {
        case .loading:
            return false
        default:
            return true
        }
    }

    /// Optional helper copy shown under the button.
    /// Keep this short and clinician-friendly.
    var helperText: String? {
        switch self {
        case .loading:
            return nil
        case .freeRemaining(let remaining):
            if let remaining {
                if remaining <= 0 { return nil }
                return remaining == 1
                    ? "1 complimentary insight remaining"
                    : "\(remaining) complimentary insights remaining"
            }
            return nil
        case .needsSignIn:
            return "Complimentary insights used. Sign in to keep going."
        case .needsSubscription:
            return "Subscribe to continue generating AI insights."
        case .subscribed:
            return nil
        }
    }

    /// Whether tapping the button should present a paywall immediately.
    ///
    /// Note: you can still choose to present paywall *after* a server call; this is for UI intent.
    var shouldPresentPaywallOnTap: Bool {
        if case .needsSubscription = self { return true }
        return false
    }

    /// Whether tapping the button should present Sign in with Apple immediately.
    var shouldPresentSignInOnTap: Bool {
        if case .needsSignIn = self { return true }
        return false
    }
}

extension AIInsightCTAState {
    /// Maps subscription + auth + complimentary quota into a single UI CTA.
    ///
    /// - Parameters:
    ///   - entitlement: StoreKit subscription entitlement.
    ///   - isSignedIn: Whether the user is signed in (Parse user present / SIWA complete).
    ///   - guestFreeRemaining: Remaining guest complimentary insights (0+). Pass `nil` if unknown.
    static func resolve(
        entitlement: SubscriptionManager.EntitlementState,
        isSignedIn: Bool,
        guestFreeRemaining: Int?
    ) -> AIInsightCTAState {

        // Active subscription always wins.
        if entitlement.isActive {
            return .subscribed
        }

        // If signed in and not subscribed, you require subscription (no signed-in freebies).
        if isSignedIn {
            return .needsSubscription
        }

        // Guest flow (3 free).
        if let remaining = guestFreeRemaining {
            return remaining > 0 ? .freeRemaining(remaining: remaining) : .needsSignIn
        }

        // Unknown guest quota (e.g. before server fetch finishes).
        return .loading
    }
}

#if DEBUG
extension SubscriptionManager {
    func debugCurrentEntitlements() async {
        var any = false
        for await result in Transaction.currentEntitlements {
            any = true
            switch result {
            case .verified(let tx):
                print("🔎 currentEntitlements ✅", tx.productID,
                      "| exp:", tx.expirationDate?.description ?? "nil",
                      "| revoked:", tx.revocationDate?.description ?? "nil")
            case .unverified(let tx, let err):
                print("🔎 currentEntitlements ⚠️", tx.productID,
                      "| exp:", tx.expirationDate?.description ?? "nil",
                      "| err:", err)
            }
        }
        if !any { print("🔎 currentEntitlements: EMPTY") }
    }

    func debugLatestMonthly() async {
        let id = "com.cvoffice.cardiothoraxia.ai.monthly"
        if let result = await Transaction.latest(for: id) {
            switch result {
            case .verified(let tx):
                print("🧾 latest(for: \(id)) ✅ exp:", tx.expirationDate?.description ?? "nil",
                      "revoked:", tx.revocationDate?.description ?? "nil")
            case .unverified(let tx, let err):
                print("🧾 latest(for: \(id)) ⚠️ exp:", tx.expirationDate?.description ?? "nil",
                      "err:", err)
            }
        } else {
            print("🧾 latest(for: \(id)) = nil")
        }
    }
}
#endif
