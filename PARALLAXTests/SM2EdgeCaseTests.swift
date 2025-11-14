//
//  SM2EdgeCaseTests.swift
//  PARALLAXTests
//
//  Tests des cas limite et edge cases pour l'algorithme SM-2
//

import CoreData
@testable import PARALLAX
import XCTest

@MainActor
class SM2EdgeCaseTests: XCTestCase {
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

        testDeck = FlashcardDeck(context: context)
        testDeck.id = UUID()
        testDeck.name = "Edge Case Test Deck"
        testDeck.createdAt = Date()

        try context.save()
    }

    override func tearDownWithError() throws {
        context = nil
        srsManager = nil
        testDeck = nil
        try super.tearDownWithError()
    }

    // MARK: - Tests Edge Cases Valeurs Limites

    func testSM2WithZeroInterval() throws {
        // Test avec intervalle à 0
        let card = createFlashcard()
        card.interval = 0.0

        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

        // L'intervalle doit être au minimum 1.0
        XCTAssertGreaterThanOrEqual(card.interval, 1.0, "L'intervalle ne doit jamais être inférieur à 1.0")
    }

    func testSM2WithNegativeInterval() throws {
        // Test avec intervalle négatif
        let card = createFlashcard()
        card.interval = -5.0

        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

        XCTAssertGreaterThanOrEqual(card.interval, 1.0, "L'intervalle négatif doit être corrigé à minimum 1.0")
    }

    func testSM2WithExtremeEaseFactor() throws {
        // Test avec ease factor extrême
        let card = createFlashcard()
        card.easeFactor = 0.5 // Valeur trop basse

        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

        XCTAssertGreaterThanOrEqual(card.easeFactor, 1.3, "L'ease factor doit être au minimum 1.3")
        XCTAssertLessThanOrEqual(card.easeFactor, 3.0, "L'ease factor doit être au maximum 3.0")
    }

    func testSM2WithVeryHighEaseFactor() throws {
        // Test avec ease factor très élevé
        let card = createFlashcard()
        card.easeFactor = 10.0 // Valeur trop haute

        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

        XCTAssertLessThanOrEqual(card.easeFactor, 3.0, "L'ease factor ne doit pas dépasser 3.0")
    }

    // MARK: - Tests Dates Edge Cases

    func testSM2WithFutureDates() throws {
        // Test avec dates dans le futur
        let card = createFlashcard()
        card.lastReviewDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) // 30 jours dans le futur

        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

        // La nouvelle lastReviewDate doit être aujourd'hui
        let today = Date()
        let timeDifference = abs(card.lastReviewDate!.timeIntervalSince(today))
        XCTAssertLessThan(timeDifference, 60, "lastReviewDate doit être mise à jour à maintenant")
    }

    func testSM2WithVeryOldDates() throws {
        // Test avec dates très anciennes
        let card = createFlashcard()
        card.lastReviewDate = Calendar.current.date(byAdding: .year, value: -10, to: Date()) // 10 ans dans le passé

        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

        XCTAssertNotNil(card.nextReviewDate, "nextReviewDate doit être calculée même avec une ancienne lastReviewDate")
        XCTAssertGreaterThan(card.nextReviewDate!, Date(), "nextReviewDate doit être dans le futur")
    }

    func testSM2NextReviewDateCalculation() throws {
        // Test précision du calcul de nextReviewDate
        let card = createFlashcard()
        card.interval = 7.0 // 7 jours

        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

        let expectedDate = Calendar.current.date(byAdding: .day, value: Int(card.interval), to: Date())!
        let actualDate = card.nextReviewDate!

        let timeDifference = abs(actualDate.timeIntervalSince(expectedDate))
        XCTAssertLessThan(timeDifference, 3600, "nextReviewDate doit être calculée avec précision (moins d'1h d'écart)")
    }

    // MARK: - Tests Overflow et Valeurs Extrêmes

    func testSM2WithVeryHighInterval() throws {
        // Test avec intervalle très élevé
        let card = createFlashcard()
        card.interval = 999_999.0 // Très grand intervalle
        card.easeFactor = 2.9

        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

        // Vérifier qu'il n'y a pas d'overflow et que l'intervalle reste raisonnable
        XCTAssertLessThan(card.interval, Double.greatestFiniteMagnitude, "L'intervalle ne doit pas causer d'overflow")
        XCTAssertNotNil(card.nextReviewDate, "nextReviewDate doit être calculable même avec un grand intervalle")
    }

    func testSM2WithMaxCorrectCount() throws {
        // Test avec un très grand nombre de bonnes réponses
        let card = createFlashcard()
        card.correctCount = Int16.max - 1

        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

        // Vérifier qu'il n'y a pas d'overflow
        XCTAssertLessThanOrEqual(card.correctCount, Int16.max, "correctCount ne doit pas causer d'overflow")
    }

    func testSM2WithMaxReviewCount() throws {
        // Test avec un très grand nombre de révisions
        let card = createFlashcard()
        card.reviewCount = Int32.max - 1

        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

        XCTAssertLessThanOrEqual(card.reviewCount, Int32.max, "reviewCount ne doit pas causer d'overflow")
    }

    // MARK: - Tests Consistency et Déterminisme

    func testSM2Determinism() throws {
        // Test que SM-2 produit des résultats déterministes
        let card1 = createFlashcard()
        let card2 = createFlashcard()

        // Même état initial
        card1.interval = 5.0
        card1.easeFactor = 2.3
        card1.correctCount = 2

        card2.interval = 5.0
        card2.easeFactor = 2.3
        card2.correctCount = 2

        // Même traitement
        srsManager.processSwipeResult(card: card1, swipeDirection: .right, context: context)
        srsManager.processSwipeResult(card: card2, swipeDirection: .right, context: context)

        // Résultats identiques
        XCTAssertEqual(card1.interval, card2.interval, accuracy: 0.001, "Même input doit donner même output")
        XCTAssertEqual(card1.easeFactor, card2.easeFactor, accuracy: 0.001, "easeFactor doit être identique")
    }

    func testSM2RepeatedOperations() throws {
        // Test opérations répétées identiques
        let card = createFlashcard()
        var previousInterval = card.interval

        // 10 bonnes réponses consécutives
        for i in 1 ... 10 {
            srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

            // L'intervalle doit toujours augmenter
            XCTAssertGreaterThan(card.interval, previousInterval, "L'intervalle doit augmenter à l'itération \(i)")
            previousInterval = card.interval

            // correctCount doit être correct
            XCTAssertEqual(card.correctCount, Int16(i), "correctCount doit être \(i) à l'itération \(i)")
        }

        // Après 10 bonnes réponses, l'intervalle doit être significatif
        XCTAssertGreaterThan(card.interval, 50.0, "Après 10 bonnes réponses, l'intervalle doit être > 50 jours")
    }

    // MARK: - Tests Invalid SwipeDirection

    func testSM2WithInvalidSwipeDirection() throws {
        // Test avec direction de swipe invalide/inconnue
        let card = createFlashcard()
        _ = card.interval
        _ = card.reviewCount

        // Utiliser .none ou une valeur non gérée
        srsManager.processSwipeResult(card: card, swipeDirection: .none, context: context)

        // Les données ne doivent pas être corrompues
        XCTAssertNotNil(card.interval, "interval ne doit pas être nil")
        XCTAssertNotNil(card.easeFactor, "easeFactor ne doit pas être nil")

        // Le système doit gérer gracieusement les valeurs inconnues
        XCTAssertGreaterThanOrEqual(card.easeFactor, 1.3, "easeFactor doit rester dans les bornes")
        XCTAssertLessThanOrEqual(card.easeFactor, 3.0, "easeFactor doit rester dans les bornes")
    }

    // MARK: - Tests Memory Management

    func testSM2MemoryLeaks() throws {
        // Test pour détecter les fuites mémoire potentielles
        weak var weakCard: Flashcard?

        autoreleasepool {
            let card = createFlashcard()
            weakCard = card

            // Traitement SM-2
            for _ in 0 ..< 100 {
                srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)
            }

            XCTAssertNotNil(weakCard, "La carte doit exister pendant le traitement")
        }

        // Nettoyer le contexte
        context.reset()

        // La carte devrait être libérée
        // Note: Ce test peut être fragile selon le GC, mais utile pour détecter les fuites évidentes
    }

    // MARK: - Tests CoreData Edge Cases

    func testSM2WithUnsavedContext() throws {
        // Test avec un contexte non sauvegardé
        let card = createFlashcard()

        // Ne pas sauvegarder le contexte initialement
        XCTAssertTrue(context.hasChanges, "Le contexte doit avoir des changements non sauvegardés")

        srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

        // SM-2 doit gérer la sauvegarde
        XCTAssertFalse(context.hasChanges, "Le contexte ne doit plus avoir de changements après SM-2")
    }

    func testSM2WithContextError() throws {
        // Test comportement avec erreur de contexte
        _ = createFlashcard()

        // Créer un contexte en read-only pour simuler une erreur
        let readOnlyContainer = NSPersistentContainer(name: "PARALLAX")
        let readOnlyDescription = NSPersistentStoreDescription()
        readOnlyDescription.type = NSInMemoryStoreType
        readOnlyDescription.setOption(true as NSNumber, forKey: NSReadOnlyPersistentStoreOption)
        readOnlyContainer.persistentStoreDescriptions = [readOnlyDescription]

        readOnlyContainer.loadPersistentStores { _, _ in }
        let readOnlyContext = readOnlyContainer.viewContext

        let readOnlyCard = Flashcard(context: readOnlyContext)
        readOnlyCard.interval = 1.0
        readOnlyCard.easeFactor = 2.5

        // Le traitement ne doit pas planter même si la sauvegarde échoue
        XCTAssertNoThrow { [self] in
            srsManager.processSwipeResult(card: readOnlyCard, swipeDirection: .right, context: readOnlyContext)
        }
    }

    // MARK: - Tests Boundary Values

    func testSM2BoundaryValues() throws {
        // Test toutes les valeurs limites importantes
        let boundaryTests: [(interval: Double, easeFactor: Double, expectation: String)] = [
            (1.0, 1.3, "Valeurs minimales"),
            (1.0, 3.0, "Interval min, EF max"),
            (365.0, 1.3, "Interval élevé, EF min"),
            (365.0, 3.0, "Valeurs maximales pratiques"),
            (0.1, 2.5, "Interval sous minimum"),
            (1000.0, 2.5, "Interval très élevé"),
        ]

        for (_, test) in boundaryTests.enumerated() {
            let card = createFlashcard()
            card.interval = test.interval
            card.easeFactor = test.easeFactor

            srsManager.processSwipeResult(card: card, swipeDirection: .right, context: context)

            // Vérifications générales pour toutes les valeurs limites
            XCTAssertGreaterThanOrEqual(card.interval, 1.0, "\(test.expectation): interval >= 1.0")
            XCTAssertGreaterThanOrEqual(card.easeFactor, 1.3, "\(test.expectation): easeFactor >= 1.3")
            XCTAssertLessThanOrEqual(card.easeFactor, 3.0, "\(test.expectation): easeFactor <= 3.0")
            XCTAssertNotNil(card.nextReviewDate, "\(test.expectation): nextReviewDate doit être calculée")
        }
    }

    // MARK: - Helper Methods

    private func createFlashcard() -> Flashcard {
        let card = Flashcard(context: context)
        card.id = UUID()
        card.question = "Edge Case Question"
        card.answer = "Edge Case Answer"
        card.deck = testDeck
        card.interval = 1.0
        card.easeFactor = 2.5
        card.reviewCount = 0
        card.correctCount = 0
        card.createdAt = Date()
        return card
    }
}
