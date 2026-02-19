//
//  SubscriptionManager.swift
//  RetireSmartIRA
//
//  Manages StoreKit 2 auto-renewable subscription
//

import SwiftUI
import StoreKit
import Combine

class SubscriptionManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseError: String? = nil
    @Published private(set) var isLoading: Bool = false

    // MARK: - Product IDs

    nonisolated static let premiumYearlyID = "com.john.RetireSmartIRA.premium.yearly"
    private nonisolated static let productIDs: Set<String> = [premiumYearlyID]

    // MARK: - Transaction Listener

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    self?.isSubscribed = await self?.checkEntitlement() ?? false
                }
            }
        }
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            products = storeProducts
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product = products.first else {
            purchaseError = "Product not available. Please try again later."
            return
        }

        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                purchaseError = "An unknown error occurred."
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        purchaseError = nil
        try? await AppStore.sync()
        await updateSubscriptionStatus()
        if !isSubscribed {
            purchaseError = "No active subscription found."
        }
        isLoading = false
    }

    // MARK: - Subscription Status

    func updateSubscriptionStatus() async {
        isSubscribed = await checkEntitlement()
    }

    /// Check current entitlements (can be called from any context)
    private func checkEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.premiumYearlyID
                    && transaction.revocationDate == nil {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Verification Helper

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Display Helpers

    /// Formatted price string from the App Store (e.g., "$5.99")
    var formattedPrice: String {
        products.first?.displayPrice ?? "$5.99"
    }
}
