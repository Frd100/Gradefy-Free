//
// GradefyCacheManager.swift
// PARALLAX
//
// Created by  on 7/1/25.
//

import Foundation
import UIKit
import os.log

class GradefyCacheManager: ObservableObject {
    static let shared = GradefyCacheManager()
    
    // MARK: - Cache Hiérarchique
    private let memoryCache = NSCache<NSString, AnyObject>()
    private let calculationCache = NSCache<NSString, NSNumber>()
    private let assetCache = NSCache<NSString, AnyObject>()
    
    // ✅ NOUVEAU: Cache persistant sur disque
    private let diskCache = NSCache<NSString, NSData>()
    private let diskCacheURL: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("GradefyCache")
    }()
    
    // MARK: - Performance Monitoring
    private let monitor = CachePerformanceMonitor()
    private let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "Cache")
    
    // MARK: - Cache Queues
    private let cacheQueue = DispatchQueue(label: "gradefy.cache", qos: .userInitiated)
    private let diskQueue = DispatchQueue(label: "gradefy.disk.cache", qos: .utility)
    
    private init() {
        print("🚀 [GRADEFY_CACHE] === INITIALISATION DÉBUT ===")
        setupCaches()
        setupMemoryWarnings()
        loadCriticalDataFromDisk()
        print("🚀 [GRADEFY_CACHE] === INITIALISATION TERMINÉE ===")
    }
    
    private func setupCaches() {
        print("⚙️ [GRADEFY_CACHE] Configuration des caches...")
        
        let config = AdaptiveCacheConfiguration.configureForDevice()
        print("⚙️ [GRADEFY_CACHE] Configuration appareil: \(config.countLimit) objets, \(config.costLimit/1024/1024)MB")
        
        // Cache mémoire principal
        memoryCache.countLimit = config.countLimit
        memoryCache.totalCostLimit = config.costLimit
        print("✅ [GRADEFY_CACHE] Cache mémoire: limit=\(config.countLimit), cost=\(config.costLimit/1024/1024)MB")
        
        // Cache calculs
        calculationCache.countLimit = 200
        calculationCache.totalCostLimit = 2 * 1024 * 1024 // 2MB
        print("✅ [GRADEFY_CACHE] Cache calculs: limit=200, cost=2MB")
        
        // Cache assets
        assetCache.countLimit = 100
        assetCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
        print("✅ [GRADEFY_CACHE] Cache assets: limit=100, cost=10MB")
        
        // ✅ NOUVEAU: Setup disk cache
        diskCache.countLimit = 500
        diskCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        print("✅ [GRADEFY_CACHE] Cache disque: limit=500, cost=100MB")
        
        // Créer le dossier de cache disque
        do {
            try FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
            print("📁 [GRADEFY_CACHE] Dossier cache créé: \(diskCacheURL.path)")
        } catch {
            print("❌ [GRADEFY_CACHE] Erreur création dossier: \(error.localizedDescription)")
        }
        
        logger.info("🗄️ GradefyCacheManager initialisé - Limites: \(config.countLimit) objets, \(config.costLimit/1024/1024)MB")
    }
    
    private func setupMemoryWarnings() {
        print("🔔 [GRADEFY_CACHE] Configuration surveillance mémoire...")
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        
        print("✅ [GRADEFY_CACHE] Surveillance mémoire activée")
    }
    
    private func handleMemoryWarning() {
        print("⚠️ [GRADEFY_CACHE] === ALERTE MÉMOIRE REÇUE ===")
        
        let beforeAssets = assetCache.totalCostLimit
        let beforeCalculations = calculationCache.totalCostLimit
        
        logger.warning("⚠️ Memory warning - clearing non-essential caches")
        
        // Sauvegarder les données critiques avant nettoyage
        print("💾 [GRADEFY_CACHE] Sauvegarde données critiques avant nettoyage...")
        saveCriticalDataToDisk()
        
        // Nettoyer le cache des assets
        assetCache.removeAllObjects()
        print("🧹 [GRADEFY_CACHE] Cache assets vidé: \(beforeAssets/1024/1024)MB libérés")
        
        // Garder le cache de calculs car plus critique
        print("✅ [GRADEFY_CACHE] Cache calculs préservé: \(beforeCalculations/1024/1024)MB")
        
        print("✅ [GRADEFY_CACHE] === ALERTE MÉMOIRE TRAITÉE ===")
    }
    
    // MARK: - ✅ NOUVEAU: Disk Cache Methods
    private func saveToDisk(key: String, data: Data) {
        print("💾 [GRADEFY_CACHE] SAVE_TO_DISK_REQUEST: '\(key)' (\(data.count) bytes)")
        
        diskQueue.async { [weak self] in
            guard let self = self else {
                print("❌ [GRADEFY_CACHE] SAVE_TO_DISK_FAILED: self is nil")
                return
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let url = self.diskCacheURL.appendingPathComponent(key)
            
            do {
                try data.write(to: url)
                self.diskCache.setObject(data as NSData, forKey: key as NSString)
                self.monitor.recordCacheWrite()
                
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                print("✅ [GRADEFY_CACHE] SAVE_TO_DISK_SUCCESS: '\(key)' (\(String(format: "%.3f", duration * 1000))ms)")
            } catch {
                print("❌ [GRADEFY_CACHE] SAVE_TO_DISK_ERROR: '\(key)' - \(error.localizedDescription)")
            }
        }
    }
    
    private func loadFromDisk(key: String) -> Data? {
        print("📂 [GRADEFY_CACHE] LOAD_FROM_DISK_REQUEST: '\(key)'")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Vérifier le cache mémoire d'abord
        if let cached = diskCache.object(forKey: key as NSString) {
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            let data = cached as Data
            print("🟢 [GRADEFY_CACHE] DISK_MEMORY_HIT: '\(key)' (\(data.count) bytes, \(String(format: "%.3f", latency * 1000))ms)")
            monitor.recordLatency(latency)
            monitor.recordCacheHit()
            return data
        }
        
        // Charger depuis le disque
        let url = diskCacheURL.appendingPathComponent(key)
        
        do {
            let data = try Data(contentsOf: url)
            
            // Mettre en cache mémoire et retourner
            diskCache.setObject(data as NSData, forKey: key as NSString)
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            print("🟡 [GRADEFY_CACHE] DISK_FILE_HIT: '\(key)' (\(data.count) bytes, \(String(format: "%.3f", latency * 1000))ms)")
            monitor.recordLatency(latency)
            monitor.recordCacheHit()
            return data
        } catch {
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            print("🔴 [GRADEFY_CACHE] DISK_MISS: '\(key)' (\(String(format: "%.3f", latency * 1000))ms) - \(error.localizedDescription)")
            monitor.recordCacheMiss()
            return nil
        }
    }
    
    private func saveCriticalDataToDisk() {
        print("💾 [GRADEFY_CACHE] === SAUVEGARDE CRITIQUE DÉBUT ===")
        
        diskQueue.async { [weak self] in
            guard let self = self else {
                print("❌ [GRADEFY_CACHE] SAVE_CRITICAL_FAILED: self is nil")
                return
            }
            
            // Sauvegarder les moyennes critiques
            let criticalKeys = ["current_semester_average", "overall_average", "subject_averages"]
            var savedCount = 0
            
            for key in criticalKeys {
                if let value = self.calculationCache.object(forKey: key as NSString) {
                    do {
                        let data = try JSONEncoder().encode(value.doubleValue)
                        self.saveToDisk(key: key, data: data)
                        savedCount += 1
                        print("💾 [GRADEFY_CACHE] CRITICAL_SAVED: '\(key)' = \(value.doubleValue)")
                    } catch {
                        print("❌ [GRADEFY_CACHE] CRITICAL_SAVE_ERROR: '\(key)' - \(error.localizedDescription)")
                    }
                } else {
                    print("⚠️ [GRADEFY_CACHE] CRITICAL_NOT_FOUND: '\(key)'")
                }
            }
            
            print("✅ [GRADEFY_CACHE] === SAUVEGARDE CRITIQUE TERMINÉE: \(savedCount)/\(criticalKeys.count) ===")
            self.logger.debug("💾 Données critiques sauvegardées sur disque")
        }
    }
    
    private func loadCriticalDataFromDisk() {
        print("📂 [GRADEFY_CACHE] === CHARGEMENT CRITIQUE DÉBUT ===")
        
        diskQueue.async { [weak self] in
            guard let self = self else {
                print("❌ [GRADEFY_CACHE] LOAD_CRITICAL_FAILED: self is nil")
                return
            }
            
            let criticalKeys = ["current_semester_average", "overall_average", "subject_averages"]
            var loadedCount = 0
            
            for key in criticalKeys {
                if let data = self.loadFromDisk(key: key) {
                    do {
                        let value = try JSONDecoder().decode(Double.self, from: data)
                        self.calculationCache.setObject(NSNumber(value: value), forKey: key as NSString)
                        loadedCount += 1
                        print("📂 [GRADEFY_CACHE] CRITICAL_LOADED: '\(key)' = \(value)")
                    } catch {
                        print("❌ [GRADEFY_CACHE] CRITICAL_DECODE_ERROR: '\(key)' - \(error.localizedDescription)")
                    }
                } else {
                    print("⚠️ [GRADEFY_CACHE] CRITICAL_DISK_MISS: '\(key)'")
                }
            }
            
            print("✅ [GRADEFY_CACHE] === CHARGEMENT CRITIQUE TERMINÉ: \(loadedCount)/\(criticalKeys.count) ===")
            self.logger.debug("📂 Données critiques chargées depuis le disque")
        }
    }
    
    // MARK: - Public API
    func cacheAverage(_ value: Double, forKey key: String) {
        print("💾 [GRADEFY_CACHE] CACHE_AVERAGE_REQUEST: '\(key)' = \(value)")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        calculationCache.setObject(NSNumber(value: value), forKey: key as NSString)
        monitor.recordCacheWrite()
        
        print("✅ [GRADEFY_CACHE] CACHE_AVERAGE_MEMORY_DONE: '\(key)' = \(value)")
        
        // ✅ NOUVEAU: Sauvegarder automatiquement les données importantes
        if key.contains("average") || key.contains("grade") {
            print("💾 [GRADEFY_CACHE] IMPORTANT_DATA_DETECTED: '\(key)' - saving to disk")
            do {
                let data = try JSONEncoder().encode(value)
                saveToDisk(key: key, data: data)
                print("✅ [GRADEFY_CACHE] DISK_SAVE_QUEUED: '\(key)'")
            } catch {
                print("❌ [GRADEFY_CACHE] ENCODE_ERROR: '\(key)' - \(error.localizedDescription)")
            }
        }
        
        let latency = CFAbsoluteTimeGetCurrent() - startTime
        monitor.recordLatency(latency)
        monitor.updateCacheSize(calculationCache.totalCostLimit)
        
        print("📊 [GRADEFY_CACHE] CACHE_AVERAGE_COMPLETE: '\(key)' (\(String(format: "%.3f", latency * 1000))ms)")
        logger.debug("📊 Moyenne cachée: \(key) = \(value)")
    }
    
    func getCachedAverage(forKey key: String) -> Double? {
        print("🔍 [GRADEFY_CACHE] GET_AVERAGE_REQUEST: '\(key)'")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Vérifier cache mémoire d'abord
        if let cached = calculationCache.object(forKey: key as NSString) {
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            let value = cached.doubleValue
            print("🟢 [GRADEFY_CACHE] MEMORY_HIT: '\(key)' = \(value) (\(String(format: "%.3f", latency * 1000))ms)")
            monitor.recordLatency(latency)
            monitor.recordCacheHit()
            return value
        }
        
        print("🔍 [GRADEFY_CACHE] MEMORY_MISS: '\(key)' - trying disk...")
        
        // ✅ NOUVEAU: Essayer de charger depuis le disque
        if let data = loadFromDisk(key: key) {
            do {
                let value = try JSONDecoder().decode(Double.self, from: data)
                // Remettre en cache mémoire
                calculationCache.setObject(NSNumber(value: value), forKey: key as NSString)
                let latency = CFAbsoluteTimeGetCurrent() - startTime
                print("🟡 [GRADEFY_CACHE] DISK_HIT_RESTORED: '\(key)' = \(value) (\(String(format: "%.3f", latency * 1000))ms)")
                return value
            } catch {
                print("❌ [GRADEFY_CACHE] DISK_DECODE_ERROR: '\(key)' - \(error.localizedDescription)")
            }
        }
        
        let latency = CFAbsoluteTimeGetCurrent() - startTime
        print("🔴 [GRADEFY_CACHE] COMPLETE_MISS: '\(key)' (\(String(format: "%.3f", latency * 1000))ms)")
        monitor.recordCacheMiss()
        return nil
    }
    
    func cacheObject(_ object: AnyObject, forKey key: String) {
        print("💾 [GRADEFY_CACHE] CACHE_OBJECT_REQUEST: '\(key)' (type: \(type(of: object)))")
        
        memoryCache.setObject(object, forKey: key as NSString)
        monitor.recordCacheWrite()
        
        print("✅ [GRADEFY_CACHE] CACHE_OBJECT_DONE: '\(key)'")
    }
    
    func getCachedObject(forKey key: String) -> AnyObject? {
        print("🔍 [GRADEFY_CACHE] GET_OBJECT_REQUEST: '\(key)'")
        
        if let cached = memoryCache.object(forKey: key as NSString) {
            monitor.recordCacheHit()
            print("🟢 [GRADEFY_CACHE] OBJECT_HIT: '\(key)' (type: \(type(of: cached)))")
            return cached
        }
        
        monitor.recordCacheMiss()
        print("🔴 [GRADEFY_CACHE] OBJECT_MISS: '\(key)'")
        return nil
    }
    
    func clearAllCaches() {
        print("🧹 [GRADEFY_CACHE] === CLEAR_ALL_DÉBUT ===")
        
        let beforeMemory = memoryCache.totalCostLimit
        let beforeCalc = calculationCache.totalCostLimit
        let beforeAsset = assetCache.totalCostLimit
        let beforeDisk = diskCache.totalCostLimit
        
        print("🧹 [GRADEFY_CACHE] AVANT CLEAR:")
        print("🧹 [GRADEFY_CACHE]   Memory: \(beforeMemory / 1024 / 1024)MB")
        print("🧹 [GRADEFY_CACHE]   Calc: \(beforeCalc / 1024 / 1024)MB")
        print("🧹 [GRADEFY_CACHE]   Asset: \(beforeAsset / 1024 / 1024)MB")
        print("🧹 [GRADEFY_CACHE]   Disk: \(beforeDisk / 1024 / 1024)MB")
        
        memoryCache.removeAllObjects()
        calculationCache.removeAllObjects()
        assetCache.removeAllObjects()
        diskCache.removeAllObjects()
        
        print("✅ [GRADEFY_CACHE] Caches mémoire vidés")
        
        // ✅ NOUVEAU: Nettoyer aussi le disque
        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil)
            
            for fileURL in files {
                try fileManager.removeItem(at: fileURL)
            }
            
            print("🧹 [GRADEFY_CACHE] Cache disque vidé: \(files.count) fichiers supprimés")
        } catch {
            print("❌ [GRADEFY_CACHE] Erreur nettoyage disque: \(error.localizedDescription)")
            
            // ✅ CORRECTION : Fallback asynchrone pour éviter le hang
            diskQueue.async { [weak self] in
                guard let self = self else { return }
                do {
                    try FileManager.default.removeItem(at: self.diskCacheURL)
                    try FileManager.default.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)
                    print("🔄 [GRADEFY_CACHE] Dossier cache recréé")
                } catch {
                    print("❌ [GRADEFY_CACHE] Erreur recréation dossier: \(error.localizedDescription)")
                }
            }
        }
        
        print("🧹 [GRADEFY_CACHE] APRÈS CLEAR: Tous à 0")
        print("🧹 [GRADEFY_CACHE] === CLEAR_ALL_TERMINÉ ===")
        
        logger.info("🗑️ Tous les caches vidés (mémoire + disque)")
    }
    
    // ✅ NOUVEAU: Méthodes d'analyse
    func getCacheStatistics() -> String {
        return monitor.getPerformanceReport()
    }
    
    func printCacheStats() {
        print("📊 [GRADEFY_CACHE] === STATISTIQUES COMPLÈTES ===")
        
        // Informations sur les limites
        print("📊 [GRADEFY_CACHE] Limites configurées:")
        print("📊 [GRADEFY_CACHE]   Memory: \(memoryCache.countLimit) objets, \(memoryCache.totalCostLimit / 1024 / 1024)MB")
        print("📊 [GRADEFY_CACHE]   Calculation: \(calculationCache.countLimit) objets, \(calculationCache.totalCostLimit / 1024 / 1024)MB")
        print("📊 [GRADEFY_CACHE]   Asset: \(assetCache.countLimit) objets, \(assetCache.totalCostLimit / 1024 / 1024)MB")
        print("📊 [GRADEFY_CACHE]   Disk: \(diskCache.countLimit) objets, \(diskCache.totalCostLimit / 1024 / 1024)MB")
        
        // ✅ CORRECTION : Informations sur le disque de manière asynchrone
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let files = try FileManager.default.contentsOfDirectory(at: self.diskCacheURL, includingPropertiesForKeys: [.fileSizeKey])
                var totalDiskSize: Int64 = 0
                
                for fileURL in files {
                    if let resources = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resources.fileSize {
                        totalDiskSize += Int64(fileSize)
                    }
                }
                
                DispatchQueue.main.async {
                    print("📊 [GRADEFY_CACHE] État disque:")
                    print("📊 [GRADEFY_CACHE]   Fichiers: \(files.count)")
                    print("📊 [GRADEFY_CACHE]   Taille totale: \(totalDiskSize / 1024 / 1024)MB")
                    print("📊 [GRADEFY_CACHE]   Dossier: \(self.diskCacheURL.path)")
                }
            } catch {
                DispatchQueue.main.async {
                    print("⚠️ [GRADEFY_CACHE] Erreur lecture disque: \(error.localizedDescription)")
                }
            }
        }
        
        // Statistiques de performance
        let perfReport = monitor.getPerformanceReport()
        print("📊 [GRADEFY_CACHE] Performance:")
        print("📊 [GRADEFY_CACHE]   \(perfReport)")
        
        print("📊 [GRADEFY_CACHE] === FIN STATISTIQUES ===")
    }
    
    // ✅ NOUVEAU : Méthode d'invalidation spécifique
    func invalidateObject(key: String) {
        print("🗑️ [GRADEFY_CACHE] INVALIDATE_OBJECT: '\(key)'")
        
        memoryCache.removeObject(forKey: key as NSString)
        calculationCache.removeObject(forKey: key as NSString)
        assetCache.removeObject(forKey: key as NSString)
        diskCache.removeObject(forKey: key as NSString)
        
        // ✅ CORRECTION : Déplacer l'I/O vers un thread en arrière-plan
        let diskFile = diskCacheURL.appendingPathComponent(key)
        diskQueue.async {
            do {
                try FileManager.default.removeItem(at: diskFile)
                print("✅ [GRADEFY_CACHE] FICHIER_SUPPRIMÉ: '\(key)'")
            } catch {
                print("⚠️ [GRADEFY_CACHE] ERREUR_SUPPRESSION: '\(key)' - \(error)")
            }
        }
        
        print("✅ [GRADEFY_CACHE] INVALIDATE_OBJECT_DONE: '\(key)' (all caches)")
    }
    
    func prefetchImportantData() {
        print("🔮 [GRADEFY_CACHE] === PREFETCH DÉBUT ===")
        
        diskQueue.async { [weak self] in
            guard let self = self else {
                print("❌ [GRADEFY_CACHE] PREFETCH_FAILED: self is nil")
                return
            }
            
            // Précharger les données probablement nécessaires
            let importantKeys = ["current_semester_average", "overall_average", "recent_grades"]
            var prefetchedCount = 0
            
            for key in importantKeys {
                print("🔮 [GRADEFY_CACHE] PREFETCH_TRY: '\(key)'")
                
                if self.getCachedAverage(forKey: key) != nil {
                    prefetchedCount += 1
                    print("✅ [GRADEFY_CACHE] PREFETCH_SUCCESS: '\(key)'")
                } else {
                    print("⚠️ [GRADEFY_CACHE] PREFETCH_MISS: '\(key)'")
                }
                
                self.logger.debug("🔮 Prefetch tenté pour: \(key)")
            }
            
            print("🔮 [GRADEFY_CACHE] === PREFETCH TERMINÉ: \(prefetchedCount)/\(importantKeys.count) ===")
        }
    }
    
    // ✅ NOUVEAU : Test complet du cache
    func performCacheTest() {
        print("🧪 [GRADEFY_CACHE] === DÉBUT TEST CACHE ===")
        
        // Test 1: Cache et récupération moyennes
        print("🧪 [GRADEFY_CACHE] Test 1: Cache moyennes")
        cacheAverage(15.5, forKey: "test_math_average")
        cacheAverage(17.2, forKey: "test_french_average")
        
        // Test 2: Cache objets
        print("🧪 [GRADEFY_CACHE] Test 2: Cache objets")
        let testString = "Test Object" as NSString
        cacheObject(testString, forKey: "test_object")
        
        // Test 3: Récupération
        print("🧪 [GRADEFY_CACHE] Test 3: Récupération")
        let mathResult = getCachedAverage(forKey: "test_math_average")
        let frenchResult = getCachedAverage(forKey: "test_french_average")
        let objectResult = getCachedObject(forKey: "test_object")
        let missResult = getCachedAverage(forKey: "test_nonexistent")
        
        print("🧪 [GRADEFY_CACHE] Résultats récupération:")
        print("🧪 [GRADEFY_CACHE]   - Math: \(mathResult?.description ?? "nil")")
        print("🧪 [GRADEFY_CACHE]   - French: \(frenchResult?.description ?? "nil")")
        print("🧪 [GRADEFY_CACHE]   - Object: \(objectResult?.description ?? "nil")")
        print("🧪 [GRADEFY_CACHE]   - Miss: \(missResult?.description ?? "nil")")
        
        // Test 4: État du cache
        print("🧪 [GRADEFY_CACHE] Test 4: État du cache")
        printCacheStats()
        
        // Test 5: Invalidation
        print("🧪 [GRADEFY_CACHE] Test 5: Invalidation")
        invalidateObject(key: "test_math_average")
        
        // Test 6: Clear
        print("🧪 [GRADEFY_CACHE] Test 6: Clear complet")
        clearAllCaches()
        
        print("🧪 [GRADEFY_CACHE] === FIN TEST CACHE ===")
    }
    
    deinit {
        print("💀 [GRADEFY_CACHE] === DESTRUCTION ===")
        
        // Sauvegarder les données critiques avant destruction
        saveCriticalDataToDisk()
        NotificationCenter.default.removeObserver(self)
        
        print("✅ [GRADEFY_CACHE] === DESTRUCTION TERMINÉE ===")
    }
}
