import CoreData
import Foundation
import os.log

class SmartAverageCache {
    // ✅ AJOUTER : Singleton pattern
    static let shared = SmartAverageCache()

    private let cache = NSCache<NSString, CachedAverage>()
    private let cacheQueue = DispatchQueue(label: "gradefy.average.cache", qos: .userInitiated, attributes: .concurrent)

    // ✅ CORRECTION THREAD SAFETY : Protection pour dependencyGraph
    private var _dependencyGraph: [String: Set<String>] = [:]
    private var dependencyGraph: [String: Set<String>] {
        get {
            return cacheQueue.sync { _dependencyGraph }
        }
        set {
            cacheQueue.async(flags: .barrier) { [weak self] in
                self?._dependencyGraph = newValue
            }
        }
    }

    // ✅ CORRECTION THREAD SAFETY : Accès sécurisé pour lecture/écriture
    private func readDependencyGraph<T>(_ operation: ([String: Set<String>]) -> T) -> T {
        return cacheQueue.sync {
            operation(_dependencyGraph)
        }
    }

    private func modifyDependencyGraph(_ operation: @escaping (inout [String: Set<String>]) -> Void) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            operation(&self._dependencyGraph)
        }
    }

    private let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "AverageCache")
    private let debugLogger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "SmartCache")

    // ✅ AJOUTER : Initializer privé pour singleton
    private init() {
        // Configuration du cache
        cache.countLimit = 100
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
        print("🚀 [SMART_CACHE] Initialisation - Limit: \(cache.countLimit) items, \(cache.totalCostLimit / 1024 / 1024)MB")
    }

    // ✅ CHANGÉ DE STRUCT À CLASS
    class CachedAverage {
        let value: Double
        let timestamp: Date
        let dependencies: Set<String>

        init(value: Double, timestamp: Date, dependencies: Set<String>) {
            self.value = value
            self.timestamp = timestamp
            self.dependencies = dependencies
        }

        var isStale: Bool {
            Date().timeIntervalSince(timestamp) > 300 // 5 minutes
        }
    }

    func cacheAverage(_ value: Double, forKey key: String, dependencies: Set<String> = []) {
        print("🟢 [SMART_CACHE] CACHE_SET_REQUEST: '\(key)' = \(value)")
        print("🟢 [SMART_CACHE] Dependencies: \(dependencies.count) items: \(dependencies)")

        let cachedValue = CachedAverage(
            value: value,
            timestamp: Date(),
            dependencies: dependencies
        )

        cache.setObject(cachedValue, forKey: key as NSString)

        // ✅ CORRECTION THREAD SAFETY : Modification sécurisée
        modifyDependencyGraph { graph in
            graph[key] = dependencies
        }

        print("✅ [SMART_CACHE] CACHE_SET_DONE: '\(key)' = \(value)")

        // ✅ CORRECTION THREAD SAFETY : Lecture sécurisée pour le log
        let currentCount = readDependencyGraph { $0.count }
        print("📊 [SMART_CACHE] Cache size after set: \(currentCount) entries")

        logger.debug("📊 Moyenne cachée: \(key) = \(value)")
    }

    func getCachedAverage(forKey key: String) -> Double? {
        print("🔍 [SMART_CACHE] CACHE_GET_REQUEST: '\(key)'")

        guard let cached = cache.object(forKey: key as NSString) else {
            print("🔴 [SMART_CACHE] CACHE_MISS: '\(key)'")
            return nil
        }

        if cached.isStale {
            let age = Date().timeIntervalSince(cached.timestamp)
            print("⚠️ [SMART_CACHE] CACHE_STALE: '\(key)' (age: \(String(format: "%.1f", age))s) - removing")
            cache.removeObject(forKey: key as NSString)

            // ✅ CORRECTION THREAD SAFETY : Suppression sécurisée
            modifyDependencyGraph { graph in
                graph.removeValue(forKey: key)
            }
            return nil
        }

        let age = Date().timeIntervalSince(cached.timestamp)
        print("🟢 [SMART_CACHE] CACHE_HIT: '\(key)' = \(cached.value) (age: \(String(format: "%.1f", age))s)")
        return cached.value
    }

    func invalidateIfNeeded(changedObjectID: String) {
        print("🗑️ [SMART_CACHE] INVALIDATE_REQUEST: objectID = '\(changedObjectID)'")

        // ✅ CORRECTION THREAD SAFETY : Opération atomique d'invalidation
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else {
                print("🔴 [SMART_CACHE] INVALIDATE_FAILED: self is nil")
                return
            }

            var invalidatedKeys: [String] = []
            let totalKeysBefore = self._dependencyGraph.count

            print("🔍 [SMART_CACHE] Checking \(totalKeysBefore) cache entries for dependencies...")

            // Identifier les clés à invalider
            for (cacheKey, dependencies) in self._dependencyGraph {
                if dependencies.contains(changedObjectID) {
                    invalidatedKeys.append(cacheKey)
                    print("🗑️ [SMART_CACHE] WILL_INVALIDATE: '\(cacheKey)' (depends on '\(changedObjectID)')")
                }
            }

            // Supprimer du cache et du graphe de dépendances
            for key in invalidatedKeys {
                self.cache.removeObject(forKey: key as NSString)
                self._dependencyGraph.removeValue(forKey: key)
            }

            let totalKeysAfter = self._dependencyGraph.count

            if !invalidatedKeys.isEmpty {
                print("🗑️ [SMART_CACHE] INVALIDATED: \(invalidatedKeys.count) keys")
                print("🗑️ [SMART_CACHE] Keys removed: \(invalidatedKeys)")
                print("📊 [SMART_CACHE] Cache size: \(totalKeysBefore) → \(totalKeysAfter)")
                self.logger.debug("🗑️ Invalidation cascade: \(invalidatedKeys.count) clés")
            } else {
                print("✅ [SMART_CACHE] NO_INVALIDATION_NEEDED for: '\(changedObjectID)'")
            }
        }
    }

    func clearCache() {
        print("🧹 [SMART_CACHE] CLEAR_ALL_REQUEST")

        // ✅ CORRECTION THREAD SAFETY : Nettoyage atomique
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else {
                print("🔴 [SMART_CACHE] CLEAR_FAILED: self is nil")
                return
            }

            let beforeCount = self._dependencyGraph.count
            let beforeMemory = self.cache.totalCostLimit

            self.cache.removeAllObjects()
            self._dependencyGraph.removeAll()

            print("🧹 [SMART_CACHE] CLEAR_ALL_DONE:")
            print("🧹 [SMART_CACHE]   - Entries: \(beforeCount) → 0")
            print("🧹 [SMART_CACHE]   - Memory limit: \(beforeMemory)")

            self.logger.debug("🗑️ Cache moyennes vidé")
        }
    }

    // ✅ NOUVEAU : Méthodes de debug pour observer l'état
    func printCacheState() {
        print("📊 [SMART_CACHE] === ÉTAT CACHE COMPLET ===")

        // ✅ CORRECTION THREAD SAFETY : Lecture sécurisée
        readDependencyGraph { graph in
            print("📊 [SMART_CACHE] Total entries: \(graph.count)")
            print("📊 [SMART_CACHE] Cache limits:")
            print("📊 [SMART_CACHE]   - Count limit: \(self.cache.countLimit)")
            print("📊 [SMART_CACHE]   - Cost limit: \(self.cache.totalCostLimit / 1024 / 1024)MB")

            if graph.isEmpty {
                print("📊 [SMART_CACHE] Cache is empty")
            } else {
                print("📊 [SMART_CACHE] Entries details:")
                for (key, deps) in graph {
                    let value = self.cache.object(forKey: key as NSString)?.value ?? -999
                    let age = self.cache.object(forKey: key as NSString).map {
                        Date().timeIntervalSince($0.timestamp)
                    } ?? -1

                    print("📊 [SMART_CACHE]   - '\(key)': value=\(value), age=\(String(format: "%.1f", age))s, deps=\(deps.count)")

                    if deps.count > 0, deps.count <= 3 {
                        print("📊 [SMART_CACHE]     deps: \(deps)")
                    } else if deps.count > 3 {
                        let preview = Array(deps.prefix(3))
                        print("📊 [SMART_CACHE]     deps: \(preview)... (+\(deps.count - 3) more)")
                    }
                }
            }
        }

        print("📊 [SMART_CACHE] === FIN ÉTAT CACHE ===")
    }

    // ✅ NOUVEAU : Statistiques détaillées
    func printCacheStatistics() {
        // ✅ CORRECTION THREAD SAFETY : Calcul sécurisé des statistiques
        readDependencyGraph { graph in
            var totalDependencies = 0
            var staleCacheCount = 0
            var validCacheCount = 0

            for (key, deps) in graph {
                totalDependencies += deps.count

                if let cached = self.cache.object(forKey: key as NSString) {
                    if cached.isStale {
                        staleCacheCount += 1
                    } else {
                        validCacheCount += 1
                    }
                }
            }

            print("📈 [SMART_CACHE] === STATISTIQUES ===")
            print("📈 [SMART_CACHE] Total entries: \(graph.count)")
            print("📈 [SMART_CACHE] Valid entries: \(validCacheCount)")
            print("📈 [SMART_CACHE] Stale entries: \(staleCacheCount)")
            print("📈 [SMART_CACHE] Total dependencies: \(totalDependencies)")
            print("📈 [SMART_CACHE] Avg dependencies per entry: \(graph.isEmpty ? 0 : totalDependencies / graph.count)")
            print("📈 [SMART_CACHE] === FIN STATISTIQUES ===")
        }
    }

    // ✅ NOUVEAU : Nettoyer les entrées expirées
    func cleanStaleEntries() {
        print("🧹 [SMART_CACHE] CLEAN_STALE_REQUEST")

        // ✅ CORRECTION THREAD SAFETY : Nettoyage atomique des entrées expirées
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            var keysToRemove: [String] = []

            for (key, _) in self._dependencyGraph {
                if let cached = self.cache.object(forKey: key as NSString), cached.isStale {
                    keysToRemove.append(key)
                }
            }

            for key in keysToRemove {
                self.cache.removeObject(forKey: key as NSString)
                self._dependencyGraph.removeValue(forKey: key)
            }

            print("🧹 [SMART_CACHE] CLEAN_STALE_DONE: \(keysToRemove.count) stale entries removed")
            if !keysToRemove.isEmpty {
                print("🧹 [SMART_CACHE] Removed keys: \(keysToRemove)")
            }
        }
    }

    // ✅ NOUVEAU : Tester le cache avec des données factices
    func performCacheTest() {
        print("🧪 [SMART_CACHE] === DÉBUT TEST CACHE ===")

        // Test 1: Cache et récupération
        print("🧪 [SMART_CACHE] Test 1: Cache et récupération")
        cacheAverage(15.5, forKey: "test_math", dependencies: ["subject_123"])
        cacheAverage(17.2, forKey: "test_french", dependencies: ["subject_456"])
        cacheAverage(14.8, forKey: "test_global", dependencies: ["subject_123", "subject_456"])

        // ✅ CORRECTION THREAD SAFETY : Attendre que les opérations async se terminent
        cacheQueue.sync(flags: .barrier) {}

        // Test 2: Récupération
        print("🧪 [SMART_CACHE] Test 2: Récupération des valeurs")
        let mathGrade = getCachedAverage(forKey: "test_math")
        let frenchGrade = getCachedAverage(forKey: "test_french")
        let globalGrade = getCachedAverage(forKey: "test_global")
        let nonExistent = getCachedAverage(forKey: "test_nonexistent")

        print("🧪 [SMART_CACHE] Résultats récupération:")
        print("🧪 [SMART_CACHE]   - Math: \(mathGrade?.description ?? "nil")")
        print("🧪 [SMART_CACHE]   - French: \(frenchGrade?.description ?? "nil")")
        print("🧪 [SMART_CACHE]   - Global: \(globalGrade?.description ?? "nil")")
        print("🧪 [SMART_CACHE]   - NonExistent: \(nonExistent?.description ?? "nil")")

        // Test 3: État du cache
        print("🧪 [SMART_CACHE] Test 3: État du cache")
        printCacheState()

        // Test 4: Invalidation
        print("🧪 [SMART_CACHE] Test 4: Invalidation")
        invalidateIfNeeded(changedObjectID: "subject_123")

        // ✅ CORRECTION THREAD SAFETY : Attendre l'invalidation
        cacheQueue.sync(flags: .barrier) {}
        print("🧪 [SMART_CACHE] État après invalidation:")
        printCacheState()

        // Test 5: Nettoyage
        print("🧪 [SMART_CACHE] Test 5: Nettoyage complet")
        clearCache()

        // ✅ CORRECTION THREAD SAFETY : Attendre le nettoyage
        cacheQueue.sync(flags: .barrier) {}
        print("🧪 [SMART_CACHE] État après nettoyage:")
        printCacheState()

        print("🧪 [SMART_CACHE] === FIN TEST CACHE ===")
    }
}
