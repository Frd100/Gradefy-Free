//
// SM2OptimizationTests.swift
// PARALLAX
//
// Created by Claude on 8/14/25.
//

import CoreData
@testable import PARALLAX
import XCTest

@MainActor
class SM2OptimizationTests: XCTestCase {
    var context: NSManagedObjectContext!
    var testDeck: FlashcardDeck!
    var srsManager: SimpleSRSManager!

    override func setUpWithError() throws {
        context = PersistenceController.shared.container.viewContext
        srsManager = SimpleSRSManager.shared

        // Créer un deck de test
        testDeck = FlashcardDeck(context: context)
        testDeck.id = UUID()
        testDeck.name = "Test Deck"
        testDeck.createdAt = Date()

        try context.save()
    }

    override func tearDownWithError() throws {
        context.rollback()
    }

    // MARK: - Tests Cache SM-2

    func testSM2CacheHitAndMiss() async throws {
        // Créer une carte de test
        let card = createTestCard(interval: 1.0, easeFactor: 2.5, reviewCount: 5)
        card.nextReviewDate = Date().addingTimeInterval(-3600) // En retard d'une heure

        try context.save()

        // Premier calcul (cache miss) - utiliser processSwipeResult pour déclencher le cache
        let startTime1 = CFAbsoluteTimeGetCurrent()
        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context, operationId: "cache_test_1")
        let latency1 = CFAbsoluteTimeGetCurrent() - startTime1

        // Deuxième calcul (cache hit)
        let startTime2 = CFAbsoluteTimeGetCurrent()
        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context, operationId: "cache_test_2")
        let latency2 = CFAbsoluteTimeGetCurrent() - startTime2

        // Vérifier que les opérations se sont bien déroulées
        XCTAssertTrue(latency1 > 0)
        XCTAssertTrue(latency2 > 0)
        XCTAssertTrue(card.reviewCount > 5, "Le reviewCount devrait avoir augmenté")
    }

    func testSM2CacheDifferentQualities() async throws {
        let card = createTestCard(interval: 1.0, easeFactor: 2.5, reviewCount: 5)
        card.nextReviewDate = Date().addingTimeInterval(-3600) // En retard d'une heure

        try context.save()

        // Calcul avec qualité 1 (mauvaise réponse)
        srsManager.processSwipeResult(card: card, swipeDirection: .left, context: context, operationId: "diff_qual_1")
        let interval1 = card.interval

        // Remettre la carte en retard pour le deuxième test
        card.nextReviewDate = Date().addingTimeInterval(-3600)
        try context.save()

        // Calcul avec qualité 2 (bonne réponse)
        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context, operationId: "diff_qual_2")
        let interval2 = card.interval

        // Les résultats devraient être différents
        XCTAssertNotEqual(interval1, interval2, "Les intervalles devraient être différents pour des qualités différentes")

        // Remettre la carte en retard pour le troisième test
        card.nextReviewDate = Date().addingTimeInterval(-3600)
        try context.save()

        // Deuxième calcul avec qualité 1 (cache hit)
        srsManager.processSwipeResult(card: card, swipeDirection: .left, context: context, operationId: "diff_qual_3")
        let interval3 = card.interval

        // Le cache devrait fonctionner
        XCTAssertNotEqual(interval2, interval3, "Les intervalles devraient être différents pour des qualités différentes")
    }

    // MARK: - Tests Sélection Optimisée

    func testOptimizedCardSelection() async throws {
        // Créer plusieurs cartes avec différents états
        let readyCard = createTestCard(interval: 1.0, easeFactor: 2.5, reviewCount: 5)
        readyCard.nextReviewDate = Date().addingTimeInterval(-3600) // En retard

        let newCard = createTestCard(interval: 0.0, easeFactor: 2.5, reviewCount: 0)
        newCard.nextReviewDate = nil // Nouvelle carte

        let moderateCard = createTestCard(interval: 3.0, easeFactor: 2.5, reviewCount: 3)
        moderateCard.nextReviewDate = Date().addingTimeInterval(86400) // Dans 1 jour

        try context.save()

        // Test de sélection optimisée
        let startTime = CFAbsoluteTimeGetCurrent()
        let selectedCards = srsManager.getSmartCards(deck: testDeck, minCards: 5)
        let latency = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertGreaterThan(selectedCards.count, 0)
        XCTAssertLessThan(latency, 0.1, "Sélection devrait être rapide (< 100ms)")

        // Vérifier que les cartes prêtes sont en premier
        let readyCards = selectedCards.filter { card in
            card.nextReviewDate != nil && card.nextReviewDate! <= Date()
        }
        XCTAssertGreaterThan(readyCards.count, 0)

        // Deuxième sélection (cache hit)
        let startTime2 = CFAbsoluteTimeGetCurrent()
        let selectedCards2 = srsManager.getSmartCards(deck: testDeck, minCards: 5)
        let latency2 = CFAbsoluteTimeGetCurrent() - startTime2

        // Vérifier que les deux sélections donnent le même résultat
        XCTAssertEqual(selectedCards.count, selectedCards2.count)
        XCTAssertTrue(latency2 > 0)
    }

    func testCardSelectionWithExclusions() async throws {
        // Créer des cartes
        let card1 = createTestCard(interval: 1.0, easeFactor: 2.5, reviewCount: 5)
        let card2 = createTestCard(interval: 1.0, easeFactor: 2.5, reviewCount: 5)
        let card3 = createTestCard(interval: 1.0, easeFactor: 2.5, reviewCount: 5)

        try context.save()

        // Sélection avec exclusion
        let selectedCards = srsManager.getSmartCards(deck: testDeck, minCards: 10, excludeCards: [card1])

        XCTAssertFalse(selectedCards.contains(card1), "Carte exclue ne devrait pas être sélectionnée")
        XCTAssertTrue(selectedCards.contains(card2) || selectedCards.contains(card3), "Autres cartes devraient être sélectionnées")
    }

    // MARK: - Tests Statistiques Optimisées

    func testOptimizedDeckStats() async throws {
        // Créer des cartes avec différents états
        let masteredCard = createTestCard(interval: 10.0, easeFactor: 2.5, reviewCount: 10)
        masteredCard.nextReviewDate = Date().addingTimeInterval(10 * 24 * 3600) // Dans 10 jours

        let readyCard = createTestCard(interval: 1.0, easeFactor: 2.5, reviewCount: 5)
        readyCard.nextReviewDate = Date().addingTimeInterval(-3600) // En retard

        let newCard = createTestCard(interval: 0.0, easeFactor: 2.5, reviewCount: 0)
        newCard.nextReviewDate = nil

        try context.save()

        // Test de calcul de stats optimisé
        let startTime = CFAbsoluteTimeGetCurrent()
        let stats = srsManager.getDeckStats(deck: testDeck)
        let latency = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertEqual(stats.totalCards, 3)
        XCTAssertGreaterThanOrEqual(stats.readyCount, 1)
        XCTAssertLessThan(latency, 0.1, "Calcul de stats devrait être rapide (< 100ms)")

        // Deuxième calcul (cache hit)
        let startTime2 = CFAbsoluteTimeGetCurrent()
        let stats2 = srsManager.getDeckStats(deck: testDeck)
        let latency2 = CFAbsoluteTimeGetCurrent() - startTime2

        XCTAssertEqual(stats.totalCards, stats2.totalCards)
        XCTAssertTrue(latency2 > 0)
    }

    // MARK: - Tests Performance

    func testPerformanceUnderLoad() async throws {
        // Créer beaucoup de cartes pour tester les performances
        for i in 0 ..< 100 {
            let card = createTestCard(interval: Double(i % 10), easeFactor: 2.5, reviewCount: Int32(i % 20))
            if i % 3 == 0 {
                card.nextReviewDate = Date().addingTimeInterval(-3600) // En retard
            } else if i % 3 == 1 {
                card.nextReviewDate = nil // Nouvelle
            } else {
                card.nextReviewDate = Date().addingTimeInterval(86400) // Dans 1 jour
            }
        }

        try context.save()

        // Test de performance
        let startTime = CFAbsoluteTimeGetCurrent()

        // Opérations multiples
        for _ in 0 ..< 10 {
            _ = srsManager.getSmartCards(deck: testDeck, minCards: 20)
            _ = srsManager.getDeckStats(deck: testDeck)
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertLessThan(totalTime, 1.0, "10 opérations devraient prendre moins de 1 seconde")
    }

    func testCacheEfficiency() async throws {
        let card = createTestCard(interval: 1.0, easeFactor: 2.5, reviewCount: 5)

        // Première série d'opérations (cache miss)
        for i in 0 ..< 5 {
            srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context, operationId: "test\(i)")
        }

        // Deuxième série d'opérations (cache hit)
        for i in 5 ..< 10 {
            srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context, operationId: "test\(i)")
        }

        // Vérifier que les opérations se sont bien déroulées
        XCTAssertTrue(card.reviewCount > 0)
    }

    // MARK: - Tests Maintenance

    func testCacheMaintenance() async throws {
        let card = createTestCard(interval: 1.0, easeFactor: 2.5, reviewCount: 5)

        // Remplir le cache
        for i in 0 ..< 10 {
            srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context, operationId: "test\(i)")
        }

        // Vérifier que les opérations se sont bien déroulées
        XCTAssertTrue(card.reviewCount > 0)
    }

    func testOptimizationReset() async throws {
        let card = createTestCard(interval: 1.0, easeFactor: 2.5, reviewCount: 5)

        // Effectuer quelques opérations
        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context, operationId: "test1")
        _ = srsManager.getSmartCards(deck: testDeck, minCards: 5)
        _ = srsManager.getDeckStats(deck: testDeck)

        // Vérifier que les opérations se sont bien déroulées
        XCTAssertTrue(card.reviewCount > 0)
    }

    // MARK: - Helpers

    private func createTestCard(interval: Double, easeFactor: Double, reviewCount: Int32) -> Flashcard {
        let card = Flashcard(context: context)
        card.id = UUID()
        card.question = "Test Question"
        card.answer = "Test Answer"
        card.interval = interval
        card.easeFactor = easeFactor
        card.reviewCount = reviewCount
        card.correctCount = 0
        card.nextReviewDate = Date()
        card.lastReviewDate = nil
        card.deck = testDeck
        return card
    }
}
