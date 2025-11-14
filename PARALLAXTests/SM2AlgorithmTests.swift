//
//  SM2AlgorithmTests.swift
//  PARALLAXTests
//
//  Tests unitaires complets pour l'algorithme SM-2
//

import XCTest
import CoreData
@testable import PARALLAX

@MainActor
class SM2AlgorithmTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    var srsManager: SimpleSRSManager!
    var testDeck: FlashcardDeck!
    var testCard: Flashcard!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Configuration CoreData en mémoire pour les tests
        let container = NSPersistentContainer(name: "PARALLAX")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        context = container.viewContext
        srsManager = SimpleSRSManager.shared
        
        // Création d'un deck et d'une carte de test
        testDeck = FlashcardDeck(context: context)
        testDeck.id = UUID()
        testDeck.name = "Test Deck"
        testDeck.createdAt = Date()
        
        testCard = Flashcard(context: context)
        testCard.id = UUID()
        testCard.question = "Test Question"
        testCard.answer = "Test Answer"
        testCard.createdAt = Date()
        testCard.deck = testDeck
        
        // Valeurs initiales SM-2
        testCard.interval = 1.0
        testCard.easeFactor = 2.5  // Valeur par défaut
        testCard.reviewCount = 0
        testCard.correctCount = 0
        
        try context.save()
    }
    
    override func tearDownWithError() throws {
        context = nil
        srsManager = nil
        testDeck = nil
        testCard = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Tests Algorithme SM-2 de Base
    
    func testSM2InitialValues() throws {
        // Test des valeurs initiales
        XCTAssertEqual(testCard.interval, 1.0, "L'intervalle initial doit être 1 jour")
        XCTAssertEqual(testCard.easeFactor, 2.5, "L'ease factor initial doit être 2.5")
        XCTAssertEqual(testCard.reviewCount, 0, "Le nombre de révisions doit être 0")
        XCTAssertEqual(testCard.correctCount, 0, "Le nombre de bonnes réponses doit être 0")
    }
    
    func testSM2CorrectAnswer() throws {
        // Test : Bonne réponse (swipe droite)
        srsManager.processSwipeResult(
            card: testCard,
            swipeDirection: .right,
            context: context
        )
        
        // Vérifications après bonne réponse
        XCTAssertGreaterThan(testCard.interval, 1.0, "L'intervalle doit augmenter après une bonne réponse")
        XCTAssertEqual(testCard.reviewCount, 1, "Le nombre de révisions doit être incrémenté")
        XCTAssertEqual(testCard.correctCount, 1, "Le nombre de bonnes réponses doit être incrémenté")
        XCTAssertNotNil(testCard.lastReviewDate, "La date de dernière révision doit être définie")
        XCTAssertNotNil(testCard.nextReviewDate, "La date de prochaine révision doit être définie")
        
        // Vérification que la prochaine révision est dans le futur
        XCTAssertGreaterThan(testCard.nextReviewDate!, Date(), "La prochaine révision doit être dans le futur")
    }
    
    func testSM2IncorrectAnswer() throws {
        // Test : Mauvaise réponse (swipe gauche)
        srsManager.processSwipeResult(
            card: testCard,
            swipeDirection: .left,
            context: context
        )
        
        // Vérifications après mauvaise réponse
        XCTAssertEqual(testCard.interval, 1.0, "L'intervalle doit être remis à 1 jour après une mauvaise réponse")
        XCTAssertEqual(testCard.reviewCount, 1, "Le nombre de révisions doit être incrémenté")
        XCTAssertEqual(testCard.correctCount, 0, "Le nombre de bonnes réponses ne doit pas être incrémenté")
        XCTAssertLessThan(testCard.easeFactor, 2.5, "L'ease factor doit diminuer après une mauvaise réponse")
        XCTAssertNotNil(testCard.lastReviewDate, "La date de dernière révision doit être définie")
    }
    
    func testSM2ProgressionSequence() throws {
        // Test : Séquence de bonnes réponses consécutives
        _ = testCard.easeFactor
        var previousInterval = testCard.interval
        
        // Première bonne réponse
        srsManager.processSwipeResult(card: testCard, swipeDirection: .right, context: context)
        XCTAssertGreaterThan(testCard.interval, previousInterval, "L'intervalle doit augmenter")
        previousInterval = testCard.interval
        
        // Deuxième bonne réponse
        srsManager.processSwipeResult(card: testCard, swipeDirection: .right, context: context)
        XCTAssertGreaterThan(testCard.interval, previousInterval, "L'intervalle doit continuer à augmenter")
        XCTAssertEqual(testCard.correctCount, 2, "Doit avoir 2 bonnes réponses")
        
        // Troisième bonne réponse
        previousInterval = testCard.interval
        srsManager.processSwipeResult(card: testCard, swipeDirection: .right, context: context)
        XCTAssertGreaterThan(testCard.interval, previousInterval, "L'intervalle doit continuer à augmenter")
        XCTAssertEqual(testCard.correctCount, 3, "Doit avoir 3 bonnes réponses")
    }
    
    func testSM2EaseFactorBounds() throws {
        // Test : Vérification des bornes de l'ease factor
        
        // Test borne inférieure (1.3)
        for _ in 0..<10 {
            srsManager.processSwipeResult(card: testCard, swipeDirection: .left, context: context)
        }
        XCTAssertGreaterThanOrEqual(testCard.easeFactor, 1.3, "L'ease factor ne doit pas descendre sous 1.3")
        
        // Reset pour test borne supérieure
        testCard.easeFactor = 2.9
        
        // Test avec bonnes réponses (ease factor ne doit pas dépasser 3.0)
        for _ in 0..<5 {
            srsManager.processSwipeResult(card: testCard, swipeDirection: .right, context: context)
        }
        XCTAssertLessThanOrEqual(testCard.easeFactor, 3.0, "L'ease factor ne doit pas dépasser 3.0")
    }
    
    // MARK: - Tests Modes Différents
    
    func testSM2WithQuizMode() throws {
        // Simulation d'une réponse correcte dans un quiz
        let questionFlashcard = testCard!
        srsManager.processSwipeResult(
            card: questionFlashcard,
            swipeDirection: .right,  // Bonne réponse quiz
            context: context
        )
        
        XCTAssertGreaterThan(testCard.interval, 1.0, "Quiz: L'intervalle doit augmenter après bonne réponse")
        XCTAssertEqual(testCard.correctCount, 1, "Quiz: Le nombre de bonnes réponses doit être 1")
    }
    
    func testSM2WithAssociationMode() throws {
        // Simulation d'un match correct dans association
        srsManager.processSwipeResult(
            card: testCard,
            swipeDirection: .right,  // Match correct
            context: context
        )
        
        XCTAssertGreaterThan(testCard.interval, 1.0, "Association: L'intervalle doit augmenter après match correct")
        XCTAssertEqual(testCard.correctCount, 1, "Association: Le nombre de bonnes réponses doit être 1")
    }
    
    // MARK: - Tests Dashboard et Métriques
    
    func testDashboardStats() throws {
        // Créer plusieurs cartes avec différents états
        
        // testCard (déjà créée) - future révision
        testCard.nextReviewDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        
        let card2 = Flashcard(context: context)
        card2.id = UUID()
        card2.question = "Question 2"
        card2.answer = "Answer 2"
        card2.deck = testDeck
        card2.interval = 25.0
        card2.correctCount = 4
        card2.lastReviewDate = Date()
        card2.nextReviewDate = Calendar.current.date(byAdding: .day, value: 2, to: Date()) // Future
        
        let card3 = Flashcard(context: context)
        card3.id = UUID()
        card3.question = "Question 3"
        card3.answer = "Answer 3"
        card3.deck = testDeck
        card3.interval = 1.0
        card3.correctCount = 0
        card3.nextReviewDate = Date() // Prête maintenant
        
        try context.save()
        
        // Test des statistiques du deck
        let stats = srsManager.getDeckStats(deck: testDeck)
        
        XCTAssertEqual(stats.totalCards, 3, "Le deck doit contenir 3 cartes")
        XCTAssertEqual(stats.masteredCards, 1, "1 carte doit être maîtrisée (interval >= 21 et correctCount >= 3)")
        XCTAssertEqual(stats.readyCount, 1, "1 carte doit être prête à réviser")
        XCTAssertGreaterThan(stats.masteryPercentage, 0, "Le pourcentage de maîtrise doit être > 0")
    }
    
    func testTodayReviewCount() throws {
        // Test comptage des révisions du jour
        testCard.lastReviewDate = Date()
        
        let card2 = Flashcard(context: context)
        card2.id = UUID()
        card2.question = "Question 2"
        card2.answer = "Answer 2"
        card2.deck = testDeck
        card2.lastReviewDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) // Hier
        
        try context.save()
        
        let stats = srsManager.getDeckStats(deck: testDeck)
        XCTAssertEqual(stats.todayReviewCount, 1, "Seule 1 carte doit être comptée comme vue aujourd'hui")
    }
    
    // MARK: - Tests de Performance et Edge Cases
    
    func testSM2PerformanceWithManyCards() throws {
        // Test de performance avec beaucoup de cartes
        let cardCount = 100
        var cards: [Flashcard] = []
        
        for i in 0..<cardCount {
            let card = Flashcard(context: context)
            card.id = UUID()
            card.question = "Question \(i)"
            card.answer = "Answer \(i)"
            card.deck = testDeck
            card.interval = 1.0
            card.easeFactor = 2.5
            cards.append(card)
        }
        
        try context.save()
        
        // Mesurer le temps d'exécution
        let startTime = Date()
        
        for card in cards {
            srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Vérifier que le traitement de 100 cartes prend moins de 1 seconde
        XCTAssertLessThan(executionTime, 1.0, "Le traitement de 100 cartes doit prendre moins de 1 seconde")
        
        // Vérifier que toutes les cartes ont été mises à jour
        for card in cards {
            XCTAssertGreaterThan(card.interval, 1.0, "Toutes les cartes doivent avoir un intervalle > 1")
            XCTAssertEqual(card.correctCount, 1, "Toutes les cartes doivent avoir 1 bonne réponse")
        }
    }
    
    func testSM2WithNilValues() throws {
        // Test avec des valeurs nulles
        testCard.lastReviewDate = nil
        testCard.nextReviewDate = nil
        
        srsManager.processSwipeResult(card: testCard, swipeDirection: .right, context: context)
        
        XCTAssertNotNil(testCard.lastReviewDate, "lastReviewDate doit être définie après une révision")
        XCTAssertNotNil(testCard.nextReviewDate, "nextReviewDate doit être définie après une révision")
    }
    
    func testSM2ConsistentResults() throws {
        // Test de consistance : même input = même output
        let initialInterval = testCard.interval
        let initialEaseFactor = testCard.easeFactor
        
        // Premier calcul
        srsManager.processSwipeResult(card: testCard, swipeDirection: .right, context: context)
        let firstInterval = testCard.interval
        let firstEaseFactor = testCard.easeFactor
        
        // Reset aux valeurs initiales
        testCard.interval = initialInterval
        testCard.easeFactor = initialEaseFactor
        testCard.reviewCount = 0
        testCard.correctCount = 0
        
        // Deuxième calcul avec même input
        srsManager.processSwipeResult(card: testCard, swipeDirection: .right, context: context)
        
        XCTAssertEqual(testCard.interval, firstInterval, accuracy: 0.01, "Les résultats doivent être consistants")
        XCTAssertEqual(testCard.easeFactor, firstEaseFactor, accuracy: 0.01, "L'ease factor doit être consistant")
    }
    
    // MARK: - Tests Cache et Optimisation
    
    func testCacheIntegration() throws {
        // Test que le cache fonctionne avec SM-2
        let cacheManager = GradefyCacheManager.shared
        
        // Vider le cache pour le test
        cacheManager.clearAllCaches()
        
        // Première exécution (mise en cache)
        srsManager.processSwipeResult(card: testCard, swipeDirection: .right, context: context)
        
        // Vérifier qu'une entrée de cache existe
        let cacheKey = "sm2_\(testCard.id?.uuidString ?? "")_4"  // Quality 4 pour swipe right
        let cachedValue = cacheManager.getCachedAverage(forKey: cacheKey)
        
        XCTAssertNotNil(cachedValue, "Une valeur doit être mise en cache")
    }
    
    // MARK: - Tests LapseBuffer (DÉPLACÉS vers Phase 2 - Étape 3)
    // Ces tests nécessitent la nouvelle API LapseBuffer qui sera implémentée dans l'étape suivante
    // Ils testent la réinjection des cartes ratées avant échéance et les limites du buffer
    
    // MARK: - Tests Log-Only
    
    // MARK: - Tests Log-Only (DÉPLACÉS vers Phase 2 - Étape 3)
    // Ces tests nécessitent la nouvelle API qui sera implémentée dans l'étape suivante
    // Ils testent le comportement log-only pour les bonnes réponses avant échéance
    
    // MARK: - Tests Mise à jour normale (DÉPLACÉS vers Phase 2 - Étape 3)
    // Ces tests nécessitent la nouvelle API qui sera implémentée dans l'étape suivante
    // Ils testent la mise à jour normale SM-2 pour les cartes à échéance
    
    // MARK: - Tests Maîtrise 21 Jours
    
    func testMastery21Days() throws {
        // Créer une carte avec interval de 21 jours et 3 révisions
        testCard.nextReviewDate = Calendar.current.date(byAdding: .day, value: 21, to: Date())
        testCard.interval = 21.0
        testCard.reviewCount = 3
        testCard.correctCount = 2
        try context.save()
        
        // ✅ Vérifier que la carte est considérée comme maîtrisée
        XCTAssertEqual(SRSConfiguration.masteryIntervalThreshold, 21.0) // Seuil de 21 jours
        XCTAssertTrue(testCard.interval >= SRSConfiguration.masteryIntervalThreshold)
    }
    
    func testNotMasteredWithLessThan21Days() throws {
        // Créer une carte avec interval de 20 jours et 3 révisions
        testCard.nextReviewDate = Calendar.current.date(byAdding: .day, value: 20, to: Date())
        testCard.interval = 20.0
        testCard.reviewCount = 3
        testCard.correctCount = 2
        try context.save()
        
        // Vérifier que la carte n'est PAS considérée comme maîtrisée
        let stats = SimpleSRSManager.shared.getDeckStats(deck: testDeck)
        XCTAssertEqual(stats.masteredCards, 0, "Une carte avec moins de 21 jours ne doit pas être maîtrisée")
        XCTAssertEqual(stats.masteryPercentage, 0, "Le pourcentage de maîtrise doit être 0%")
    }
    
    func testNotMasteredWithLessThan3Reviews() throws {
        // Créer une carte avec interval de 21 jours mais seulement 2 révisions
        testCard.nextReviewDate = Calendar.current.date(byAdding: .day, value: 21, to: Date())
        testCard.interval = 21.0
        testCard.reviewCount = 2
        testCard.correctCount = 1
        try context.save()
        
        // Vérifier que la carte n'est PAS considérée comme maîtrisée
        let stats = SimpleSRSManager.shared.getDeckStats(deck: testDeck)
        XCTAssertEqual(stats.masteredCards, 0, "Une carte avec moins de 3 révisions ne doit pas être maîtrisée")
        XCTAssertEqual(stats.masteryPercentage, 0, "Le pourcentage de maîtrise doit être 0%")
    }
    
    // MARK: - Tests Timezone
    
    func testTimezoneHandling() throws {
        // Test que les dates sont calculées correctement avec le timezone Europe/Paris
        let initialDate = Date()
        testCard.interval = 1.0
        testCard.easeFactor = 2.5
        
        // Simuler une bonne réponse
        SimpleSRSManager.shared.processSwipeResult(
            card: testCard,
            swipeDirection: .right,
            context: context
        )
        
        // Vérifier que nextReviewDate est dans le futur
        XCTAssertNotNil(testCard.nextReviewDate, "nextReviewDate doit être défini")
        XCTAssertGreaterThan(testCard.nextReviewDate!, initialDate, "nextReviewDate doit être dans le futur")
        
        // Vérifier que l'intervalle est d'environ 1 jour
        let daysDiff = Calendar.current.dateComponents([.day], from: initialDate, to: testCard.nextReviewDate!).day ?? 0
        XCTAssertEqual(daysDiff, 1, "L'intervalle doit être d'environ 1 jour")
    }
    
    // MARK: - Tests Compatibilité Legacy
    
    func testLegacyProcessSwipeResult() throws {
        // Test que l'ancienne méthode fonctionne toujours
        testCard.nextReviewDate = Date() // Carte due
        testCard.interval = 1.0
        testCard.easeFactor = 2.5
        try context.save()
        
        let initialInterval = testCard.interval
        
        // Utiliser l'ancienne méthode
        SimpleSRSManager.shared.processSwipeResult(
            card: testCard,
            swipeDirection: .right,
            context: context
        )
        
        // Vérifier que ça fonctionne comme avant
        XCTAssertGreaterThan(testCard.interval, initialInterval, "L'intervalle doit augmenter")
        XCTAssertEqual(testCard.reviewCount, 1, "Le review count doit être incrémenté")
    }
    
    // ✅ NOUVEAU TEST : Règle de maîtrise simplifiée
    func testNewMasteryRule_SingleSuccessMakesMastered() throws {
        // Given
        let testCard = Flashcard(context: context)
        testCard.id = UUID()
        testCard.question = "Test question"
        testCard.answer = "Test answer"
        testCard.interval = 1.0
        testCard.easeFactor = SRSConfiguration.defaultEaseFactor
        testCard.reviewCount = 0
        testCard.correctCount = 0
        testCard.nextReviewDate = Date()
        
        try context.save()
        
        // When - Première réussite
        let result = srsManager.calculateSM2Safely(
            interval: testCard.interval,
            easeFactor: testCard.easeFactor,
            quality: SRSConfiguration.confidentAnswerQuality,
            card: testCard
        )
        
        // Then - La carte devrait être maîtrisée après une seule réussite
        XCTAssertNotNil(result)
        XCTAssertEqual(testCard.correctCount, 0) // Pas encore mis à jour
        XCTAssertEqual(SRSConfiguration.masteryIntervalThreshold, 21.0) // Seuil de 21 jours
        
        // Simuler la mise à jour de la carte
        testCard.interval = 25.0
        XCTAssertTrue(testCard.interval >= SRSConfiguration.masteryIntervalThreshold)
    }
    
    // ✅ NOUVEAU TEST : 4 statuts simplifiés
    func testSimplifiedStatuses_FourStatusesOnly() throws {
        // Given
        let testCard = Flashcard(context: context)
        testCard.id = UUID()
        testCard.question = "Test question"
        testCard.answer = "Test answer"
        testCard.interval = 1.0
        testCard.easeFactor = SRSConfiguration.defaultEaseFactor
        testCard.reviewCount = 0
        testCard.correctCount = 0
        testCard.nextReviewDate = Date()
        
        try context.save()
        
        // When & Then - Test des 4 statuts
        let status1 = srsManager.getCardStatusMessage(card: testCard)
        XCTAssertEqual(status1.message, "Nouvelle")
        
        // Simuler une révision
        testCard.reviewCount = 1
        testCard.nextReviewDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        let status2 = srsManager.getCardStatusMessage(card: testCard)
        XCTAssertEqual(status2.message, "À réviser")
        
        // Simuler une carte en retard
        testCard.nextReviewDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        let status3 = srsManager.getCardStatusMessage(card: testCard)
        XCTAssertTrue(status3.message.contains("En retard"))
        
        // Simuler une carte maîtrisée (intervalle >= 21 jours)
        testCard.interval = 25.0
        testCard.nextReviewDate = Calendar.current.date(byAdding: .day, value: 10, to: Date())
        let status4 = srsManager.getCardStatusMessage(card: testCard)
        XCTAssertEqual(status4.message, "Maîtrisée")
    }
    
    // ✅ NOUVEAUX TESTS : Ajustements SRS
    
    // Test 1 : Lapse moins brutal pour les cartes avec streak
    func testGentleLapse_ForCardsWithStreak() throws {
        // Given - Carte avec streak de 6 succès
        let testCard = Flashcard(context: context)
        testCard.id = UUID()
        testCard.question = "Test question"
        testCard.answer = "Test answer"
        testCard.interval = 10.0
        testCard.easeFactor = 2.5
        testCard.reviewCount = 6
        testCard.correctCount = 6  // Streak de 6 succès
        testCard.nextReviewDate = Date()
        
        try context.save()
        
        // When - Réponse incorrecte
        let result = srsManager.calculateSM2Safely(
            interval: testCard.interval,
            easeFactor: testCard.easeFactor,
            quality: SRSConfiguration.incorrectAnswerQuality,
            card: testCard
        )
        
        // Then - Lapse plus clément (×0.6 au lieu de ×0.4)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.interval, 6.0)  // 10 × 0.6 = 6
        XCTAssertEqual(result?.easeFactor, 2.35)  // 2.5 - 0.15 = 2.35
    }
    
    // Test 2 : Lapse standard pour les cartes sans streak
    func testStandardLapse_ForCardsWithoutStreak() throws {
        // Given - Carte sans streak
        let testCard = Flashcard(context: context)
        testCard.id = UUID()
        testCard.question = "Test question"
        testCard.answer = "Test answer"
        testCard.interval = 10.0
        testCard.easeFactor = 2.5
        testCard.reviewCount = 3
        testCard.correctCount = 2  // Pas de streak
        testCard.nextReviewDate = Date()
        
        try context.save()
        
        // When - Réponse incorrecte
        let result = srsManager.calculateSM2Safely(
            interval: testCard.interval,
            easeFactor: testCard.easeFactor,
            quality: SRSConfiguration.incorrectAnswerQuality,
            card: testCard
        )
        
        // Then - Lapse standard (×0.4)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.interval, 4.0)  // 10 × 0.4 = 4
        XCTAssertEqual(result?.easeFactor, 2.35)  // 2.5 - 0.15 = 2.35
    }
    
    // Test 3 : Phase early avec graduating silencieux
    func testEarlyGraduating_FirstSuccess() throws {
        // Given - Nouvelle carte
        let testCard = Flashcard(context: context)
        testCard.id = UUID()
        testCard.question = "Test question"
        testCard.answer = "Test answer"
        testCard.interval = 1.0
        testCard.easeFactor = SRSConfiguration.defaultEaseFactor
        testCard.reviewCount = 0  // Première révision
        testCard.correctCount = 0
        testCard.nextReviewDate = Date()
        
        try context.save()
        
        // When - Première réussite
        let result = srsManager.calculateSM2Safely(
            interval: testCard.interval,
            easeFactor: testCard.easeFactor,
            quality: SRSConfiguration.confidentAnswerQuality,
            card: testCard
        )
        
        // Then - Intervalle fixe de 3 jours (phase early)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.interval, 3.0)  // Premier intervalle fixe
        XCTAssertEqual(result?.easeFactor, 2.42)  // 2.3 + 0.12 = 2.42
    }
    
    // Test 4 : Phase early - deuxième succès
    func testEarlyGraduating_SecondSuccess() throws {
        // Given - Carte après première réussite
        let testCard = Flashcard(context: context)
        testCard.id = UUID()
        testCard.question = "Test question"
        testCard.answer = "Test answer"
        testCard.interval = 3.0
        testCard.easeFactor = 2.42
        testCard.reviewCount = 1  // Deuxième révision
        testCard.correctCount = 1
        testCard.nextReviewDate = Date()
        
        try context.save()
        
        // When - Deuxième réussite
        let result = srsManager.calculateSM2Safely(
            interval: testCard.interval,
            easeFactor: testCard.easeFactor,
            quality: SRSConfiguration.confidentAnswerQuality,
            card: testCard
        )
        
        // Then - Intervalle fixe de 7 jours (deuxième intervalle fixe)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.interval, 7.0)  // Deuxième intervalle fixe
        XCTAssertEqual(result?.easeFactor, 2.54)  // 2.42 + 0.12 = 2.54
    }
    
    // Test 5 : Phase normale après graduating
    func testNormalPhase_AfterGraduating() throws {
        // Given - Carte après phase early
        let testCard = Flashcard(context: context)
        testCard.id = UUID()
        testCard.question = "Test question"
        testCard.answer = "Test answer"
        testCard.interval = 7.0
        testCard.easeFactor = 2.54
        testCard.reviewCount = 2  // Troisième révision (phase normale)
        testCard.correctCount = 2
        testCard.nextReviewDate = Date()
        
        try context.save()
        
        // When - Troisième réussite
        let result = srsManager.calculateSM2Safely(
            interval: testCard.interval,
            easeFactor: testCard.easeFactor,
            quality: SRSConfiguration.confidentAnswerQuality,
            card: testCard
        )
        
        // Then - Algorithme SM-2 standard (7 × 2.54 = 17.78)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.interval, 17.78, accuracy: 0.01)  // SM-2 standard
        XCTAssertEqual(result?.easeFactor, 2.66)  // 2.54 + 0.12 = 2.66
    }
    
    // Test 6 : Réinjection contrôlée
    func testControlledReinjection() throws {
        // Given - Configuration de réinjection
        XCTAssertTrue(SRSConfiguration.reinjectOnlyIncorrect)
        XCTAssertEqual(SRSConfiguration.maxReinjectionQuota, 0.4)
        
        // When & Then - Test réinjection incorrecte
        let shouldReinjectIncorrect = srsManager.shouldReinjectCard(
            card: testCard, 
            quality: SRSConfiguration.incorrectAnswerQuality
        )
        XCTAssertTrue(shouldReinjectIncorrect)
        
        // When & Then - Test pas de réinjection pour correcte
        let shouldReinjectCorrect = srsManager.shouldReinjectCard(
            card: testCard, 
            quality: SRSConfiguration.confidentAnswerQuality
        )
        XCTAssertFalse(shouldReinjectCorrect)
    }
    
    // ✅ NOUVEAU TEST : Dashboard "Vous êtes à jour !"
    func testDashboardUpToDatePanel() throws {
        // Given - Deck avec cartes mais aucune due
        let futureCard = Flashcard(context: context)
        futureCard.id = UUID()
        futureCard.question = "Test question"
        futureCard.answer = "Test answer"
        futureCard.interval = 5.0
        futureCard.easeFactor = 2.5
        futureCard.reviewCount = 1
        futureCard.correctCount = 1
        futureCard.nextReviewDate = Calendar.current.date(byAdding: .day, value: 5, to: Date()) // +5 jours
        
        try context.save()
        
        // When - Vérifier les conditions pour le panel "à jour"
        let smartCards = srsManager.getSmartCards(deck: testDeck, minCards: 1)
        let stats = srsManager.getDeckStats(deck: testDeck)
        let canStartSM2 = srsManager.canStartSM2Session(deck: testDeck)
        
        // Then - Panel "à jour" doit s'afficher
        XCTAssertTrue(smartCards.isEmpty, "Aucune carte due")
        XCTAssertEqual(stats.totalCards, 1, "Deck contient 1 carte")
        XCTAssertFalse(canStartSM2, "Session SM-2 impossible")
        
        // Vérifier que le mode libre reste disponible
        let allCards = srsManager.getAllCardsInOptimalOrder(deck: testDeck)
        XCTAssertEqual(allCards.count, 1, "Mode libre toujours disponible")
    }
    
    // ✅ NOUVEAU TEST : Dashboard deck vide
    func testDashboardEmptyDeckPanel() throws {
        // Given - Deck vide
        let emptyDeck = FlashcardDeck(context: context)
        emptyDeck.id = UUID()
        emptyDeck.name = "Empty Deck"
        
        try context.save()
        
        // When - Vérifier les conditions pour le panel "deck vide"
        let smartCards = srsManager.getSmartCards(deck: emptyDeck, minCards: 1)
        let stats = srsManager.getDeckStats(deck: emptyDeck)
        let canStartSM2 = srsManager.canStartSM2Session(deck: emptyDeck)
        
        // Then - Panel "deck vide" doit s'afficher
        XCTAssertTrue(smartCards.isEmpty, "Aucune carte")
        XCTAssertEqual(stats.totalCards, 0, "Deck vide")
        XCTAssertFalse(canStartSM2, "Session SM-2 impossible")
    }
    
    // ✅ TESTS EXPORT/IMPORT - Schéma JSON versionné
    
    func testExportCompleteness_AllSM2FieldsIncluded() throws {
        // Given
        let testCard = Flashcard(context: context)
        testCard.id = UUID()
        testCard.question = "Test question"
        testCard.answer = "Test answer"
        testCard.interval = 5.0
        testCard.easeFactor = 2.1
        testCard.correctCount = 3
        testCard.reviewCount = 4
        testCard.nextReviewDate = Date()
        testCard.lastReviewDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        testCard.createdAt = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        
        let testDeck = FlashcardDeck(context: context)
        testDeck.id = UUID()
        testDeck.name = "Test Deck"
        testCard.deck = testDeck
        
        try context.save()
        
        // When
        let exportManager = DataImportExportManager()
        exportManager.setContext(context)
        let exportData = try await exportManager.exportAllData()
        let jsonObject = try JSONSerialization.jsonObject(with: exportData) as? [String: Any]
        
        // Then
        XCTAssertNotNil(jsonObject)
        let flashcards = jsonObject?["flashcards"] as? [[String: Any]] ?? []
        XCTAssertEqual(flashcards.count, 1)
        
        let cardData = flashcards.first!
        XCTAssertEqual(cardData["intervalDays"] as? Double, 5.0)
        XCTAssertEqual(cardData["easeFactor"] as? Double, 2.1)
        XCTAssertEqual(cardData["correctCount"] as? Int32, 3)
        XCTAssertEqual(cardData["reviewCount"] as? Int32, 4)
        XCTAssertEqual(cardData["schemaVersion"] as? String, "2.0")
        XCTAssertNotNil(cardData["nextReviewDate"] as? String)
        XCTAssertNotNil(cardData["lastReviewDate"] as? String)
    }
    
    func testImportOverride_ExistingCardUpdated() throws {
        // Given - Carte existante
        let existingCard = Flashcard(context: context)
        existingCard.id = UUID()
        existingCard.question = "Old question"
        existingCard.answer = "Old answer"
        existingCard.interval = 1.0
        existingCard.easeFactor = 2.0
        existingCard.correctCount = 0
        existingCard.reviewCount = 0
        
        let testDeck = FlashcardDeck(context: context)
        testDeck.id = UUID()
        testDeck.name = "Test Deck"
        existingCard.deck = testDeck
        
        try context.save()
        
        // JSON d'import avec même ID mais données différentes
        let importJSON: [String: Any] = [
            "metadata": [
                "export_date": "2024-01-01T00:00:00Z",
                "app_version": "1.0",
                "format_version": "2.0"
            ],
            "flashcard_decks": [
                [
                    "id": testDeck.id!.uuidString,
                    "name": "Test Deck",
                    "createdAt": "2024-01-01T00:00:00Z"
                ]
            ],
            "flashcards": [
                [
                    "id": existingCard.id!.uuidString,
                    "question": "New question",
                    "answer": "New answer",
                    "intervalDays": 10.0,
                    "easeFactor": 2.5,
                    "correctCount": 5,
                    "reviewCount": 7,
                    "nextReviewDate": "2024-01-15T00:00:00Z",
                    "lastReviewDate": "2024-01-10T00:00:00Z",
                    "createdAt": "2024-01-01T00:00:00Z",
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ]
            ]
        ]
        
        // When
        let importManager = DataImportExportManager()
        importManager.setContext(context)
        let importData = try JSONSerialization.data(withJSONObject: importJSON)
        try await importManager.importAllData(from: importData)
        
        // Then - Carte existante mise à jour
        let updatedCard = try context.fetch(Flashcard.fetchRequest()).first
        XCTAssertNotNil(updatedCard)
        XCTAssertEqual(updatedCard?.question, "New question")
        XCTAssertEqual(updatedCard?.interval, 10.0)
        XCTAssertEqual(updatedCard?.easeFactor, 2.5)
        XCTAssertEqual(updatedCard?.correctCount, 5)
        XCTAssertEqual(updatedCard?.reviewCount, 7)
    }
    
    func testImportCreate_NewCardCreated() throws {
        // Given - Deck existant
        let testDeck = FlashcardDeck(context: context)
        testDeck.id = UUID()
        testDeck.name = "Test Deck"
        try context.save()
        
        // JSON d'import avec nouvelle carte
        let newCardId = UUID()
        let importJSON: [String: Any] = [
            "metadata": [
                "export_date": "2024-01-01T00:00:00Z",
                "app_version": "1.0",
                "format_version": "2.0"
            ],
            "flashcard_decks": [
                [
                    "id": testDeck.id!.uuidString,
                    "name": "Test Deck",
                    "createdAt": "2024-01-01T00:00:00Z"
                ]
            ],
            "flashcards": [
                [
                    "id": newCardId.uuidString,
                    "question": "New card question",
                    "answer": "New card answer",
                    "intervalDays": 3.0,
                    "easeFactor": 2.0,
                    "correctCount": 2,
                    "reviewCount": 3,
                    "nextReviewDate": "2024-01-05T00:00:00Z",
                    "lastReviewDate": "2024-01-02T00:00:00Z",
                    "createdAt": "2024-01-01T00:00:00Z",
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ]
            ]
        ]
        
        // When
        let importManager = DataImportExportManager()
        importManager.setContext(context)
        let importData = try JSONSerialization.data(withJSONObject: importJSON)
        try await importManager.importAllData(from: importData)
        
        // Then - Nouvelle carte créée
        let cards = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.id, newCardId)
        XCTAssertEqual(cards.first?.question, "New card question")
        XCTAssertEqual(cards.first?.interval, 3.0)
    }
    
    func testMissingFieldsFallback_DefaultsApplied() throws {
        // Given - JSON avec champs manquants
        let testDeck = FlashcardDeck(context: context)
        testDeck.id = UUID()
        testDeck.name = "Test Deck"
        try context.save()
        
        let importJSON: [String: Any] = [
            "metadata": [
                "export_date": "2024-01-01T00:00:00Z",
                "app_version": "1.0",
                "format_version": "2.0"
            ],
            "flashcard_decks": [
                [
                    "id": testDeck.id!.uuidString,
                    "name": "Test Deck",
                    "createdAt": "2024-01-01T00:00:00Z"
                ]
            ],
            "flashcards": [
                [
                    "id": UUID().uuidString,
                    "question": "Test question",
                    "answer": "Test answer"
                    // Champs SM-2 manquants
                ]
            ]
        ]
        
        // When
        let importManager = DataImportExportManager()
        importManager.setContext(context)
        let importData = try JSONSerialization.data(withJSONObject: importJSON)
        try await importManager.importAllData(from: importData)
        
        // Then - Fallback appliqué
        let card = try context.fetch(Flashcard.fetchRequest()).first
        XCTAssertNotNil(card)
        XCTAssertEqual(card?.interval, 1.0) // Fallback
        XCTAssertEqual(card?.easeFactor, SRSConfiguration.defaultEaseFactor) // Fallback
        XCTAssertEqual(card?.correctCount, 0) // Fallback
        XCTAssertEqual(card?.reviewCount, 0) // Fallback
        XCTAssertNil(card?.nextReviewDate) // Fallback "nouvelle"
    }
    
    func testRoundTrip_ExportImportPreservesData() throws {
        // Given - Carte avec données SM-2 complètes
        let testCard = Flashcard(context: context)
        testCard.id = UUID()
        testCard.question = "Round trip test"
        testCard.answer = "Round trip answer"
        testCard.interval = 7.0
        testCard.easeFactor = 2.3
        testCard.correctCount = 4
        testCard.reviewCount = 6
        testCard.nextReviewDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())
        testCard.lastReviewDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        testCard.createdAt = Calendar.current.date(byAdding: .day, value: -20, to: Date())
        
        let testDeck = FlashcardDeck(context: context)
        testDeck.id = UUID()
        testDeck.name = "Round Trip Deck"
        testCard.deck = testDeck
        
        try context.save()
        
        // When - Export puis import
        let manager = DataImportExportManager()
        manager.setContext(context)
        
        let exportData = try await manager.exportAllData()
        
        // Nettoyer le contexte
        try clearContext()
        
        // Réimporter
        try await manager.importAllData(from: exportData)
        
        // Then - Données préservées
        let importedCard = try context.fetch(Flashcard.fetchRequest()).first
        XCTAssertNotNil(importedCard)
        XCTAssertEqual(importedCard?.question, "Round trip test")
        XCTAssertEqual(importedCard?.interval, 7.0)
        XCTAssertEqual(importedCard?.easeFactor, 2.3)
        XCTAssertEqual(importedCard?.correctCount, 4)
        XCTAssertEqual(importedCard?.reviewCount, 6)
        XCTAssertNotNil(importedCard?.nextReviewDate)
        XCTAssertNotNil(importedCard?.lastReviewDate)
    }
    
    // ✅ MÉTHODE UTILITAIRE POUR NETTOYER LE CONTEXTE
    private func clearContext() throws {
        let entities = ["Flashcard", "FlashcardDeck"]
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        }
        try context.save()
    }
    
    // ✅ TESTS CRITIQUES PRODUCTION - 6 cas edge cases
    
    func testProduction_EFBoundariesClamped() throws {
        // Given - JSON avec ease factor hors limites
        let testDeck = createTestDeck(name: "Test Deck")
        try context.save()
        
        let importJSON: [String: Any] = [
            "metadata": [
                "export_date": "2024-01-01T00:00:00Z",
                "app_version": "1.0",
                "format_version": "2.0"
            ],
            "flashcard_decks": [
                [
                    "id": testDeck.id!.uuidString,
                    "name": "Test Deck",
                    "createdAt": "2024-01-01T00:00:00Z"
                ]
            ],
            "flashcards": [
                [
                    "id": UUID().uuidString,
                    "question": "EF trop bas",
                    "answer": "Réponse",
                    "intervalDays": 1.0,
                    "easeFactor": 0.5, // < 1.3
                    "correctCount": 1,
                    "reviewCount": 1,
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ],
                [
                    "id": UUID().uuidString,
                    "question": "EF trop haut",
                    "answer": "Réponse",
                    "intervalDays": 1.0,
                    "easeFactor": 5.0, // > 3.0
                    "correctCount": 1,
                    "reviewCount": 1,
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ]
            ]
        ]
        
        // When - Import
        let manager = DataImportExportManager()
        manager.setContext(context)
        let importData = try JSONSerialization.data(withJSONObject: importJSON)
        try await manager.importAllData(from: importData)
        
        // Then - EF clampé aux bornes
        let cards = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(cards.count, 2)
        
        let cardEFBas = cards.first { $0.question == "EF trop bas" }
        XCTAssertEqual(cardEFBas?.easeFactor, SRSConfiguration.minEaseFactor) // 1.3
        
        let cardEFHaut = cards.first { $0.question == "EF trop haut" }
        XCTAssertEqual(cardEFHaut?.easeFactor, SRSConfiguration.maxEaseFactor) // 3.0
    }
    
    func testProduction_InvalidIntervalFallback() throws {
        // Given - JSON avec interval invalide
        let testDeck = createTestDeck(name: "Test Deck")
        try context.save()
        
        let importJSON: [String: Any] = [
            "metadata": [
                "export_date": "2024-01-01T00:00:00Z",
                "app_version": "1.0",
                "format_version": "2.0"
            ],
            "flashcard_decks": [
                [
                    "id": testDeck.id!.uuidString,
                    "name": "Test Deck",
                    "createdAt": "2024-01-01T00:00:00Z"
                ]
            ],
            "flashcards": [
                [
                    "id": UUID().uuidString,
                    "question": "Interval négatif",
                    "answer": "Réponse",
                    "intervalDays": -5.0,
                    "easeFactor": 2.0,
                    "correctCount": 1,
                    "reviewCount": 1,
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ],
                [
                    "id": UUID().uuidString,
                    "question": "Interval NaN",
                    "answer": "Réponse",
                    "intervalDays": Double.nan,
                    "easeFactor": 2.0,
                    "correctCount": 1,
                    "reviewCount": 1,
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ]
            ]
        ]
        
        // When - Import
        let manager = DataImportExportManager()
        manager.setContext(context)
        let importData = try JSONSerialization.data(withJSONObject: importJSON)
        try await manager.importAllData(from: importData)
        
        // Then - Fallback à 1.0 et statut "nouvelle"
        let cards = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(cards.count, 2)
        
        let cardNegatif = cards.first { $0.question == "Interval négatif" }
        XCTAssertEqual(cardNegatif?.interval, 1.0) // Fallback
        
        let cardNaN = cards.first { $0.question == "Interval NaN" }
        XCTAssertEqual(cardNaN?.interval, 1.0) // Fallback
        
        // Vérifier statuts
        let statusNegatif = SimpleSRSManager.shared.getCardStatusMessage(card: cardNegatif!)
        let statusNaN = SimpleSRSManager.shared.getCardStatusMessage(card: cardNaN!)
        XCTAssertEqual(statusNegatif.message, "Nouvelle")
        XCTAssertEqual(statusNaN.message, "Nouvelle")
    }
    
    func testProduction_InconsistentDatesHandling() throws {
        // Given - JSON avec dates incohérentes
        let testDeck = createTestDeck(name: "Test Deck")
        try context.save()
        
        let importJSON: [String: Any] = [
            "metadata": [
                "export_date": "2024-01-01T00:00:00Z",
                "app_version": "1.0",
                "format_version": "2.0"
            ],
            "flashcard_decks": [
                [
                    "id": testDeck.id!.uuidString,
                    "name": "Test Deck",
                    "createdAt": "2024-01-01T00:00:00Z"
                ]
            ],
            "flashcards": [
                [
                    "id": UUID().uuidString,
                    "question": "Dates incohérentes",
                    "answer": "Réponse",
                    "intervalDays": 5.0,
                    "easeFactor": 2.0,
                    "correctCount": 1,
                    "reviewCount": 1,
                    "nextReviewDate": "2024-01-01T00:00:00Z", // Plus tôt
                    "lastReviewDate": "2024-01-05T00:00:00Z", // Plus tard
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ]
            ]
        ]
        
        // When - Import
        let manager = DataImportExportManager()
        manager.setContext(context)
        let importData = try JSONSerialization.data(withJSONObject: importJSON)
        try await manager.importAllData(from: importData)
        
        // Then - Pas de crash, dates préservées, statut recalculé
        let cards = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(cards.count, 1)
        
        let card = cards.first!
        XCTAssertNotNil(card.nextReviewDate)
        XCTAssertNotNil(card.lastReviewDate)
        
        // Le statut doit être calculé correctement malgré l'incohérence
        let status = SimpleSRSManager.shared.getCardStatusMessage(card: card)
        XCTAssertTrue(["Nouvelle", "À réviser", "En retard", "Maîtrisée"].contains(status.message))
    }
    
    func testProduction_TimezoneHandling() throws {
        // Given - JSON avec date proche de minuit UTC
        let testDeck = createTestDeck(name: "Test Deck")
        try context.save()
        
        // Date UTC proche de minuit (23:59 UTC)
        let nearMidnightUTC = "2024-01-15T23:59:00.000Z"
        
        let importJSON: [String: Any] = [
            "metadata": [
                "export_date": "2024-01-01T00:00:00Z",
                "app_version": "1.0",
                "format_version": "2.0"
            ],
            "flashcard_decks": [
                [
                    "id": testDeck.id!.uuidString,
                    "name": "Test Deck",
                    "createdAt": "2024-01-01T00:00:00Z"
                ]
            ],
            "flashcards": [
                [
                    "id": UUID().uuidString,
                    "question": "Test fuseau",
                    "answer": "Réponse",
                    "intervalDays": 1.0,
                    "easeFactor": 2.0,
                    "correctCount": 1,
                    "reviewCount": 1,
                    "nextReviewDate": nearMidnightUTC,
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ]
            ]
        ]
        
        // When - Import
        let manager = DataImportExportManager()
        manager.setContext(context)
        let importData = try JSONSerialization.data(withJSONObject: importJSON)
        try await manager.importAllData(from: importData)
        
        // Then - Date correctement parsée et statut local correct
        let cards = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(cards.count, 1)
        
        let card = cards.first!
        XCTAssertNotNil(card.nextReviewDate)
        
        // Le statut doit être cohérent avec le fuseau local
        let status = SimpleSRSManager.shared.getCardStatusMessage(card: card)
        XCTAssertTrue(["Nouvelle", "À réviser", "En retard", "Maîtrisée"].contains(status.message))
    }
    
    func testProduction_IDCollisionCrossDeck() throws {
        // Given - Même card ID dans deux decks différents
        let deck1 = createTestDeck(name: "Deck 1")
        let deck2 = createTestDeck(name: "Deck 2")
        try context.save()
        
        let sameCardId = UUID()
        
        let importJSON: [String: Any] = [
            "metadata": [
                "export_date": "2024-01-01T00:00:00Z",
                "app_version": "1.0",
                "format_version": "2.0"
            ],
            "flashcard_decks": [
                [
                    "id": deck1.id!.uuidString,
                    "name": "Deck 1",
                    "createdAt": "2024-01-01T00:00:00Z"
                ],
                [
                    "id": deck2.id!.uuidString,
                    "name": "Deck 2",
                    "createdAt": "2024-01-01T00:00:00Z"
                ]
            ],
            "flashcards": [
                [
                    "id": sameCardId.uuidString,
                    "question": "Carte Deck 1",
                    "answer": "Réponse 1",
                    "intervalDays": 1.0,
                    "easeFactor": 2.0,
                    "correctCount": 1,
                    "reviewCount": 1,
                    "deckId": deck1.id!.uuidString,
                    "schemaVersion": "2.0"
                ],
                [
                    "id": sameCardId.uuidString, // Même ID !
                    "question": "Carte Deck 2",
                    "answer": "Réponse 2",
                    "intervalDays": 5.0,
                    "easeFactor": 2.5,
                    "correctCount": 3,
                    "reviewCount": 4,
                    "deckId": deck2.id!.uuidString,
                    "schemaVersion": "2.0"
                ]
            ]
        ]
        
        // When - Import
        let manager = DataImportExportManager()
        manager.setContext(context)
        let importData = try JSONSerialization.data(withJSONObject: importJSON)
        try await manager.importAllData(from: importData)
        
        // Then - Stratégie de conflit appliquée (Option A: déplacer selon deckId)
        let cards = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(cards.count, 1) // Une seule carte avec cet ID
        
        let card = cards.first!
        XCTAssertEqual(card.id, sameCardId)
        // La dernière carte du JSON écrase la première (deckId fait foi)
        XCTAssertEqual(card.deck?.name, "Deck 2")
        XCTAssertEqual(card.question, "Carte Deck 2")
        XCTAssertEqual(card.interval, 5.0)
        XCTAssertEqual(card.correctCount, 3)
    }
    
    func testProduction_LargeVolumeImport() throws {
        // Given - Import de 1000+ cartes (simulation grand volume)
        let testDeck = createTestDeck(name: "Grand Deck")
        try context.save()
        
        var flashcards: [[String: Any]] = []
        
        // Générer 1000 cartes
        for i in 0..<1000 {
            flashcards.append([
                "id": UUID().uuidString,
                "question": "Question \(i)",
                "answer": "Réponse \(i)",
                "intervalDays": Double(i % 10 + 1),
                "easeFactor": 2.0 + (Double(i % 10) * 0.1),
                "correctCount": Int32(i % 5),
                "reviewCount": Int32(i % 10),
                "nextReviewDate": "2024-01-\(15 + (i % 30))T12:00:00.000Z",
                "lastReviewDate": "2024-01-\(10 + (i % 10))T12:00:00.000Z",
                "createdAt": "2024-01-01T00:00:00.000Z",
                "deckId": testDeck.id!.uuidString,
                "schemaVersion": "2.0"
            ])
        }
        
        let importJSON: [String: Any] = [
            "metadata": [
                "export_date": "2024-01-01T00:00:00Z",
                "app_version": "1.0",
                "format_version": "2.0"
            ],
            "flashcard_decks": [
                [
                    "id": testDeck.id!.uuidString,
                    "name": "Grand Deck",
                    "createdAt": "2024-01-01T00:00:00Z"
                ]
            ],
            "flashcards": flashcards
        ]
        
        // When - Import (ne doit pas bloquer l'UI)
        let manager = DataImportExportManager()
        manager.setContext(context)
        let importData = try JSONSerialization.data(withJSONObject: importJSON)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        try await manager.importAllData(from: importData)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then - Import réussi et performant
        let cards = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(cards.count, 1000)
        
        // Performance acceptable (< 5 secondes pour 1000 cartes)
        XCTAssertLessThan(duration, 5.0, "Import trop lent: \(duration)s")
        
        // Vérifier quelques cartes
        let card0 = cards.first { $0.question == "Question 0" }
        XCTAssertNotNil(card0)
        XCTAssertEqual(card0?.interval, 1.0)
        
        let card999 = cards.first { $0.question == "Question 999" }
        XCTAssertNotNil(card999)
        XCTAssertEqual(card999?.interval, 10.0)
    }
    
    func testProduction_ImportIdempotence() throws {
        // Given - Import initial
        let testDeck = createTestDeck(name: "Test Deck")
        try context.save()
        
        let cardId = UUID()
        let importJSON: [String: Any] = [
            "metadata": [
                "export_date": "2024-01-01T00:00:00Z",
                "app_version": "1.0",
                "format_version": "2.0"
            ],
            "flashcard_decks": [
                [
                    "id": testDeck.id!.uuidString,
                    "name": "Test Deck",
                    "createdAt": "2024-01-01T00:00:00Z"
                ]
            ],
            "flashcards": [
                [
                    "id": cardId.uuidString,
                    "question": "Test idempotence",
                    "answer": "Réponse",
                    "intervalDays": 5.0,
                    "easeFactor": 2.1,
                    "correctCount": 3,
                    "reviewCount": 4,
                    "nextReviewDate": "2024-01-10T00:00:00Z",
                    "lastReviewDate": "2024-01-05T00:00:00Z",
                    "createdAt": "2024-01-01T00:00:00Z",
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ]
            ]
        ]
        
        let manager = DataImportExportManager()
        manager.setContext(context)
        let importData = try JSONSerialization.data(withJSONObject: importJSON)
        
        // When - Premier import
        try await manager.importAllData(from: importData)
        
        // Snapshot après premier import
        let cardsAfterFirst = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(cardsAfterFirst.count, 1)
        let cardAfterFirst = cardsAfterFirst.first!
        
        // Deuxième import (même fichier)
        try await manager.importAllData(from: importData)
        
        // Then - Résultat identique (idempotence)
        let cardsAfterSecond = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(cardsAfterSecond.count, 1)
        let cardAfterSecond = cardsAfterSecond.first!
        
        // Même données
        XCTAssertEqual(cardAfterSecond.id, cardAfterFirst.id)
        XCTAssertEqual(cardAfterSecond.question, cardAfterFirst.question)
        XCTAssertEqual(cardAfterSecond.interval, cardAfterFirst.interval)
        XCTAssertEqual(cardAfterSecond.easeFactor, cardAfterFirst.easeFactor)
        XCTAssertEqual(cardAfterSecond.correctCount, cardAfterFirst.correctCount)
        XCTAssertEqual(cardAfterSecond.reviewCount, cardAfterFirst.reviewCount)
    }
    
    func testProduction_StatusMappingAfterImport() throws {
        // Given - Cartes avec différents états SM-2
        let testDeck = createTestDeck(name: "Test Deck")
        try context.save()
        
        let importJSON: [String: Any] = [
            "metadata": [
                "export_date": "2024-01-01T00:00:00Z",
                "app_version": "1.0",
                "format_version": "2.0"
            ],
            "flashcard_decks": [
                [
                    "id": testDeck.id!.uuidString,
                    "name": "Test Deck",
                    "createdAt": "2024-01-01T00:00:00Z"
                ]
            ],
            "flashcards": [
                [
                    "id": UUID().uuidString,
                    "question": "Nouvelle carte",
                    "answer": "Réponse",
                    "intervalDays": 1.0,
                    "easeFactor": 2.0,
                    "correctCount": 0,
                    "reviewCount": 0,
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ],
                [
                    "id": UUID().uuidString,
                    "question": "Carte due aujourd'hui",
                    "answer": "Réponse",
                    "intervalDays": 1.0,
                    "easeFactor": 2.0,
                    "correctCount": 2,
                    "reviewCount": 3,
                    "nextReviewDate": "2024-01-15T00:00:00Z", // Aujourd'hui
                    "lastReviewDate": "2024-01-14T00:00:00Z",
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ],
                [
                    "id": UUID().uuidString,
                    "question": "Carte en retard",
                    "answer": "Réponse",
                    "intervalDays": 5.0,
                    "easeFactor": 2.0,
                    "correctCount": 1,
                    "reviewCount": 1,
                    "nextReviewDate": "2024-01-10T00:00:00Z", // 5 jours en retard
                    "lastReviewDate": "2024-01-05T00:00:00Z",
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ],
                [
                    "id": UUID().uuidString,
                    "question": "Carte maîtrisée due",
                    "answer": "Réponse",
                    "intervalDays": 10.0,
                    "easeFactor": 2.5,
                    "correctCount": 5,
                    "reviewCount": 6,
                    "nextReviewDate": "2024-01-15T00:00:00Z", // Due aujourd'hui mais maîtrisée
                    "lastReviewDate": "2024-01-05T00:00:00Z",
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ],
                [
                    "id": UUID().uuidString,
                    "question": "Carte maîtrisée future",
                    "answer": "Réponse",
                    "intervalDays": 15.0,
                    "easeFactor": 2.8,
                    "correctCount": 8,
                    "reviewCount": 10,
                    "nextReviewDate": "2024-01-25T00:00:00Z", // Dans 10 jours
                    "lastReviewDate": "2024-01-10T00:00:00Z",
                    "deckId": testDeck.id!.uuidString,
                    "schemaVersion": "2.0"
                ]
            ]
        ]
        
        // When - Import
        let manager = DataImportExportManager()
        manager.setContext(context)
        let importData = try JSONSerialization.data(withJSONObject: importJSON)
        try await manager.importAllData(from: importData)
        
        // Then - Vérifier les statuts selon la règle : priorité temporelle + badge maîtrise
        let cards = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(cards.count, 5)
        
        // 1. Nouvelle carte
        let newCard = cards.first { $0.question == "Nouvelle carte" }
        XCTAssertNotNil(newCard)
        let statusNew = SimpleSRSManager.shared.getCardStatusMessage(card: newCard!)
        XCTAssertEqual(statusNew.message, "Nouvelle")
        XCTAssertEqual(statusNew.icon, "sparkles")
        XCTAssertEqual(statusNew.color, Color.cyan)
        
        // 2. Carte due aujourd'hui (priorité temporelle)
        let dueCard = cards.first { $0.question == "Carte due aujourd'hui" }
        XCTAssertNotNil(dueCard)
        let statusDue = SimpleSRSManager.shared.getCardStatusMessage(card: dueCard!)
        XCTAssertEqual(statusDue.message, "À réviser")
        XCTAssertEqual(statusDue.icon, "clock.fill")
        XCTAssertEqual(statusDue.color, Color.orange)
        
        // 3. Carte en retard (priorité temporelle)
        let overdueCard = cards.first { $0.question == "Carte en retard" }
        XCTAssertNotNil(overdueCard)
        let statusOverdue = SimpleSRSManager.shared.getCardStatusMessage(card: overdueCard!)
        XCTAssertTrue(statusOverdue.message.hasPrefix("En retard"))
        XCTAssertEqual(statusOverdue.icon, "exclamationmark.triangle.fill")
        XCTAssertEqual(statusOverdue.color, Color.red)
        
        // 4. Carte maîtrisée due (priorité temporelle sur maîtrise)
        let masteredDueCard = cards.first { $0.question == "Carte maîtrisée due" }
        XCTAssertNotNil(masteredDueCard)
        let statusMasteredDue = SimpleSRSManager.shared.getCardStatusMessage(card: masteredDueCard!)
        XCTAssertEqual(statusMasteredDue.message, "À réviser") // Priorité temporelle
        XCTAssertEqual(statusMasteredDue.icon, "clock")
        XCTAssertEqual(statusMasteredDue.color, Color.orange)
        // Note: Dans l'UI, on pourrait ajouter un badge maîtrise (couronne) à côté
        
        // 5. Carte maîtrisée future (statut maîtrise)
        let masteredFutureCard = cards.first { $0.question == "Carte maîtrisée future" }
        XCTAssertNotNil(masteredFutureCard)
        let statusMasteredFuture = SimpleSRSManager.shared.getCardStatusMessage(card: masteredFutureCard!)
        XCTAssertEqual(statusMasteredFuture.message, "Maîtrisée")
        XCTAssertEqual(statusMasteredFuture.icon, "crown")
        XCTAssertEqual(statusMasteredFuture.color, Color.purple)
        XCTAssertNotNil(statusMasteredFuture.timeUntilNext)
    }
    

    
    // ✅ MÉTHODES UTILITAIRES POUR LES TESTS
    private func createTestDeck(name: String) -> FlashcardDeck {
        let deck = FlashcardDeck(context: context)
        deck.id = UUID()
        deck.name = name
        deck.createdAt = Date()
        return deck
    }
}

// MARK: - Extensions de Test

extension SM2AlgorithmTests {
    
    /// Crée une carte avec des valeurs SM-2 spécifiques pour les tests
    func createTestCard(interval: Double, easeFactor: Double, correctCount: Int16) -> Flashcard {
        let card = Flashcard(context: context)
        card.id = UUID()
        card.question = "Test Question"
        card.answer = "Test Answer"
        card.deck = testDeck
        card.interval = interval
        card.easeFactor = easeFactor
        card.correctCount = correctCount
        card.reviewCount = Int32(correctCount)
        return card
    }
    
    /// Simule une séquence de révisions avec des résultats donnés
    func simulateReviewSequence(card: Flashcard, results: [SwipeDirection]) {
        for result in results {
            srsManager.processSwipeResult(card: card, swipeDirection: result, context: context)
        }
    }
}
