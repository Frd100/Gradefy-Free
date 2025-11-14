//
// SM2PerformanceMonitor.swift
// PARALLAX
//
// Created by Claude on 8/14/25.
//

import Foundation
import os.log

/// Moniteur de performance spécialisé pour les opérations SM-2
/// S'intègre avec CachePerformanceMonitor existant
class SM2PerformanceMonitor {
    static let shared = SM2PerformanceMonitor()

    // MARK: - Intégration avec le système existant

    private let cacheMonitor = CachePerformanceMonitor()

    // MARK: - Métriques SM-2 Spécifiques

    private var sm2Calculations: Int = 0
    private var sm2CacheHits: Int = 0
    private var sm2CacheMisses: Int = 0
    private var sm2TotalLatency: TimeInterval = 0
    private var sm2OperationCount: Int = 0

    // MARK: - Métriques de Sélection

    private var cardSelectionCount: Int = 0
    private var cardSelectionLatency: TimeInterval = 0
    private var cardSelectionCacheHits: Int = 0
    private var cardSelectionCacheMisses: Int = 0

    // MARK: - Métriques de Statistiques

    private var statsCalculationCount: Int = 0
    private var statsCalculationLatency: TimeInterval = 0
    private var statsCacheHits: Int = 0
    private var statsCacheMisses: Int = 0

    // MARK: - Métriques de Batch

    private var batchOperationCount: Int = 0
    private var batchOperationLatency: TimeInterval = 0
    private var batchSizeHistory: [Int] = []

    // MARK: - Historique de Performance

    private var performanceHistory: [SM2PerformanceSnapshot] = []
    private let maxHistorySize = 100

    // MARK: - Queues

    private let metricsQueue = DispatchQueue(label: "sm2.metrics", qos: .background)
    private let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "SM2Monitor")

    private init() {
        print("🚀 [SM2_MONITOR] Moniteur de performance SM-2 initialisé")
        startPeriodicReporting()
    }

    // MARK: - Métriques SM-2

    /// Enregistre un calcul SM-2
    func recordSM2Calculation(latency: TimeInterval, cacheHit: Bool) {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }

            self.sm2Calculations += 1
            self.sm2TotalLatency += latency
            self.sm2OperationCount += 1

            if cacheHit {
                self.sm2CacheHits += 1
            } else {
                self.sm2CacheMisses += 1
            }

            // Alerter si latence élevée
            if latency > 0.05 { // 50ms
                self.logger.warning("⚠️ Latence SM-2 élevée: \(Int(latency * 1000))ms")
            }

            self.checkPerformanceThresholds()
        }
    }

    /// Enregistre une sélection de cartes
    func recordCardSelection(latency: TimeInterval, cardCount: Int, cacheHit: Bool) {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }

            self.cardSelectionCount += 1
            self.cardSelectionLatency += latency

            if cacheHit {
                self.cardSelectionCacheHits += 1
            } else {
                self.cardSelectionCacheMisses += 1
            }

            // Alerter si latence élevée
            if latency > 0.1 { // 100ms
                self.logger.warning("⚠️ Latence sélection élevée: \(Int(latency * 1000))ms pour \(cardCount) cartes")
            }
        }
    }

    /// Enregistre un calcul de statistiques
    func recordStatsCalculation(latency: TimeInterval, cacheHit: Bool) {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }

            self.statsCalculationCount += 1
            self.statsCalculationLatency += latency

            if cacheHit {
                self.statsCacheHits += 1
            } else {
                self.statsCacheMisses += 1
            }

            // Alerter si latence élevée
            if latency > 0.2 { // 200ms
                self.logger.warning("⚠️ Latence stats élevée: \(Int(latency * 1000))ms")
            }
        }
    }

    /// Enregistre une opération batch
    func recordBatchOperation(latency: TimeInterval, batchSize: Int) {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }

            self.batchOperationCount += 1
            self.batchOperationLatency += latency
            self.batchSizeHistory.append(batchSize)

            // Garder seulement les 50 dernières tailles de batch
            if self.batchSizeHistory.count > 50 {
                self.batchSizeHistory.removeFirst()
            }

            // Alerter si latence élevée
            if latency > 0.5 { // 500ms
                self.logger.warning("⚠️ Latence batch élevée: \(Int(latency * 1000))ms pour \(batchSize) cartes")
            }
        }
    }

    // MARK: - Vérifications de Performance

    private func checkPerformanceThresholds() {
        // Vérifier le taux de cache hit
        let totalSM2Operations = sm2CacheHits + sm2CacheMisses
        if totalSM2Operations > 0 {
            let hitRate = Double(sm2CacheHits) / Double(totalSM2Operations)
            if hitRate < 0.7 { // Moins de 70% de cache hit
                logger.warning("⚠️ Taux de cache hit SM-2 faible: \(Int(hitRate * 100))%")
            }
        }

        // Vérifier la latence moyenne
        if sm2OperationCount > 0 {
            let averageLatency = sm2TotalLatency / Double(sm2OperationCount)
            if averageLatency > 0.03 { // Plus de 30ms en moyenne
                logger.warning("⚠️ Latence moyenne SM-2 élevée: \(Int(averageLatency * 1000))ms")
            }
        }
    }

    // MARK: - Rapports de Performance

    private func startPeriodicReporting() {
        // Rapport toutes les 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.generatePerformanceReport()
        }
    }

    private func generatePerformanceReport() {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }

            let snapshot = self.createPerformanceSnapshot()
            self.performanceHistory.append(snapshot)

            // Garder seulement les 100 derniers snapshots
            if self.performanceHistory.count > self.maxHistorySize {
                self.performanceHistory.removeFirst()
            }

            self.logPerformanceReport(snapshot)
        }
    }

    private func createPerformanceSnapshot() -> SM2PerformanceSnapshot {
        let sm2HitRate = sm2OperationCount > 0 ? Double(sm2CacheHits) / Double(sm2CacheHits + sm2CacheMisses) : 0
        let sm2AverageLatency = sm2OperationCount > 0 ? sm2TotalLatency / Double(sm2OperationCount) : 0

        let selectionHitRate = (cardSelectionCacheHits + cardSelectionCacheMisses) > 0 ?
            Double(cardSelectionCacheHits) / Double(cardSelectionCacheHits + cardSelectionCacheMisses) : 0
        let selectionAverageLatency = cardSelectionCount > 0 ? cardSelectionLatency / Double(cardSelectionCount) : 0

        let statsHitRate = (statsCacheHits + statsCacheMisses) > 0 ?
            Double(statsCacheHits) / Double(statsCacheHits + statsCacheMisses) : 0
        let statsAverageLatency = statsCalculationCount > 0 ? statsCalculationLatency / Double(statsCalculationCount) : 0

        let batchAverageLatency = batchOperationCount > 0 ? batchOperationLatency / Double(batchOperationCount) : 0
        let averageBatchSize = batchSizeHistory.isEmpty ? 0 : batchSizeHistory.reduce(0, +) / batchSizeHistory.count

        return SM2PerformanceSnapshot(
            timestamp: Date(),
            sm2Calculations: sm2Calculations,
            sm2HitRate: sm2HitRate,
            sm2AverageLatency: sm2AverageLatency,
            cardSelections: cardSelectionCount,
            selectionHitRate: selectionHitRate,
            selectionAverageLatency: selectionAverageLatency,
            statsCalculations: statsCalculationCount,
            statsHitRate: statsHitRate,
            statsAverageLatency: statsAverageLatency,
            batchOperations: batchOperationCount,
            batchAverageLatency: batchAverageLatency,
            averageBatchSize: averageBatchSize
        )
    }

    private func logPerformanceReport(_ snapshot: SM2PerformanceSnapshot) {
        print("📊 [SM2_MONITOR] === RAPPORT DE PERFORMANCE SM-2 ===")
        print("📊 [SM2_MONITOR] Calculs SM-2: \(snapshot.sm2Calculations) (hit rate: \(Int(snapshot.sm2HitRate * 100))%, latence: \(Int(snapshot.sm2AverageLatency * 1000))ms)")
        print("📊 [SM2_MONITOR] Sélections: \(snapshot.cardSelections) (hit rate: \(Int(snapshot.selectionHitRate * 100))%, latence: \(Int(snapshot.selectionAverageLatency * 1000))ms)")
        print("📊 [SM2_MONITOR] Statistiques: \(snapshot.statsCalculations) (hit rate: \(Int(snapshot.statsHitRate * 100))%, latence: \(Int(snapshot.statsAverageLatency * 1000))ms)")
        print("📊 [SM2_MONITOR] Batch: \(snapshot.batchOperations) (latence: \(Int(snapshot.batchAverageLatency * 1000))ms, taille moy: \(snapshot.averageBatchSize))")
        print("📊 [SM2_MONITOR] ======================================")

        // Log structuré pour analytics
        logger.info("📊 Performance SM-2 - SM2: \(snapshot.sm2Calculations) ops, \(Int(snapshot.sm2HitRate * 100))% hit, \(Int(snapshot.sm2AverageLatency * 1000))ms avg")
    }

    // MARK: - API Publique

    /// Obtient les métriques actuelles de performance SM-2
    func getCurrentMetrics() -> SM2PerformanceMetrics {
        return metricsQueue.sync {
            let sm2HitRate = sm2OperationCount > 0 ? Double(sm2CacheHits) / Double(sm2CacheHits + sm2CacheMisses) : 0
            let sm2AverageLatency = sm2OperationCount > 0 ? sm2TotalLatency / Double(sm2OperationCount) : 0

            let selectionHitRate = (cardSelectionCacheHits + cardSelectionCacheMisses) > 0 ?
                Double(cardSelectionCacheHits) / Double(cardSelectionCacheHits + cardSelectionCacheMisses) : 0
            let selectionAverageLatency = cardSelectionCount > 0 ? cardSelectionLatency / Double(cardSelectionCount) : 0

            let statsHitRate = (statsCacheHits + statsCacheMisses) > 0 ?
                Double(statsCacheHits) / Double(statsCacheHits + statsCacheMisses) : 0
            let statsAverageLatency = statsCalculationCount > 0 ? statsCalculationLatency / Double(statsCalculationCount) : 0

            let batchAverageLatency = batchOperationCount > 0 ? batchOperationLatency / Double(batchOperationCount) : 0
            let averageBatchSize = batchSizeHistory.isEmpty ? 0 : batchSizeHistory.reduce(0, +) / batchSizeHistory.count

            return SM2PerformanceMetrics(
                sm2Calculations: sm2Calculations,
                sm2HitRate: sm2HitRate,
                sm2AverageLatency: sm2AverageLatency,
                cardSelections: cardSelectionCount,
                selectionHitRate: selectionHitRate,
                selectionAverageLatency: selectionAverageLatency,
                statsCalculations: statsCalculationCount,
                statsHitRate: statsHitRate,
                statsAverageLatency: statsAverageLatency,
                batchOperations: batchOperationCount,
                batchAverageLatency: batchAverageLatency,
                averageBatchSize: averageBatchSize,
                performanceHistory: performanceHistory
            )
        }
    }

    /// Réinitialise toutes les métriques
    func resetMetrics() {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }

            self.sm2Calculations = 0
            self.sm2CacheHits = 0
            self.sm2CacheMisses = 0
            self.sm2TotalLatency = 0
            self.sm2OperationCount = 0

            self.cardSelectionCount = 0
            self.cardSelectionLatency = 0
            self.cardSelectionCacheHits = 0
            self.cardSelectionCacheMisses = 0

            self.statsCalculationCount = 0
            self.statsCalculationLatency = 0
            self.statsCacheHits = 0
            self.statsCacheMisses = 0

            self.batchOperationCount = 0
            self.batchOperationLatency = 0
            self.batchSizeHistory.removeAll()

            self.performanceHistory.removeAll()

            print("🔄 [SM2_MONITOR] Toutes les métriques réinitialisées")
        }
    }

    /// Force la génération d'un rapport de performance
    func forcePerformanceReport() {
        generatePerformanceReport()
    }
}

// MARK: - Structures de Métriques

struct SM2PerformanceSnapshot {
    let timestamp: Date
    let sm2Calculations: Int
    let sm2HitRate: Double
    let sm2AverageLatency: TimeInterval
    let cardSelections: Int
    let selectionHitRate: Double
    let selectionAverageLatency: TimeInterval
    let statsCalculations: Int
    let statsHitRate: Double
    let statsAverageLatency: TimeInterval
    let batchOperations: Int
    let batchAverageLatency: TimeInterval
    let averageBatchSize: Int
}

struct SM2PerformanceMetrics {
    let sm2Calculations: Int
    let sm2HitRate: Double
    let sm2AverageLatency: TimeInterval
    let cardSelections: Int
    let selectionHitRate: Double
    let selectionAverageLatency: TimeInterval
    let statsCalculations: Int
    let statsHitRate: Double
    let statsAverageLatency: TimeInterval
    let batchOperations: Int
    let batchAverageLatency: TimeInterval
    let averageBatchSize: Int
    let performanceHistory: [SM2PerformanceSnapshot]
}
