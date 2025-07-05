//
//  GradefyCacheManager.swift
//  PARALLAX
//
//  Created by Farid on 7/1/25.
//


import Foundation
import UIKit  // ✅ AJOUTER CETTE LIGNE
import os.log

class GradefyCacheManager: ObservableObject {
    static let shared = GradefyCacheManager()
    
    // MARK: - Cache Hiérarchique
    private let memoryCache = NSCache<NSString, NSData>()
    private let calculationCache = NSCache<NSString, NSNumber>()
    private let assetCache = NSCache<NSString, UIImage>()
    
    // MARK: - Performance Monitoring
    private let monitor = CachePerformanceMonitor()
    private let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "Cache")
    
    // MARK: - Cache Queues
    private let cacheQueue = DispatchQueue(label: "gradefy.cache", qos: .userInitiated)
    private let diskQueue = DispatchQueue(label: "gradefy.disk.cache", qos: .utility)
    
    private init() {
        setupCaches()
        setupMemoryWarnings()
    }
    
    private func setupCaches() {
        let config = AdaptiveCacheConfiguration.configureForDevice()
        
        // Cache mémoire principal
        memoryCache.countLimit = config.countLimit
        memoryCache.totalCostLimit = config.costLimit
        
        // Cache calculs
        calculationCache.countLimit = 200
        calculationCache.totalCostLimit = 2 * 1024 * 1024 // 2MB
        
        // Cache assets
        assetCache.countLimit = 100
        assetCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
        
        logger.info("🗄️ GradefyCacheManager initialisé - Limites: \(config.countLimit) objets, \(config.costLimit/1024/1024)MB")
    }
    
    private func setupMemoryWarnings() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        logger.warning("⚠️ Memory warning - clearing non-essential caches")
        assetCache.removeAllObjects()
        // Garder le cache de calculs car plus critique
    }
    
    // MARK: - Public API
    func cacheAverage(_ value: Double, forKey key: String) {
        monitor.recordCacheWrite()
        calculationCache.setObject(NSNumber(value: value), forKey: key as NSString)
    }
    
    func getCachedAverage(forKey key: String) -> Double? {
        if let cached = calculationCache.object(forKey: key as NSString) {
            monitor.recordCacheHit()
            return cached.doubleValue
        }
        monitor.recordCacheMiss()
        return nil
    }
    
    func clearAllCaches() {
        memoryCache.removeAllObjects()
        calculationCache.removeAllObjects()
        assetCache.removeAllObjects()
        logger.info("🗑️ Tous les caches vidés")
    }
}
