//
//  CachePerformanceMonitor.swift
//  PARALLAX
//
//  Created by Farid on 7/1/25.
//


import Foundation
import os.log

class CachePerformanceMonitor {
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private var cacheWrites: Int = 0
    private var startTime = Date()
    private let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "CacheMonitor")
    
    func recordCacheHit() {
        cacheHits += 1
        checkPerformanceMetrics()
    }
    
    func recordCacheMiss() {
        cacheMisses += 1
        checkPerformanceMetrics()
    }
    
    func recordCacheWrite() {
        cacheWrites += 1
    }
    
    private func checkPerformanceMetrics() {
        let totalRequests = cacheHits + cacheMisses
        
        if totalRequests % 50 == 0 && totalRequests > 0 {
            let hitRate = Double(cacheHits) / Double(totalRequests) * 100
            logger.info("📊 Cache Stats - Hit Rate: \(String(format: "%.1f", hitRate))%, Total: \(totalRequests)")
            
            if hitRate < 70 {
                logger.warning("⚠️ Cache hit rate below 70% - consider optimization")
            }
        }
    }
    
    func getPerformanceReport() -> String {
        let totalRequests = cacheHits + cacheMisses
        let hitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) * 100 : 0
        let sessionDuration = Date().timeIntervalSince(startTime) / 60
        
        return """
        📊 Cache Performance Report:
        - Hit Rate: \(String(format: "%.1f", hitRate))%
        - Total Requests: \(totalRequests)
        - Cache Writes: \(cacheWrites)
        - Session Duration: \(String(format: "%.1f", sessionDuration)) min
        """
    }
}
