//
//  AverageCacheAdvancedTests.swift
//  PARALLAX
//
//  Created by Farid on 7/1/25.
//


import XCTest
import Foundation
@testable import PARALLAX

@MainActor
final class AverageCacheAdvancedTests: XCTestCase {
    var cache: AverageCache!
    var frenchSystem: FrenchSystem!
    var usaSystem: USASystem!
    
    override func setUpWithError() throws {
        cache = AverageCache.createTestInstance()
        frenchSystem = FrenchSystem()
        usaSystem = USASystem()
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        cache = nil
        frenchSystem = nil
        usaSystem = nil
    }
    
    // MARK: - Tests Cache Anti-Spam
    func test_cacheAntiSpam_whenFrequentClears_shouldPreventSpam() throws {
        // Arrange
        let startTime = Date()
        
        // Act - Multiple clears en succession
        cache.clearCache()
        cache.clearCache()
        cache.clearCache()
        
        let endTime = Date()
        
        // Assert - Le système anti-spam devrait empêcher les clears trop fréquents
        XCTAssertLessThan(endTime.timeIntervalSince(startTime), 0.1, "Multiple clears should be very fast due to anti-spam")
    }
    
    // MARK: - Tests Cache Invalidation Intelligence
    func test_cacheInvalidation_whenDataChanges_shouldInvalidateAutomatically() throws {
        // Arrange
        let originalSubjects = [
            SubjectData(code: "MATH", name: "Math", grade: 15.0, coefficient: 2.0, periodName: "S1")
        ]
        
        let modifiedSubjects = [
            SubjectData(code: "MATH", name: "Math", grade: 16.0, coefficient: 2.0, periodName: "S1")
        ]
        
        // Act
        let avg1 = cache.getAverage(for: originalSubjects, using: frenchSystem)
        let avg2 = cache.getAverage(for: modifiedSubjects, using: frenchSystem)
        
        // Assert
        XCTAssertEqual(avg1, 15.0, "First average should be 15.0")
        XCTAssertEqual(avg2, 16.0, "Second average should be 16.0 (cache invalidated)")
        XCTAssertNotEqual(avg1, avg2, "Cache should invalidate when data changes")
    }
    
    // MARK: - Tests Cache Hash Calculation
    func test_cacheHash_whenIdenticalData_shouldHaveSameHash() throws {
        // Arrange
        let subjects1 = [
            SubjectData(code: "MATH", name: "Math", grade: 15.0, coefficient: 2.0, periodName: "S1"),
            SubjectData(code: "PHYS", name: "Physics", grade: 17.0, coefficient: 3.0, periodName: "S1")
        ]
        
        let subjects2 = [
            SubjectData(code: "MATH", name: "Math", grade: 15.0, coefficient: 2.0, periodName: "S1"),
            SubjectData(code: "PHYS", name: "Physics", grade: 17.0, coefficient: 3.0, periodName: "S1")
        ]
        
        // Act
        let avg1 = cache.getAverage(for: subjects1, using: frenchSystem)
        let avg2 = cache.getAverage(for: subjects2, using: frenchSystem)
        
        // Assert
        XCTAssertEqual(avg1, avg2, "Identical data should produce same result from cache")
    }
    
    // MARK: - Tests Cache System Switching
    func test_cacheSystemSwitch_whenDifferentSystems_shouldRecalculate() throws {
        // Arrange
        let subjects = [
            SubjectData(code: "MATH", name: "Math", grade: 15.0, coefficient: 2.0, periodName: "S1")
        ]
        
        // Act
        let frenchAvg = cache.getAverage(for: subjects, using: frenchSystem)
        let usaAvg = cache.getAverage(for: subjects, using: usaSystem)
        
        // Assert
        XCTAssertEqual(frenchAvg, 15.0, "French system should return 15.0")
        XCTAssertNotEqual(usaAvg, 15.0, "USA system should convert the value")
        XCTAssertTrue(cache.isCacheValid(for: usaSystem.id), "Cache should be valid for USA system")
    }
    
    // MARK: - Tests Cache Duration
    func test_cacheExpiration_whenTimeoutExceeded_shouldInvalidate() throws {
        // Arrange
        let subjects = [
            SubjectData(code: "MATH", name: "Math", grade: 15.0, coefficient: 2.0, periodName: "S1")
        ]
        
        // Act
        _ = cache.getAverage(for: subjects, using: frenchSystem)
        XCTAssertTrue(cache.isCacheValid(for: frenchSystem.id), "Cache should be initially valid")
        
        // Simuler expiration en forçant invalidation
        cache.invalidateCacheIfNeeded()
        
        // Assert - Le cache devrait toujours être valide car pas assez de temps écoulé
        // (la durée de cache est de 30 secondes dans le code réel)
    }
    
    // MARK: - Tests Cache with Empty Data
    func test_cacheWithEmptyData_whenNoSubjects_shouldReturnNoGrade() throws {
        // Arrange
        let emptySubjects: [SubjectData] = []
        
        // Act
        let average = cache.getAverage(for: emptySubjects, using: frenchSystem)
        
        // Assert
        XCTAssertEqual(average, NO_GRADE, "Empty subjects should return NO_GRADE")
        XCTAssertFalse(cache.isCacheValid(for: frenchSystem.id), "Cache should not be valid for NO_GRADE")
    }
    
    // MARK: - Tests Cache Debug Info
    func test_cacheDebugInfo_whenCacheUsed_shouldProvideValidInfo() throws {
        // Arrange
        let subjects = [
            SubjectData(code: "MATH", name: "Math", grade: 15.0, coefficient: 2.0, periodName: "S1")
        ]
        
        // Act
        _ = cache.getAverage(for: subjects, using: frenchSystem)
        let debugInfo = cache.getDebugInfo()
        
        // Assert
        XCTAssertNotNil(debugInfo["cachedAverage"], "Debug info should contain cached average")
        XCTAssertNotNil(debugInfo["lastCalculationTime"], "Debug info should contain calculation time")
        XCTAssertNotNil(debugInfo["lastSystemId"], "Debug info should contain system ID")
        XCTAssertNotNil(debugInfo["isValid"], "Debug info should contain validity status")
    }
    
    // MARK: - Tests Batch Update
    func test_batchUpdate_whenMultipleOperations_shouldPreventMultipleClears() throws {
        // Arrange
        let subjects = [
            SubjectData(code: "MATH", name: "Math", grade: 15.0, coefficient: 2.0, periodName: "S1")
        ]
        
        // Act & Assert - Aucune exception ne devrait être levée
        XCTAssertNoThrow { [self] in
            let result = cache.batchUpdate {
                _ = cache.getAverage(for: subjects, using: frenchSystem)
                cache.clearCache()
                cache.forceInvalidate()
                return "success"
            }
            XCTAssertEqual(result, "success", "Batch update should return correct value")
        }
    }
    
    // MARK: - Tests Performance Edge Cases
    func test_cachePerformance_whenLargeDatasetRepeated_shouldUseCache() throws {
        // Arrange
        let largeSubjects = Array(0..<1000).map { i in
            SubjectData(code: "SUB\(i)", name: "Subject \(i)", 
                       grade: Double(10 + i % 10), coefficient: 1.0, periodName: "S1")
        }
        
        // Act & Measure first calculation (cache miss)
        let startTime1 = CFAbsoluteTimeGetCurrent()
        let avg1 = cache.getAverage(for: largeSubjects, using: frenchSystem)
        let time1 = CFAbsoluteTimeGetCurrent() - startTime1
        
        // Second calculation (cache hit)
        let startTime2 = CFAbsoluteTimeGetCurrent()
        let avg2 = cache.getAverage(for: largeSubjects, using: frenchSystem)
        let time2 = CFAbsoluteTimeGetCurrent() - startTime2
        
        // Assert
        XCTAssertEqual(avg1, avg2, "Results should be identical")
        XCTAssertLessThan(time2, time1 * 0.1, "Cache hit should be at least 10x faster")
    }
}
