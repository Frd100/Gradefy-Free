//
// PremiumManager.swift
// PARALLAX
//
// Created by  on 7/9/25.
//

import SwiftUI
import StoreKit
import WidgetKit
import TipKit
import CoreData

enum SubscriptionStatus {
    case active, inactive, expired, trial, pending
}

enum PremiumFeature: String, CaseIterable {
    case unlimitedFlashcardsPerDeck = "unlimited_flashcards_per_deck"
    case unlimitedDecks = "unlimited_decks"                          // ✅ AJOUTER cette ligne
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
    
    // ✅ CORRECTION : Propriété computed avec notification intelligente
    var isPremium: Bool {
        get { _isPremium }
        set {
            // Ne poster notification que si changement réel
            if _isPremium != newValue {
                let oldValue = _isPremium
                _isPremium = newValue
                _subscriptionStatus = newValue ? .active : .inactive
                _features = newValue ? Set(PremiumFeature.allCases) : []
                
                // Persistance
                UserDefaults.standard.set(newValue, forKey: "isPremium")
                
                // Synchronisation App Group avec gestion d'erreur
                syncToAppGroup(newValue)
                
                // Mise à jour des widgets
                updateWidgets()
                
                // ✅ Notification uniquement sur changement réel
                NotificationCenter.default.post(
                    name: .premiumStatusChanged,
                    object: nil,
                    userInfo: ["previousValue": oldValue, "newValue": newValue]
                )
                
                print("📢 Statut premium modifié : \(oldValue) → \(newValue)")
            }
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
    private var lastValidationAttempt: Date = Date.distantPast
    private let validationCooldown: TimeInterval = 300 // 5 minutes
    
    // ✅ CORRECTION : Protection debug accessible
    var debugOverride: Bool = false
    
    // ✅ LIMITES MISE À JOUR SELON SPÉCIFICATIONS
    private let maxFreeFlashcardsTotal = 300       // Total gratuit global
    private let maxPremiumFlashcardsTotal = 2000   // Total premium global 
    private let maxFlashcardsPerDeck = 200         // Max par deck (gratuit ET premium)
    private let maxFreeDecks = 3                   // Decks gratuits (3 maximum)
    
    // ✅ LIMITES MÉDIAS MISE À JOUR
    private let maxFreeMediaTotal = 50             // Total médias gratuits
    private let maxPremiumMediaTotal = 200         // Total médias premium
    private let maxMediaPerDeck = 200              // Max médias par deck (médias inclus dans les 200 flashcards)
    private let maxAudioDuration: TimeInterval = 30.0 // Durée max audio en secondes
    
    // ✅ Débounce des notifications
    private var lastNotificationTime: Date = Date.distantPast
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
    
    // Vérifier limite globale (gratuit vs premium)
    func canCreateFlashcardGlobal(context: NSManagedObjectContext) -> Bool {
        let totalCount = getTotalFlashcardCount(context: context)
        let maxTotal = isPremium ? maxPremiumFlashcardsTotal : maxFreeFlashcardsTotal
        return totalCount < maxTotal
    }
    
    // Vérifier limite par deck (gratuit ET premium)
    func canCreateFlashcardInDeck(currentDeckCount: Int) -> Bool {
        return currentDeckCount < maxFlashcardsPerDeck  // 200 pour tous
    }
    
    // Méthode principale qui combine les deux
    func canCreateFlashcard(currentDeckCount: Int, context: NSManagedObjectContext) -> Bool {
        return canCreateFlashcardGlobal(context: context) && 
               canCreateFlashcardInDeck(currentDeckCount: currentDeckCount)
    }
    
    // Decks illimités en premium, 3 max en gratuit
    func canCreateDeck(currentDeckCount: Int) -> Bool {
        if isPremium {
            return true  // ✅ Decks illimités en premium
        }
        
        #if DEBUG
        if debugOverride {
            return true
        }
        #endif
        
        return currentDeckCount < maxFreeDecks
    }
    
    // ✅ NOUVELLES MÉTHODES D'INFORMATION POUR L'UI
    
    func getTotalFlashcardInfo(context: NSManagedObjectContext) -> (current: Int, max: Int, remaining: Int) {
        let current = getTotalFlashcardCount(context: context)
        let max = isPremium ? maxPremiumFlashcardsTotal : maxFreeFlashcardsTotal
        let remaining = Swift.max(0, max - current)
        return (current: current, max: max, remaining: remaining)
    }
    
    func getDeckFlashcardInfo(currentDeckCount: Int) -> (current: Int, max: Int, remaining: Int) {
        let remaining = Swift.max(0, maxFlashcardsPerDeck - currentDeckCount)
        return (current: currentDeckCount, max: maxFlashcardsPerDeck, remaining: remaining)  // 200 pour tous (médias inclus)
    }
    
    func getDetailedLimitMessage(currentDeckCount: Int, context: NSManagedObjectContext) -> String? {
        let globalInfo = getTotalFlashcardInfo(context: context)
        
        // Si on peut pas créer à cause de la limite globale
        if !canCreateFlashcardGlobal(context: context) {
            return "Limite atteinte : \(globalInfo.current)/\(globalInfo.max) flashcards total"
        }
        
        // Si on peut pas créer à cause de la limite par deck
        if !canCreateFlashcardInDeck(currentDeckCount: currentDeckCount) {
            return "Deck complet : \(currentDeckCount)/\(maxFlashcardsPerDeck) flashcards max par deck"
        }
        
        return nil // Peut créer
    }
    
    var maxFlashcardsPerDeckProperty: Int {
        return maxFlashcardsPerDeck  // 200 pour tous (médias inclus)
    }
    
    var maxMediaPerDeckProperty: Int {
        return maxMediaPerDeck  // 200 pour tous
    }
    
    var maxDecks: Int {
        return isPremium ? Int.max : maxFreeDecks
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
    
    // Vérifier limite globale des médias
    func canAddMediaGlobal(context: NSManagedObjectContext) -> Bool {
        let totalMedia = getTotalMediaCount(context: context)
        let maxTotal = isPremium ? maxPremiumMediaTotal : maxFreeMediaTotal
        return totalMedia < maxTotal
    }
    
    // Vérifier limite par deck des médias
    func canAddMediaToDeck(deck: FlashcardDeck) -> Bool {
        let deckMedia = getDeckMediaCount(deck: deck)
        return deckMedia < maxMediaPerDeck
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
        let max = isPremium ? maxPremiumMediaTotal : maxFreeMediaTotal
        let remaining = Swift.max(0, max - current)
        return (current: current, max: max, remaining: remaining)
    }
    
    func getDeckMediaInfo(deck: FlashcardDeck) -> (current: Int, max: Int, remaining: Int) {
        let current = getDeckMediaCount(deck: deck)
        let remaining = Swift.max(0, maxMediaPerDeck - current)
        return (current: current, max: maxMediaPerDeck, remaining: remaining)
    }
    
    func getMediaLimitMessage(deck: FlashcardDeck, context: NSManagedObjectContext) -> String? {
        let globalInfo = getTotalMediaInfo(context: context)
        
        // Si on peut pas ajouter à cause de la limite globale
        if !canAddMediaGlobal(context: context) {
            return "Limite médias atteinte : \(globalInfo.current)/\(globalInfo.max) médias total"
        }
        
        // Si on peut pas ajouter à cause de la limite par deck
        if !canAddMediaToDeck(deck: deck) {
            let deckInfo = getDeckMediaInfo(deck: deck)
            return "Deck complet : \(deckInfo.current)/\(deckInfo.max) médias max par deck"
        }
        
        return nil // Peut ajouter
    }
    
    // ✅ CORRECTION : Vérification des quotas mise à jour
    func checkQuota(for operation: QuotaOperation) -> QuotaResult {
        if isPremium {
            return .allowed
        }
        
        switch operation {
        case .createDeck(let currentCount):
            return currentCount < maxFreeDecks ? .allowed : .exceeded
            
        case .createFlashcard(let currentDeckCount, let context):
            if !canCreateFlashcard(currentDeckCount: currentDeckCount, context: context) {
                return .exceeded
            }
            return .allowed
            
        case .useFeature(let feature):
            return hasAccess(to: feature) ? .allowed : .requiresPremium
        }
    }
    
    // MARK: - Méthodes Publiques
    
    func hasAccess(to feature: PremiumFeature) -> Bool {
        return isPremium && features.contains(feature)
    }
    
    // ✅ CORRECTION : Méthodes publiques utilisent le setter intelligent
    func activatePremium() {
        isPremium = true // Le setter gère tout automatiquement
        print("🌟 Premium activé")
    }
    
    func deactivatePremium() {
        isPremium = false // Le setter gère tout automatiquement
        print("❌ Premium désactivé")
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
        if !isPremium && now.timeIntervalSince(lastValidationAttempt) < 5.0 {
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
        _isPremium = UserDefaults.standard.bool(forKey: "isPremium")
        if _isPremium {
            _subscriptionStatus = .active
            _features = Set(PremiumFeature.allCases)
        }
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
        case .verified(let safe):
            return safe
        }
    }
    
    // ✅ CORRECTION : Synchronisation App Group avec gestion d'erreur
    private func syncToAppGroup(_ isPremium: Bool) {
        let appGroupDefaults = UserDefaults(suiteName: "group.com.Coefficient.PARALLAX2")
        appGroupDefaults?.set(isPremium, forKey: "isPremium")
        appGroupDefaults?.synchronize()
        
        if isPremium {
            print("✅ Premium synchronisé vers App Group")
        } else {
            print("✅ Premium désynchronisé de App Group")
        }
    }
    
    // ✅ CORRECTION : Mise à jour widgets avec gestion d'erreur
    private func updateWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        
        if isPremium {
            print("✅ Widgets mis à jour")
        } else {
            print("❌ Widgets verrouillés")
        }
    }
    
    // MARK: - Méthodes Debug
    
    #if DEBUG
    func enableDebugPremium() {
        debugOverride = true
        isPremium = true
        print("🐛 DEBUG: Premium activé avec override - widgets mis à jour")
    }
    
    func disableDebugPremium() {
        debugOverride = false
        // ✅ DÉSACTIVER IMMÉDIATEMENT SANS VALIDATION
        isPremium = false
        print("🐛 DEBUG: Premium désactivé, override supprimé - widgets verrouillés")
        
        // ✅ VALIDATION DIFFÉRÉE SEULEMENT SI PAS EN MODE DEBUG
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondes
            if !debugOverride {
                await validateSubscription()
            }
        }
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
