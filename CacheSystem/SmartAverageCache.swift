import Foundation
import CoreData
import os.log

class SmartAverageCache {
    private let cache = NSCache<NSString, CachedAverage>()
    private let cacheQueue = DispatchQueue(label: "gradefy.average.cache", qos: .userInitiated)
    private var dependencyGraph: [String: Set<String>] = [:]
    private let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "AverageCache")
    
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
        cacheQueue.async { [weak self] in
            let cachedValue = CachedAverage(
                value: value,
                timestamp: Date(),
                dependencies: dependencies
            )
            
            self?.cache.setObject(cachedValue, forKey: key as NSString)
            self?.dependencyGraph[key] = dependencies
            self?.logger.debug("📊 Moyenne cachée: \(key) = \(value)")
        }
    }
    
    func getCachedAverage(forKey key: String) -> Double? {
        return cacheQueue.sync { [weak self] in
            guard let cached = self?.cache.object(forKey: key as NSString) else {
                return nil
            }
            
            if cached.isStale {
                self?.cache.removeObject(forKey: key as NSString)
                self?.dependencyGraph.removeValue(forKey: key)
                return nil
            }
            
            return cached.value
        }
    }
    
    func invalidateIfNeeded(changedObjectID: String) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            var invalidatedKeys: [String] = []
            
            for (cacheKey, dependencies) in self.dependencyGraph {
                if dependencies.contains(changedObjectID) {
                    self.cache.removeObject(forKey: cacheKey as NSString)
                    invalidatedKeys.append(cacheKey)
                }
            }
            
            for key in invalidatedKeys {
                self.dependencyGraph.removeValue(forKey: key)
            }
            
            if !invalidatedKeys.isEmpty {
                self.logger.debug("🗑️ Invalidation cascade: \(invalidatedKeys.count) clés")
            }
        }
    }
    
    func clearCache() {
        cacheQueue.async { [weak self] in
            self?.cache.removeAllObjects()
            self?.dependencyGraph.removeAll()
            self?.logger.debug("🗑️ Cache moyennes vidé")
        }
    }
}
