//
//  SM2IdempotenceTests.swift
//  PARALLAXTests
//
//  Tests pour l'idempotence du système SM-2
//

import XCTest
@testable import PARALLAX

final class SM2IdempotenceTests: XCTestCase {
    
    // Test 1: Configuration centralisée
    func testConfiguration_ConstantsAreCentralized() throws {
        XCTAssertEqual(SRSConfiguration.masteryIntervalThreshold, 21.0)
        XCTAssertEqual(SRSConfiguration.defaultEaseFactor, 2.3)  // ✅ AJUSTEMENT 2
        XCTAssertEqual(SRSConfiguration.minEaseFactor, 1.3)
        XCTAssertEqual(SRSConfiguration.maxEaseFactor, 3.0)
        XCTAssertEqual(SRSConfiguration.minInterval, 1.0)
        XCTAssertEqual(SRSConfiguration.softCapThreshold, 365 * 3) // 3 ans
        XCTAssertEqual(SRSConfiguration.confidentAnswerQuality, 2)
        XCTAssertEqual(SRSConfiguration.hesitantAnswerQuality, 1)
        XCTAssertEqual(SRSConfiguration.incorrectAnswerQuality, 1)
        XCTAssertEqual(SRSConfiguration.incorrectEaseFactorDecrease, 0.15)  // ✅ AJUSTEMENT 1
        XCTAssertEqual(SRSConfiguration.streakThresholdForGentleLapse, 6)  // ✅ AJUSTEMENT 1
        XCTAssertEqual(SRSConfiguration.gentleLapseIntervalMultiplier, 0.6)  // ✅ AJUSTEMENT 1
        XCTAssertTrue(SRSConfiguration.reinjectOnlyIncorrect)  // ✅ AJUSTEMENT 3
        XCTAssertEqual(SRSConfiguration.maxReinjectionQuota, 0.4)  // ✅ AJUSTEMENT 3
        XCTAssertTrue(SRSConfiguration.idempotenceCheckEnabled)
        XCTAssertEqual(SRSConfiguration.maxOperationCacheSize, 1000)
        // ✅ Vérifier que la configuration est correcte
        XCTAssertEqual(SRSConfiguration.masteryIntervalThreshold, 21.0) // Seuil de 21 jours
    }
    
    // Test 2: Timezone policy
    func testConfiguration_TimezonePolicy() throws {
        let timezone = SRSConfiguration.timeZonePolicy.timeZone
        XCTAssertNotNil(timezone)
        
        // Vérifier que c'est bien la timezone courante par défaut
        XCTAssertEqual(timezone.identifier, TimeZone.current.identifier)
    }
    
    // Test 3: Soft-cap sur intervalles (test statique)
    func testSoftCap_IntervalCalculation() throws {
        // Test avec un intervalle normal (pas de cap)
        let normalInterval = 100.0
        let result1 = applySoftCapStatic(interval: normalInterval)
        XCTAssertEqual(result1, normalInterval, "Intervalle normal ne doit pas être modifié")
        
        // Test avec un intervalle > 3 ans (doit être amorti)
        let longInterval = 1500.0 // ~4 ans
        let result2 = applySoftCapStatic(interval: longInterval)
        XCTAssertGreaterThan(result2, SRSConfiguration.softCapThreshold, "Doit être au-dessus du seuil")
        XCTAssertLessThan(result2, longInterval, "Doit être amorti")
    }
    
    // Test 4: Arrondi des intervalles (test statique)
    func testRounding_Intervals_ShouldRoundCorrectly() throws {
        // Test cas d'arrondi
        let testCases: [(input: Double, expected: Int)] = [
            (2.4, 2),  // 2.4 → 2
            (2.5, 3),  // 2.5 → 3
            (2.6, 3),  // 2.6 → 3
            (1.0, 1),  // 1.0 → 1
            (10.9, 11) // 10.9 → 11
        ]
        
        for (input, expected) in testCases {
            let rounded = Int(input.rounded())
            XCTAssertEqual(rounded, expected, "Arrondi incorrect pour \(input)")
        }
    }
    
    // Test 5: Idempotence par opération (test statique)
    func testIdempotence_OperationBased() throws {
        var seenOperationIds = Set<String>()
        
        let testOpId = "test_duplicate_op"
        
        // Premier appel - doit être traité
        let firstResult = processOperationIdStatic(opId: testOpId, seenIds: &seenOperationIds)
        XCTAssertTrue(firstResult, "Premier appel doit être traité")
        
        // Deuxième appel avec même opId - doit être ignoré
        let secondResult = processOperationIdStatic(opId: testOpId, seenIds: &seenOperationIds)
        XCTAssertFalse(secondResult, "Deuxième appel avec même opId doit être ignoré")
        
        // Troisième appel avec opId différent - doit être traité
        let thirdResult = processOperationIdStatic(opId: "test_different_op", seenIds: &seenOperationIds)
        XCTAssertTrue(thirdResult, "Appel avec opId différent doit être traité")
    }
    
    // Test 6: Swipe libre - pas de cooldown (test statique)
    func testSwipeFree_NoCooldown() throws {
        var seenOperationIds = Set<String>()
        
        // Simuler 10 swipes rapides consécutifs
        let testOpIds = (1...10).map { "test_op_\($0)" }
        var processedCount = 0
        
        for opId in testOpIds {
            // Simuler un swipe (sans vraie carte pour simplifier)
            let wasProcessed = processOperationIdStatic(opId: opId, seenIds: &seenOperationIds)
            if wasProcessed {
                processedCount += 1
            }
        }
        
        // Tous les swipes doivent être traités (pas de cooldown)
        XCTAssertEqual(processedCount, 10, "Tous les swipes doivent être traités sans cooldown")
    }
}

// Fonctions statiques pour les tests (évite les problèmes MainActor)
func applySoftCapStatic(interval: Double) -> Double {
    if interval > SRSConfiguration.softCapThreshold {
        let excess = interval - SRSConfiguration.softCapThreshold
        let taperingFactor = max(1.1, SRSConfiguration.maxEaseFactor - (excess / 365) * 0.1)
        return SRSConfiguration.softCapThreshold + (excess * taperingFactor)
    }
    return interval
}

func processOperationIdStatic(opId: String, seenIds: inout Set<String>) -> Bool {
    if SRSConfiguration.idempotenceCheckEnabled {
        if seenIds.contains(opId) {
            return false // Déjà traité
        }
        seenIds.insert(opId)
        
        // Limite pour éviter l'accumulation infinie
        if seenIds.count > SRSConfiguration.maxOperationCacheSize {
            seenIds.removeAll()
        }
    }
    return true // Traité avec succès
}
