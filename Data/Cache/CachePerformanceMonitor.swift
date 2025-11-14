//
// CachePerformanceMonitor.swift
// PARALLAX
//
// Created by  on 7/1/25.
//

import Foundation
import os.log

class CachePerformanceMonitor {
    // MARK: - Basic Metrics

    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private var cacheWrites: Int = 0
    private var startTime = Date()

    // ✅ NOUVEAU: Advanced Metrics
    private var totalLatency: TimeInterval = 0
    private var requestCount: Int = 0
    private var cacheSize: Int = 0
    private var evictionCount: Int = 0
    private var diskHits: Int = 0
    private var diskMisses: Int = 0

    // MARK: - Performance Tracking

    private var latencyHistory: [TimeInterval] = []
    private var hitRateHistory: [Double] = []
    private let maxHistorySize = 100

    private let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "CacheMonitor")
    private let performanceQueue = DispatchQueue(label: "cache.performance", qos: .background)

    // MARK: - Recording Methods

    func recordCacheHit() {
        performanceQueue.async { [weak self] in
            guard let self = self else { return }
            self.cacheHits += 1
            self.checkPerformanceMetrics()
        }
    }

    func recordCacheMiss() {
        performanceQueue.async { [weak self] in
            guard let self = self else { return }
            self.cacheMisses += 1
            self.checkPerformanceMetrics()
        }
    }

    func recordCacheWrite() {
        performanceQueue.async { [weak self] in
            guard let self = self else { return }
            self.cacheWrites += 1
        }
    }

    // ✅ NOUVEAU: Advanced Recording Methods
    func recordLatency(_ latency: TimeInterval) {
        performanceQueue.async { [weak self] in
            guard let self = self else { return }
            self.totalLatency += latency
            self.requestCount += 1

            // Maintenir l'historique de latence
            self.latencyHistory.append(latency)
            if self.latencyHistory.count > self.maxHistorySize {
                self.latencyHistory.removeFirst()
            }

            // Alerter si latence élevée
            if latency > 0.1 { // 100ms
                self.logger.warning("⚠️ Latence élevée détectée: \(Int(latency * 1000))ms")
            }
        }
    }

    func recordEviction() {
        performanceQueue.async { [weak self] in
            guard let self = self else { return }
            self.evictionCount += 1
            self.logger.debug("🗑️ Éviction cache détectée")
        }
    }

    func updateCacheSize(_ size: Int) {
        performanceQueue.async { [weak self] in
            guard let self = self else { return }
            self.cacheSize = size
        }
    }

    func recordDiskHit() {
        performanceQueue.async { [weak self] in
            guard let self = self else { return }
            self.diskHits += 1
        }
    }

    func recordDiskMiss() {
        performanceQueue.async { [weak self] in
            guard let self = self else { return }
            self.diskMisses += 1
        }
    }

    // MARK: - Performance Analysis

    private func checkPerformanceMetrics() {
        let totalRequests = cacheHits + cacheMisses

        if totalRequests % 50 == 0, totalRequests > 0 {
            let hitRate = Double(cacheHits) / Double(totalRequests) * 100

            // Maintenir l'historique du hit rate
            hitRateHistory.append(hitRate)
            if hitRateHistory.count > maxHistorySize {
                hitRateHistory.removeFirst()
            }

            logger.info("📊 Cache Stats - Hit Rate: \(String(format: "%.1f", hitRate))%, Total: \(totalRequests)")

            // Alertes de performance
            if hitRate < 70 {
                logger.warning("⚠️ Cache hit rate below 70% - consider optimization")
            }

            if hitRate < 50 {
                logger.fault("🚨 Cache hit rate critically low: \(String(format: "%.1f", hitRate))%")
            }
        }
    }

    // MARK: - ✅ NOUVEAU: Computed Properties

    var averageLatency: TimeInterval {
        return requestCount > 0 ? totalLatency / TimeInterval(requestCount) : 0
    }

    var currentHitRate: Double {
        let totalRequests = cacheHits + cacheMisses
        return totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) * 100 : 0
    }

    var diskHitRate: Double {
        let totalDiskRequests = diskHits + diskMisses
        return totalDiskRequests > 0 ? Double(diskHits) / Double(totalDiskRequests) * 100 : 0
    }

    var evictionRate: Double {
        return cacheWrites > 0 ? Double(evictionCount) / Double(cacheWrites) * 100 : 0
    }

    var peakLatency: TimeInterval {
        return latencyHistory.max() ?? 0
    }

    var averageHitRate: Double {
        return hitRateHistory.isEmpty ? 0 : hitRateHistory.reduce(0, +) / Double(hitRateHistory.count)
    }

    // MARK: - Reporting

    func getPerformanceReport() -> String {
        return performanceQueue.sync { [weak self] in
            guard let self = self else { return "⚠️ Monitor non disponible" }

            let totalRequests = self.cacheHits + self.cacheMisses
            let hitRate = totalRequests > 0 ? Double(self.cacheHits) / Double(totalRequests) * 100 : 0
            let sessionDuration = Date().timeIntervalSince(self.startTime) / 60

            return """
            📊 Cache Performance Report:

            🎯 Hit Rates:
            - Memory Cache: \(String(format: "%.1f", hitRate))%
            - Disk Cache: \(String(format: "%.1f", self.diskHitRate))%
            - Average Session: \(String(format: "%.1f", self.averageHitRate))%

            ⚡ Performance:
            - Total Requests: \(totalRequests)
            - Cache Writes: \(self.cacheWrites)
            - Average Latency: \(String(format: "%.2f", self.averageLatency * 1000))ms
            - Peak Latency: \(String(format: "%.2f", self.peakLatency * 1000))ms

            💾 Memory:
            - Cache Size: \(ByteCountFormatter.string(fromByteCount: Int64(self.cacheSize), countStyle: .memory))
            - Evictions: \(self.evictionCount)
            - Eviction Rate: \(String(format: "%.1f", self.evictionRate))%

            ⏱️ Session:
            - Duration: \(String(format: "%.1f", sessionDuration)) min
            - Requests/min: \(String(format: "%.1f", Double(totalRequests) / sessionDuration))

            🔍 Health Status: \(self.getHealthStatus())
            """
        }
    }

    // ✅ NOUVEAU: Health Status
    private func getHealthStatus() -> String {
        let hitRate = currentHitRate
        let latency = averageLatency * 1000 // en ms

        if hitRate >= 85 && latency <= 50 {
            return "🟢 Excellent"
        } else if hitRate >= 70 && latency <= 100 {
            return "🟡 Bon"
        } else if hitRate >= 50 && latency <= 200 {
            return "🟠 Moyen"
        } else {
            return "🔴 Critique"
        }
    }

    // ✅ NOUVEAU: Performance Alerts
    func checkForPerformanceAlerts() -> [String] {
        var alerts: [String] = []

        if currentHitRate < 50 {
            alerts.append("🚨 Hit rate critique: \(String(format: "%.1f", currentHitRate))%")
        }

        if averageLatency > 0.2 {
            alerts.append("⚠️ Latence élevée: \(String(format: "%.0f", averageLatency * 1000))ms")
        }

        if evictionRate > 20 {
            alerts.append("🗑️ Trop d'évictions: \(String(format: "%.1f", evictionRate))%")
        }

        return alerts
    }

    // MARK: - Reset & Maintenance

    func resetMetrics() {
        performanceQueue.async { [weak self] in
            guard let self = self else { return }

            self.cacheHits = 0
            self.cacheMisses = 0
            self.cacheWrites = 0
            self.totalLatency = 0
            self.requestCount = 0
            self.evictionCount = 0
            self.diskHits = 0
            self.diskMisses = 0

            self.latencyHistory.removeAll()
            self.hitRateHistory.removeAll()

            self.startTime = Date()

            self.logger.info("🔄 Métriques de performance réinitialisées")
        }
    }
}
