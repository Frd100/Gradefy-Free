//
//  SimpleSRSManager.swift
//  PARALLAX
//
//  SM-2 Manager invisible - intégration non-invasive
//

import Foundation
import CoreData
import SwiftUI

@MainActor
class SimpleSRSManager: ObservableObject {
    static let shared = SimpleSRSManager()

    private let cache = GradefyCacheManager.shared
    private let operationQueue = DispatchQueue(label: "com.parallax.srs.operations", qos: .userInitiated)
    private var seenOperationIds = Set<String>() // ✅ IDEMPOTENCE : Set en mémoire par session
    
    // MARK: - Optimisations Phase 3
    private let sm2Cache = SM2OptimizationCache.shared
    private let coreDataOptimizer = SM2CoreDataOptimizer.shared
    private let performanceMonitor = SM2PerformanceMonitor.shared
    private let freeModeStore = FreeModeProgressStore.shared
    private let freeSessionStore = FreeModeSessionStore.shared
    
    // ✅ STOCKAGE des états temporaires du mode libre
    private var freeModeCardStates: [String: FreeModeCardState] = [:]
    
    // ✅ COMPTEUR de réinjections par carte par session
    private var sessionReinjectionCount: [String: Int] = [:]
    
    private init() {}
    
    // ✅ MÉTHODE POUR LES TESTS : Réinitialiser le cache d'opId
    func clearOperationCache() {
        operationQueue.sync {
            seenOperationIds.removeAll()
        }
        print("🧹 [SM2] Cache des opérations réinitialisé pour les tests")
    }
    
    // ✅ MÉTHODE : Réinitialiser le compteur de réinjections pour une nouvelle session
    func resetSessionReinjectionCount() {
        sessionReinjectionCount.removeAll()
        print("🧹 [LAPSEBUFFER] Compteur de réinjections réinitialisé pour la nouvelle session")
    }
    
    // MARK: - SM-2 Core Algorithm (30 lignes)
    
    func processSwipeResult(card: Flashcard, swipeDirection: SwipeDirection, context: NSManagedObjectContext, operationId: String? = nil) {
        // ✅ IDEMPOTENCE PAR OPÉRATION : operationId obligatoire côté UI
        guard let opId = operationId else {
            assertionFailure("[SM2] operationId est nil (idempotence cassée)")
            return
        }
        
        if SRSConfiguration.idempotenceCheckEnabled {
            let shouldProcess = operationQueue.sync {
                if seenOperationIds.contains(opId) {
                    return false
                }
                seenOperationIds.insert(opId)
                
                // ✅ ÉVICTION FIFO : Nettoyer si le cache dépasse la limite
                if seenOperationIds.count > SRSConfiguration.maxOperationCacheSize {
                    // Éviction FIFO : garder seulement les plus récents
                    let sortedIds = Array(seenOperationIds).suffix(SRSConfiguration.maxOperationCacheSize / 2)
                    seenOperationIds = Set(sortedIds)
                    print("🧹 [SM2] Cache des opérations nettoyé (éviction FIFO: \(SRSConfiguration.maxOperationCacheSize / 2) conservés)")
                }
                return true
            }
            
            if !shouldProcess {
                if SRSConfiguration.enableDetailedLogging {
                    print("🔄 [SM2] Opération déjà traitée - idempotence (opId: \(opId.prefix(8)))")
                }
                return
            }
        }
        
        // ✅ VALIDATION D'ENTRÉE : Vérifier les données de la carte
        guard validateCardData(card: card) else {
            if SRSConfiguration.enableDetailedLogging {
                print("❌ [SM2] Données de carte invalides - opération annulée")
            }
            return
        }
        
        let quality = mapSwipeToQuality(swipeDirection)
        
        // ✅ NOUVEAU : Feedback haptique selon la qualité
        provideHapticFeedback(for: quality)
        
        // ✅ SM-2 pur : Vérifier si cette révision doit mettre à jour les paramètres SM-2
        if shouldUpdateSM2(card: card) {
            // ✅ Mise à jour normale SM-2 (carte due ou nouvelle)
            guard let result = calculateSM2Safely(
                interval: card.interval,
                easeFactor: card.easeFactor,
                quality: quality,
                card: card
            ) else {
                if SRSConfiguration.enableDetailedLogging {
                    print("❌ [SM2] Erreur de calcul SM-2 - opération annulée")
                }
                return
            }
            
            // ✅ LOG STRUCTURÉ : Pour observabilité (conditionnel)
            if SRSConfiguration.enableDetailedLogging {
                logSM2Operation(opId: opId, cardId: card.id?.uuidString ?? "unknown", quality: quality, result: result)
            }
            
            // Update card with idempotence and error handling
            updateCardSM2DataSafely(card: card, result: result, quality: quality, context: context)
            
            // Cache for performance
            cacheResult(card: card, quality: quality, result: result)
            
            // ✅ AJOUT : Invalider le cache des statistiques pour forcer le rechargement
            // sm2Cache.clearAllSM2Caches() // Temporairement désactivé pour éviter les crashes
        } else {
            // ✅ LOG-ONLY : Révision avant échéance (pas de mise à jour SM-2)
            if SRSConfiguration.enableDetailedLogging {
                print("📝 [SM2] Log-only mode - carte pas encore due")
            }
            processLogOnlyUpdate(card: card, context: context)
        }
    }
    
    // ✅ SM-2 pur : Vérifier si cette révision doit mettre à jour les paramètres SM-2
    private func shouldUpdateSM2(card: Flashcard) -> Bool {
        // Nouvelles cartes (jamais révisées) : toujours OK
        guard let nextReview = card.nextReviewDate else { return true }
        
        // Cartes existantes : seulement si la date programmée est atteinte/dépassée
        // Si avant échéance → log-only (pas de mise à jour SM-2)
        return Date() >= nextReview
    }
    
    // ✅ NOUVELLE MÉTHODE : Traitement log-only pour révisions avant échéance
    private func processLogOnlyUpdate(card: Flashcard, context: NSManagedObjectContext) {
        // En log-only, on met à jour seulement reviewCount et lastReviewDate
        card.reviewCount += 1
        card.lastReviewDate = Date()
        
        // Pas de mise à jour des paramètres SM-2 (interval, easeFactor, nextReviewDate)
        if SRSConfiguration.enableDetailedLogging {
            print("📝 [SM2] Log-only: reviewCount=\(card.reviewCount), lastReviewDate=\(card.lastReviewDate?.formatted() ?? "nil")")
        }
        
        // ✅ AJOUT : Invalider le cache des statistiques pour forcer le rechargement
        // sm2Cache.clearAllSM2Caches() // Temporairement désactivé pour éviter les crashes
    }
    
    // ✅ LAPSEBUFFER DÉSACTIVÉ : Comportement SM-2 standard
    func shouldReinjectCard(card: Flashcard, quality: Int, sessionStats: SessionStats? = nil) -> Bool {
        // ✅ SM-2 STANDARD : Aucune réinjection dans la même session
        // Chaque carte est vue exactement une fois par session
        print("⏭️ [LAPSEBUFFER] Pas de réinjection (SM-2 standard)")
        return false
    }
    
        private func mapSwipeToQuality(_ direction: SwipeDirection) -> Int {
        switch direction {
        case .right: return 2  // Bon
        case .left: return 1   // Faux
        default: return 2      // Par défaut bon
        }
    }
    
    private func calculateSM2(interval: Double, easeFactor: Double, quality: Int, card: Flashcard) -> SM2Result {
        let currentInterval = max(SRSConfiguration.minInterval, interval)
        
        // ✅ Ease factor initial plus conservateur (inspiré Anki grand public)
        // Seulement pour les vraies nouvelles cartes (reviewCount == 0 && lastReviewDate == nil)
        let defaultEF: Double
        if easeFactor == 2.5 && card.reviewCount == 0 && card.lastReviewDate == nil {
            defaultEF = SRSConfiguration.defaultEaseFactor  // 2.3 pour nouveaux utilisateurs
        } else {
            defaultEF = easeFactor  // Garder la valeur existante pour cartes importées
        }
        
        let currentEF = max(SRSConfiguration.minEaseFactor, min(SRSConfiguration.maxEaseFactor, defaultEF))
        
        switch quality {
        case 2:  // Bon
            // ✅ AJUSTEMENT 2 : Graduating silencieux pour phase early
            let newInterval: Double
            if card.reviewCount < SRSConfiguration.earlyGraduatingMaxReviews {
                // Phase early : utiliser les intervalles fixes
                let earlyIndex = min(Int(card.reviewCount), SRSConfiguration.earlyGraduatingIntervals.count - 1)
                newInterval = SRSConfiguration.earlyGraduatingIntervals[earlyIndex]
                if SRSConfiguration.enableDetailedLogging {
                    print("🚀 [SM2] Phase early: intervalle fixe \(newInterval)j (révision \(card.reviewCount + 1))")
                }
            } else {
                // Phase normale : algorithme SM-2 standard
                newInterval = currentInterval * currentEF
            }
            
            // ✅ CORRECTION 5 : Appliquer les clamps après calcul
            let rawInterval = newInterval
            let cappedInterval = applySoftCap(interval: rawInterval)
            let rawEF = currentEF + SRSConfiguration.confidentEaseFactorIncrease
            let newEF = min(SRSConfiguration.maxEaseFactor, rawEF)
            
            return SM2Result(
                interval: cappedInterval,
                easeFactor: newEF,
                nextReviewDate: calculateNextReviewDate(interval: cappedInterval)
            )
            
        case 1:  // Faux
            // ✅ CORRECTION 4 : Lapse moins brutal pour les cartes avec ancienneté (pas streak)
            let lapseMultiplier: Double
            if card.correctCount >= SRSConfiguration.gentleLapseThreshold {
                lapseMultiplier = SRSConfiguration.gentleLapseMultiplier
                if SRSConfiguration.enableDetailedLogging {
                    print("🤝 [SM2] Lapse clément (ancienneté \(card.correctCount)): ×\(lapseMultiplier)")
                }
            } else {
                lapseMultiplier = SRSConfiguration.standardLapseMultiplier
                if SRSConfiguration.enableDetailedLogging {
                    print("❌ [SM2] Lapse standard: ×\(lapseMultiplier)")
                }
            }
            
            // ✅ CORRECTION 5 : Appliquer les clamps après calcul
            let rawInterval = currentInterval * lapseMultiplier
            let newInterval = max(
                SRSConfiguration.lapseIntervalMin, 
                min(SRSConfiguration.lapseIntervalMax, rawInterval)
            )
            let rawEF = currentEF - SRSConfiguration.incorrectEaseFactorDecrease
            let newEF = max(SRSConfiguration.minEaseFactor, rawEF)
            
            return SM2Result(
                interval: newInterval,
                easeFactor: newEF,
                nextReviewDate: calculateNextReviewDate(interval: newInterval)
            )
            
        default:
            // Fallback pour compatibilité
            let newEF = max(SRSConfiguration.minEaseFactor, currentEF - SRSConfiguration.incorrectEaseFactorDecrease)
            return SM2Result(
                interval: SRSConfiguration.resetInterval,
                easeFactor: newEF,
                nextReviewDate: calculateNextReviewDate(interval: SRSConfiguration.resetInterval)
            )
        }
    }
    
    // ✅ FONCTION UTILITAIRE : Conversion cohérente des durées
    private func formatDuration(days: Int) -> String {
        if days >= 7 {
            let weeks = days / 7
            if weeks > 52 {
                return "+1a"
            } else {
                return "\(weeks)s"
            }
        } else {
            return "\(days)j"
        }
    }
    
    // ✅ NOUVELLE FONCTION : Soft-cap pour éviter les intervalles aberrants
    private func applySoftCap(interval: Double) -> Double {
        if interval > SRSConfiguration.softCapThreshold {
            let excess = interval - SRSConfiguration.softCapThreshold
            // ✅ CORRECTION 1 : Utiliser les constants au lieu de magic numbers
            let taperingFactor = max(
                SRSConfiguration.softCapTaperingBase,
                SRSConfiguration.maxEaseFactor - (excess / SRSConfiguration.softCapTaperingPeriod) * SRSConfiguration.softCapTaperingRate
            )
            return SRSConfiguration.softCapThreshold + (excess * taperingFactor)
        }
        return interval
    }
    
    // ✅ NOUVELLE FONCTION : Calcul de date avec timezone configurable et midi local
    private func calculateNextReviewDate(interval: Double) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = SRSConfiguration.timeZonePolicy.timeZone
        
        let today = Date()
        let noonToday = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today) ?? today
        
        // ✅ CORRECTION 1 : Utiliser ceil() pour éviter qu'une carte revienne trop tôt
        let ceilDays = Int(ceil(interval))
        return calendar.date(byAdding: .day, value: ceilDays, to: noonToday) ?? today
    }
    
    private func updateCardSM2Data(card: Flashcard, result: SM2Result, context: NSManagedObjectContext) {
        let oldInterval = card.interval // Sauvegarder l'ancien interval avant modification
        
        card.interval = result.interval
        card.easeFactor = result.easeFactor
        card.nextReviewDate = result.nextReviewDate
        card.lastReviewDate = Date()
        card.reviewCount += 1
        
        if result.interval > oldInterval { // Si interval a augmenté = bonne réponse
            card.correctCount += 1
        }
        
        // ✅ ATOMICITÉ : Utiliser context.perform pour les opérations atomiques
        context.perform {
            do {
                try context.save()
            } catch {
                print("❌ SM-2 save error: \(error)")
            }
        }
    }
    
    private func cacheResult(card: Flashcard, quality: Int, result: SM2Result) {
        let cacheKey = "sm2_\(card.id?.uuidString ?? "")_\(quality)"
        cache.cacheAverage(result.interval, forKey: cacheKey)
    }
    
    // ✅ NETTOYAGE : Optionnel - nettoyer le cache des opérations (éviter accumulation)
    // Méthode déjà déclarée plus haut
    
    // MARK: - Dashboard Metrics
    
    func getDeckStats(deck: FlashcardDeck) -> DeckSRSStats {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Utiliser l'optimiseur Core Data
        guard let context = deck.managedObjectContext else {
            print("❌ [SM2] Contexte Core Data manquant pour stats")
            return DeckSRSStats(masteryPercentage: 0, readyCount: 0, studyStreak: 0, todayReviewCount: 0, totalCards: 0, masteredCards: 0, overdue: 0)
        }
        
        let stats = coreDataOptimizer.getDeckStatsOptimized(forDeck: deck, context: context)
        
        let latency = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordStatsCalculation(latency: latency, cacheHit: false)
        
        return stats
    }
    
    private func calculateStudyStreak(deck: FlashcardDeck) -> Int {
        // Calcul simple basé sur lastReviewDate des cartes
        let flashcards = (deck.flashcards as? Set<Flashcard>) ?? []
        let recentReviews = flashcards.compactMap { $0.lastReviewDate }
            .filter { Calendar.current.isDateInToday($0) || Calendar.current.isDateInYesterday($0) }
        
        return recentReviews.isEmpty ? 0 : 1  // Simplifié pour v1
    }
    
    func getReadyCards(deck: FlashcardDeck) -> [Flashcard] {
        let flashcards = Array((deck.flashcards as? Set<Flashcard>) ?? [])
        
        return flashcards.filter { card in
            guard let nextReview = card.nextReviewDate else { 
                return true  // Nouvelle carte = prête
            }
            return nextReview <= Date()
        }.sorted { card1, card2 in
            // Priorité : cartes les plus urgentes d'abord
            let date1 = card1.nextReviewDate ?? Date.distantPast
            let date2 = card2.nextReviewDate ?? Date.distantPast
            return date1 < date2
        }
    }
    
    // ✅ NOUVELLE MÉTHODE : Vérifier si une session SM-2 est possible (SM-2 strict)
    func canStartSM2Session(deck: FlashcardDeck) -> Bool {
        let flashcards = Array((deck.flashcards as? Set<Flashcard>) ?? [])
        let now = Date()
        
        // 🎯 SM-2 STRICT : Au moins 1 carte due (pas de nouvelles seules)
        let hasDueCards = flashcards.contains { card in
            guard let nextReview = card.nextReviewDate else { return false } // Nouvelles ne comptent pas
            return nextReview <= now
        }
        
        if SRSConfiguration.enableDetailedLogging {
            print("🔍 [SM2] Vérification session stricte: \(hasDueCards ? "session possible" : "aucune carte due")")
        }
        return hasDueCards
    }
    
    // ✅ NOUVELLE MÉTHODE : Obtenir les statistiques pour l'utilisateur
    func getSessionStats(deck: FlashcardDeck) -> SessionStats {
        let flashcards = Array((deck.flashcards as? Set<Flashcard>) ?? [])
        let now = Date()
        
        // ✅ NOUVELLE LOGIQUE : Utiliser SRSData pour éviter le double comptage
        var overdueCount = 0
        var dueTodayCount = 0
        
        for card in flashcards {
            let srsData = getSRSData(card: card, now: now)
            if srsData.isOverdue {
                overdueCount += 1
            } else if srsData.isDueToday {
                dueTodayCount += 1
            }
        }
        
        // ✅ NOUVEAU : Cartes acquises (intervalle >= 7j mais < 21j)
        let acquiredCards = flashcards.filter { card in
            card.interval >= SRSConfiguration.acquiredIntervalThreshold && 
            card.interval < SRSConfiguration.masteryIntervalThreshold
        }
        
        // ✅ NOUVEAU : Cartes vraiment maîtrisées (intervalle >= 21j)
        let masteredCards = flashcards.filter { card in
            card.interval >= SRSConfiguration.masteryIntervalThreshold
        }
        
        // Prochaine révision
        let futureCards = flashcards.filter { card in
            guard let nextReview = card.nextReviewDate else { return false }
            return nextReview > now
        }.sorted { card1, card2 in
            let date1 = card1.nextReviewDate ?? Date.distantFuture
            let date2 = card2.nextReviewDate ?? Date.distantFuture
            return date1 < date2
        }
        
        // ✅ CORRECTION 6 : daysUntilNext = minimum pour "prochaine révision globale"
        let nextReviewDate = futureCards.first?.nextReviewDate
        let daysUntilNext = nextReviewDate.map { nextReview in
            Calendar.current.dateComponents([.day], from: now, to: nextReview).day ?? 0
        } ?? 0
        
        return SessionStats(
            dueToday: dueTodayCount,  // ✅ Séparé de overdue
            overdue: overdueCount,     // ✅ Nouveau champ pour overdue
            acquired: acquiredCards.count,
            mastered: masteredCards.count,
            totalCards: flashcards.count,
            daysUntilNext: max(0, daysUntilNext),  // ✅ Minimum pour prochaine révision globale
            lapseCount: 0, // Sera mis à jour pendant la session
            totalCardsReviewed: 0 // Sera mis à jour pendant la session
        )
    }
    
    // ✅ MÉTHODE SIMPLIFIÉE : Seulement les cartes dues (SM-2 strict)
    func getSmartCards(deck: FlashcardDeck, minCards: Int = 10, excludeCards: [Flashcard] = []) -> [Flashcard] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let excludeIds = Set(excludeCards.map { $0.id?.uuidString ?? "" })
        
        // Vérifier le cache d'abord
        let deckId = deck.id?.uuidString ?? "unknown"
        if let cached = sm2Cache.getCachedCardSelection(forDeck: deckId, minCards: minCards, excludeIds: excludeIds) {
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            performanceMonitor.recordCardSelection(latency: latency, cardCount: cached.count, cacheHit: true)
            return cached
        }
        
        // Utiliser l'optimiseur Core Data
        guard let context = deck.managedObjectContext else {
            print("❌ [SM2] Contexte Core Data manquant")
            return []
        }
        
        var result: [Flashcard] = []
        
        // 🎯 PRIORITÉ 1 : Cartes dues aujourd'hui (SM-2 strict)
        let dueCards = coreDataOptimizer.getReadyCardsOptimized(forDeck: deck, context: context)
        result += dueCards.filter { !excludeIds.contains($0.id?.uuidString ?? "") }
        
        // 🎯 PRIORITÉ 2 : Nouvelles cartes (seulement si au moins 1 carte due ET pas de doublons)
        if result.count < minCards && !dueCards.isEmpty {
            let needed = minCards - result.count
            let newCards = coreDataOptimizer.getNewCardsOptimized(forDeck: deck, limit: needed, context: context)
            
            // ✅ CORRECTION : Éviter les doublons en filtrant les cartes déjà présentes
            let existingIds = Set(result.map { $0.id?.uuidString ?? "" })
            let uniqueNewCards = newCards.filter { card in
                let cardId = card.id?.uuidString ?? ""
                return !excludeIds.contains(cardId) && !existingIds.contains(cardId)
            }
            
            result += uniqueNewCards
        }
        
        let latency = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordCardSelection(latency: latency, cardCount: result.count, cacheHit: false)
        
        // Mettre en cache le résultat
        sm2Cache.cacheCardSelection(result, forDeck: deckId, minCards: minCards, excludeIds: excludeIds)
        
        if SRSConfiguration.enableDetailedLogging {
            print("🎯 [SM2] Sélection SM-2 stricte: \(result.count) cartes (\(dueCards.count) dues, \(result.count - dueCards.count) nouvelles) en \(Int(latency * 1000))ms")
        }
        return result
    }
    
    // ✅ NOUVELLE MÉTHODE : Retourner toutes les cartes dans un ordre optimal
    private func getAllCardsInOptimalOrder(availableCards: [Flashcard]) -> [Flashcard] {
        var result: [Flashcard] = []
        
        // 1️⃣ PRIORITÉ 1 : Cartes prêtes selon SM-2 (les plus urgentes)
        let readyCards = availableCards.filter { card in
            guard let nextReview = card.nextReviewDate else { return false }
            return nextReview <= Date()
        }.sorted { card1, card2 in
            let date1 = card1.nextReviewDate ?? Date.distantPast
            let date2 = card2.nextReviewDate ?? Date.distantPast
            return date1 < date2
        }
        
        // 2️⃣ PRIORITÉ 2 : Nouvelles cartes (jamais révisées)
        let newCards = availableCards.filter { $0.nextReviewDate == nil }.shuffled()
        
        // 3️⃣ PRIORITÉ 3 : Toutes les autres cartes
        let remainingCards = availableCards.filter { card in
            return !readyCards.contains(card) && !newCards.contains(card)
        }.shuffled()
        
        // Assembler dans l'ordre optimal
        result += readyCards
        result += newCards
        result += remainingCards
        
        if SRSConfiguration.enableDetailedLogging {
            print("🎯 [SM2] Toutes les cartes: \(result.count) (\(readyCards.count) prêtes, \(newCards.count) nouvelles, \(remainingCards.count) autres)")
        }
        
        return result
    }
    
    // ✅ 4 STATUTS SIMPLIFIÉS : nouvelle, à réviser, acquis, maîtrisé
    // ✅ MOTEUR SRS PUR : Retourne les données brutes sans logique UI
    func getSRSData(card: Flashcard, calendar: Calendar = .current, now: Date = Date()) -> SRSData {
        return SRSData(from: card, calendar: calendar, now: now)
    }
    
    // ✅ ANCIENNE MÉTHODE : Maintenue pour compatibilité, déléguée à l'UI
    func getCardStatusMessage(card: Flashcard) -> CardStatus {
        let srsData = getSRSData(card: card)
        return CardStatusUI.getStatus(from: srsData)
    }
    
    // ✅ NOUVELLE MÉTHODE : Mise à jour immédiate du statut
    private func updateCardStatusImmediately(card: Flashcard, isCorrect: Bool) {
        // ✅ LOGIQUE : Erreur = perte immédiate de tous les statuts
        if !isCorrect {
            // L'erreur va réduire l'intervalle, donc la carte perd son statut acquis/maîtrisé
            // Le statut sera automatiquement mis à jour lors du prochain affichage
            print("❌ [STATUS] Carte perd son statut suite à une erreur")
        } else {
            // Vérifier si la bonne réponse permet d'atteindre un nouveau niveau
            let newInterval = card.interval * card.easeFactor
            
            if newInterval >= SRSConfiguration.masteryIntervalThreshold {
                print("👑 [STATUS] Carte devient maîtrisée suite à une bonne réponse")
            } else if newInterval >= SRSConfiguration.acquiredIntervalThreshold {
                print("⭐ [STATUS] Carte devient acquise suite à une bonne réponse")
            }
        }
    }
}

// MARK: - UI Interpréteur (Séparation Moteur/UI)
class CardStatusUI {
    static func getStatus(from srsData: SRSData) -> CardStatus {
        // 1️⃣ Nouvelle carte (jamais étudiée)
        if srsData.reviewCount == 0 {
            return CardStatus(message: "Nouvelle", color: Color.cyan, icon: "sparkles")
        }
        
        // 2️⃣ En retard (date de révision dépassée)
        if srsData.isOverdue {
            return CardStatus(message: "En retard", color: Color.red, icon: "exclamationmark.triangle")
        }
        
        // 3️⃣ À réviser (aujourd'hui) - PRIORITÉ ABSOLUE
        if srsData.isDueToday {
            return CardStatus(message: "À réviser", color: Color.orange, icon: "clock")
        }
        
        // 4️⃣ 👑 Maîtrisé (intervalle >= 21 jours ET pas due aujourd'hui)
        if srsData.interval >= SRSConfiguration.masteryIntervalThreshold {
            let timeMessage = formatDuration(days: srsData.daysUntilNext)
            return CardStatus(message: "Maîtrisé", color: Color.purple, icon: "checkmark.circle", timeUntilNext: timeMessage)
        }
        
        // 5️⃣ ⭐ Acquis (intervalle >= 7 jours mais < 21 jours)
        if srsData.interval >= SRSConfiguration.acquiredIntervalThreshold {
            let timeMessage = formatDuration(days: srsData.daysUntilNext)
            return CardStatus(message: "Acquis", color: Color.blue, icon: "star", timeUntilNext: timeMessage)
        }
        
        // 6️⃣ Par défaut : à réviser (intervalle < 7 jours)
        return CardStatus(message: "À réviser", color: Color.orange, icon: "clock")
    }
    
    // ✅ NOUVELLE MÉTHODE : Badges personnalisés
    static func getCustomBadges(from srsData: SRSData) -> [CardStatus] {
        var badges: [CardStatus] = []
        
        // Badge "Streak" pour les cartes avec beaucoup de succès consécutifs
        if srsData.correctCount >= 10 && srsData.correctCount == srsData.reviewCount {
            badges.append(CardStatus(message: "Streak", color: Color.orange, icon: "flame"))
        }
        
        // Badge "Stable" pour les cartes avec un EF élevé et stable
        if srsData.easeFactor >= 2.5 && srsData.interval >= 14 {
            badges.append(CardStatus(message: "Stable", color: Color.green, icon: "shield"))
        }
        
        // Badge "Difficile" pour les cartes avec un EF bas
        if srsData.easeFactor <= 1.5 && srsData.reviewCount >= 5 {
            badges.append(CardStatus(message: "Difficile", color: Color.red, icon: "exclamationmark.triangle"))
        }
        
        return badges
    }
    
    // ✅ MÉTHODE UTILITAIRE : Formatage de durée
    private static func formatDuration(days: Int) -> String {
        if days == 0 {
            return "aujourd'hui"
        } else if days == 1 {
            return "1j"
        } else if days < 7 {
            return "\(days)j"
        } else if days < 30 {
            let weeks = days / 7
            return "\(weeks)s"
        } else {
            let months = days / 30
            return "\(months)m"
        }
    }
}

// ✅ NOUVEAU : Structure pour les statuts de cartes
struct CardStatus {
    let message: String
    let color: Color
    let icon: String
    let timeUntilNext: String?
    
    init(message: String, color: Color, icon: String, timeUntilNext: String? = nil) {
        self.message = message
        self.color = color
        self.icon = icon
        self.timeUntilNext = timeUntilNext
    }
}

// MARK: - Supporting Types

struct SM2Result {
    let interval: Double
    let easeFactor: Double
    let nextReviewDate: Date
}

struct DeckSRSStats {
    let masteryPercentage: Int
    let readyCount: Int
    let studyStreak: Int
    // ✅ Nouvelles métriques inspirées des apps populaires
    let todayReviewCount: Int
    let totalCards: Int
    let masteredCards: Int
    let overdue: Int // ✅ Nouveau champ pour les cartes en retard
}

// ✅ NOUVELLE STRUCTURE : Statistiques de session pour l'utilisateur
struct SessionStats {
    let dueToday: Int
    let overdue: Int // ✅ Nouveau champ pour overdue
    let acquired: Int // ✅ Nouveau : cartes acquises
    let mastered: Int
    let totalCards: Int
    let daysUntilNext: Int
    let lapseCount: Int
    let totalCardsReviewed: Int
}

// MARK: - Robustesse et Validation (Phase 2 - Étape 2)

extension SimpleSRSManager {
    
    // ✅ VALIDATION D'ENTRÉE : Vérifier les données de la carte
    private func validateCardData(card: Flashcard) -> Bool {
        // ✅ CORRECTION 8 : Validation renforcée
        // Vérifier que l'intervalle est valide
        guard card.interval >= 0 && !card.interval.isNaN && !card.interval.isInfinite else {
            if SRSConfiguration.enableDetailedLogging {
                print("❌ [SM2] Intervalle invalide: \(card.interval)")
            }
            return false
        }
        
        // Vérifier que l'ease factor est dans les bornes
        guard card.easeFactor >= SRSConfiguration.minEaseFactor && 
              card.easeFactor <= SRSConfiguration.maxEaseFactor &&
              !card.easeFactor.isNaN && !card.easeFactor.isInfinite else {
            if SRSConfiguration.enableDetailedLogging {
                print("❌ [SM2] Ease factor invalide: \(card.easeFactor)")
            }
            return false
        }
        
        // Vérifier que les compteurs sont cohérents
        guard card.reviewCount >= 0 && card.correctCount >= 0 &&
              card.correctCount <= card.reviewCount else {
            if SRSConfiguration.enableDetailedLogging {
                print("❌ [SM2] Compteurs incohérents: reviewCount=\(card.reviewCount), correctCount=\(card.correctCount)")
            }
            return false
        }
        
        // ✅ NOUVEAU : Validation des dates (Date n'a pas isNaN/isInfinite)
        if let nextReview = card.nextReviewDate {
            // Date est toujours valide en Swift, mais on peut vérifier qu'elle n'est pas dans le futur lointain
            let distantFuture = Date.distantFuture
            let distantPast = Date.distantPast
            guard nextReview != distantFuture && nextReview != distantPast else {
                if SRSConfiguration.enableDetailedLogging {
                    print("❌ [SM2] Date de révision invalide: \(nextReview)")
                }
                return false
            }
        }
        
        if let lastReview = card.lastReviewDate {
            // Date est toujours valide en Swift, mais on peut vérifier qu'elle n'est pas dans le futur lointain
            let distantFuture = Date.distantFuture
            let distantPast = Date.distantPast
            guard lastReview != distantFuture && lastReview != distantPast else {
                if SRSConfiguration.enableDetailedLogging {
                    print("❌ [SM2] Date de dernière révision invalide: \(lastReview)")
                }
                return false
            }
        }
        
        return true
    }
    
    // Feedback haptique selon la qualité
    private func provideHapticFeedback(for quality: Int) {
        switch quality {
        case 2:  // Bon
            HapticFeedbackManager.shared.notification(type: .success)
        case 1:  // Faux
            HapticFeedbackManager.shared.notification(type: .error)
        default:
            HapticFeedbackManager.shared.impact(style: .light)
        }
    }
    
    // ✅ CALCUL ROBUSTE : Avec gestion d'erreurs
    private func calculateSM2Safely(interval: Double, easeFactor: Double, quality: Int, card: Flashcard) -> SM2Result? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Vérifier le cache SM-2 d'abord
        if let cardId = card.id?.uuidString,
           let cachedResult = sm2Cache.getCachedSM2Result(forCard: cardId, quality: quality) {
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            performanceMonitor.recordSM2Calculation(latency: latency, cacheHit: true)
            return cachedResult
        }
        
        let result = calculateSM2(interval: interval, easeFactor: easeFactor, quality: quality, card: card)
        
        // Vérifier que le résultat est valide
        guard result.interval > 0 && !result.interval.isNaN && !result.interval.isInfinite else {
            if SRSConfiguration.enableDetailedLogging {
                print("❌ [SM2] Intervalle calculé invalide: \(result.interval)")
            }
            return nil
        }
        
        guard result.easeFactor >= SRSConfiguration.minEaseFactor && 
              result.easeFactor <= SRSConfiguration.maxEaseFactor &&
              !result.easeFactor.isNaN && !result.easeFactor.isInfinite else {
            if SRSConfiguration.enableDetailedLogging {
                print("❌ [SM2] Ease factor calculé invalide: \(result.easeFactor)")
            }
            return nil
        }
        
        // Mettre en cache le résultat
        if let cardId = card.id?.uuidString {
            sm2Cache.cacheSM2Result(result, forCard: cardId, quality: quality)
        }
        
        let latency = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordSM2Calculation(latency: latency, cacheHit: false)
        
        return result
    }
    
    // ✅ LOG STRUCTURÉ : Pour observabilité
    private func logSM2Operation(opId: String, cardId: String, quality: Int, result: SM2Result) {
        let changes = [
            "interval": String(format: "%.1f", result.interval),
            "EF": String(format: "%.2f", result.easeFactor),
            "next": result.nextReviewDate.formatted(date: .abbreviated, time: .omitted)
        ]
        
        let mode: String
        switch quality {
        case 2:
            mode = "correct"
        case 1:
            mode = "incorrect"
        default:
            mode = "unknown"
        }
        
        print("📊 [SM2] Opération \(opId.prefix(8)) | Carte \(cardId.prefix(8)) | Qualité: \(quality) (\(mode)) | Changements: \(changes)")
    }
    
    // ✅ PERSISTANCE ATOMIQUE : Avec gestion d'erreurs
    private func updateCardSM2DataSafely(card: Flashcard, result: SM2Result, quality: Int, context: NSManagedObjectContext) {
        // Capturer l'état initial avant le closure
        let originalInterval = card.interval
        let originalEaseFactor = card.easeFactor
        let originalNextReviewDate = card.nextReviewDate
        let originalReviewCount = card.reviewCount
        let originalCorrectCount = card.correctCount
        
        // Vérifier si on est sur le bon thread pour ce contexte
        if context.concurrencyType == .mainQueueConcurrencyType && !Thread.isMainThread {
            // Exécuter de manière asynchrone sur le main thread
            context.perform {
                self.updateCardSM2DataSafely(card: card, result: result, quality: quality, context: context)
            }
            return
        }
        
        do {
            // Appliquer les changements
            card.interval = result.interval
            card.easeFactor = result.easeFactor
            card.nextReviewDate = result.nextReviewDate
            card.reviewCount += 1
            
            // ✅ NOUVEAU : Incrémenter correctCount pour les réponses confiantes ET hésitantes
            // Quality 3 = confiant, Quality 2 = hésité, Quality 1 = incorrect
            if quality >= SRSConfiguration.hesitantAnswerQuality {
                card.correctCount += 1
            }
            
            card.lastReviewDate = Date()
            
            // Sauvegarder atomiquement
            try context.save()
            
            print("✅ [SM2] Carte mise à jour avec succès")
            
        } catch {
            // Rollback en cas d'erreur
            print("❌ [SM2] Erreur de sauvegarde: \(error.localizedDescription)")
            print("🔄 [SM2] Tentative de rollback...")
            
            // Restaurer l'état initial
            card.interval = originalInterval
            card.easeFactor = originalEaseFactor
            card.nextReviewDate = originalNextReviewDate
            card.reviewCount = originalReviewCount
            card.correctCount = originalCorrectCount
            
            // Ne pas sauvegarder le rollback pour éviter une boucle d'erreur
            print("⚠️ [SM2] Rollback effectué - données non sauvegardées")
        }
    }
    
    // ✅ ROLLBACK SM-2 : Restaurer l'état précédent d'une carte
    func rollbackSM2Data(card: Flashcard, undoAction: UndoAction, context: NSManagedObjectContext) {
        print("🔄 [SM2] Rollback de la carte \(card.id?.uuidString.prefix(8) ?? "unknown")")
        
        // Restaurer l'état SM-2 précédent
        card.interval = undoAction.previousInterval
        card.easeFactor = undoAction.previousEaseFactor
        card.nextReviewDate = undoAction.previousNextReviewDate
        card.reviewCount = undoAction.previousReviewCount
        card.correctCount = undoAction.previousCorrectCount
        card.lastReviewDate = undoAction.previousLastReviewDate
        
        // Sauvegarder les changements
        context.perform {
            do {
                try context.save()
                print("✅ [SM2] Rollback sauvegardé avec succès")
            } catch {
                print("❌ [SM2] Erreur lors du rollback: \(error.localizedDescription)")
            }
        }
    }
    
    // ✅ ROLLBACK SESSION COMPLÈTE : Restaurer toutes les données SM-2 d'une session
    func rollbackSessionSM2Data(undoActions: [UndoAction], context: NSManagedObjectContext) {
        print("🔄 [SM2] Rollback de session complète avec \(undoActions.count) actions")
        
        for undoAction in undoActions {
            rollbackSM2Data(card: undoAction.card, undoAction: undoAction, context: context)
        }
        
        print("✅ [SM2] Rollback de session terminé")
    }
    
    // MARK: - Mode Libre - Système séparé
    
    // ✅ ÉTAT TEMPORAIRE pour le mode libre (ne touche pas aux données SM-2)
    struct FreeModeCardState {
        let cardId: String
        let wasCorrect: Bool
        let timestamp: Date
        let originalReviewCount: Int32
        let originalLastReviewDate: Date?
    }
    
    
    // ✅ MARQUER une carte en mode libre (sans toucher aux données SM-2)
    func markCardReviewedInFreeModeSafe(_ card: Flashcard, wasCorrect: Bool, context: NSManagedObjectContext) {
        guard let cardId = card.id?.uuidString else { return }
        
        // ✅ STOCKER l'état temporaire (sans modifier les données SM-2)
        let freeModeState = FreeModeCardState(
            cardId: cardId,
            wasCorrect: wasCorrect,
            timestamp: Date(),
            originalReviewCount: card.reviewCount,
            originalLastReviewDate: card.lastReviewDate
        )
        
        freeModeCardStates[cardId] = freeModeState
        
        // ✅ STOCKER dans le store externe pour la persistance
        if wasCorrect {
            freeModeStore.markMastered(cardId)
        } else {
            freeModeStore.markToStudy(cardId)
        }
        
        print("🆓 [FREE_MODE] Carte \(cardId.prefix(8)) marquée revue (sans modification SM-2)")
    }
    
    // ✅ ROLLBACK mode libre : Restaurer l'état temporaire
    func rollbackFreeModeCard(cardId: String) {
        guard let freeModeState = freeModeCardStates[cardId] else {
            print("⚠️ [FREE_MODE] Aucun état trouvé pour la carte \(cardId.prefix(8))")
            return
        }
        
        // ✅ RESTAURER l'état dans le store externe
        if freeModeState.wasCorrect {
            freeModeStore.markToStudy(cardId)  // Retirer du mastered
        } else {
            // Ne rien faire car markToStudy fait déjà remove
        }
        
        // ✅ SUPPRIMER l'état temporaire
        freeModeCardStates.removeValue(forKey: cardId)
        
        print("🔄 [FREE_MODE] Rollback de la carte \(cardId.prefix(8))")
    }
    
    // ✅ NETTOYER tous les états temporaires du mode libre
    func clearFreeModeStates() {
        freeModeCardStates.removeAll()
        print("🧹 [FREE_MODE] Tous les états temporaires nettoyés")
    }
    
    // MARK: - Mode Quiz - Système de reprise de session
    
    struct QuizProgressSnapshot: Codable {
        struct QuizRecord: Codable {
            let questionId: String
            let selectedAnswer: String?
            let isCorrect: Bool
            let timestamp: Date
        }
        
        let deckId: String
        let initialQuestionCount: Int
        let currentQuestionIndex: Int
        let correctAnswers: Int
        let incorrectAnswers: Int
        let quizRecords: [QuizRecord]
        let startTime: Date
        let lastUpdateTime: Date
    }
    
    func saveQuizProgress(for deck: FlashcardDeck, snapshot: QuizProgressSnapshot) {
        guard let deckId = deck.id?.uuidString else { return }
        let key = "quiz_progress_\(deckId)"
        
        do {
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: key)
            print("💾 [QUIZ] Progression sauvegardée pour deck \(deckId)")
        } catch {
            print("❌ [QUIZ] Erreur sauvegarde progression: \(error)")
        }
    }
    
    func loadQuizProgress(for deck: FlashcardDeck) -> QuizProgressSnapshot? {
        guard let deckId = deck.id?.uuidString else { return nil }
        let key = "quiz_progress_\(deckId)"
        
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        
        do {
            let snapshot = try JSONDecoder().decode(QuizProgressSnapshot.self, from: data)
            print("📖 [QUIZ] Progression chargée pour deck \(deckId)")
            return snapshot
        } catch {
            print("❌ [QUIZ] Erreur chargement progression: \(error)")
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
    }
    
    func clearQuizProgress(for deck: FlashcardDeck) {
        guard let deckId = deck.id?.uuidString else { return }
        let key = "quiz_progress_\(deckId)"
        UserDefaults.standard.removeObject(forKey: key)
        print("🧹 [QUIZ] Progression effacée pour deck \(deckId)")
    }
    
    // MARK: - Mode Association - Système de reprise de session
    
    struct AssociationProgressSnapshot: Codable {
        struct MatchRecord: Codable {
            let questionId: String
            let answerId: String
            let isCorrect: Bool
            let timestamp: Date
        }
        
        let deckId: String
        let totalPairs: Int
        let currentMatches: Int
        let correctMatches: Int
        let incorrectMatches: Int
        let matchRecords: [MatchRecord]
        let startTime: Date
        let lastUpdateTime: Date
    }
    
    func saveAssociationProgress(for deck: FlashcardDeck, snapshot: AssociationProgressSnapshot) {
        guard let deckId = deck.id?.uuidString else { return }
        let key = "association_progress_\(deckId)"
        
        do {
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: key)
            print("💾 [ASSOCIATION] Progression sauvegardée pour deck \(deckId)")
        } catch {
            print("❌ [ASSOCIATION] Erreur sauvegarde progression: \(error)")
        }
    }
    
    func loadAssociationProgress(for deck: FlashcardDeck) -> AssociationProgressSnapshot? {
        guard let deckId = deck.id?.uuidString else { return nil }
        let key = "association_progress_\(deckId)"
        
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        
        do {
            let snapshot = try JSONDecoder().decode(AssociationProgressSnapshot.self, from: data)
            print("📖 [ASSOCIATION] Progression chargée pour deck \(deckId)")
            return snapshot
        } catch {
            print("❌ [ASSOCIATION] Erreur chargement progression: \(error)")
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
    }
    
    func clearAssociationProgress(for deck: FlashcardDeck) {
        guard let deckId = deck.id?.uuidString else { return }
        let key = "association_progress_\(deckId)"
        UserDefaults.standard.removeObject(forKey: key)
        print("🧹 [ASSOCIATION] Progression effacée pour deck \(deckId)")
    }
    
    // ✅ MÉTRIQUES DE PERFORMANCE : Pour monitoring
    func getPerformanceMetrics() -> [String: Any] {
        let sm2Metrics = performanceMonitor.getCurrentMetrics()
        let cacheMetrics = sm2Cache.getSM2CacheMetrics()
        
        return [
            "cacheSize": seenOperationIds.count,
            "maxCacheSize": SRSConfiguration.maxOperationCacheSize,
            "idempotenceEnabled": SRSConfiguration.idempotenceCheckEnabled,
            "sm2Calculations": sm2Metrics.sm2Calculations,
            "sm2HitRate": sm2Metrics.sm2HitRate,
            "sm2AverageLatency": sm2Metrics.sm2AverageLatency,
            "cardSelections": sm2Metrics.cardSelections,
            "selectionHitRate": sm2Metrics.selectionHitRate,
            "selectionAverageLatency": sm2Metrics.selectionAverageLatency,
            "statsCalculations": sm2Metrics.statsCalculations,
            "statsHitRate": sm2Metrics.statsHitRate,
            "statsAverageLatency": sm2Metrics.statsAverageLatency,
            "batchOperations": sm2Metrics.batchOperations,
            "batchAverageLatency": sm2Metrics.batchAverageLatency,
            "averageBatchSize": sm2Metrics.averageBatchSize,
            "sm2CacheMemoryUsage": cacheMetrics.totalMemoryUsage
        ]
    }
    
    // ✅ MAINTENANCE : Nettoyage des caches
    func performMaintenance() {
        sm2Cache.cleanupExpiredCaches()
        coreDataOptimizer.performMaintenance()
        print("🔧 [SM2] Maintenance des optimisations terminée")
    }
    
    // ✅ RÉINITIALISATION : Pour les tests
    func resetOptimizations() {
        sm2Cache.clearAllSM2Caches()
        performanceMonitor.resetMetrics()
        print("🔄 [SM2] Optimisations réinitialisées")
    }
    
    // MARK: - Intégration Quiz et Association
    
    // ✅ MÉTHODE QUIZ : Traiter les résultats du mode Quiz
    func processQuizResult(card: Flashcard, quality: Int, context: NSManagedObjectContext, operationId: String? = nil) {
        // ✅ IDEMPOTENCE PAR OPÉRATION : operationId obligatoire côté UI
        guard let opId = operationId else {
            assertionFailure("[SM2] operationId est nil (idempotence cassée)")
            return
        }
        
        if SRSConfiguration.idempotenceCheckEnabled {
            let shouldProcess = operationQueue.sync {
                if seenOperationIds.contains(opId) {
                    return false
                }
                seenOperationIds.insert(opId)
                
                // ✅ ÉVICTION FIFO : Nettoyer si le cache dépasse la limite
                if seenOperationIds.count > SRSConfiguration.maxOperationCacheSize {
                    // Éviction FIFO : garder seulement les plus récents
                    let sortedIds = Array(seenOperationIds).suffix(SRSConfiguration.maxOperationCacheSize / 2)
                    seenOperationIds = Set(sortedIds)
                    print("🧹 [SM2] Cache des opérations nettoyé (éviction FIFO: \(SRSConfiguration.maxOperationCacheSize / 2) conservés)")
                }
                return true
            }
            
            if !shouldProcess {
                if SRSConfiguration.enableDetailedLogging {
                    print("🔄 [SM2] Opération Quiz déjà traitée - idempotence (opId: \(opId.prefix(8)))")
                }
                return
            }
        }
        
        // ✅ VALIDATION D'ENTRÉE : Vérifier les données de la carte
        guard validateCardData(card: card) else {
            if SRSConfiguration.enableDetailedLogging {
                print("❌ [SM2] Données de carte invalides - opération Quiz annulée")
            }
            return
        }
        
        // ✅ SM-2 pur : Vérifier si cette révision doit mettre à jour les paramètres SM-2
        if shouldUpdateSM2(card: card) {
            // ✅ Mise à jour normale SM-2 (carte due ou nouvelle)
            guard let result = calculateSM2Safely(
                interval: card.interval,
                easeFactor: card.easeFactor,
                quality: quality,
                card: card
            ) else {
                if SRSConfiguration.enableDetailedLogging {
                    print("❌ [SM2] Erreur de calcul SM-2 - opération Quiz annulée")
                }
                return
            }
            
            // ✅ LOG STRUCTURÉ : Pour observabilité (conditionnel)
            if SRSConfiguration.enableDetailedLogging {
                logSM2Operation(opId: opId, cardId: card.id?.uuidString ?? "unknown", quality: quality, result: result)
            }
            
            // Update card with idempotence and error handling
            updateCardSM2DataSafely(card: card, result: result, quality: quality, context: context)
            
            // Cache for performance
            cacheResult(card: card, quality: quality, result: result)
        } else {
            // ✅ LOG-ONLY : Révision avant échéance (pas de mise à jour SM-2)
            if SRSConfiguration.enableDetailedLogging {
                print("📝 [SM2] Log-only mode Quiz - carte pas encore due")
            }
            processLogOnlyUpdate(card: card, context: context)
        }
    }
    
    // ✅ MÉTHODE ASSOCIATION : Traiter les résultats du mode Association
    func processAssociationResult(card1: Flashcard, card2: Flashcard, quality: Int, context: NSManagedObjectContext, operationId: String? = nil) {
        // ✅ IDEMPOTENCE PAR OPÉRATION : operationId obligatoire côté UI
        guard let opId = operationId else {
            assertionFailure("[SM2] operationId est nil (idempotence cassée)")
            return
        }
        
        if SRSConfiguration.idempotenceCheckEnabled {
            let shouldProcess = operationQueue.sync {
                if seenOperationIds.contains(opId) {
                    return false
                }
                seenOperationIds.insert(opId)
                return true
            }
            
            if !shouldProcess {
                if SRSConfiguration.enableDetailedLogging {
                    print("🔄 [SM2] Opération Association déjà traitée - idempotence (opId: \(opId.prefix(8)))")
                }
                return
            }
        }
        
        // ✅ VALIDATION D'ENTRÉE : Vérifier les données des cartes
        guard validateCardData(card: card1) && validateCardData(card: card2) else {
            if SRSConfiguration.enableDetailedLogging {
                print("❌ [SM2] Données de cartes invalides - opération Association annulée")
            }
            return
        }
        
        // ✅ TRAITER LES 2 CARTES AVEC LA MÊME QUALITÉ
        print("🔗 [SM2] Association: traiter 2 cartes avec quality \(quality)")
        
        // Traiter la première carte
        if shouldUpdateSM2(card: card1) {
            guard let result1 = calculateSM2Safely(
                interval: card1.interval,
                easeFactor: card1.easeFactor,
                quality: quality,
                card: card1
            ) else {
                print("❌ [SM2] Erreur de calcul SM-2 pour carte 1 - opération Association annulée")
                return
            }
            
            updateCardSM2DataSafely(card: card1, result: result1, quality: quality, context: context)
            cacheResult(card: card1, quality: quality, result: result1)
        } else {
            processLogOnlyUpdate(card: card1, context: context)
        }
        
        // Traiter la deuxième carte
        if shouldUpdateSM2(card: card2) {
            guard let result2 = calculateSM2Safely(
                interval: card2.interval,
                easeFactor: card2.easeFactor,
                quality: quality,
                card: card2
            ) else {
                print("❌ [SM2] Erreur de calcul SM-2 pour carte 2 - opération Association annulée")
                return
            }
            
            updateCardSM2DataSafely(card: card2, result: result2, quality: quality, context: context)
            cacheResult(card: card2, quality: quality, result: result2)
        } else {
            processLogOnlyUpdate(card: card2, context: context)
        }
        
        print("✅ [SM2] Association traitée: 2 cartes mises à jour avec quality \(quality)")
    }
    
    // ✅ MÉTHODE UTILITAIRE : Obtenir toutes les cartes en ordre optimal (mode libre)
    func getAllCardsInOptimalOrder(deck: FlashcardDeck) -> [Flashcard] {
        let flashcards = Array((deck.flashcards as? Set<Flashcard>) ?? [])

        let readyCards = flashcards.filter { card in
            guard let nextReview = card.nextReviewDate else { return false }
            return nextReview <= Date()
        }
        let readyIds = Set(readyCards.map { $0.objectID })

        let newCards = flashcards.filter { card in
            card.nextReviewDate == nil && !readyIds.contains(card.objectID)
        }
        let newIds = Set(newCards.map { $0.objectID })

        let remainingCards = flashcards.filter { card in
            !readyIds.contains(card.objectID) && !newIds.contains(card.objectID)
        }

        print("🔍 [DEBUG] getSmartCards - readyCards: \(readyCards.count)")
        print("🔍 [DEBUG] getSmartCards - newCards: \(newCards.count)")
        print("🔍 [DEBUG] getSmartCards - remainingCards: \(remainingCards.count)")
        print("🔍 [DEBUG] getSmartCards - total: \(readyCards.count + newCards.count + remainingCards.count)")
        
        return readyCards
            + newCards
            + remainingCards.shuffled()
    }

    func countFreeModeCards(deck: FlashcardDeck) -> Int {
        let count = getAllCardsInOptimalOrder(deck: deck).count
        print("🔍 [DEBUG] countFreeModeCards: \(count)")
        return count
    }

    func markCardReviewedInFreeMode(_ card: Flashcard, wasCorrect: Bool, context: NSManagedObjectContext) {
        // ✅ UTILISER la nouvelle méthode sécurisée
        markCardReviewedInFreeModeSafe(card, wasCorrect: wasCorrect, context: context)
    }

    func loadFreeModeSession(for deck: FlashcardDeck) -> [Flashcard] {
        guard let deckId = deck.id?.uuidString,
              let identifiers = freeSessionStore.loadSession(forDeckId: deckId),
              !identifiers.isEmpty else {
            return []
        }

        let flashcardsSet = deck.flashcards as? Set<Flashcard> ?? []
        let flashcardMap = Dictionary(uniqueKeysWithValues: flashcardsSet.compactMap { card -> (String, Flashcard)? in
            guard let id = card.id?.uuidString else { return nil }
            return (id, card)
        })

        let restored = identifiers.compactMap { flashcardMap[$0] }
        return restored
    }

    func saveFreeModeSession(for deck: FlashcardDeck, cards: [Flashcard]) {
        guard let deckId = deck.id?.uuidString else { return }
        let identifiers = cards.compactMap { $0.id?.uuidString }
        if identifiers.isEmpty {
            freeSessionStore.clearSession(forDeckId: deckId)
        } else {
            freeSessionStore.saveSession(forDeckId: deckId, identifiers: identifiers)
        }
    }

    func clearFreeModeSession(for deck: FlashcardDeck) {
        guard let deckId = deck.id?.uuidString else { return }
        freeSessionStore.clearSession(forDeckId: deckId)
    }

    struct FreeModeProgressSnapshot: Codable {
        struct UndoRecord: Codable {
            let cardId: String
            let swipeDirection: String
        }

        let initialCount: Int
        let currentIndex: Int
        let cardsKnown: Int
        let cardsToReview: Int
        let undoRecords: [UndoRecord]
    }

    func loadFreeModeProgress(for deck: FlashcardDeck) -> FreeModeProgressSnapshot? {
        guard let deckId = deck.id?.uuidString else { return nil }
        return freeSessionStore.loadProgress(forDeckId: deckId)
    }

    func saveFreeModeProgress(for deck: FlashcardDeck, snapshot: FreeModeProgressSnapshot) {
        guard let deckId = deck.id?.uuidString else { return }
        freeSessionStore.saveProgress(snapshot, forDeckId: deckId)
    }

    func clearFreeModeProgress(for deck: FlashcardDeck) {
        guard let deckId = deck.id?.uuidString else { return }
        freeSessionStore.clearProgress(forDeckId: deckId)
    }

    func countFreeModeMastered(deck: FlashcardDeck) -> Int {
        let flashcards = Array((deck.flashcards as? Set<Flashcard>) ?? [])
        let count = flashcards.reduce(into: 0) { count, card in
            if let id = card.id?.uuidString, freeModeStore.isMastered(id) {
                count += 1
            }
        }
        print("🔍 [DEBUG] countFreeModeMastered: \(count)")
        return count
    }
}

extension SimpleSRSManager {
    enum FreeModeStatus: Equatable {
        case new
        case toStudy
        case mastered

        var icon: String {
            switch self {
            case .new: return "sparkles"
            case .toStudy: return "clock"
            case .mastered: return "checkmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .new: return .cyan
            case .toStudy: return .orange
            case .mastered: return .purple
            }
        }

        var displayName: String {
            switch self {
            case .new: return "Nouvelle"
            case .toStudy: return "À étudier"
            case .mastered: return "Maîtrisé"
            }
        }

        var caption: String { displayName.lowercased() }
    }

    func getFreeModeStatus(for card: Flashcard) -> FreeModeStatus {
        if card.reviewCount == 0 && card.lastReviewDate == nil {
            return .new
        }
        if let cardId = card.id?.uuidString, freeModeStore.isMastered(cardId) {
            return .mastered
        }
        return .toStudy
    }
}

private final class FreeModeProgressStore {
    static let shared = FreeModeProgressStore()

    private let storageKey = "com.parallax.freemode.mastered"
    private var masteredIds: Set<String>
    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let stored = userDefaults.array(forKey: storageKey) as? [String] {
            masteredIds = Set(stored)
        } else {
            masteredIds = []
        }
    }

    func markMastered(_ id: String) {
        masteredIds.insert(id)
        persist()
    }

    func markToStudy(_ id: String) {
        masteredIds.remove(id)
        persist()
    }

    func isMastered(_ id: String) -> Bool {
        masteredIds.contains(id)
    }

    private func persist() {
        userDefaults.set(Array(masteredIds), forKey: storageKey)
    }
}

private final class FreeModeSessionStore {
    static let shared = FreeModeSessionStore()

    private let storageKeyPrefix = "free_session_"
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    func loadSession(forDeckId deckId: String) -> [String]? {
        defaults.array(forKey: storageKeyPrefix + deckId) as? [String]
    }

    func saveSession(forDeckId deckId: String, identifiers: [String]) {
        defaults.set(identifiers, forKey: storageKeyPrefix + deckId)
    }

    func clearSession(forDeckId deckId: String) {
        defaults.removeObject(forKey: storageKeyPrefix + deckId)
    }

    private func progressKey(forDeckId deckId: String) -> String {
        storageKeyPrefix + deckId + "_progress"
    }

    func loadProgress(forDeckId deckId: String) -> SimpleSRSManager.FreeModeProgressSnapshot? {
        let key = progressKey(forDeckId: deckId)
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try decoder.decode(SimpleSRSManager.FreeModeProgressSnapshot.self, from: data)
        } catch {
            print("⚠️ [FREE_MODE] Impossible de charger la progression sauvegardée: \(error.localizedDescription)")
            defaults.removeObject(forKey: key)
            return nil
        }
    }

    func saveProgress(_ snapshot: SimpleSRSManager.FreeModeProgressSnapshot, forDeckId deckId: String) {
        let key = progressKey(forDeckId: deckId)
        do {
            let data = try encoder.encode(snapshot)
            defaults.set(data, forKey: key)
        } catch {
            print("⚠️ [FREE_MODE] Impossible d'enregistrer la progression: \(error.localizedDescription)")
        }
    }

    func clearProgress(forDeckId deckId: String) {
        defaults.removeObject(forKey: progressKey(forDeckId: deckId))
    }
}
