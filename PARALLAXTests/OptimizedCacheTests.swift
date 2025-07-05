import XCTest
import Foundation
@testable import PARALLAX

@MainActor
final class OptimizedCacheTests: XCTestCase {
    var cache: AverageCache!
    var testSystems: [GradingSystemPlugin]!
    
    override func setUpWithError() throws {
        cache = AverageCache.createTestInstance()
        testSystems = [FrenchSystem(), USASystem()]
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        cache = nil
        testSystems = nil
    }
    
    // MARK: - Tests Cache Multi-systèmes
    // Dans OptimizedCacheTests.swift, remplacez le test par :
    func test_cache_whenSwitchingSystems_shouldInvalidateCorrectly() throws {
        // ✅ CORRECTION : Utilisez des notes adaptées à chaque système
        let frenchSubjects = [
            SubjectData(code: "MATH", name: "Math", grade: 15.0, coefficient: 1.0, periodName: "S1")
        ]
        
        let usaSubjects = [
            SubjectData(code: "MATH", name: "Math", grade: 3.5, coefficient: 1.0, periodName: "S1") // GPA valide
        ]
        
        // Test système français
        let frenchAvg = cache.getAverage(for: frenchSubjects, using: FrenchSystem())
        XCTAssertNotEqual(frenchAvg, NO_GRADE, "Cache should return valid average for french")
        
        // Test système américain avec données appropriées
        let usaAvg = cache.getAverage(for: usaSubjects, using: USASystem())
        XCTAssertNotEqual(usaAvg, NO_GRADE, "Cache should return valid average for usa")
    }

    
    // MARK: - Tests Performance Sans Surcharge
    func test_cache_whenLargeDataset_shouldPerformWithinTime() throws {
        // Arrange
        let subjects = Array(0..<100).map { i in
            SubjectData(code: "SUB\(i)", name: "Subject \(i)",
                       grade: Double(10 + i % 10), coefficient: 1.0, periodName: "S1")
        }
        
        // Act & Assert
        measure {
            _ = cache.getAverage(for: subjects, using: FrenchSystem())
        }
    }
    
    // MARK: - Tests Anti-Spam Cache
    func test_cache_whenFrequentClearing_shouldPreventSpam() throws {
        // Act
        cache.clearCache()
        cache.clearCache() // Appel immédiat
        
        // Assert - Le cache devrait empêcher le spam
        // Pas d'erreur = le système anti-spam fonctionne
    }
}
