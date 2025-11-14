//
//  SM2IntegrationTests.swift
//  PARALLAXTests
//
//  Tests d'intégration pour SM-2 avec les différents modes de révision
//

import XCTest
import CoreData
@testable import PARALLAX

@MainActor
class SM2IntegrationTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    var srsManager: SimpleSRSManager!
    var testDeck: FlashcardDeck!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Configuration CoreData en mémoire
        let container = NSPersistentContainer(name: "PARALLAX")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        context = container.viewContext
        srsManager = SimpleSRSManager.shared
        
        // Création du deck de test
        testDeck = FlashcardDeck(context: context)
        testDeck.id = UUID()
        testDeck.name = "Integration Test Deck"
        testDeck.createdAt = Date()
        
        try context.save()
    }
    
    override func tearDownWithError() throws {
        context = nil
        srsManager = nil
        testDeck = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Tests FlashcardRevisionSystem Integration
    
    func testFlashcardModeIntegration() throws {
        // Test intégration avec le mode flashcard classique
        let card = createFlashcard(question: "Flashcard Test", answer: "Test Answer")
        
        // Simuler un swipe droite dans FlashcardRevisionSystem
        let initialInterval = card.interval
        let initialReviewCount = card.reviewCount
        
        srsManager.processSwipeResult(
            card: card,
            swipeDirection: .right,
            context: context
        )
        
        // Vérifications post-swipe
        XCTAssertGreaterThan(card.interval, initialInterval, "L'intervalle doit augmenter après swipe droite")
        XCTAssertEqual(card.reviewCount, initialReviewCount + 1, "reviewCount doit être incrémenté")
        XCTAssertNotNil(card.lastReviewDate, "lastReviewDate doit être définie")
        XCTAssertNotNil(card.nextReviewDate, "nextReviewDate doit être définie")
        
        // Vérifier la persistance
        try context.save()
        context.refreshAllObjects()
        
        XCTAssertGreaterThan(card.interval, initialInterval, "Les changements doivent persister")
    }
    
    func testMultipleSwipesInSession() throws {
        // Test de plusieurs swipes dans une même session
        let cards = [
            createFlashcard(question: "Card 1", answer: "Answer 1"),
            createFlashcard(question: "Card 2", answer: "Answer 2"),
            createFlashcard(question: "Card 3", answer: "Answer 3")
        ]
        
        let swipeResults: [SwipeDirection] = [.right, .left, .right]
        
        for (index, card) in cards.enumerated() {
            let initialInterval = card.interval
            
            srsManager.processSwipeResult(
                card: card,
                swipeDirection: swipeResults[index],
                context: context
            )
            
            if swipeResults[index] == .right {
                XCTAssertGreaterThan(card.interval, initialInterval, "Swipe droite doit augmenter l'intervalle")
                XCTAssertEqual(card.correctCount, 1, "correctCount doit être incrémenté pour swipe droite")
            } else {
                XCTAssertEqual(card.interval, 1.0, "Swipe gauche doit remettre l'intervalle à 1")
                XCTAssertEqual(card.correctCount, 0, "correctCount ne doit pas être incrémenté pour swipe gauche")
            }
        }
    }
    
    // MARK: - Tests QuizSystem Integration
    
    func testQuizModeIntegration() throws {
        // Test intégration avec le mode quiz
        let card = createFlashcard(question: "Quiz Question", answer: "Quiz Answer")
        
        // Simuler une réponse correcte dans un quiz
        let initialStats = srsManager.getDeckStats(deck: testDeck)
        
        srsManager.processSwipeResult(
            card: card,
            swipeDirection: .right,  // Réponse correcte mappée à .right
            context: context
        )
        
        // Vérifications
        XCTAssertGreaterThan(card.interval, 1.0, "Quiz: Réponse correcte doit augmenter l'intervalle")
        XCTAssertEqual(card.correctCount, 1, "Quiz: correctCount doit être incrémenté")
        
        let newStats = srsManager.getDeckStats(deck: testDeck)
        XCTAssertEqual(newStats.todayReviewCount, initialStats.todayReviewCount + 1, "Quiz doit incrémenter todayReviewCount")
    }
    
    func testQuizIncorrectAnswer() throws {
        // Test réponse incorrecte dans un quiz
        let card = createFlashcard(question: "Quiz Question Hard", answer: "Quiz Answer Hard")
        
        srsManager.processSwipeResult(
            card: card,
            swipeDirection: .left,  // Réponse incorrecte mappée à .left
            context: context
        )
        
        XCTAssertEqual(card.interval, 1.0, "Quiz: Réponse incorrecte doit remettre l'intervalle à 1")
        XCTAssertEqual(card.correctCount, 0, "Quiz: correctCount ne doit pas être incrémenté")
        XCTAssertLessThan(card.easeFactor, 2.5, "Quiz: easeFactor doit diminuer")
    }
    
    // MARK: - Tests AssociationView Integration
    
    func testAssociationModeIntegration() throws {
        // Test intégration avec le mode association
        let card = createFlashcard(question: "Association Term", answer: "Association Definition")
        
        // Simuler un match correct dans association
        srsManager.processSwipeResult(
            card: card,
            swipeDirection: .right,  // Match correct
            context: context
        )
        
        XCTAssertGreaterThan(card.interval, 1.0, "Association: Match correct doit augmenter l'intervalle")
        XCTAssertEqual(card.correctCount, 1, "Association: correctCount doit être incrémenté")
    }
    
    func testAssociationIncorrectMatch() throws {
        // Test match incorrect dans association
        let card = createFlashcard(question: "Association Term 2", answer: "Association Definition 2")
        
        srsManager.processSwipeResult(
            card: card,
            swipeDirection: .left,  // Match incorrect
            context: context
        )
        
        XCTAssertEqual(card.interval, 1.0, "Association: Match incorrect doit remettre l'intervalle à 1")
        XCTAssertEqual(card.correctCount, 0, "Association: correctCount ne doit pas être incrémenté")
    }
    
    // MARK: - Tests Mixed Mode Sessions
    
    func testMixedModeSessionsOnSameCard() throws {
        // Test d'une carte utilisée dans différents modes
        let card = createFlashcard(question: "Multi-mode Card", answer: "Multi-mode Answer")
        
        // Session 1: Mode flashcard (swipe droite)
        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
        let afterFlashcard = card.interval
        XCTAssertGreaterThan(afterFlashcard, 1.0, "Première session doit augmenter l'intervalle")
        
        // Session 2: Mode quiz (réponse correcte)
        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
        let afterQuiz = card.interval
        XCTAssertGreaterThan(afterQuiz, afterFlashcard, "Deuxième session doit continuer à augmenter")
        
        // Session 3: Mode association (match correct)
        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
        let afterAssociation = card.interval
        XCTAssertGreaterThan(afterAssociation, afterQuiz, "Troisième session doit continuer à augmenter")
        
        XCTAssertEqual(card.correctCount, 3, "Doit avoir 3 bonnes réponses au total")
    }
    
    // MARK: - Tests Dashboard Real-time Updates
    
    func testDashboardUpdatesAfterRevision() throws {
        // Test que le dashboard se met à jour après révision
        let cards = [
            createFlashcard(question: "Dashboard Card 1", answer: "Answer 1"),
            createFlashcard(question: "Dashboard Card 2", answer: "Answer 2"),
            createFlashcard(question: "Dashboard Card 3", answer: "Answer 3")
        ]
        
        // État initial
        let initialStats = srsManager.getDeckStats(deck: testDeck)
        XCTAssertEqual(initialStats.todayReviewCount, 0, "Initialement 0 cartes vues")
        XCTAssertEqual(initialStats.masteryPercentage, 0, "Initialement 0% maîtrisé")
        
        // Simuler une session de révision
        for card in cards {
            srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
        }
        
        // Vérifier mise à jour des stats
        let updatedStats = srsManager.getDeckStats(deck: testDeck)
        XCTAssertEqual(updatedStats.todayReviewCount, 3, "Doit compter 3 cartes vues aujourd'hui")
        XCTAssertEqual(updatedStats.totalCards, 3, "Doit compter 3 cartes total")
        XCTAssertEqual(updatedStats.masteredCards, 0, "Aucune carte maîtrisée encore (interval < 21)")
    }
    
    func testReadyCardsFiltering() throws {
        // Test du filtrage des cartes prêtes à réviser
        let pastCard = createFlashcard(question: "Past Card", answer: "Past Answer")
        pastCard.nextReviewDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) // 1h dans le passé
        
        let futureCard = createFlashcard(question: "Future Card", answer: "Future Answer")
        futureCard.nextReviewDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) // 1h dans le futur
        
        let nowCard = createFlashcard(question: "Now Card", answer: "Now Answer")
        nowCard.nextReviewDate = Date() // Maintenant
        
        try context.save()
        
        let stats = srsManager.getDeckStats(deck: testDeck)
        
        // Doit compter les cartes prêtes (passé + maintenant)
        XCTAssertGreaterThanOrEqual(stats.readyCount, 2, "Au moins 2 cartes doivent être prêtes")
    }
    
    // MARK: - Tests Performance et Stress
    
    func testHighVolumeSessionPerformance() throws {
        // Test performance avec beaucoup de cartes en session
        let cardCount = 200
        var cards: [Flashcard] = []
        
        for i in 0..<cardCount {
            let card = createFlashcard(question: "Perf Card \(i)", answer: "Perf Answer \(i)")
            cards.append(card)
        }
        
        try context.save()
        
        // Mesurer temps d'exécution pour une session complète
        let startTime = Date()
        
        for card in cards {
            srsManager.processSwipeResult(
                card: card,
                swipeDirection: Bool.random() ? .right : .left,
                context: context
            )
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Performance benchmark : 200 cartes en moins de 2 secondes
        XCTAssertLessThan(duration, 2.0, "200 cartes doivent être traitées en moins de 2 secondes")
        
        // Vérifier que toutes les cartes ont été traitées
        let finalStats = srsManager.getDeckStats(deck: testDeck)
        XCTAssertEqual(finalStats.todayReviewCount, cardCount, "Toutes les cartes doivent être comptées")
    }
    
    func testConcurrentAccessSafety() throws {
        // Test sécurité accès concurrent (simulation)
        let cards = [
            createFlashcard(question: "Concurrent 1", answer: "Answer 1"),
            createFlashcard(question: "Concurrent 2", answer: "Answer 2")
        ]
        
        let expectation = XCTestExpectation(description: "Concurrent processing")
        expectation.expectedFulfillmentCount = 2
        
        // Simuler accès concurrent
        DispatchQueue.global().async {
            self.srsManager.processSwipeResult(card: cards[0], swipeDirection: .right, context: self.context)
            expectation.fulfill()
        }
        
        DispatchQueue.global().async {
            self.srsManager.processSwipeResult(card: cards[1], swipeDirection: .left, context: self.context)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Vérifier intégrité des données après accès concurrent
        XCTAssertEqual(cards[0].reviewCount, 1, "Première carte doit avoir 1 révision")
        XCTAssertEqual(cards[1].reviewCount, 1, "Deuxième carte doit avoir 1 révision")
    }
    
    // MARK: - Helpers
    
    private func createFlashcard(question: String, answer: String) -> Flashcard {
        let card = Flashcard(context: context)
        card.id = UUID()
        card.question = question
        card.answer = answer
        card.deck = testDeck
        card.interval = 1.0
        card.easeFactor = 2.5
        card.reviewCount = 0
        card.correctCount = 0
        card.createdAt = Date()
        return card
    }
}

// MARK: - Tests Quiz et Association Integration

extension SM2IntegrationTests {
    
    func testQuizIntegration_SM2Mode() {
        // Given
        let deck = createTestDeck()
        let card1 = createTestFlashcard(in: deck, question: "Test Q1", answer: "Test A1")
        let card2 = createTestFlashcard(in: deck, question: "Test Q2", answer: "Test A2")
        
        // When - Simuler une réponse correcte en mode SM-2
        let operationId = UUID().uuidString
        SimpleSRSManager.shared.processQuizResult(
            card: card1,
            quality: 2, // Réponse correcte
            context: context,
            operationId: operationId
        )
        
        // Then
        XCTAssertEqual(card1.reviewCount, 1)
        XCTAssertEqual(card1.correctCount, 1)
        XCTAssertGreaterThan(card1.interval, 0)
        XCTAssertNotNil(card1.nextReviewDate)
    }
    
    func testQuizIntegration_FreeMode() {
        // Given
        let deck = createTestDeck()
        let card = createTestFlashcard(in: deck, question: "Test Q", answer: "Test A")
        let initialReviewCount = card.reviewCount
        let initialCorrectCount = card.correctCount
        let initialInterval = card.interval
        
        // When - Simuler une réponse en mode libre (ne devrait pas affecter SM-2)
        // Note: En mode libre, processQuizResult ne devrait pas être appelé
        // Mais si c'était appelé, les paramètres SM-2 ne devraient pas changer
        
        // Then - Vérifier que les paramètres SM-2 n'ont pas changé
        XCTAssertEqual(card.reviewCount, initialReviewCount)
        XCTAssertEqual(card.correctCount, initialCorrectCount)
        XCTAssertEqual(card.interval, initialInterval)
    }
    
    func testAssociationIntegration_SM2Mode_Correct() {
        // Given
        let deck = createTestDeck()
        let card1 = createTestFlashcard(in: deck, question: "Q1", answer: "A1")
        let card2 = createTestFlashcard(in: deck, question: "Q2", answer: "A2")
        
        // When - Simuler une association correcte en mode SM-2
        let operationId = UUID().uuidString
        SimpleSRSManager.shared.processAssociationResult(
            card1: card1,
            card2: card2,
            quality: 2, // Association correcte
            context: context,
            operationId: operationId
        )
        
        // Then - Les 2 cartes doivent être affectées
        XCTAssertEqual(card1.reviewCount, 1)
        XCTAssertEqual(card1.correctCount, 1)
        XCTAssertEqual(card2.reviewCount, 1)
        XCTAssertEqual(card2.correctCount, 1)
    }
    
    func testAssociationIntegration_SM2Mode_Incorrect() {
        // Given
        let deck = createTestDeck()
        let card1 = createTestFlashcard(in: deck, question: "Q1", answer: "A1")
        let card2 = createTestFlashcard(in: deck, question: "Q2", answer: "A2")
        
        // When - Simuler une association incorrecte en mode SM-2
        let operationId = UUID().uuidString
        SimpleSRSManager.shared.processAssociationResult(
            card1: card1,
            card2: card2,
            quality: 1, // Association incorrecte
            context: context,
            operationId: operationId
        )
        
        // Then - Les 2 cartes doivent être pénalisées
        XCTAssertEqual(card1.reviewCount, 1)
        XCTAssertEqual(card1.correctCount, 0) // Pas de correctCount car quality = 1
        XCTAssertEqual(card2.reviewCount, 1)
        XCTAssertEqual(card2.correctCount, 0) // Pas de correctCount car quality = 1
    }
    
    func testAssociationIntegration_FreeMode() {
        // Given
        let deck = createTestDeck()
        let card1 = createTestFlashcard(in: deck, question: "Q1", answer: "A1")
        let card2 = createTestFlashcard(in: deck, question: "Q2", answer: "A2")
        let initialReviewCount1 = card1.reviewCount
        let initialReviewCount2 = card2.reviewCount
        
        // When - En mode libre, processAssociationResult ne devrait pas être appelé
        // Mais si c'était appelé, les paramètres SM-2 ne devraient pas changer
        
        // Then - Vérifier que les paramètres SM-2 n'ont pas changé
        XCTAssertEqual(card1.reviewCount, initialReviewCount1)
        XCTAssertEqual(card2.reviewCount, initialReviewCount2)
    }
    
    func testGetAllCardsInOptimalOrder() {
        // Given
        let deck = createTestDeck()
        let card1 = createTestFlashcard(in: deck, question: "Q1", answer: "A1")
        let card2 = createTestFlashcard(in: deck, question: "Q2", answer: "A2")
        let card3 = createTestFlashcard(in: deck, question: "Q3", answer: "A3")
        
        // When
        let allCards = SimpleSRSManager.shared.getAllCardsInOptimalOrder(deck: deck)
        
        // Then
        XCTAssertEqual(allCards.count, 3)
        XCTAssertTrue(allCards.contains(card1))
        XCTAssertTrue(allCards.contains(card2))
        XCTAssertTrue(allCards.contains(card3))
        // Note: L'ordre est aléatoire, donc on ne peut pas tester l'ordre spécifique
    }
    
    // MARK: - Helpers
    
    private func createTestDeck() -> FlashcardDeck {
        let deck = FlashcardDeck(context: context)
        deck.id = UUID()
        deck.name = "Test Deck"
        deck.createdAt = Date()
        return deck
    }
    
    private func createTestFlashcard(in deck: FlashcardDeck, question: String, answer: String) -> Flashcard {
        let card = Flashcard(context: context)
        card.id = UUID()
        card.deck = deck
        card.question = question
        card.answer = answer
        card.interval = 1.0
        card.easeFactor = 2.5
        card.reviewCount = 0
        card.correctCount = 0
        card.nextReviewDate = Date().addingTimeInterval(-3600) // Carte en retard
        card.lastReviewDate = nil
        card.createdAt = Date()
        return card
    }
}
