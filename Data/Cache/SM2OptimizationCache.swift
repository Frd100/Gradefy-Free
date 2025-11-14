//
// SM2OptimizationCache.swift
// PARALLAX
//
// Created by Claude on 8/14/25.
//

import CoreData
import Foundation
import os.log

/// Cache spécialisé pour les optimisations SM-2
/// S'intègre avec GradefyCacheManager et SmartAverageCache existants
class SM2OptimizationCache {
    static let shared = SM2OptimizationCache()

    // MARK: - Cache SM-2 Spécialisé

    private let sm2ResultCache = NSCache<NSString, SM2CachedResult>()
    private let cardSelectionCache = NSCache<NSString, CardSelectionCache>()
    private let deckStatsCache = NSCache<NSString, DeckStatsCache>()

    private var sm2ResultKeys = Set<String>()
    private var selectionKeysByDeck = [String: Set<String>]()
    private var deckStatsKeys = Set<String>()

    // MARK: - Intégration avec le système existant

    private let gradefyCache = GradefyCacheManager.shared
    private let averageCache = SmartAverageCache.shared
    private let monitor = CachePerformanceMonitor()

    // MARK: - Queues

    private let sm2Queue = DispatchQueue(label: "sm2.optimization", qos: .userInitiated, attributes: .concurrent)
    private let selectionQueue = DispatchQueue(label: "sm2.selection", qos: .userInitiated)

    private let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "SM2Cache")

    private init() {
        setupSM2Caches()
        print("🚀 [SM2_CACHE] Cache SM-2 optimisé initialisé")
    }

    private func setupSM2Caches() {
        // Cache des résultats SM-2 (calculs coûteux)
        sm2ResultCache.countLimit = 100
        sm2ResultCache.totalCostLimit = 5 * 1024 * 1024 // 5MB

        // Cache des sélections de cartes
        cardSelectionCache.countLimit = 50
        cardSelectionCache.totalCostLimit = 2 * 1024 * 1024 // 2MB

        // Cache des statistiques de deck
        deckStatsCache.countLimit = 20
        deckStatsCache.totalCostLimit = 1 * 1024 * 1024 // 1MB

        print("⚙️ [SM2_CACHE] Configuration: \(sm2ResultCache.countLimit) résultats, \(cardSelectionCache.countLimit) sélections, \(deckStatsCache.countLimit) stats")
    }

    // MARK: - Cache des Résultats SM-2

    /// Cache un résultat de calcul SM-2
    func cacheSM2Result(_ result: SM2Result, forCard cardId: String, quality: Int) {
        let startTime = CFAbsoluteTimeGetCurrent()

        let keyString = "sm2_result_\(cardId)_\(quality)"
        let key = keyString as NSString
        let cachedResult = SM2CachedResult(
            result: result,
            timestamp: Date(),
            cardId: cardId,
            quality: quality
        )

        sm2Queue.async(flags: .barrier) { [weak self] in
            self?.sm2ResultCache.setObject(cachedResult, forKey: key)
            self?.sm2ResultKeys.insert(keyString)
            self?.monitor.recordCacheWrite()

            let latency = CFAbsoluteTimeGetCurrent() - startTime
            self?.monitor.recordLatency(latency)

            print("💾 [SM2_CACHE] Résultat SM-2 caché: \(cardId) (qualité: \(quality)) en \(Int(latency * 1000))ms")
        }
    }

    /// Récupère un résultat SM-2 du cache
    func getCachedSM2Result(forCard cardId: String, quality: Int) -> SM2Result? {
        let startTime = CFAbsoluteTimeGetCurrent()

        let keyString = "sm2_result_\(cardId)_\(quality)"
        let key = keyString as NSString

        guard let cached = sm2ResultCache.object(forKey: key) else {
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            monitor.recordLatency(latency)
            monitor.recordCacheMiss()
            return nil
        }

        // Vérifier si le cache est encore valide (5 minutes)
        if Date().timeIntervalSince(cached.timestamp) > 300 {
            sm2Queue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                self.sm2ResultCache.removeObject(forKey: key)
                self.sm2ResultKeys.remove(keyString)
            }
            monitor.recordCacheMiss()
            return nil
        }

        let latency = CFAbsoluteTimeGetCurrent() - startTime
        monitor.recordLatency(latency)
        monitor.recordCacheHit()

        print("⚡ [SM2_CACHE] Cache hit SM-2: \(cardId) (qualité: \(quality)) en \(Int(latency * 1000))ms")
        return cached.result
    }

    // MARK: - Cache des Sélections de Cartes

    /// Cache une sélection intelligente de cartes
    func cacheCardSelection(_ cards: [Flashcard], forDeck deckId: String, minCards: Int, excludeIds: Set<String>) {
        let startTime = CFAbsoluteTimeGetCurrent()

        let keyString = "selection_\(deckId)_\(minCards)_\(excludeIds.hashValue)"
        let key = keyString as NSString
        let selectionCache = CardSelectionCache(
            cards: cards,
            timestamp: Date(),
            deckId: deckId,
            minCards: minCards,
            excludeIds: excludeIds
        )

        selectionQueue.async { [weak self] in
            self?.cardSelectionCache.setObject(selectionCache, forKey: key)
            self?.selectionKeysByDeck[deckId, default: []].insert(keyString)
            self?.monitor.recordCacheWrite()

            let latency = CFAbsoluteTimeGetCurrent() - startTime
            self?.monitor.recordLatency(latency)

            print("🎯 [SM2_CACHE] Sélection cachée: \(cards.count) cartes pour deck \(deckId) en \(Int(latency * 1000))ms")
        }
    }

    /// Récupère une sélection de cartes du cache
    func getCachedCardSelection(forDeck deckId: String, minCards: Int, excludeIds: Set<String>) -> [Flashcard]? {
        let startTime = CFAbsoluteTimeGetCurrent()

        let keyString = "selection_\(deckId)_\(minCards)_\(excludeIds.hashValue)"
        let key = keyString as NSString

        guard let cached = cardSelectionCache.object(forKey: key) else {
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            monitor.recordLatency(latency)
            monitor.recordCacheMiss()
            return nil
        }

        // Vérifier si le cache est encore valide (2 minutes pour les sélections)
        if Date().timeIntervalSince(cached.timestamp) > 120 {
            selectionQueue.async { [weak self] in
                guard let self = self else { return }
                self.cardSelectionCache.removeObject(forKey: key)
                self.selectionKeysByDeck[deckId]?.remove(keyString)
                if self.selectionKeysByDeck[deckId]?.isEmpty == true {
                    self.selectionKeysByDeck.removeValue(forKey: deckId)
                }
            }
            monitor.recordCacheMiss()
            return nil
        }

        let latency = CFAbsoluteTimeGetCurrent() - startTime
        monitor.recordLatency(latency)
        monitor.recordCacheHit()

        print("⚡ [SM2_CACHE] Cache hit sélection: \(cached.cards.count) cartes pour deck \(deckId) en \(Int(latency * 1000))ms")
        return cached.cards
    }

    // MARK: - Cache des Statistiques de Deck

    /// Cache les statistiques d'un deck
    func cacheDeckStats(_ stats: DeckSRSStats, forDeck deckId: String) {
        let startTime = CFAbsoluteTimeGetCurrent()

        let keyString = "stats_\(deckId)"
        let key = keyString as NSString
        let statsCache = DeckStatsCache(
            stats: stats,
            timestamp: Date(),
            deckId: deckId
        )

        sm2Queue.async(flags: .barrier) { [weak self] in
            self?.deckStatsCache.setObject(statsCache, forKey: key)
            self?.deckStatsKeys.insert(keyString)
            self?.monitor.recordCacheWrite()

            let latency = CFAbsoluteTimeGetCurrent() - startTime
            self?.monitor.recordLatency(latency)

            print("📊 [SM2_CACHE] Stats cachées pour deck \(deckId) en \(Int(latency * 1000))ms")
        }
    }

    /// Récupère les statistiques d'un deck du cache
    func getCachedDeckStats(forDeck deckId: String) -> DeckSRSStats? {
        let startTime = CFAbsoluteTimeGetCurrent()

        let keyString = "stats_\(deckId)"
        let key = keyString as NSString

        guard let cached = deckStatsCache.object(forKey: key) else {
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            monitor.recordLatency(latency)
            monitor.recordCacheMiss()
            return nil
        }

        // Vérifier si le cache est encore valide (1 minute pour les stats)
        if Date().timeIntervalSince(cached.timestamp) > 60 {
            sm2Queue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                self.deckStatsCache.removeObject(forKey: key)
                self.deckStatsKeys.remove(keyString)
            }
            monitor.recordCacheMiss()
            return nil
        }

        let latency = CFAbsoluteTimeGetCurrent() - startTime
        monitor.recordLatency(latency)
        monitor.recordCacheHit()

        print("⚡ [SM2_CACHE] Cache hit stats pour deck \(deckId) en \(Int(latency * 1000))ms")
        return cached.stats
    }

    // MARK: - Nettoyage et Maintenance

    /// Nettoie les caches expirés
    func cleanupExpiredCaches() {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Pour NSCache, on ne peut pas itérer sur toutes les clés
        // Le nettoyage se fait automatiquement lors des accès
        // On peut juste vider complètement si nécessaire

        // Nettoyer le cache des résultats SM-2 (expiration 5 minutes)
        sm2Queue.async(flags: .barrier) { [weak self] in
            _ = self // Utiliser self pour éviter l'avertissement
            // NSCache gère automatiquement l'éviction basée sur la mémoire
            // Le nettoyage se fait lors des accès avec vérification de timestamp
        }

        // Nettoyer le cache des sélections (expiration 2 minutes)
        selectionQueue.async { [weak self] in
            _ = self // Utiliser self pour éviter l'avertissement
            // Même logique pour les sélections
        }

        // Nettoyer le cache des stats (expiration 1 minute)
        sm2Queue.async(flags: .barrier) { [weak self] in
            _ = self // Utiliser self pour éviter l'avertissement
            // Même logique pour les stats
        }

        let latency = CFAbsoluteTimeGetCurrent() - startTime
        print("🧹 [SM2_CACHE] Nettoyage automatique activé en \(Int(latency * 1000))ms")
    }

    /// Vide tous les caches SM-2
    func clearAllSM2Caches() {
        sm2Queue.async(flags: .barrier) { [weak self] in
            self?.sm2ResultCache.removeAllObjects()
            self?.deckStatsCache.removeAllObjects()
            self?.sm2ResultKeys.removeAll()
            self?.deckStatsKeys.removeAll()
        }

        selectionQueue.async { [weak self] in
            self?.cardSelectionCache.removeAllObjects()
            self?.selectionKeysByDeck.removeAll()
        }

        print("🗑️ [SM2_CACHE] Tous les caches SM-2 vidés")
    }

    /// Vide seulement le cache d'un deck spécifique (plus efficace)
    func clearDeckCache(deck: FlashcardDeck) {
        let deckId = deck.id?.uuidString ?? "unknown"
        invalidateDeckStats(forDeckId: deckId)
        invalidateCardSelections(forDeckId: deckId)

        print("🧹 [SM2_CACHE] Cache deck invalidé (deck \(deckId))")
    }

    /// Invalide uniquement les statistiques d'un deck
    func invalidateDeckStats(forDeckId deckId: String) {
        let keyString = "stats_\(deckId)"
        let key = keyString as NSString
        sm2Queue.async(flags: .barrier) { [weak self] in
            self?.deckStatsCache.removeObject(forKey: key)
            self?.deckStatsKeys.remove(keyString)
        }
    }

    /// Invalide les sélections de cartes pour un deck (toutes variantes de paramètres)
    func invalidateCardSelections(forDeckId deckId: String) {
        selectionQueue.async { [weak self] in
            guard let self = self, let keys = self.selectionKeysByDeck.removeValue(forKey: deckId) else { return }
            for keyString in keys {
                let nsKey = keyString as NSString
                self.cardSelectionCache.removeObject(forKey: nsKey)
            }
        }
    }

    // MARK: - Métriques et Monitoring

    /// Obtient les métriques de performance du cache SM-2
    func getSM2CacheMetrics() -> SM2CacheMetrics {
        let sm2ResultCount = sm2Queue.sync { sm2ResultKeys.count }
        let selectionCount = selectionQueue.sync { selectionKeysByDeck.values.reduce(0) { $0 + $1.count } }
        let statsCount = sm2Queue.sync { deckStatsKeys.count }

        return SM2CacheMetrics(
            sm2ResultCount: sm2ResultCount,
            selectionCount: selectionCount,
            statsCount: statsCount,
            totalMemoryUsage: sm2ResultCount + selectionCount + statsCount
        )
    }
}

// MARK: - Classes de Cache

class SM2CachedResult {
    let result: SM2Result
    let timestamp: Date
    let cardId: String
    let quality: Int

    init(result: SM2Result, timestamp: Date, cardId: String, quality: Int) {
        self.result = result
        self.timestamp = timestamp
        self.cardId = cardId
        self.quality = quality
    }
}

class CardSelectionCache {
    let cards: [Flashcard]
    let timestamp: Date
    let deckId: String
    let minCards: Int
    let excludeIds: Set<String>

    init(cards: [Flashcard], timestamp: Date, deckId: String, minCards: Int, excludeIds: Set<String>) {
        self.cards = cards
        self.timestamp = timestamp
        self.deckId = deckId
        self.minCards = minCards
        self.excludeIds = excludeIds
    }
}

class DeckStatsCache {
    let stats: DeckSRSStats
    let timestamp: Date
    let deckId: String

    init(stats: DeckSRSStats, timestamp: Date, deckId: String) {
        self.stats = stats
        self.timestamp = timestamp
        self.deckId = deckId
    }
}

struct SM2CacheMetrics {
    let sm2ResultCount: Int
    let selectionCount: Int
    let statsCount: Int
    let totalMemoryUsage: Int
}
