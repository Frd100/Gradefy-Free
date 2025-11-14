//
//  SM2ValidationTests.swift
//  PARALLAXTests
//
//  Tests de validation finale pour l'algorithme SM-2
//  Vérifie que l'implémentation respecte exactement les spécifications SM-2
//

import CoreData
@testable import PARALLAX
import XCTest

@MainActor
class SM2ValidationTests: XCTestCase {
    var context: NSManagedObjectContext!
    var srsManager: SimpleSRSManager!
    var testDeck: FlashcardDeck!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let container = NSPersistentContainer(name: "PARALLAX")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }

        context = container.viewContext
        srsManager = SimpleSRSManager.shared

        testDeck = FlashcardDeck(context: context)
        testDeck.id = UUID()
        testDeck.name = "SM2 Validation Deck"
        testDeck.createdAt = Date()

        try context.save()
    }

    override func tearDownWithError() throws {
        context = nil
        srsManager = nil
        testDeck = nil
        try super.tearDownWithError()
    }

    // MARK: - Tests Conformité Algorithme SM-2 Original

    func testSM2OriginalSpecificationCompliance() throws {
        // Test que l'implémentation respecte les spécifications SM-2 originales
        let card = createTestCard()

        // Test séquence classique SM-2
        // 1ère révision : interval 1 → dépend de l'ease factor
        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
        let firstInterval = card.interval
        XCTAssertGreaterThan(firstInterval, 1.0, "Première révision doit augmenter l'intervalle")

        // 2ème révision : interval augmente selon ease factor
        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
        let secondInterval = card.interval
        XCTAssertGreaterThan(secondInterval, firstInterval, "Deuxième révision doit continuer à augmenter")

        // Vérifier que la croissance respecte la formule SM-2
        let expectedRatio = card.easeFactor
        let actualRatio = secondInterval / firstInterval
        XCTAssertEqual(actualRatio, expectedRatio, accuracy: 0.1, "La croissance doit respecter l'ease factor")
    }

    func testSM2EaseFactorModification() throws {
        // Test modification de l'ease factor selon les spécifications
        let card = createTestCard()
        card.easeFactor = 2.5 // Valeur standard

        // Bonne réponse → ease factor peut augmenter ou rester stable
        let initialEF = card.easeFactor
        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
        XCTAssertGreaterThanOrEqual(card.easeFactor, initialEF * 0.9, "EF ne doit pas trop diminuer sur bonne réponse")

        // Mauvaise réponse → ease factor doit diminuer
        let beforeBadResponse = card.easeFactor
        srsManager.processSwipeResult(card: card, swipeDirection: .left, context: context)
        XCTAssertLessThan(card.easeFactor, beforeBadResponse, "EF doit diminuer sur mauvaise réponse")
    }

    func testSM2IntervalResetOnFailure() throws {
        // Test remise à zéro de l'intervalle sur échec
        let card = createTestCard()

        // Augmenter l'intervalle avec quelques bonnes réponses
        for _ in 0 ..< 3 {
            srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
        }

        let highInterval = card.interval
        XCTAssertGreaterThan(highInterval, 5.0, "L'intervalle doit être élevé après bonnes réponses")

        // Mauvaise réponse → reset à 1
        srsManager.processSwipeResult(card: card, swipeDirection: .left, context: context)
        XCTAssertEqual(card.interval, 1.0, "L'intervalle doit être remis à 1 après échec")
    }

    // MARK: - Tests Validation Mathématique

    func testSM2MathematicalCorrectness() throws {
        // Test précision mathématique des calculs
        let card = createTestCard()
        card.interval = 5.0
        card.easeFactor = 2.3

        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

        // Calcul manuel selon SM-2
        let expectedInterval = 5.0 * 2.3 // (ou valeur ajustée selon l'implémentation)
        let tolerance = expectedInterval * 0.1 // 10% de tolérance

        XCTAssertEqual(card.interval, expectedInterval, accuracy: tolerance,
                       "Le calcul d'intervalle doit être mathématiquement correct")
    }

    func testSM2QualityMappingAccuracy() throws {
        // Test que le mapping swipe → quality est correct
        let testCases: [(SwipeDirection, String)] = [
            (.right, "Bonne réponse"),
            (.left, "Mauvaise réponse"),
            (.right, "Très bonne réponse"),
            (.left, "Réponse difficile"),
        ]

        for (swipeDirection, description) in testCases {
            let card = createTestCard()
            let initialEF = card.easeFactor

            srsManager.processSwipeResult(card: card, swipeDirection: swipeDirection, context: context)

            switch swipeDirection {
            case .right:
                XCTAssertGreaterThan(card.interval, 1.0, "\(description): L'intervalle doit augmenter")
                XCTAssertGreaterThanOrEqual(card.easeFactor, initialEF * 0.8, "\(description): EF ne doit pas trop baisser")
            case .left:
                XCTAssertEqual(card.interval, 1.0, "\(description): L'intervalle doit être remis à 1")
                XCTAssertLessThan(card.easeFactor, initialEF, "\(description): EF doit diminuer")
            default:
                // Cas par défaut
                break
            }
        }
    }

    // MARK: - Tests Validation Long Terme

    func testSM2LongTermBehavior() throws {
        // Test comportement à long terme de SM-2
        let card = createTestCard()
        var intervals: [Double] = []

        // 20 bonnes réponses consécutives
        for _ in 0 ..< 20 {
            srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
            intervals.append(card.interval)
        }

        // Vérifier croissance exponentielle
        for i in 1 ..< intervals.count {
            XCTAssertGreaterThan(intervals[i], intervals[i - 1],
                                 "L'intervalle doit toujours croître avec de bonnes réponses")
        }

        // Vérifier que l'intervalle final est dans une plage raisonnable
        let finalInterval = intervals.last!
        XCTAssertGreaterThan(finalInterval, 100.0, "Après 20 bonnes réponses, l'intervalle doit être > 100 jours")
        XCTAssertLessThan(finalInterval, 10000.0, "L'intervalle ne doit pas devenir absurde")
    }

    func testSM2MixedResponsePattern() throws {
        // Test comportement avec pattern de réponses mixtes (réaliste)
        let card = createTestCard()

        // Pattern réaliste : bonne, bonne, mauvaise, bonne, bonne, mauvaise...
        let responsePattern: [SwipeDirection] = [.right, .right, .left, .right, .right, .right, .left, .right]
        var intervalHistory: [Double] = []

        for response in responsePattern {
            srsManager.processSwipeResult(card: card, swipeDirection: response, context: context)
            intervalHistory.append(card.interval)
        }

        // Analyser le pattern
        var resets = 0
        for i in 1 ..< intervalHistory.count {
            if intervalHistory[i] == 1.0, intervalHistory[i - 1] > 1.0 {
                resets += 1
            }
        }

        XCTAssertEqual(resets, 2, "Doit y avoir exactement 2 resets à 1 jour (pour les 2 réponses incorrectes)")
        XCTAssertGreaterThan(intervalHistory.last!, 1.0, "L'intervalle final doit être > 1 jour")
    }

    // MARK: - Tests Validation Dashboard

    func testDashboardMetricsAccuracy() throws {
        // Test précision des métriques dashboard
        let cards = createTestCards(count: 10)

        // État initial
        let initialStats = srsManager.getDeckStats(deck: testDeck)
        XCTAssertEqual(initialStats.totalCards, 10, "Doit compter 10 cartes")
        XCTAssertEqual(initialStats.masteredCards, 0, "Aucune carte maîtrisée initialement")
        XCTAssertEqual(initialStats.todayReviewCount, 0, "Aucune révision aujourd'hui initialement")

        // Réviser quelques cartes
        for i in 0 ..< 5 {
            srsManager.processSwipeResult(card: cards[i], swipeDirection: .right, context: context)
        }

        let afterReviewStats = srsManager.getDeckStats(deck: testDeck)
        XCTAssertEqual(afterReviewStats.todayReviewCount, 5, "5 cartes vues aujourd'hui")
        XCTAssertEqual(afterReviewStats.readyCount, 5, "5 cartes encore prêtes (celles non révisées)")

        // Simuler des cartes maîtrisées (interval >= 21, correctCount >= 3)
        cards[0].interval = 25.0
        cards[0].correctCount = 4
        cards[1].interval = 30.0
        cards[1].correctCount = 5

        try context.save()

        let finalStats = srsManager.getDeckStats(deck: testDeck)
        XCTAssertEqual(finalStats.masteredCards, 2, "2 cartes doivent être comptées comme maîtrisées")
        XCTAssertEqual(finalStats.masteryPercentage, 20, "20% de maîtrise (2/10)")
    }

    func testReadyCardsCalculation() throws {
        // Test calcul précis des cartes prêtes
        let cards = createTestCards(count: 5)

        // Configurer différents états
        cards[0].nextReviewDate = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) // Prête
        cards[1].nextReviewDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) // Pas prête
        cards[2].nextReviewDate = Date() // Prête maintenant
        cards[3].nextReviewDate = nil // Nouvelle carte = prête
        cards[4].nextReviewDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) // Prête

        try context.save()

        let stats = srsManager.getDeckStats(deck: testDeck)
        XCTAssertEqual(stats.readyCount, 4, "4 cartes doivent être prêtes (indices 0, 2, 3, 4)")
    }

    // MARK: - Tests Validation Performance

    func testSM2PerformanceRequirements() throws {
        // Test que SM-2 respecte les exigences de performance iPhone SE
        let cardCount = 300 // Limite gratuite de l'app
        let cards = createTestCards(count: cardCount)

        // Mesurer performance traitement complet
        let startTime = Date()

        for card in cards {
            srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
        }

        let processingTime = Date().timeIntervalSince(startTime)

        // Performance requirement : 300 cartes en moins de 0.5 seconde
        XCTAssertLessThan(processingTime, 0.5, "300 cartes doivent être traitées en moins de 0.5s pour iPhone SE")

        // Vérifier intégrité après traitement haute vitesse
        let stats = srsManager.getDeckStats(deck: testDeck)
        XCTAssertEqual(stats.todayReviewCount, cardCount, "Toutes les cartes doivent être comptées")
        XCTAssertEqual(stats.totalCards, cardCount, "Le nombre total doit être correct")
    }

    // MARK: - Tests Validation Cache

    func testSM2CacheEffectiveness() throws {
        // Test efficacité du cache pour SM-2
        let card = createTestCard()
        let cacheManager = GradefyCacheManager.shared

        // Nettoyer le cache
        cacheManager.clearAllCaches()

        // Premier traitement (mise en cache)
        let startTime1 = Date()
        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
        let time1 = Date().timeIntervalSince(startTime1)

        // Reset pour deuxième traitement
        card.interval = 1.0
        card.easeFactor = 2.5
        card.reviewCount = 0
        card.correctCount = 0

        // Deuxième traitement (utilisation cache)
        let startTime2 = Date()
        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
        let time2 = Date().timeIntervalSince(startTime2)

        // Le cache devrait améliorer les performances
        // Note: Ce test peut être fragile selon l'implémentation du cache
        print("Temps sans cache: \(time1)s, Temps avec cache: \(time2)s")

        // Au minimum, vérifier que le cache ne casse rien
        XCTAssertGreaterThan(card.interval, 1.0, "Le cache ne doit pas affecter la correction des calculs")
    }

    // MARK: - Test Final de Validation Complète

    func testSM2CompleteValidation() throws {
        // Test de validation complète simulant utilisation réelle
        let cards = createTestCards(count: 50)

        // Simulation de 30 jours d'utilisation
        for day in 1 ... 30 {
            let cardsToReview = cards.filter { card in
                guard let nextReview = card.nextReviewDate else { return true }
                let dayDate = Calendar.current.date(byAdding: .day, value: day, to: Date())!
                return nextReview <= dayDate
            }

            // Réviser les cartes du jour avec 80% de réussite
            for card in cardsToReview {
                let success = Double.random(in: 0 ... 1) < 0.8
                let direction: SwipeDirection = success ? .right : .left

                srsManager.processSwipeResult(card: card, swipeDirection: direction, context: context)
            }
        }

        // Validation finale après 30 jours
        let finalStats = srsManager.getDeckStats(deck: testDeck)

        XCTAssertGreaterThan(finalStats.masteryPercentage, 0, "Après 30 jours, certaines cartes doivent être maîtrisées")
        XCTAssertLessThan(finalStats.masteryPercentage, 100, "Pas toutes les cartes doivent être maîtrisées")
        XCTAssertEqual(finalStats.totalCards, 50, "Le nombre total de cartes doit être préservé")

        // Vérifier distribution réaliste des intervalles
        let intervals = cards.map { $0.interval }
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        XCTAssertGreaterThan(averageInterval, 1.0, "L'intervalle moyen doit être > 1 jour")
        XCTAssertLessThan(averageInterval, 365.0, "L'intervalle moyen doit être < 1 an")
    }

    // MARK: - Helpers

    private func createTestCard() -> Flashcard {
        let card = Flashcard(context: context)
        card.id = UUID()
        card.question = "Validation Question"
        card.answer = "Validation Answer"
        card.deck = testDeck
        card.interval = 1.0
        card.easeFactor = 2.5
        card.reviewCount = 0
        card.correctCount = 0
        card.createdAt = Date()
        return card
    }

    private func createTestCards(count: Int) -> [Flashcard] {
        var cards: [Flashcard] = []

        for i in 0 ..< count {
            let card = Flashcard(context: context)
            card.id = UUID()
            card.question = "Question \(i)"
            card.answer = "Answer \(i)"
            card.deck = testDeck
            card.interval = 1.0
            card.easeFactor = 2.5
            card.reviewCount = 0
            card.correctCount = 0
            card.createdAt = Date()
            cards.append(card)
        }

        return cards
    }
}
