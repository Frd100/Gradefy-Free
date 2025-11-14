//
//  AdaptiveCacheConfiguration.swift
//  PARALLAX
//
//  Created by  on 7/1/25.
//


import Foundation

struct AdaptiveCacheConfiguration {
    let countLimit: Int
    let costLimit: Int
    
    static func configureForDevice() -> AdaptiveCacheConfiguration {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let deviceMemoryGB = physicalMemory / (1024 * 1024 * 1024)
        
        switch deviceMemoryGB {
        case 0...2: // iPhone SE, anciens modèles
            return AdaptiveCacheConfiguration(countLimit: 30, costLimit: 3 * 1024 * 1024) // ↓ Optimisé pour 300-2000 flashcards
        case 3...4: // iPhone standard
            return AdaptiveCacheConfiguration(countLimit: 100, costLimit: 15 * 1024 * 1024)
        case 5...8: // iPhone Pro
            return AdaptiveCacheConfiguration(countLimit: 200, costLimit: 30 * 1024 * 1024)
        default: // iPad Pro
            return AdaptiveCacheConfiguration(countLimit: 500, costLimit: 50 * 1024 * 1024)
        }
    }
}
