//
// PremiumManager.swift
// PARALLAX
//
// Created by  on 7/9/25.
//

import CoreData
import StoreKit
import SwiftUI
import TipKit
import WidgetKit

enum SubscriptionStatus {
    case active, inactive, expired, trial, pending
}

enum PremiumFeature: String, CaseIterable {
    case unlimitedFlashcardsPerDeck = "unlimited_flashcards_per_deck"
    case unlimitedDecks = "unlimited_decks" // ✅ AJOUTER cette ligne
    case customThemes = "custom_themes"
    case premiumWidgets = "premium_widgets"
    case advancedStats = "advanced_stats"
    case exportData = "export_data"
    case prioritySupport = "priority_support"
}

enum QuotaOperation {
    case createDeck(currentCount: Int) // ✅ MODIFIÉ : Ajouter le paramètre count
    case createFlashcard(currentDeckCount: Int, context: NSManagedObjectContext)
    case useFeature(PremiumFeature)
}

enum QuotaResult {
    case allowed
    case exceeded
    case requiresPremium
}

@MainActor
@Observable
final class PremiumManager {
    static let shared = PremiumManager()

    // MARK: - État premium avec setter intelligent

    private var _isPremium: Bool = false
    private var _subscriptionStatus: SubscriptionStatus = .inactive
    private var _features: Set<PremiumFeature> = []

    // ✅ MODIFIÉ : Toujours retourner true - Application entièrement gratuite
    var isPremium: Bool {
        get { true } // Toujours gratuit
        set {
            // Ne rien faire - l'application est toujours gratuite
            _isPremium = true
            _subscriptionStatus = .active
            _features = Set(PremiumFeature.allCases)

            // Synchronisation App Group
            syncToAppGroup(true)

            // Mise à jour des widgets
            updateWidgets()
        }
    }

    var subscriptionStatus: SubscriptionStatus { _subscriptionStatus }
    var features: Set<PremiumFeature> { _features }

    // MARK: - Validation avec circuit breaker amélioré

    private(set) var isValidating: Bool = false
    private(set) var lastValidation: Date?

    // Circuit breaker intelligent
    private var validationAttempts = 0
    private let maxValidationAttempts = 3
    private var lastValidationAttempt: Date = .distantPast
    private let validationCooldown: TimeInterval = 300 // 5 minutes

    // ✅ CORRECTION : Protection debug accessible
    var debugOverride: Bool = false

    // ✅ MODIFIÉ : Limites supprimées - Application entièrement gratuite
    // Toutes les limites sont maintenant illimitées (Int.max)
    private let maxFreeFlashcardsTotal = Int.max // Illimité
    private let maxPremiumFlashcardsTotal = Int.max // Illimité
    private let maxFlashcardsPerDeck = Int.max // Illimité
    private let maxFreeDecks = Int.max // Illimité

    // ✅ LIMITES MÉDIAS SUPPRIMÉES
    private let maxFreeMediaTotal = Int.max // Illimité
    private let maxPremiumMediaTotal = Int.max // Illimité
    private let maxMediaPerDeck = Int.max // Illimité
    private let maxAudioDuration: TimeInterval = 30.0 // Durée max audio en secondes (conservée)

    // ✅ Débounce des notifications
    private var lastNotificationTime: Date = .distantPast
    private let notificationDebounce: TimeInterval = 1.0

    private init() {
        loadPremiumStatus()
    }

    // MARK: - Méthodes de limitation Premium

    // Compter le total de flashcards
    private func getTotalFlashcardCount(context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
        return (try? context.count(for: request)) ?? 0
    }

    // ✅ MODIFIÉ : Toujours autoriser - Application entièrement gratuite
    func canCreateFlashcardGlobal(context _: NSManagedObjectContext) -> Bool {
        return true // Toujours autorisé
    }

    // ✅ MODIFIÉ : Toujours autoriser - Application entièrement gratuite
    func canCreateFlashcardInDeck(currentDeckCount _: Int) -> Bool {
        return true // Toujours autorisé
    }

    // Méthode principale qui combine les deux
    func canCreateFlashcard(currentDeckCount: Int, context: NSManagedObjectContext) -> Bool {
        return canCreateFlashcardGlobal(context: context) &&
            canCreateFlashcardInDeck(currentDeckCount: currentDeckCount)
    }

    // ✅ MODIFIÉ : Toujours autoriser - Application entièrement gratuite
    func canCreateDeck(currentDeckCount _: Int) -> Bool {
        return true // Toujours autorisé - Decks illimités
    }

    // ✅ NOUVELLES MÉTHODES D'INFORMATION POUR L'UI

    func getTotalFlashcardInfo(context: NSManagedObjectContext) -> (current: Int, max: Int, remaining: Int) {
        let current = getTotalFlashcardCount(context: context)
        return (current: current, max: Int.max, remaining: Int.max) // Illimité
    }

    func getDeckFlashcardInfo(currentDeckCount: Int) -> (current: Int, max: Int, remaining: Int) {
        return (current: currentDeckCount, max: Int.max, remaining: Int.max) // Illimité
    }

    func getDetailedLimitMessage(currentDeckCount _: Int, context _: NSManagedObjectContext) -> String? {
        return nil // Toujours autorisé - pas de limite
    }

    var maxFlashcardsPerDeckProperty: Int {
        return Int.max // Illimité
    }

    var maxMediaPerDeckProperty: Int {
        return Int.max // Illimité
    }

    var maxDecks: Int {
        return Int.max // Illimité
    }

    // MARK: - Méthodes de limitation Médias

    // Compter le total de médias
    private func getTotalMediaCount(context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
        let allFlashcards = (try? context.fetch(request)) ?? []

        var totalMedia = 0
        for flashcard in allFlashcards {
            // Compter les médias de question
            if flashcard.questionContentType != .text { totalMedia += 1 }
            // Compter les médias de réponse
            if flashcard.answerContentType != .text { totalMedia += 1 }
        }

        return totalMedia
    }

    // Compter les médias d'un deck spécifique
    private func getDeckMediaCount(deck: FlashcardDeck) -> Int {
        let flashcards = (deck.flashcards as? Set<Flashcard>) ?? []
        var deckMedia = 0

        for flashcard in flashcards {
            // Compter les médias de question
            if flashcard.questionContentType != .text { deckMedia += 1 }
            // Compter les médias de réponse
            if flashcard.answerContentType != .text { deckMedia += 1 }
        }

        return deckMedia
    }

    // ✅ MODIFIÉ : Toujours autoriser - Application entièrement gratuite
    func canAddMediaGlobal(context _: NSManagedObjectContext) -> Bool {
        return true // Toujours autorisé
    }

    // ✅ MODIFIÉ : Toujours autoriser - Application entièrement gratuite
    func canAddMediaToDeck(deck _: FlashcardDeck) -> Bool {
        return true // Toujours autorisé
    }

    // Méthode principale qui combine les deux
    func canAddMedia(deck: FlashcardDeck, context: NSManagedObjectContext) -> Bool {
        return canAddMediaGlobal(context: context) &&
            canAddMediaToDeck(deck: deck)
    }

    // Vérifier durée audio
    func isValidAudioDuration(_ duration: TimeInterval) -> Bool {
        return duration <= maxAudioDuration
    }

    // ✅ NOUVELLES MÉTHODES D'INFORMATION MÉDIAS POUR L'UI

    func getTotalMediaInfo(context: NSManagedObjectContext) -> (current: Int, max: Int, remaining: Int) {
        let current = getTotalMediaCount(context: context)
        return (current: current, max: Int.max, remaining: Int.max) // Illimité
    }

    func getDeckMediaInfo(deck: FlashcardDeck) -> (current: Int, max: Int, remaining: Int) {
        let current = getDeckMediaCount(deck: deck)
        return (current: current, max: Int.max, remaining: Int.max) // Illimité
    }

    func getMediaLimitMessage(deck _: FlashcardDeck, context _: NSManagedObjectContext) -> String? {
        return nil // Toujours autorisé - pas de limite
    }

    // ✅ MODIFIÉ : Toujours autoriser - Application entièrement gratuite
    func checkQuota(for _: QuotaOperation) -> QuotaResult {
        return .allowed // Toujours autorisé
    }

    // MARK: - Méthodes Publiques

    func hasAccess(to _: PremiumFeature) -> Bool {
        return true // Toujours autorisé - toutes les fonctionnalités sont gratuites
    }

    // ✅ MODIFIÉ : Méthodes conservées pour compatibilité mais toujours actives - Application entièrement gratuite
    func activatePremium() {
        isPremium = true // Toujours actif - Application entièrement gratuite
        print("🌟 Accès illimité activé")
    }

    func deactivatePremium() {
        // Ne fait rien - Application toujours gratuite
        print("ℹ️ Tentative de désactivation ignorée - Application entièrement gratuite")
    }

    // ✅ CORRECTION : Circuit breaker intelligent avec exponential backoff
    func validateSubscription() async {
        let now = Date()

        // ✅ CORRECTION : Éviter validation en mode debug
        if debugOverride {
            print("🐛 Validation ignorée - mode debug override actif")
            return
        }

        // ✅ PROTECTION : Si premium vient d'être désactivé manuellement, attendre
        if !isPremium, now.timeIntervalSince(lastValidationAttempt) < 5.0 {
            print("🐛 Validation ignorée - premium récemment désactivé manuellement")
            return
        }

        // Circuit breaker avec backoff exponentiel
        if validationAttempts >= maxValidationAttempts {
            let backoffTime = validationCooldown * pow(2.0, Double(validationAttempts - maxValidationAttempts))
            if now.timeIntervalSince(lastValidationAttempt) < backoffTime {
                print("🛑 Circuit breaker actif - validation bloquée (backoff: \(Int(backoffTime))s)")
                return
            } else {
                validationAttempts = 0 // Reset après cooldown
                print("🔄 Circuit breaker reset - nouvelle tentative autorisée")
            }
        }

        guard !isValidating else {
            print("⚠️ Validation déjà en cours")
            return
        }

        isValidating = true
        validationAttempts += 1
        lastValidationAttempt = now

        print("🔍 Début validation subscription (tentative \(validationAttempts)/\(maxValidationAttempts))")

        await performReceiptValidation()

        isValidating = false
        lastValidation = Date()
    }

    // MARK: - Méthodes Privées

    private func loadPremiumStatus() {
        // ✅ MODIFIÉ : Toujours activer premium - Application entièrement gratuite
        _isPremium = true
        _subscriptionStatus = .active
        _features = Set(PremiumFeature.allCases)
    }

    // ✅ CORRECTION : Gestion d'erreur 509 robuste
    private func performReceiptValidation() async {
        var hasValidEntitlement = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try await checkVerified(result)
                if transaction.revocationDate == nil {
                    hasValidEntitlement = true
                    print("✅ Entitlement valide trouvé : \(transaction.productID)")
                    break
                }
            } catch {
                print("⚠️ Erreur validation transaction : \(error)")
                continue
            }
        }

        // ✅ CORRECTION : Utilisation du setter intelligent pour éviter boucle
        if hasValidEntitlement != isPremium {
            isPremium = hasValidEntitlement
            if hasValidEntitlement {
                validationAttempts = 0 // Reset sur succès
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) async throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.unverifiedTransaction
        case let .verified(safe):
            return safe
        }
    }

    // ✅ CORRECTION : Synchronisation App Group avec gestion d'erreur
    private func syncToAppGroup(_ isPremium: Bool) {
        let appGroupDefaults = UserDefaults(suiteName: "group.com.Coefficient.PARALLAX2")
        appGroupDefaults?.set(isPremium, forKey: "isPremium")
        appGroupDefaults?.synchronize()

        // ✅ MODIFIÉ : Toujours synchroniser - Application entièrement gratuite
        print("✅ Accès illimité synchronisé vers App Group")
    }

    // ✅ CORRECTION : Mise à jour widgets avec gestion d'erreur
    private func updateWidgets() {
        WidgetCenter.shared.reloadAllTimelines()

        // ✅ MODIFIÉ : Toujours actif - Application entièrement gratuite
        print("✅ Widgets mis à jour")
    }

    // MARK: - Méthodes Debug

    #if DEBUG
        func enableDebugPremium() {
            // ✅ MODIFIÉ : Toujours actif - Application entièrement gratuite
            debugOverride = true
            isPremium = true
            print("🐛 DEBUG: Accès illimité activé - widgets mis à jour")
        }

        func disableDebugPremium() {
            // ✅ MODIFIÉ : Ne fait rien - Application toujours gratuite
            debugOverride = false
            print("🐛 DEBUG: Tentative de désactivation ignorée - Application entièrement gratuite")
        }
    #endif

    func getFeatureDescription(for feature: PremiumFeature) -> String {
        switch feature {
        case .unlimitedFlashcardsPerDeck:
            return String(localized: "premium_feature_unlimited_flashcards")
        case .unlimitedDecks:
            return String(localized: "premium_feature_unlimited_decks")
        case .customThemes:
            return String(localized: "premium_feature_custom_themes")
        case .premiumWidgets:
            return String(localized: "premium_feature_widgets")
        case .advancedStats:
            return String(localized: "premium_feature_advanced_stats")
        case .exportData:
            return String(localized: "premium_feature_export_data")
        case .prioritySupport:
            return String(localized: "premium_feature_priority_support")
        }
    }
}

extension Notification.Name {
    static let premiumStatusChanged = Notification.Name("premiumStatusChanged")
}

enum StoreKitError: LocalizedError {
    case unverifiedTransaction
    case paymentPending
    case unknownError

    var errorDescription: String? {
        switch self {
        case .unverifiedTransaction:
            return String(localized: "storekit_error_unverified")
        case .paymentPending:
            return String(localized: "storekit_error_payment_pending")
        case .unknownError:
            return String(localized: "storekit_error_unknown")
        }
    }
}
