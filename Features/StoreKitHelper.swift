//
// StoreKitHelper.swift
// PARALLAX
//
// Created by  on 7/9/25.
//

import StoreKit

// ✅ Définition des ProductIDs
enum ProductIDs {
    static let monthly = "com.gradefy.pro.monthly"
    static let yearly = "com.gradefy.pro.annual"
}

@MainActor
final class StoreKitHelper: ObservableObject {
    static let shared = StoreKitHelper()

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProducts: Set<String> = []
    @Published private(set) var isLoading = false

    private var transactionListener: Task<Void, Never>?
    private var lastTransactionCheck: Date = .distantPast
    private let minimumCheckInterval: TimeInterval = 5.0

    init() {
        // Écouter les transactions en arrière-plan
        transactionListener = listenForTransactions()

        // Charger les produits au démarrage
        Task {
            try? await loadProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async throws {
        isLoading = true
        defer { isLoading = false }

        products = try await Product.products(for: [
            ProductIDs.monthly,
            ProductIDs.yearly,
        ])

        await updatePurchasedProducts()
    }

    var monthlyProduct: Product? {
        return products.first { $0.id == ProductIDs.monthly }
    }

    var yearlyProduct: Product? {
        return products.first { $0.id == ProductIDs.yearly }
    }

    var monthlyDisplayPrice: String {
        return monthlyProduct?.displayPrice ?? "2,99 €"
    }

    var yearlyDisplayPrice: String {
        return yearlyProduct?.displayPrice ?? "29,99 €"
    }

    func getProduct(for productID: String) -> Product? {
        return products.first { $0.id == productID }
    }

    // MARK: - Account Verification

    // ✅ CORRECTION : Vérification de compte avant énumération
    private func hasActiveStoreAccount() async -> Bool {
        do {
            // ✅ CORRECTION : Utiliser _ au lieu de let testProducts
            _ = try await Product.products(for: ["test"])
            return true
        } catch {
            let nsError = error as NSError
            if nsError.code == 509 && nsError.domain == "ASDErrorDomain" {
                print("⚠️ Aucun compte App Store actif")
                return false
            }
            return true
        }
    }

    // MARK: - Purchase Status Management

    private func updatePurchasedProducts() async {
        guard await hasActiveStoreAccount() else {
            print("⚠️ Impossible de vérifier les achats - pas de compte App Store actif")
            return
        }

        var purchased: Set<String> = []

        // ✅ PAS de do-catch externe inutile
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try await checkVerified(result)
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            } catch {
                print("❌ Erreur transaction : \(error)")
                continue
            }
        }

        purchasedProducts = purchased
        if !purchased.isEmpty || !purchasedProducts.isEmpty {
            await updateFeatureManagerStatus()
        }
    }

    // ✅ MÉTHODE : Mise à jour du statut premium
    private func updatePremiumStatus(for transaction: Transaction) async {
        // Ajouter ou retirer le produit des achats
        if transaction.revocationDate == nil {
            purchasedProducts.insert(transaction.productID)
        } else {
            purchasedProducts.remove(transaction.productID)
        }

        // Informer le FeatureManager
        await updateFeatureManagerStatus()
    }

    // ✅ MÉTHODE : Synchronisation avec FeatureManager
    private func updateFeatureManagerStatus() async {
        let hasPremium = !purchasedProducts.isEmpty
        await MainActor.run {
            if hasPremium {
                FeatureManager.shared.activateFullAccess()
            } else {
                FeatureManager.shared.deactivateFullAccess()
            }
        }
    }

    // MARK: - Transaction Monitoring

    // ✅ CORRECTION : Suppression du bloc do-catch inutile dans listenForTransactions
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            for await result in Transaction.updates {
                // ✅ CORRECTION : Gestion du throttling dans un contexte @MainActor
                let shouldProcess = await MainActor.run {
                    let now = Date()
                    if now.timeIntervalSince(self.lastTransactionCheck) < self.minimumCheckInterval {
                        print("🔄 Transaction ignorée (throttling actif)")
                        return false
                    }

                    self.lastTransactionCheck = now
                    return true
                }

                guard shouldProcess else { continue }

                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePremiumStatus(for: transaction)
                    await transaction.finish()
                } catch {
                    print("❌ Erreur transaction : \(error)")
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) async throws -> T {
        switch result {
        case .unverified:
            throw StoreKitHelperError.unverifiedTransaction
        case let .verified(safe):
            return safe
        }
    }

    // MARK: - Public Methods

    // ✅ MÉTHODE PUBLIQUE : Achat d'un produit avec gestion d'erreur
    func purchase(_ product: Product) async throws -> Transaction? {
        // Vérifier qu'un compte est actif avant l'achat
        guard await hasActiveStoreAccount() else {
            throw StoreKitHelperError.noActiveAccount
        }

        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case let .success(verification):
            let transaction = try await checkVerified(verification)
            await updatePremiumStatus(for: transaction)
            await transaction.finish()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            throw StoreKitHelperError.paymentPending

        @unknown default:
            throw StoreKitHelperError.unknownError
        }
    }

    // ✅ MÉTHODE PUBLIQUE : Restaurer les achats avec gestion d'erreur
    func restorePurchases() async throws {
        guard await hasActiveStoreAccount() else {
            throw StoreKitHelperError.noActiveAccount
        }

        isLoading = true
        defer { isLoading = false }

        try await AppStore.sync()
        await updatePurchasedProducts()
    }

    // ✅ MÉTHODE PUBLIQUE : Vérifier si un produit est acheté
    func isPurchased(_ productID: String) -> Bool {
        return purchasedProducts.contains(productID)
    }

    // ✅ MÉTHODE PUBLIQUE : Obtenir le prix d'un produit
    func getPrice(for productID: String) -> String? {
        return products.first { $0.id == productID }?.displayPrice
    }

    // MARK: - Error Types

    // ✅ CORRECTION : Enum d'erreurs maintenant À L'INTÉRIEUR de la classe
    enum StoreKitHelperError: LocalizedError {
        case unverifiedTransaction
        case paymentPending
        case unknownError
        case noActiveAccount

        var errorDescription: String? {
            switch self {
            case .unverifiedTransaction:
                return "Transaction non vérifiée"
            case .paymentPending:
                return "Paiement en attente"
            case .unknownError:
                return "Erreur inconnue"
            case .noActiveAccount:
                return "Aucun compte App Store actif. Veuillez vous connecter dans les Réglages."
            }
        }
    }
}
