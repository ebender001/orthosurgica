//
//  SubscriptionManager.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 2/23/26.
//

import Foundation
import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    enum EntitlementState: Equatable {
        case unknown
        case notSubscribed
        case subscribed(productID: String, expiresDate: Date?)
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var entitlement: EntitlementState = .unknown
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var lastErrorMessage: String?

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
        lastErrorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            lastErrorMessage = "Restore failed. Please try again."
        }
    }

    // MARK: - Entitlement

    var hasActiveSubscription: Bool {
        if case .subscribed = entitlement { return true }
        return false
    }

    private func refreshEntitlement() async {
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
            entitlement = .subscribed(productID: best.productID, expiresDate: best.expires)
        } else {
            entitlement = .notSubscribed
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
