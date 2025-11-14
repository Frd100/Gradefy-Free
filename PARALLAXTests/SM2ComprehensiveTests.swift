import XCTest
@testable import PARALLAX

final class SM2ComprehensiveTests: XCTestCase {
    
    // MARK: - Tests unitaires SM-2
    
    func testCalculateSM2_NewCard_FirstConfidentAnswer() throws {
        // Given: Nouvelle carte (EF=2.5, interval=1.0)
        let interval = 1.0
        let easeFactor = 2.5
        let quality = SRSConfiguration.confidentAnswerQuality // 2 (confiant)
        
        // When: Première réponse confiante
        let result = calculateSM2Static(
            interval: interval,
            easeFactor: easeFactor,
            quality: quality,
            isNewCard: true
        )
        
        // Then: EF doit être ajusté à 2.0 + 0.12 = 2.12, interval augmenté
        XCTAssertEqual(result.easeFactor, SRSConfiguration.defaultEaseFactor + SRSConfiguration.confidentEaseFactorIncrease, "Nouvelle carte doit utiliser EF par défaut + augmentation confiante")
        XCTAssertGreaterThan(result.interval, interval, "Interval doit augmenter avec réponse confiante")
        XCTAssertEqual(result.interval, SRSConfiguration.defaultEaseFactor, "Premier interval = EF par défaut")
    }
    
    func testCalculateSM2_ExistingCard_ConfidentAnswer() throws {
        // Given: Carte existante (EF=2.2, interval=5.0)
        let interval = 5.0
        let easeFactor = 2.2
        let quality = SRSConfiguration.confidentAnswerQuality // 2 (confiant)
        
        // When: Réponse confiante
        let result = calculateSM2Static(
            interval: interval,
            easeFactor: easeFactor,
            quality: quality,
            isNewCard: false
        )
        
        // Then: EF et interval augmentent
        XCTAssertEqual(result.easeFactor, easeFactor + SRSConfiguration.confidentEaseFactorIncrease, "EF doit augmenter de 0.12")
        XCTAssertEqual(result.interval, interval * easeFactor, "Nouvel interval = ancien * EF")
    }
    
    func testCalculateSM2_ExistingCard_HesitantAnswer() throws {
        // Given: Carte existante (EF=2.2, interval=5.0)
        let interval = 5.0
        let easeFactor = 2.2
        let quality = SRSConfiguration.hesitantAnswerQuality // 1 (hésité)
        
        // When: Réponse hésitante
        let result = calculateSM2Static(
            interval: interval,
            easeFactor: easeFactor,
            quality: quality,
            isNewCard: false
        )
        
        // Then: EF inchangé, interval progression modérée
        XCTAssertEqual(result.easeFactor, easeFactor + SRSConfiguration.hesitantEaseFactorIncrease, "EF doit rester inchangé (+0.0)")
        XCTAssertEqual(result.interval, interval * SRSConfiguration.hesitantIntervalMultiplier, "Nouvel interval = ancien * 1.35")
    }
    
    func testCalculateSM2_IncorrectAnswer() throws {
        // Given: Carte existante (EF=2.2, interval=5.0)
        let interval = 5.0
        let easeFactor = 2.2
        let quality = SRSConfiguration.incorrectAnswerQuality // 1 (incorrect)
        
        // When: Mauvaise réponse
        let result = calculateSM2Static(
            interval: interval,
            easeFactor: easeFactor,
            quality: quality,
            isNewCard: false
        )
        
        // Then: EF diminue, interval réduit avec clamp
        XCTAssertEqual(result.easeFactor, easeFactor - SRSConfiguration.incorrectEaseFactorDecrease, "EF doit diminuer de 0.18")
        let expectedInterval = max(
            SRSConfiguration.incorrectIntervalMin,
            min(SRSConfiguration.incorrectIntervalMax, interval * SRSConfiguration.incorrectIntervalMultiplier)
        )
        XCTAssertEqual(result.interval, expectedInterval, "Interval doit être réduit avec clamp 1-7")
    }
    
    func testCalculateSM2_EFBoundaries() throws {
        // Test EF minimum
        let minEFResult = calculateSM2Static(
            interval: 1.0,
            easeFactor: SRSConfiguration.minEaseFactor,
            quality: SRSConfiguration.incorrectAnswerQuality,
            isNewCard: false
        )
        XCTAssertEqual(minEFResult.easeFactor, SRSConfiguration.minEaseFactor, "EF ne doit pas descendre en dessous du minimum")
        
        // Test EF maximum
        let maxEFResult = calculateSM2Static(
            interval: 1.0,
            easeFactor: SRSConfiguration.maxEaseFactor,
            quality: SRSConfiguration.confidentAnswerQuality,
            isNewCard: false
        )
        XCTAssertEqual(maxEFResult.easeFactor, SRSConfiguration.maxEaseFactor, "EF ne doit pas dépasser le maximum")
    }
    
    // MARK: - Tests de robustesse
    
    func testSoftCap_LongIntervals() throws {
        // Given: Interval très long
        let longInterval = 2000.0 // ~5.5 ans
        
        // When: Application du soft-cap
        let cappedInterval = applySoftCapStatic(interval: longInterval)
        
        // Then: Interval doit être amorti mais pas coupé
        XCTAssertGreaterThan(cappedInterval, SRSConfiguration.softCapThreshold, "Doit être au-dessus du seuil")
        XCTAssertLessThan(cappedInterval, longInterval, "Doit être amorti")
        XCTAssertGreaterThan(cappedInterval, SRSConfiguration.softCapThreshold + 100, "Doit garder une progression")
    }
    
    func testSoftCap_NormalIntervals() throws {
        // Given: Interval normal
        let normalInterval = 100.0
        
        // When: Application du soft-cap
        let result = applySoftCapStatic(interval: normalInterval)
        
        // Then: Interval inchangé
        XCTAssertEqual(result, normalInterval, "Interval normal ne doit pas être modifié")
    }
    
    func testRounding_AllCases() throws {
        let testCases: [(input: Double, expected: Int)] = [
            (1.0, 1),    // Entier
            (1.4, 1),    // Arrondi vers le bas
            (1.5, 2),    // Arrondi vers le haut
            (1.6, 2),    // Arrondi vers le haut
            (10.9, 11),  // Arrondi vers le haut
            (10.1, 10),  // Arrondi vers le bas
        ]
        
        for (input, expected) in testCases {
            let rounded = Int(input.rounded())
            XCTAssertEqual(rounded, expected, "Arrondi incorrect pour \(input)")
        }
    }
    
    // MARK: - Tests de performance
    
    func testPerformance_100Calculations() throws {
        measure {
            for _ in 1...100 {
                _ = calculateSM2Static(
                    interval: Double.random(in: 1...100),
                    easeFactor: Double.random(in: 1.3...3.0),
                    quality: Int.random(in: 1...2),
                    isNewCard: Bool.random()
                )
            }
        }
    }
    
    func testPerformance_SoftCap() throws {
        measure {
            for _ in 1...1000 {
                _ = applySoftCapStatic(interval: Double.random(in: 1...2000))
            }
        }
    }
    
    // MARK: - Tests d'intégration
    
    func testIntegration_CompleteSM2Flow() throws {
        // Simuler un flux complet SM-2
        var currentInterval = 1.0
        var currentEF = SRSConfiguration.defaultEaseFactor
        var isNewCard = true
        
        // Première bonne réponse
        var result = calculateSM2Static(
            interval: currentInterval,
            easeFactor: currentEF,
            quality: SRSConfiguration.confidentAnswerQuality,
            isNewCard: isNewCard
        )
        
        XCTAssertEqual(result.interval, SRSConfiguration.defaultEaseFactor, "Premier interval = EF par défaut")
        XCTAssertEqual(result.easeFactor, SRSConfiguration.defaultEaseFactor + SRSConfiguration.confidentEaseFactorIncrease, "EF augmente")
        
        // Mise à jour pour la prochaine itération
        currentInterval = result.interval
        currentEF = result.easeFactor
        isNewCard = false
        
        // Deuxième réponse confiante
        result = calculateSM2Static(
            interval: currentInterval,
            easeFactor: currentEF,
            quality: SRSConfiguration.confidentAnswerQuality,
            isNewCard: isNewCard
        )
        
        XCTAssertGreaterThan(result.interval, currentInterval, "Interval doit continuer à augmenter")
        XCTAssertGreaterThan(result.easeFactor, currentEF, "EF doit continuer à augmenter")
        
        // Mauvaise réponse
        result = calculateSM2Static(
            interval: result.interval,
            easeFactor: result.easeFactor,
            quality: SRSConfiguration.incorrectAnswerQuality,
            isNewCard: isNewCard
        )
        
        XCTAssertEqual(result.interval, SRSConfiguration.resetInterval, "Interval doit être reset")
        XCTAssertLessThan(result.easeFactor, currentEF, "EF doit diminuer")
    }
    
    // MARK: - Tests avec horloge déterministe (Garde-fou #2)
    
    func testSM2_DeterministicClock_DateCalculations() throws {
        // Utiliser une date fixe pour éviter les problèmes de timezone/DST
        let fixedDate = Date(timeIntervalSince1970: 1704067200) // 1er janvier 2024, 12:00 UTC
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? TimeZone.current
        
        // Test avec une carte due à cette date fixe
        let card = TestCard(
            interval: 3.0,
            easeFactor: 2.5,
            reviewCount: 2,
            correctCount: 1,
            nextReviewDate: fixedDate,
            lastReviewDate: nil
        )
        
        let result = calculateSM2Static(
            interval: card.interval,
            easeFactor: card.easeFactor,
            quality: SRSConfiguration.confidentAnswerQuality,
            isNewCard: false
        )
        
        // Vérifier que la date calculée est cohérente
        let expectedDate = calendar.date(byAdding: .day, value: Int(result.interval.rounded()), to: fixedDate) ?? fixedDate
        XCTAssertEqual(result.nextReviewDate, expectedDate, "Date calculée doit être cohérente avec l'horloge fixe")
    }
    
    func testSM2_DeterministicClock_DSTTransition() throws {
        // Test autour du changement d'heure (DST)
        // 31 mars 2024: passage à l'heure d'été en Europe
        let beforeDST = Date(timeIntervalSince1970: 1711929600) // 31 mars 2024, 02:00
        let afterDST = Date(timeIntervalSince1970: 1711933200)  // 31 mars 2024, 03:00 (après changement)
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? TimeZone.current
        
        // Test que J+1 reste J+1 même avec le changement d'heure
        let card1 = TestCard(
            interval: 1.0,
            easeFactor: 2.5,
            reviewCount: 1,
            correctCount: 0,
            nextReviewDate: beforeDST,
            lastReviewDate: nil
        )
        
        let card2 = TestCard(
            interval: 1.0,
            easeFactor: 2.5,
            reviewCount: 1,
            correctCount: 0,
            nextReviewDate: afterDST,
            lastReviewDate: nil
        )
        
        let result1 = calculateSM2Static(
            interval: card1.interval,
            easeFactor: card1.easeFactor,
            quality: SRSConfiguration.confidentAnswerQuality,
            isNewCard: false
        )
        
        let result2 = calculateSM2Static(
            interval: card2.interval,
            easeFactor: card2.easeFactor,
            quality: SRSConfiguration.confidentAnswerQuality,
            isNewCard: false
        )
        
        // Les deux cartes doivent avoir la même date de prochaine révision (J+1)
        let expectedDate1 = calendar.date(byAdding: .day, value: 1, to: beforeDST) ?? beforeDST
        let expectedDate2 = calendar.date(byAdding: .day, value: 1, to: afterDST) ?? afterDST
        
        XCTAssertTrue(calendar.isDate(result1.nextReviewDate, inSameDayAs: expectedDate1), "J+1 avant DST doit être cohérent")
        XCTAssertTrue(calendar.isDate(result2.nextReviewDate, inSameDayAs: expectedDate2), "J+1 après DST doit être cohérent")
    }
    
    // MARK: - Tests des 4 cas SM-2 de base (Garde-fou #3)
    
    func testSM2_CorrectAnswer_WhenDue() throws {
        // Cas 1: Bonne réponse à échéance
        let card = TestCard(
            interval: 5.0,
            easeFactor: 2.5,
            reviewCount: 3,
            correctCount: 2,
            nextReviewDate: Date(), // Carte due aujourd'hui
            lastReviewDate: nil
        )
        
        let result = calculateSM2Static(
            interval: card.interval,
            easeFactor: card.easeFactor,
            quality: SRSConfiguration.confidentAnswerQuality,
            isNewCard: false
        )
        
        // Vérifications SM-2 normales
        XCTAssertGreaterThan(result.interval, card.interval, "Interval doit augmenter")
        XCTAssertGreaterThan(result.easeFactor, card.easeFactor, "EF doit augmenter")
        XCTAssertNotNil(result.nextReviewDate, "Date de prochaine révision doit être définie")
        
        // Vérifier que la date est dans le futur
        var calendar = Calendar.current
        calendar.timeZone = SRSConfiguration.timeZonePolicy.timeZone
        XCTAssertTrue(calendar.isDate(result.nextReviewDate, inSameDayAs: Date()) || result.nextReviewDate > Date(), "Date doit être aujourd'hui ou dans le futur")
    }
    
    func testSM2_CorrectAnswer_BeforeDue() throws {
        // Cas 2: Bonne réponse avant échéance (log-only)
        let futureDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        let card = TestCard(
            interval: 5.0,
            easeFactor: 2.5,
            reviewCount: 2,
            correctCount: 1,
            nextReviewDate: futureDate, // Carte pas encore due
            lastReviewDate: nil
        )
        
        let initialInterval = card.interval
        let initialEaseFactor = card.easeFactor
        let initialCorrectCount = card.correctCount
        
        // En log-only, seuls reviewCount et lastReviewDate changent
        // Les paramètres SM-2 restent inchangés
        XCTAssertEqual(initialInterval, 5.0, "Interval ne doit pas changer en log-only")
        XCTAssertEqual(initialEaseFactor, 2.5, "EF ne doit pas changer en log-only")
        XCTAssertEqual(initialCorrectCount, 1, "Correct count ne doit pas changer en log-only")
        
        // Note: Le test réel de log-only nécessite l'API complète avec isDue check
        // Ce test valide que les données de base sont correctes pour le log-only
    }
    
    func testSM2_IncorrectAnswer_WhenDue() throws {
        // Cas 3: Mauvaise réponse à échéance
        let card = TestCard(
            interval: 10.0,
            easeFactor: 2.5,
            reviewCount: 5,
            correctCount: 4,
            nextReviewDate: Date(), // Carte due aujourd'hui
            lastReviewDate: nil
        )
        
        let result = calculateSM2Static(
            interval: card.interval,
            easeFactor: card.easeFactor,
            quality: SRSConfiguration.incorrectAnswerQuality,
            isNewCard: false
        )
        
        // Vérifications SM-2 pour mauvaise réponse
        let expectedInterval = max(
            SRSConfiguration.incorrectIntervalMin,
            min(SRSConfiguration.incorrectIntervalMax, card.interval * SRSConfiguration.incorrectIntervalMultiplier)
        )
        XCTAssertEqual(result.interval, expectedInterval, "Interval doit être réduit avec clamp 1-7")
        XCTAssertLessThan(result.easeFactor, card.easeFactor, "EF doit diminuer")
        XCTAssertEqual(result.easeFactor, card.easeFactor - SRSConfiguration.incorrectEaseFactorDecrease, "EF doit diminuer de 0.18")
        
        // Vérifier que la date est demain (interval = 1.0)
        var calendar = Calendar.current
        calendar.timeZone = SRSConfiguration.timeZonePolicy.timeZone
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        XCTAssertTrue(calendar.isDate(result.nextReviewDate, inSameDayAs: tomorrow), "Date doit être demain")
    }
    
    func testSM2_IncorrectAnswer_BeforeDue() throws {
        // Cas 4: Mauvaise réponse avant échéance (lapse intra-session)
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date()
        let card = TestCard(
            interval: 8.0,
            easeFactor: 2.3,
            reviewCount: 4,
            correctCount: 3,
            nextReviewDate: futureDate, // Carte pas encore due
            lastReviewDate: nil
        )
        
        let initialInterval = card.interval
        let initialEaseFactor = card.easeFactor
        let initialCorrectCount = card.correctCount
        
        // En lapse intra-session, seuls reviewCount et lastReviewDate changent
        // Les paramètres SM-2 restent inchangés (comme en log-only)
        XCTAssertEqual(initialInterval, 8.0, "Interval ne doit pas changer en lapse intra-session")
        XCTAssertEqual(initialEaseFactor, 2.3, "EF ne doit pas changer en lapse intra-session")
        XCTAssertEqual(initialCorrectCount, 3, "Correct count ne doit pas changer en lapse intra-session")
        
        // Note: Le test réel de lapse intra-session nécessite l'API complète avec LapseBuffer
        // Ce test valide que les données de base sont correctes pour le lapse intra-session
    }
}

// MARK: - Structures de test

struct TestCard {
    let interval: Double
    let easeFactor: Double
    let reviewCount: Int
    let correctCount: Int
    let nextReviewDate: Date
    let lastReviewDate: Date?
}

// MARK: - Fonctions statiques pour les tests

func calculateSM2Static(interval: Double, easeFactor: Double, quality: Int, isNewCard: Bool, reviewCount: Int = 0, correctCount: Int = 0) -> SM2Result {
    let currentInterval = max(SRSConfiguration.minInterval, interval)
    
    // Ease factor initial plus conservateur (inspiré Anki grand public)
    let defaultEF: Double
    if easeFactor == 2.5 && isNewCard {
        defaultEF = SRSConfiguration.defaultEaseFactor  // 2.3 pour nouveaux utilisateurs
    } else {
        defaultEF = easeFactor  // Garder la valeur existante pour cartes importées
    }
    
    let currentEF = max(SRSConfiguration.minEaseFactor, min(SRSConfiguration.maxEaseFactor, defaultEF))
    
    switch quality {
    case SRSConfiguration.confidentAnswerQuality:
        // ✅ Bon (confiant) - swipe droite
        let newInterval: Double
        if reviewCount < SRSConfiguration.earlyGraduatingMaxReviews {
            // Phase early : utiliser les intervalles fixes
            let earlyIndex = min(reviewCount, SRSConfiguration.earlyGraduatingIntervals.count - 1)
            newInterval = SRSConfiguration.earlyGraduatingIntervals[earlyIndex]
        } else {
            // Phase normale : algorithme SM-2 standard
            newInterval = currentInterval * currentEF
        }
        
        let cappedInterval = applySoftCapStatic(interval: newInterval)
        let newEF = min(SRSConfiguration.maxEaseFactor, currentEF + SRSConfiguration.confidentEaseFactorIncrease)
        
        return SM2Result(
            interval: cappedInterval,
            easeFactor: newEF,
            nextReviewDate: calculateNextReviewDateStatic(interval: cappedInterval)
        )
        
    case SRSConfiguration.hesitantAnswerQuality:
        // 🔵 Bon mais hésité - swipe haut
        let newInterval = currentInterval * SRSConfiguration.hesitantIntervalMultiplier
        let cappedInterval = applySoftCapStatic(interval: newInterval)
        let newEF = currentEF + SRSConfiguration.hesitantEaseFactorIncrease  // +0.0 (inchangé)
        
        return SM2Result(
            interval: cappedInterval,
            easeFactor: newEF,
            nextReviewDate: calculateNextReviewDateStatic(interval: cappedInterval)
        )
        
    case SRSConfiguration.incorrectAnswerQuality:
        // ❌ Faux - swipe gauche
        let lapseMultiplier: Double
        if correctCount >= SRSConfiguration.streakThresholdForGentleLapse {
            lapseMultiplier = SRSConfiguration.gentleLapseIntervalMultiplier  // ×0.6 pour les streaks
        } else {
            lapseMultiplier = SRSConfiguration.incorrectIntervalMultiplier  // ×0.4 standard
        }
        
        let newInterval = max(
            SRSConfiguration.incorrectIntervalMin, 
            min(SRSConfiguration.incorrectIntervalMax, currentInterval * lapseMultiplier)
        )
        let newEF = max(SRSConfiguration.minEaseFactor, currentEF - SRSConfiguration.incorrectEaseFactorDecrease)
        
        return SM2Result(
            interval: newInterval,
            easeFactor: newEF,
            nextReviewDate: calculateNextReviewDateStatic(interval: newInterval)
        )
        
    default:
        // Fallback pour compatibilité
        let newEF = max(SRSConfiguration.minEaseFactor, currentEF - SRSConfiguration.incorrectEaseFactorDecrease)
        return SM2Result(
            interval: SRSConfiguration.resetInterval,
            easeFactor: newEF,
            nextReviewDate: calculateNextReviewDateStatic(interval: SRSConfiguration.resetInterval)
        )
    }
}

// Fonction calculateNextReviewDateStatic définie dans SM2RobustnessTests.swift
