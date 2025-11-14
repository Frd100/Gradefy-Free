//
// SM2CoreDataOptimizer.swift
// PARALLAX
//
// Created by Claude on 8/14/25.
//

import Foundation
import CoreData
import os.log

/// Optimiseur Core Data spécialisé pour les opérations SM-2
/// Optimise les requêtes et les opérations batch pour de meilleures performances
class SM2CoreDataOptimizer {
    static let shared = SM2CoreDataOptimizer()
    
    // MARK: - Intégration avec le système existant
    private let sm2Cache = SM2OptimizationCache.shared
    private let monitor = CachePerformanceMonitor()
    
    // MARK: - Queues optimisées
    private let fetchQueue = DispatchQueue(label: "sm2.fetch", qos: .userInitiated, attributes: .concurrent)
    private let batchQueue = DispatchQueue(label: "sm2.batch", qos: .userInitiated)
    
    private let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "SM2CoreData")
    
    private init() {
        print("🚀 [SM2_COREDATA] Optimiseur Core Data SM-2 initialisé")
    }
    
    // MARK: - Requêtes Optimisées pour SM-2
    
    /// Requête optimisée pour obtenir les cartes prêtes (due)
    func getReadyCardsOptimized(forDeck deck: FlashcardDeck, context: NSManagedObjectContext) -> [Flashcard] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Vérifier le cache d'abord
        let deckId = deck.id?.uuidString ?? "unknown"
        if let cached = sm2Cache.getCachedCardSelection(forDeck: deckId, minCards: 0, excludeIds: []) {
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            monitor.recordLatency(latency)
            print("⚡ [SM2_COREDATA] Cache hit pour cartes prêtes: \(cached.count) cartes en \(Int(latency * 1000))ms")
            return cached
        }
        
        // Requête optimisée avec prédicat précis
        let fetchRequest: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
        
        // ✅ CORRECTION : Prédicat SM-2 strict pour cartes dues
        let now = Date()
        fetchRequest.predicate = NSPredicate(format: "deck == %@ AND (nextReviewDate == nil OR nextReviewDate <= %@)", deck, now as NSDate)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "nextReviewDate", ascending: true),
            NSSortDescriptor(key: "reviewCount", ascending: true)
        ]
        
        // Optimisations Core Data
        fetchRequest.fetchBatchSize = 20
        fetchRequest.returnsObjectsAsFaults = false
        
        do {
            let cards = try context.performAndWait {
                try fetchRequest.execute()
            }
            
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            monitor.recordLatency(latency)
            
            // ✅ CORRECTION : Logs optimisés
            if SRSConfiguration.enableDetailedLogging {
                print("🔍 [SM2_COREDATA] Cartes dues trouvées: \(cards.count) pour deck \(deckId)")
            }
            
            // Mettre en cache le résultat
            sm2Cache.cacheCardSelection(cards, forDeck: deckId, minCards: 0, excludeIds: [])
            
            print("📊 [SM2_COREDATA] Requête optimisée: \(cards.count) cartes prêtes en \(Int(latency * 1000))ms")
            return cards
            
        } catch {
            logger.error("❌ Erreur requête cartes prêtes: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Requête optimisée pour obtenir les nouvelles cartes
    func getNewCardsOptimized(forDeck deck: FlashcardDeck, limit: Int, context: NSManagedObjectContext) -> [Flashcard] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let fetchRequest: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
        
        // ✅ AJOUT : Exclure les cartes révisées aujourd'hui
        let today = Calendar.current.startOfDay(for: Date())
        fetchRequest.predicate = NSPredicate(format: "deck == %@ AND nextReviewDate == nil AND (lastReviewDate == nil OR lastReviewDate < %@)", deck, today as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        fetchRequest.fetchLimit = limit
        
        // Optimisations
        fetchRequest.fetchBatchSize = min(limit, 20)
        fetchRequest.returnsObjectsAsFaults = false
        
        do {
            let cards = try context.performAndWait {
                try fetchRequest.execute()
            }
            
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            monitor.recordLatency(latency)
            
            print("🆕 [SM2_COREDATA] Nouvelles cartes: \(cards.count) cartes en \(Int(latency * 1000))ms")
            return cards
            
        } catch {
            logger.error("❌ Erreur requête nouvelles cartes: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Requête optimisée pour obtenir les cartes modérément maîtrisées
    func getModerateCardsOptimized(forDeck deck: FlashcardDeck, limit: Int, context: NSManagedObjectContext) -> [Flashcard] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let moderateCardsRequest: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
        
        // ✅ AJOUT : Exclure les cartes révisées aujourd'hui
        let today = Calendar.current.startOfDay(for: Date())
        moderateCardsRequest.predicate = NSPredicate(format: "deck == %@ AND interval <= %f AND nextReviewDate > %@ AND (lastReviewDate == nil OR lastReviewDate < %@)", 
            deck, 7.0, Date() as NSDate, today as NSDate) // 7 jours comme seuil modéré
        moderateCardsRequest.sortDescriptors = [NSSortDescriptor(key: "nextReviewDate", ascending: true)]
        moderateCardsRequest.fetchLimit = limit
        
        // Optimisations
        moderateCardsRequest.fetchBatchSize = min(limit, 20)
        moderateCardsRequest.returnsObjectsAsFaults = false
        
        do {
            let cards = try context.performAndWait {
                try moderateCardsRequest.execute()
            }
            
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            monitor.recordLatency(latency)
            
            print("📈 [SM2_COREDATA] Cartes modérées: \(cards.count) cartes en \(Int(latency * 1000))ms")
            return cards
            
        } catch {
            logger.error("❌ Erreur requête cartes modérées: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Opérations Batch Optimisées
    
    /// Mise à jour batch optimisée pour les résultats SM-2
    func batchUpdateSM2Results(_ updates: [(Flashcard, SM2Result, Int)], context: NSManagedObjectContext) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        context.performAndWait {
            var affectedDeckIds = Set<String>()
            for (card, result, quality) in updates {
                // Mettre à jour la carte
                card.interval = result.interval
                card.easeFactor = result.easeFactor
                card.nextReviewDate = result.nextReviewDate
                card.lastReviewDate = Date()
                card.reviewCount += 1

                // Incrémenter correctCount seulement pour les bonnes réponses
                if quality >= SRSConfiguration.confidentAnswerQuality {
                    card.correctCount += 1
                }

                if let deckId = card.deck?.id?.uuidString {
                    affectedDeckIds.insert(deckId)
                }

                // Mettre en cache le résultat SM-2
                if let cardId = card.id?.uuidString {
                    sm2Cache.cacheSM2Result(result, forCard: cardId, quality: quality)
                }
            }
            
            // Sauvegarde optimisée
            do {
                try context.save()
                let latency = CFAbsoluteTimeGetCurrent() - startTime
                monitor.recordLatency(latency)

                print("💾 [SM2_COREDATA] Batch update: \(updates.count) cartes en \(Int(latency * 1000))ms")

                for deckId in affectedDeckIds {
                    sm2Cache.invalidateDeckStats(forDeckId: deckId)
                    sm2Cache.invalidateCardSelections(forDeckId: deckId)
                }

            } catch {
                logger.error("❌ Erreur batch update: \(error.localizedDescription)")
                context.rollback()
            }
        }
    }
    
    /// Mise à jour batch optimisée pour le mode log-only
    func batchUpdateLogOnly(_ cards: [Flashcard], context: NSManagedObjectContext) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        context.performAndWait {
            var affectedDeckIds = Set<String>()
            for card in cards {
                card.reviewCount += 1
                card.lastReviewDate = Date()
                if let deckId = card.deck?.id?.uuidString {
                    affectedDeckIds.insert(deckId)
                }
                // Pas de mise à jour des paramètres SM-2
            }

            do {
                try context.save()
                let latency = CFAbsoluteTimeGetCurrent() - startTime
                monitor.recordLatency(latency)

                print("📝 [SM2_COREDATA] Log-only batch: \(cards.count) cartes en \(Int(latency * 1000))ms")

                for deckId in affectedDeckIds {
                    sm2Cache.invalidateDeckStats(forDeckId: deckId)
                    sm2Cache.invalidateCardSelections(forDeckId: deckId)
                }

            } catch {
                logger.error("❌ Erreur log-only batch: \(error.localizedDescription)")
                context.rollback()
            }
        }
    }
    
    // MARK: - Statistiques Optimisées
    
    /// Calcul optimisé des statistiques de deck
    func getDeckStatsOptimized(forDeck deck: FlashcardDeck, context: NSManagedObjectContext) -> DeckSRSStats {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Vérifier le cache d'abord
        let deckId = deck.id?.uuidString ?? "unknown"
        if let cached = sm2Cache.getCachedDeckStats(forDeck: deckId) {
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            monitor.recordLatency(latency)
            print("⚡ [SM2_COREDATA] Cache hit stats pour deck \(deckId) en \(Int(latency * 1000))ms")
            return cached
        }
        
        // Requêtes optimisées pour les statistiques
        let totalCards = getTotalCardsCount(forDeck: deck, context: context)
        let masteredCards = getMasteredCardsCount(forDeck: deck, context: context)
        let readyCards = getReadyCardsCount(forDeck: deck, context: context)
        let todayReviews = getTodayReviewsCount(forDeck: deck, context: context)
        let streak = calculateStudyStreakOptimized(forDeck: deck, context: context)
        
        // ✅ AJOUT : Calculer les cartes en retard
        let overdueCards = getOverdueCardsCount(forDeck: deck, context: context)
        
        let stats = DeckSRSStats(
            masteryPercentage: totalCards > 0 ? Int((Double(masteredCards) / Double(totalCards)) * 100) : 0,
            readyCount: readyCards,
            studyStreak: streak,
            todayReviewCount: todayReviews,
            totalCards: totalCards,
            masteredCards: masteredCards,
            overdue: overdueCards
        )
        
        let latency = CFAbsoluteTimeGetCurrent() - startTime
        monitor.recordLatency(latency)
        
        // Mettre en cache les statistiques
        sm2Cache.cacheDeckStats(stats, forDeck: deckId)
        
        print("📊 [SM2_COREDATA] Stats calculées pour deck \(deckId) en \(Int(latency * 1000))ms")
        return stats
    }
    
    // MARK: - Méthodes Privées Optimisées
    
    private func getTotalCardsCount(forDeck deck: FlashcardDeck, context: NSManagedObjectContext) -> Int {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Flashcard.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "deck == %@", deck)
        fetchRequest.resultType = .countResultType
        
        do {
            let count = try context.performAndWait {
                try context.count(for: fetchRequest)
            }
            return count
        } catch {
            logger.error("❌ Erreur count total: \(error.localizedDescription)")
            return 0
        }
    }
    
    private func getMasteredCardsCount(forDeck deck: FlashcardDeck, context: NSManagedObjectContext) -> Int {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Flashcard.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "deck == %@ AND interval >= %f", 
                                           deck, 
                                           SRSConfiguration.masteryIntervalThreshold)
        fetchRequest.resultType = .countResultType
        
        do {
            let count = try context.performAndWait {
                try context.count(for: fetchRequest)
            }
            return count
        } catch {
            logger.error("❌ Erreur count maîtrisées: \(error.localizedDescription)")
            return 0
        }
    }
    
    private func getAcquiredCardsCount(forDeck deck: FlashcardDeck, context: NSManagedObjectContext) -> Int {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Flashcard.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "deck == %@ AND interval >= %f AND interval < %f", 
                                           deck, 
                                           SRSConfiguration.acquiredIntervalThreshold,
                                           SRSConfiguration.masteryIntervalThreshold)
        fetchRequest.resultType = .countResultType
        
        do {
            let count = try context.performAndWait {
                try context.count(for: fetchRequest)
            }
            return count
        } catch {
            logger.error("❌ Erreur count acquises: \(error.localizedDescription)")
            return 0
        }
    }
    
    private func getReadyCardsCount(forDeck deck: FlashcardDeck, context: NSManagedObjectContext) -> Int {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Flashcard.fetchRequest()
        
        // ✅ AJOUT : Exclure les cartes révisées aujourd'hui
        let today = Calendar.current.startOfDay(for: Date())
        fetchRequest.predicate = NSPredicate(format: "deck == %@ AND (nextReviewDate == nil OR nextReviewDate <= %@) AND (lastReviewDate == nil OR lastReviewDate < %@)", deck, Date() as NSDate, today as NSDate)
        fetchRequest.resultType = .countResultType
        
        do {
            let count = try context.performAndWait {
                try context.count(for: fetchRequest)
            }
            return count
        } catch {
            logger.error("❌ Erreur count prêtes: \(error.localizedDescription)")
            return 0
        }
    }
    
    private func getTodayReviewsCount(forDeck deck: FlashcardDeck, context: NSManagedObjectContext) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Flashcard.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "deck == %@ AND lastReviewDate >= %@ AND lastReviewDate < %@", 
                                           deck, today as NSDate, tomorrow as NSDate)
        fetchRequest.resultType = .countResultType
        
        do {
            let count = try context.performAndWait {
                try context.count(for: fetchRequest)
            }
            return count
        } catch {
            logger.error("❌ Erreur count aujourd'hui: \(error.localizedDescription)")
            return 0
        }
    }
    
    private func calculateStudyStreakOptimized(forDeck deck: FlashcardDeck, context: NSManagedObjectContext) -> Int {
        // Calcul simplifié pour les performances
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Flashcard.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "deck == %@ AND lastReviewDate >= %@", deck, yesterday as NSDate)
        fetchRequest.resultType = .countResultType
        
        do {
            let count = try context.performAndWait {
                try context.count(for: fetchRequest)
            }
            return count > 0 ? 1 : 0 // Simplifié pour les performances
        } catch {
            logger.error("❌ Erreur calcul streak: \(error.localizedDescription)")
            return 0
        }
    }
    
    // ✅ NOUVELLE MÉTHODE : Compter les cartes en retard
    private func getOverdueCardsCount(forDeck deck: FlashcardDeck, context: NSManagedObjectContext) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Flashcard.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "deck == %@ AND nextReviewDate < %@", deck, today as NSDate)
        fetchRequest.resultType = .countResultType
        
        do {
            let count = try context.performAndWait {
                try context.count(for: fetchRequest)
            }
            return count
        } catch {
            logger.error("❌ Erreur count en retard: \(error.localizedDescription)")
            return 0
        }
    }
    
    // MARK: - Maintenance et Nettoyage
    
    /// Nettoie les caches et optimise les performances
    func performMaintenance() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Nettoyer les caches SM-2
        sm2Cache.cleanupExpiredCaches()
        
        // Optimisations Core Data
        batchQueue.async {
            // Ici on pourrait ajouter des optimisations Core Data spécifiques
            // comme la défragmentation ou la compression
        }
        
        let latency = CFAbsoluteTimeGetCurrent() - startTime
        print("🔧 [SM2_COREDATA] Maintenance terminée en \(Int(latency * 1000))ms")
    }
    
    /// Obtient les métriques de performance Core Data
    func getCoreDataMetrics() -> CoreDataMetrics {
        return CoreDataMetrics(
            totalOperations: 0, // À implémenter avec un compteur
            averageLatency: 0, // À calculer
            cacheHitRate: 0 // À calculer
        )
    }
}

// MARK: - Structures de Métriques

struct CoreDataMetrics {
    let totalOperations: Int
    let averageLatency: TimeInterval
    let cacheHitRate: Double
}
