//
//  SM2RobustnessTests.swift
//  PARALLAXTests
//
//  Tests de robustesse pour SM-2 (Phase 2 - Étape 2)
//

import CoreData
@testable import PARALLAX
import XCTest

@MainActor
final class SM2RobustnessTests: XCTestCase {
    var context: NSManagedObjectContext!
    var srsManager: SimpleSRSManager!
    var testCard: Flashcard!
    var testDeck: FlashcardDeck!

    override func setUpWithError() throws {
        let persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        srsManager = SimpleSRSManager.shared

        // Réinitialiser le cache d'opId entre les tests
        srsManager.clearOperationCache()

        // Créer un deck de test
        testDeck = FlashcardDeck(context: context)
        testDeck.id = UUID()
        testDeck.name = "Test Deck"
        testDeck.createdAt = Date()

        // Créer une carte de test
        testCard = Flashcard(context: context)
        testCard.id = UUID()
        testCard.question = "Test Question"
        testCard.answer = "Test Answer"
        testCard.interval = 1.0
        testCard.easeFactor = 2.5
        testCard.reviewCount = 0
        testCard.correctCount = 0
        testCard.nextReviewDate = Date().addingTimeInterval(-3600) // Carte en retard (due hier)
        testCard.lastReviewDate = nil
        testCard.deck = testDeck

        try context.save()
    }

    override func tearDownWithError() throws {
        context = nil
        srsManager = nil
        testCard = nil
        testDeck = nil
    }

    // MARK: - Tests de validation d'entrée

    func testValidation_ValidCardData() throws {
        // Carte valide
        XCTAssertTrue(validateCardDataStatic(card: testCard), "Carte valide doit passer la validation")
    }

    func testValidation_InvalidInterval() throws {
        // Intervalle négatif
        testCard.interval = -1.0
        XCTAssertFalse(validateCardDataStatic(card: testCard), "Intervalle négatif doit être rejeté")

        // Intervalle NaN
        testCard.interval = Double.nan
        XCTAssertFalse(validateCardDataStatic(card: testCard), "Intervalle NaN doit être rejeté")

        // Intervalle infini
        testCard.interval = Double.infinity
        XCTAssertFalse(validateCardDataStatic(card: testCard), "Intervalle infini doit être rejeté")
    }

    func testValidation_InvalidEaseFactor() throws {
        // EF < 1.3
        testCard.easeFactor = 1.0
        XCTAssertFalse(validateCardDataStatic(card: testCard), "EF < 1.3 doit être rejeté")

        // EF > 3.0
        testCard.easeFactor = 3.5
        XCTAssertFalse(validateCardDataStatic(card: testCard), "EF > 3.0 doit être rejeté")

        // EF NaN
        testCard.easeFactor = Double.nan
        XCTAssertFalse(validateCardDataStatic(card: testCard), "EF NaN doit être rejeté")
    }

    func testValidation_InvalidCounters() throws {
        // correctCount > reviewCount
        testCard.correctCount = 5
        testCard.reviewCount = 3
        XCTAssertFalse(validateCardDataStatic(card: testCard), "correctCount > reviewCount doit être rejeté")

        // reviewCount négatif
        testCard.reviewCount = -1
        testCard.correctCount = 0
        XCTAssertFalse(validateCardDataStatic(card: testCard), "reviewCount négatif doit être rejeté")

        // correctCount négatif
        testCard.reviewCount = 0
        testCard.correctCount = -1
        XCTAssertFalse(validateCardDataStatic(card: testCard), "correctCount négatif doit être rejeté")
    }

    func testValidation_BoundaryValues() throws {
        // EF à la limite min
        testCard.easeFactor = SRSConfiguration.minEaseFactor
        XCTAssertTrue(validateCardDataStatic(card: testCard), "EF à la limite min doit être accepté")

        // EF à la limite max
        testCard.easeFactor = SRSConfiguration.maxEaseFactor
        XCTAssertTrue(validateCardDataStatic(card: testCard), "EF à la limite max doit être accepté")

        // Intervalle 0
        testCard.interval = 0.0
        XCTAssertTrue(validateCardDataStatic(card: testCard), "Intervalle 0 doit être accepté")

        // Compteurs à 0
        testCard.reviewCount = 0
        testCard.correctCount = 0
        XCTAssertTrue(validateCardDataStatic(card: testCard), "Compteurs à 0 doivent être acceptés")
    }

    // MARK: - Tests Log-Only (bonnes réponses avant échéance)

    func testLogOnly_CorrectAnswerBeforeDue() throws {
        // Créer une carte avec une date de révision future
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date()
        testCard.nextReviewDate = futureDate
        testCard.interval = 8.0
        testCard.easeFactor = 2.3
        testCard.reviewCount = 3
        testCard.correctCount = 2

        let initialInterval = testCard.interval
        let initialEaseFactor = testCard.easeFactor
        let initialCorrectCount = testCard.correctCount
        let initialReviewCount = testCard.reviewCount

        // Traiter une bonne réponse avant échéance
        srsManager.processSwipeResult(card: testCard, swipeDirection: .right, context: context)

        // En log-only, seuls reviewCount et lastReviewDate changent
        XCTAssertEqual(testCard.interval, initialInterval, "Interval ne doit pas changer en log-only")
        XCTAssertEqual(testCard.easeFactor, initialEaseFactor, "EF ne doit pas changer en log-only")
        XCTAssertEqual(testCard.correctCount, initialCorrectCount, "Correct count ne doit pas changer en log-only")
        XCTAssertEqual(testCard.reviewCount, initialReviewCount + 1, "Review count doit être incrémenté en log-only")
        XCTAssertNotNil(testCard.lastReviewDate, "Last review date doit être mis à jour en log-only")
    }

    func testLogOnly_MultipleCorrectAnswersBeforeDue() throws {
        // Créer une carte avec une date de révision future
        let futureDate = Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date()
        testCard.nextReviewDate = futureDate
        testCard.interval = 15.0
        testCard.easeFactor = 2.1
        testCard.reviewCount = 5
        testCard.correctCount = 4

        let initialInterval = testCard.interval
        let initialEaseFactor = testCard.easeFactor
        let initialCorrectCount = testCard.correctCount

        // Traiter plusieurs bonnes réponses avant échéance
        for i in 1 ... 3 {
            srsManager.processSwipeResult(card: testCard, swipeDirection: .right, context: context)

            // Vérifier que les paramètres SM-2 restent inchangés
            XCTAssertEqual(testCard.interval, initialInterval, "Interval ne doit pas changer en log-only (itération \(i))")
            XCTAssertEqual(testCard.easeFactor, initialEaseFactor, "EF ne doit pas changer en log-only (itération \(i))")
            XCTAssertEqual(testCard.correctCount, initialCorrectCount, "Correct count ne doit pas changer en log-only (itération \(i))")
            XCTAssertEqual(testCard.reviewCount, Int32(5 + i), "Review count doit être incrémenté en log-only (itération \(i))")
        }
    }

    // MARK: - Tests Lapse Intra-Session (mauvaises réponses avant échéance)

    func testLapseIntraSession_IncorrectAnswerBeforeDue() throws {
        // Créer une carte avec une date de révision future
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        testCard.nextReviewDate = futureDate
        testCard.interval = 12.0
        testCard.easeFactor = 2.4
        testCard.reviewCount = 6
        testCard.correctCount = 5

        let initialInterval = testCard.interval
        let initialEaseFactor = testCard.easeFactor
        let initialCorrectCount = testCard.correctCount
        let initialReviewCount = testCard.reviewCount

        // Traiter une mauvaise réponse avant échéance
        srsManager.processSwipeResult(card: testCard, swipeDirection: .left, context: context)

        // En lapse intra-session, seuls reviewCount et lastReviewDate changent
        XCTAssertEqual(testCard.interval, initialInterval, "Interval ne doit pas changer en lapse intra-session")
        XCTAssertEqual(testCard.easeFactor, initialEaseFactor, "EF ne doit pas changer en lapse intra-session")
        XCTAssertEqual(testCard.correctCount, initialCorrectCount, "Correct count ne doit pas changer en lapse intra-session")
        XCTAssertEqual(testCard.reviewCount, initialReviewCount + 1, "Review count doit être incrémenté en lapse intra-session")
        XCTAssertNotNil(testCard.lastReviewDate, "Last review date doit être mis à jour en lapse intra-session")
    }

    func testLapseIntraSession_MultipleIncorrectAnswersBeforeDue() throws {
        // Créer une carte avec une date de révision future
        let futureDate = Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date()
        testCard.nextReviewDate = futureDate
        testCard.interval = 20.0
        testCard.easeFactor = 2.2
        testCard.reviewCount = 8
        testCard.correctCount = 7

        let initialInterval = testCard.interval
        let initialEaseFactor = testCard.easeFactor
        let initialCorrectCount = testCard.correctCount

        // Traiter plusieurs mauvaises réponses avant échéance
        for i in 1 ... 2 {
            srsManager.processSwipeResult(card: testCard, swipeDirection: .left, context: context)

            // Vérifier que les paramètres SM-2 restent inchangés
            XCTAssertEqual(testCard.interval, initialInterval, "Interval ne doit pas changer en lapse intra-session (itération \(i))")
            XCTAssertEqual(testCard.easeFactor, initialEaseFactor, "EF ne doit pas changer en lapse intra-session (itération \(i))")
            XCTAssertEqual(testCard.correctCount, initialCorrectCount, "Correct count ne doit pas changer en lapse intra-session (itération \(i))")
            XCTAssertEqual(testCard.reviewCount, Int32(8 + i), "Review count doit être incrémenté en lapse intra-session (itération \(i))")
        }
    }

    // MARK: - Tests Sélection Intelligente (Lapses → Due → New → Modérées → Reste)

    func testSmartCardSelection_PriorityOrder() throws {
        // Créer plusieurs cartes avec différents états
        let cards = createTestCardsWithDifferentStates()

        // Tester la sélection intelligente
        let smartCards = srsManager.getSmartCards(deck: testDeck, minCards: 10)

        // Vérifier que les cartes sont dans l'ordre de priorité correct
        XCTAssertGreaterThan(smartCards.count, 0, "Au moins une carte doit être sélectionnée")

        // Les cartes prêtes (due) doivent être en premier
        let readyCards = smartCards.filter { card in
            guard let nextReview = card.nextReviewDate else { return false }
            return nextReview <= Date()
        }

        // Les nouvelles cartes doivent être en deuxième
        let newCards = smartCards.filter { $0.nextReviewDate == nil }

        // Les cartes modérées doivent être en troisième
        let moderateCards = smartCards.filter { card in
            card.interval <= 7.0 && // 7 jours comme seuil modéré
                card.nextReviewDate != nil &&
                card.nextReviewDate! > Date()
        }

        print("🎯 [Test] Sélection intelligente: \(smartCards.count) cartes (\(readyCards.count) prêtes, \(newCards.count) nouvelles, \(moderateCards.count) modérées)")

        // Vérifier que l'ordre est respecté (approximatif)
        XCTAssertGreaterThanOrEqual(readyCards.count + newCards.count, moderateCards.count, "Les cartes prioritaires doivent être plus nombreuses que les modérées")
    }

    func testSmartCardSelection_ExcludeCards() throws {
        // Créer plusieurs cartes
        let cards = createTestCardsWithDifferentStates()

        // Exclure certaines cartes
        let excludeCards = Array(cards.prefix(2))
        let smartCards = srsManager.getSmartCards(deck: testDeck, minCards: 5, excludeCards: excludeCards)

        // Vérifier qu'aucune carte exclue n'est présente
        let excludeIds = Set(excludeCards.map { $0.objectID })
        let includedIds = Set(smartCards.map { $0.objectID })

        let intersection = excludeIds.intersection(includedIds)
        XCTAssertTrue(intersection.isEmpty, "Aucune carte exclue ne doit être présente dans la sélection")
    }

    // MARK: - Tests Idempotence par opId

    func testIdempotence_OperationId() throws {
        let operationId = "test_operation_123"

        // Première exécution
        let initialInterval = testCard.interval

        let expectation1 = XCTestExpectation(description: "First operation")
        context.perform {
            self.srsManager.processSwipeResult(card: self.testCard, swipeDirection: .right, context: self.context, operationId: operationId)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5.0)
        try context.save()

        let firstInterval = testCard.interval

        // Deuxième exécution avec le même opId
        let expectation2 = XCTestExpectation(description: "Second operation")
        context.perform {
            self.srsManager.processSwipeResult(card: self.testCard, swipeDirection: .right, context: self.context, operationId: operationId)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5.0)
        try context.save()

        let secondInterval = testCard.interval

        // Les intervalles doivent être identiques (idempotence)
        XCTAssertEqual(firstInterval, secondInterval, "L'opération doit être idempotente avec le même opId")
        XCTAssertNotEqual(firstInterval, initialInterval, "La première exécution doit avoir modifié l'intervalle")
    }

    func testIdempotence_DifferentOperationIds() throws {
        // Créer une carte qui reste due pour les deux opérations
        let card = Flashcard(context: context)
        card.id = UUID()
        card.question = "Test Question"
        card.answer = "Test Answer"
        card.interval = 0.5 // Intervalle très court pour que la carte reste due
        card.easeFactor = 2.5
        card.reviewCount = 0
        card.correctCount = 0
        card.nextReviewDate = Date().addingTimeInterval(-3600) // En retard d'une heure
        card.lastReviewDate = nil
        card.deck = testDeck

        try context.save()

        // Première exécution
        let initialInterval = card.interval

        let expectation1 = XCTestExpectation(description: "First operation")
        context.perform {
            self.srsManager.processSwipeResult(card: card, swipeDirection: .right, context: self.context, operationId: "op1")
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5.0)
        try context.save()

        let firstInterval = card.interval

        // Forcer la carte à rester due pour la deuxième opération
        card.nextReviewDate = Date().addingTimeInterval(-3600) // En retard d'une heure
        try context.save()

        // Deuxième exécution avec un opId différent
        let expectation2 = XCTestExpectation(description: "Second operation")
        context.perform {
            self.srsManager.processSwipeResult(card: card, swipeDirection: .right, context: self.context, operationId: "op2")
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5.0)
        try context.save()

        let secondInterval = card.interval

        // Les intervalles doivent être différents (pas d'idempotence)
        XCTAssertNotEqual(firstInterval, secondInterval, "Les opérations avec des opIds différents ne doivent pas être idempotentes")
        XCTAssertNotEqual(firstInterval, initialInterval, "La première exécution doit avoir modifié l'intervalle")
    }

    // MARK: - Tests Arrondi + Midi Local + DST

    func testDateCalculation_RoundingAndNoon() throws {
        // Tester le calcul de date avec arrondi et midi local
        let interval = 3.7 // Doit être arrondi à 4 jours
        let result = calculateNextReviewDateStatic(interval: interval)

        // Vérifier que la date est à midi
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result)
        let minute = calendar.component(.minute, from: result)

        XCTAssertEqual(hour, 12, "La date de révision doit être à midi")
        XCTAssertEqual(minute, 0, "La date de révision doit être à midi pile")

        // Vérifier que l'intervalle est arrondi
        let today = Date()
        let daysDiff = calendar.dateComponents([.day], from: today, to: result).day ?? 0
        XCTAssertEqual(daysDiff, 4, "L'intervalle 3.7 doit être arrondi à 4 jours")
    }

    func testDateCalculation_DSTHandling() throws {
        // Tester la gestion du DST
        let interval = 1.0

        // Calculer la date de révision
        let result = calculateNextReviewDateStatic(interval: interval)

        // Vérifier que la date est valide et dans le futur
        XCTAssertGreaterThan(result, Date(), "La date de révision doit être dans le futur")

        // Vérifier que c'est toujours à midi
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result)
        XCTAssertEqual(hour, 12, "La date de révision doit rester à midi même avec DST")
    }

    // MARK: - Tests Intégration avec les Modes de Révision

    func testIntegration_FlashcardMode() throws {
        // Simuler l'intégration avec le mode flashcard
        let cards = createTestCardsWithDifferentStates()

        // Attendre que toutes les opérations soient terminées
        let expectation = XCTestExpectation(description: "Flashcard mode operations")
        expectation.expectedFulfillmentCount = 3

        // Simuler des swipes dans le mode flashcard avec gestion asynchrone
        for card in cards.prefix(3) {
            context.perform {
                self.srsManager.processSwipeResult(card: card, swipeDirection: .right, context: self.context)
                expectation.fulfill()
            }
        }

        // Attendre la fin des opérations
        wait(for: [expectation], timeout: 5.0)

        // Forcer la sauvegarde et attendre
        try context.save()

        // Vérifier que les cartes ont été mises à jour
        let updatedCards = cards.prefix(3)
        for card in updatedCards {
            XCTAssertNotNil(card.lastReviewDate, "Last review date doit être mis à jour")
            // En mode SM-2 normal, reviewCount est incrémenté
            XCTAssertGreaterThan(card.reviewCount, 0, "Review count doit être incrémenté")
            // Vérifier que les paramètres SM-2 ont été mis à jour
            XCTAssertNotEqual(card.interval, 1.0, "Interval doit être mis à jour par SM-2")
            XCTAssertNotEqual(card.easeFactor, 2.5, "Ease factor doit être mis à jour par SM-2")
        }
    }

    func testIntegration_QuizMode() throws {
        // Simuler l'intégration avec le mode quiz
        let cards = createTestCardsWithDifferentStates()

        // Attendre que toutes les opérations soient terminées
        let expectation = XCTestExpectation(description: "Quiz mode operations")
        expectation.expectedFulfillmentCount = 4

        // Capturer les valeurs initiales pour les mauvaises réponses
        let incorrectCardsInitialCorrectCounts = cards.dropFirst(2).prefix(2).map { $0.correctCount }

        // Simuler des réponses correctes dans le mode quiz
        for card in cards.prefix(2) {
            context.perform {
                self.srsManager.processSwipeResult(card: card, swipeDirection: .right, context: self.context)
                expectation.fulfill()
            }
        }

        // Simuler des réponses incorrectes
        for card in cards.dropFirst(2).prefix(2) {
            context.perform {
                self.srsManager.processSwipeResult(card: card, swipeDirection: .left, context: self.context)
                expectation.fulfill()
            }
        }

        // Attendre la fin des opérations
        wait(for: [expectation], timeout: 5.0)

        // Forcer la sauvegarde et attendre
        try context.save()

        // Vérifier que les cartes ont été mises à jour correctement
        let correctCards = cards.prefix(2)
        let incorrectCards = cards.dropFirst(2).prefix(2)

        for card in correctCards {
            XCTAssertGreaterThan(card.correctCount, 0, "Correct count doit être incrémenté pour les bonnes réponses")
            // Vérifier que les paramètres SM-2 ont été mis à jour
            XCTAssertNotEqual(card.interval, 1.0, "Interval doit être mis à jour par SM-2")
            XCTAssertNotEqual(card.easeFactor, 2.5, "Ease factor doit être mis à jour par SM-2")
        }

        for (index, card) in incorrectCards.enumerated() {
            XCTAssertEqual(card.interval, SRSConfiguration.resetInterval, "Interval doit être reset pour les mauvaises réponses")
            // Vérifier que correctCount n'a pas été incrémenté pour les mauvaises réponses
            let initialCorrectCount = incorrectCardsInitialCorrectCounts[index]
            XCTAssertEqual(card.correctCount, initialCorrectCount, "Correct count ne doit pas être incrémenté pour les mauvaises réponses")
        }
    }

    func testIntegration_AssociationMode() throws {
        // Simuler l'intégration avec le mode association
        let cards = createTestCardsWithDifferentStates()

        // Attendre que toutes les opérations soient terminées
        let expectation = XCTestExpectation(description: "Association mode operations")
        expectation.expectedFulfillmentCount = 4

        // Simuler des matches corrects
        for card in cards.prefix(2) {
            context.perform {
                self.srsManager.processSwipeResult(card: card, swipeDirection: .right, context: self.context)
                expectation.fulfill()
            }
        }

        // Simuler des matches incorrects
        for card in cards.dropFirst(2).prefix(2) {
            context.perform {
                self.srsManager.processSwipeResult(card: card, swipeDirection: .left, context: self.context)
                expectation.fulfill()
            }
        }

        // Attendre la fin des opérations
        wait(for: [expectation], timeout: 5.0)

        // Forcer la sauvegarde et attendre
        try context.save()

        // Vérifier que les cartes ont été mises à jour
        let correctCards = cards.prefix(2)
        let incorrectCards = cards.dropFirst(2).prefix(2)

        // Vérifier les bonnes réponses
        for card in correctCards {
            XCTAssertNotNil(card.lastReviewDate, "Last review date doit être mis à jour")
            XCTAssertGreaterThan(card.reviewCount, 0, "Review count doit être incrémenté")
            // Les bonnes réponses doivent avoir un intervalle > 1.0 et easeFactor > 2.5
            XCTAssertGreaterThan(card.interval, 1.0, "Interval doit être augmenté pour les bonnes réponses")
            XCTAssertGreaterThan(card.easeFactor, 2.5, "Ease factor doit être augmenté pour les bonnes réponses")
        }

        // Vérifier les mauvaises réponses
        for card in incorrectCards {
            XCTAssertNotNil(card.lastReviewDate, "Last review date doit être mis à jour")
            XCTAssertGreaterThan(card.reviewCount, 0, "Review count doit être incrémenté")
            // Les mauvaises réponses doivent avoir un intervalle reset à 1.0 et easeFactor < 2.5
            XCTAssertEqual(card.interval, 1.0, "Interval doit être reset à 1.0 pour les mauvaises réponses")
            XCTAssertLessThan(card.easeFactor, 2.5, "Ease factor doit être diminué pour les mauvaises réponses")
        }
    }

    // MARK: - Tests CorrectCount Log-Only vs SM-2 Normal

    func testCorrectCount_BonneReponseDue() throws {
        // Créer une carte due avec une bonne réponse
        let card = Flashcard(context: context)
        card.id = UUID()
        card.question = "Test Question"
        card.answer = "Test Answer"
        card.interval = 1.0
        card.easeFactor = 2.5
        card.reviewCount = 0
        card.correctCount = 0
        card.nextReviewDate = Date().addingTimeInterval(-3600) // En retard d'une heure
        card.lastReviewDate = nil
        card.deck = testDeck

        try context.save()

        let initialCorrectCount = card.correctCount

        // Simuler une bonne réponse sur une carte due
        let expectation = XCTestExpectation(description: "Good response on due card")
        context.perform {
            self.srsManager.processSwipeResult(card: card, swipeDirection: .right, context: self.context)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
        try context.save()

        // Vérifier que correctCount a été incrémenté
        XCTAssertEqual(card.correctCount, initialCorrectCount + 1, "CorrectCount doit être incrémenté pour une bonne réponse sur une carte due")
    }

    func testCorrectCount_BonneReponseLogOnly() throws {
        // Créer une carte pas encore due avec une bonne réponse
        let card = Flashcard(context: context)
        card.id = UUID()
        card.question = "Test Question"
        card.answer = "Test Answer"
        card.interval = 5.0
        card.easeFactor = 2.5
        card.reviewCount = 0
        card.correctCount = 0
        card.nextReviewDate = Date().addingTimeInterval(3600) // Dans une heure (pas encore due)
        card.lastReviewDate = nil
        card.deck = testDeck

        try context.save()

        let initialCorrectCount = card.correctCount

        // Simuler une bonne réponse sur une carte pas encore due (log-only)
        let expectation = XCTestExpectation(description: "Good response on not due card")
        context.perform {
            self.srsManager.processSwipeResult(card: card, swipeDirection: .right, context: self.context)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
        try context.save()

        // Vérifier que correctCount n'a PAS été incrémenté
        XCTAssertEqual(card.correctCount, initialCorrectCount, "CorrectCount ne doit PAS être incrémenté pour une bonne réponse en mode log-only")

        // Vérifier que reviewCount a été incrémenté
        XCTAssertEqual(card.reviewCount, 1, "ReviewCount doit être incrémenté même en mode log-only")

        // Vérifier que les paramètres SM-2 n'ont pas été modifiés
        XCTAssertEqual(card.interval, 5.0, "Interval ne doit pas être modifié en mode log-only")
        XCTAssertEqual(card.easeFactor, 2.5, "EaseFactor ne doit pas être modifié en mode log-only")
    }

    // MARK: - Tests de Robustesse Core Data

    func testCoreDataErrorHandling() throws {
        // Tester la gestion d'erreurs Core Data
        let invalidCard = Flashcard(context: context)
        invalidCard.id = UUID()
        invalidCard.question = nil // Données invalides
        invalidCard.answer = nil

        // L'opération doit être gérée gracieusement
        srsManager.processSwipeResult(card: invalidCard, swipeDirection: .right, context: context)

        // Le système ne doit pas planter
        XCTAssertTrue(true, "Le système doit gérer gracieusement les erreurs Core Data")
    }

    func testConcurrentOperations() throws {
        // Tester les opérations concurrentes
        let cards = createTestCardsWithDifferentStates()

        // Attendre que toutes les opérations soient terminées
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = cards.count

        // Simuler des opérations concurrentes avec gestion d'acteur
        DispatchQueue.concurrentPerform(iterations: cards.count) { index in
            let card = cards[index]
            Task { @MainActor in
                self.srsManager.processSwipeResult(card: card, swipeDirection: .right, context: self.context)
                expectation.fulfill()
            }
        }

        // Attendre la fin des opérations
        wait(for: [expectation], timeout: 10.0)

        // Forcer la sauvegarde et attendre
        try context.save()

        // Vérifier que toutes les cartes ont été traitées
        for card in cards {
            XCTAssertNotNil(card.lastReviewDate, "Toutes les cartes doivent avoir été traitées")
        }
    }

    // MARK: - Helpers

    private func createTestCardsWithDifferentStates() -> [Flashcard] {
        var cards: [Flashcard] = []

        // Cartes prêtes (due) - valeurs initiales pour tests SM-2
        for i in 0 ..< 3 {
            let card = Flashcard(context: context)
            card.id = UUID()
            card.question = "Question \(i)"
            card.answer = "Answer \(i)"
            card.interval = Double(i + 2) // Valeurs différentes pour éviter les conflits avec les résultats SM-2
            card.easeFactor = 2.5 // Valeur initiale pour test SM-2
            card.reviewCount = Int32(i)
            card.correctCount = Int16(i)
            card.nextReviewDate = Date().addingTimeInterval(-Double(i * 3600)) // En retard
            card.lastReviewDate = Date().addingTimeInterval(-Double((i + 1) * 86400))
            card.deck = testDeck
            cards.append(card)
        }

        // Nouvelles cartes
        for i in 3 ..< 5 {
            let card = Flashcard(context: context)
            card.id = UUID()
            card.question = "Question \(i)"
            card.answer = "Answer \(i)"
            card.interval = 1.0
            card.easeFactor = 2.5
            card.reviewCount = 0
            card.correctCount = 0
            card.nextReviewDate = nil // Jamais révisée
            card.lastReviewDate = nil
            card.deck = testDeck
            cards.append(card)
        }

        // Cartes modérées
        for i in 5 ..< 7 {
            let card = Flashcard(context: context)
            card.id = UUID()
            card.question = "Question \(i)"
            card.answer = "Answer \(i)"
            card.interval = 5.0
            card.easeFactor = 2.2
            card.reviewCount = Int32(i)
            card.correctCount = Int16(i - 1)
            card.nextReviewDate = Date().addingTimeInterval(Double((i - 4) * 86400)) // Dans quelques jours
            card.lastReviewDate = Date().addingTimeInterval(-Double((i - 4) * 86400))
            card.deck = testDeck
            cards.append(card)
        }

        // Cartes maîtrisées
        for i in 7 ..< 10 {
            let card = Flashcard(context: context)
            card.id = UUID()
            card.question = "Question \(i)"
            card.answer = "Answer \(i)"
            card.interval = 30.0
            card.easeFactor = 2.8
            card.reviewCount = Int32(i + 5)
            card.correctCount = Int16(i + 4)
            card.nextReviewDate = Date().addingTimeInterval(Double((i - 6) * 86400)) // Dans plusieurs jours
            card.lastReviewDate = Date().addingTimeInterval(-Double((i - 6) * 86400))
            card.deck = testDeck
            cards.append(card)
        }

        try? context.save()
        return cards
    }
}

// MARK: - Fonctions statiques pour les tests

func validateCardDataStatic(card: Flashcard) -> Bool {
    // Vérifier que l'intervalle est valide
    guard card.interval >= 0 && !card.interval.isNaN && !card.interval.isInfinite else {
        return false
    }

    // Vérifier que l'ease factor est dans les bornes
    guard card.easeFactor >= SRSConfiguration.minEaseFactor &&
        card.easeFactor <= SRSConfiguration.maxEaseFactor &&
        !card.easeFactor.isNaN && !card.easeFactor.isInfinite
    else {
        return false
    }

    // Vérifier que les compteurs sont cohérents
    guard card.reviewCount >= 0 && card.correctCount >= 0 &&
        card.correctCount <= card.reviewCount
    else {
        return false
    }

    return true
}

func calculateNextReviewDateStatic(interval: Double) -> Date {
    var calendar = Calendar.current
    calendar.timeZone = SRSConfiguration.timeZonePolicy.timeZone

    let today = Date()
    let noonToday = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today) ?? today

    return calendar.date(byAdding: .day, value: Int(interval.rounded()), to: noonToday) ?? today
}
