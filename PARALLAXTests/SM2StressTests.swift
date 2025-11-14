import XCTest
@testable import PARALLAX

final class SM2StressTests: XCTestCase {
    
    // MARK: - Tests de stress - Idempotence
    
    func testStress_Idempotence_1000Operations() throws {
        var seenOperationIds = Set<String>()
        var processedCount = 0
        var duplicateCount = 0
        
        // Simuler 1000 opérations avec quelques doublons
        for i in 1...1000 {
            let opId = i % 100 == 0 ? "duplicate_op_\(i/100)" : "unique_op_\(i)"
            
            let wasProcessed = processOperationIdStatic(opId: opId, seenIds: &seenOperationIds)
            
            if wasProcessed {
                processedCount += 1
            } else {
                duplicateCount += 1
            }
        }
        
        // Vérifications
        XCTAssertEqual(processedCount, 1000, "Toutes les opérations doivent être traitées")
        XCTAssertEqual(duplicateCount, 0, "Pas de doublons dans ce test")
        XCTAssertEqual(seenOperationIds.count, 1000, "Tous les opIds doivent être dans le cache")
    }
    
    func testStress_Idempotence_Duplicates() throws {
        var seenOperationIds = Set<String>()
        var processedCount = 0
        var duplicateCount = 0
        
        // Simuler des opérations avec doublons intentionnels
        let testOpIds = (1...100).map { "op_\($0)" }
        
        // Premier passage - toutes les opérations doivent être traitées
        for opId in testOpIds {
            let wasProcessed = processOperationIdStatic(opId: opId, seenIds: &seenOperationIds)
            if wasProcessed {
                processedCount += 1
            }
        }
        
        // Deuxième passage - toutes les opérations doivent être ignorées
        for opId in testOpIds {
            let wasProcessed = processOperationIdStatic(opId: opId, seenIds: &seenOperationIds)
            if !wasProcessed {
                duplicateCount += 1
            }
        }
        
        // Vérifications
        XCTAssertEqual(processedCount, 100, "Premier passage: 100 opérations traitées")
        XCTAssertEqual(duplicateCount, 100, "Deuxième passage: 100 doublons détectés")
    }
    
    // MARK: - Tests de stress - Calculs SM-2
    
    func testStress_SM2Calculations_10000Operations() throws {
        measure {
            for _ in 1...10000 {
                _ = calculateSM2Static(
                    interval: Double.random(in: 1...500),
                    easeFactor: Double.random(in: 1.3...3.0),
                    quality: Int.random(in: 1...2),
                    isNewCard: Bool.random()
                )
            }
        }
    }
    
    func testStress_SoftCap_ExtremeValues() throws {
        // Test avec des valeurs extrêmes
        let extremeIntervals = [
            1.0,           // Minimum
            100.0,         // Normal
            1000.0,        // Long
            5000.0,        // Très long
            10000.0,       // Extrême
            50000.0        // Absurde
        ]
        
        for interval in extremeIntervals {
            let result = applySoftCapStatic(interval: interval)
            
            // Vérifications de base
            XCTAssertGreaterThan(result, 0, "Interval doit être positif")
            XCTAssertLessThanOrEqual(result, interval * 2, "Interval ne doit pas exploser")
            
            if interval <= SRSConfiguration.softCapThreshold {
                XCTAssertEqual(result, interval, "Interval normal ne doit pas être modifié")
            } else {
                XCTAssertGreaterThan(result, SRSConfiguration.softCapThreshold, "Doit être au-dessus du seuil")
                XCTAssertLessThan(result, interval, "Doit être amorti")
            }
        }
    }
    
    // MARK: - Tests de stress - Cache et mémoire
    
    func testStress_CacheOverflow() throws {
        var seenOperationIds = Set<String>()
        
        // Remplir le cache jusqu'à la limite
        for i in 1...SRSConfiguration.maxOperationCacheSize {
            let opId = "op_\(i)"
            let wasProcessed = processOperationIdStatic(opId: opId, seenIds: &seenOperationIds)
            XCTAssertTrue(wasProcessed, "Opération \(i) doit être traitée")
        }
        
        // Vérifier que le cache est plein
        XCTAssertEqual(seenOperationIds.count, SRSConfiguration.maxOperationCacheSize, "Cache doit être plein")
        
        // Ajouter une opération supplémentaire - doit déclencher le nettoyage
        let overflowOpId = "overflow_op"
        let wasProcessed = processOperationIdStatic(opId: overflowOpId, seenIds: &seenOperationIds)
        XCTAssertTrue(wasProcessed, "Opération de débordement doit être traitée")
        
        // Le cache doit être nettoyé (vide ou partiellement vide)
        XCTAssertLessThanOrEqual(seenOperationIds.count, SRSConfiguration.maxOperationCacheSize, "Cache doit être nettoyé")
    }
    
    // MARK: - Tests de stress - Concurrence simulée
    
    func testStress_ConcurrentOperations() throws {
        let operationCount = 1000
        var results: [Bool] = Array(repeating: false, count: operationCount)
        
        // Simuler des opérations concurrentes (séquentielles mais avec des opIds uniques)
        DispatchQueue.concurrentPerform(iterations: operationCount) { index in
            var localCache = Set<String>()
            let opId = "concurrent_op_\(index)"
            let wasProcessed = processOperationIdStatic(opId: opId, seenIds: &localCache)
            results[index] = wasProcessed
        }
        
        // Toutes les opérations doivent être traitées
        let processedCount = results.filter { $0 }.count
        XCTAssertEqual(processedCount, operationCount, "Toutes les opérations concurrentes doivent être traitées")
    }
    
    // MARK: - Tests de stress - Données corrompues
    
    func testStress_CorruptedData() throws {
        // Test avec des données potentiellement corrompues
        let corruptedCases = [
            (interval: -1.0, easeFactor: 2.0, quality: 2),      // Interval négatif
            (interval: 0.0, easeFactor: 2.0, quality: 2),       // Interval zéro
            (interval: 1.0, easeFactor: -1.0, quality: 2),      // EF négatif
            (interval: 1.0, easeFactor: 0.0, quality: 2),       // EF zéro
            (interval: 1.0, easeFactor: 2.0, quality: 0),       // Qualité invalide
            (interval: 1.0, easeFactor: 2.0, quality: 3),       // Qualité invalide
            (interval: Double.infinity, easeFactor: 2.0, quality: 2), // Interval infini
            (interval: 1.0, easeFactor: Double.nan, quality: 2), // EF NaN
        ]
        
        for (interval, easeFactor, quality) in corruptedCases {
            let result = calculateSM2Static(
                interval: interval,
                easeFactor: easeFactor,
                quality: quality,
                isNewCard: false
            )
            
            // Vérifications de robustesse
            XCTAssertGreaterThan(result.interval, 0, "Interval doit être positif")
            XCTAssertGreaterThanOrEqual(result.easeFactor, SRSConfiguration.minEaseFactor, "EF doit respecter le minimum")
            XCTAssertLessThanOrEqual(result.easeFactor, SRSConfiguration.maxEaseFactor, "EF doit respecter le maximum")
            XCTAssertNotNil(result.nextReviewDate, "Date de révision doit être valide")
        }
    }
    
    // MARK: - Tests de stress - Performance sous charge
    
    func testStress_Performance_ConcurrentCalculations() throws {
        let calculationCount = 5000
        
        measure {
            DispatchQueue.concurrentPerform(iterations: calculationCount) { _ in
                _ = calculateSM2Static(
                    interval: Double.random(in: 1...1000),
                    easeFactor: Double.random(in: 1.3...3.0),
                    quality: Int.random(in: 1...2),
                    isNewCard: Bool.random()
                )
            }
        }
    }
    
    func testStress_Performance_MixedOperations() throws {
        let operationCount = 2000
        
        measure {
            for i in 1...operationCount {
                // Mélanger différents types d'opérations
                switch i % 4 {
                case 0:
                    // Calcul SM-2
                    _ = calculateSM2Static(
                        interval: Double.random(in: 1...100),
                        easeFactor: Double.random(in: 1.3...3.0),
                        quality: Int.random(in: 1...2),
                        isNewCard: Bool.random()
                    )
                case 1:
                    // Soft-cap
                    _ = applySoftCapStatic(interval: Double.random(in: 1...2000))
                case 2:
                    // Date de révision
                    _ = calculateNextReviewDateStatic(interval: Double.random(in: 1...365))
                case 3:
                    // Idempotence
                    var cache = Set<String>()
                    _ = processOperationIdStatic(opId: "stress_op_\(i)", seenIds: &cache)
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Fonctions utilitaires pour les tests de stress
// Note: processOperationIdStatic est déjà défini dans SM2IdempotenceTests.swift
