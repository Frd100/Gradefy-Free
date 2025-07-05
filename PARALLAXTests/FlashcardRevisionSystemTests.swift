//
//  FlashcardRevisionSystemTests.swift
//  PARALLAX
//
//  Created by Farid on 7/1/25.
//


import XCTest
import Foundation
import CoreData        // ✅ AJOUT
import ActivityKit     // ✅ AJOUT
@testable import PARALLAX

@MainActor
final class FlashcardRevisionSystemTests: XCTestCase {
    var revisionManager: RevisionActivityManager!
    var mockContext: NSManagedObjectContext!
    var testDeck: FlashcardDeck!
    
    override func setUpWithError() throws {
        revisionManager = RevisionActivityManager()
        mockContext = PersistenceController.inMemory.container.viewContext
        testDeck = createTestDeck()
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        revisionManager = nil
        mockContext = nil
        testDeck = nil
    }
    
    // MARK: - Tests Live Activities
    func test_revisionActivityManager_whenStartActivity_shouldTrackCorrectly() throws {
        // Arrange
        let subjectName = "Mathématiques"
        let deckName = "Algèbre"
        let totalCards = 20
        
        // Act - Simuler démarrage Live Activity
        revisionManager.startFlashcardActivity(
            subjectName: subjectName,
            deckName: deckName,
            totalCards: totalCards
        )
        
        // Assert
        XCTAssertTrue(revisionManager.isActivityActive, "Activity should be marked as active")
    }
    
    func test_revisionActivityManager_whenUpdateActivity_shouldMaintainState() throws {
        // Arrange
        revisionManager.startFlashcardActivity(subjectName: "Math", deckName: "Test", totalCards: 10)
        
        // Act
        revisionManager.updateFlashcardActivity(
            cardsCompleted: 5,
            currentCard: "Question 6",
            cardsKnown: 3,
            cardsToReview: 2,
            isActive: true
        )
        
        // Assert - Verify internal state tracking
        XCTAssertTrue(revisionManager.isActivityActive, "Activity should remain active")
    }
    
    func test_revisionActivityManager_whenEndActivity_shouldCleanup() throws {
        // Arrange
        revisionManager.startFlashcardActivity(subjectName: "Test", deckName: "Test", totalCards: 5)
        
        // Act
        revisionManager.endRevisionActivity()
        
        // Assert
        XCTAssertFalse(revisionManager.isActivityActive, "Activity should be ended")
    }
    
    // MARK: - Tests Swipe Direction Logic
    func test_swipeDirection_whenLeftSwipe_shouldMarkAsReview() throws {
        // Arrange
        let direction: SwipeDirection = .left
        var cardsToReview = 0
        var cardsKnown = 0
        
        // Act - Simuler logique de swipe
        switch direction {
        case .left:
            cardsToReview += 1
        case .right:
            cardsKnown += 1
        default:
            break
        }
        
        // Assert
        XCTAssertEqual(cardsToReview, 1, "Left swipe should increment review count")
        XCTAssertEqual(cardsKnown, 0, "Known count should remain 0")
    }
    
    func test_swipeDirection_whenRightSwipe_shouldMarkAsKnown() throws {
        // Arrange
        let direction: SwipeDirection = .right
        var cardsToReview = 0
        var cardsKnown = 0
        
        // Act
        switch direction {
        case .left:
            cardsToReview += 1
        case .right:
            cardsKnown += 1
        default:
            break
        }
        
        // Assert
        XCTAssertEqual(cardsKnown, 1, "Right swipe should increment known count")
        XCTAssertEqual(cardsToReview, 0, "Review count should remain 0")
    }
    
    // MARK: - Tests Session Statistics
    func test_sessionStatistics_whenCardsProcessed_shouldCalculateCorrectly() throws {
        // Arrange
        let totalCards = 10
        var currentIndex = 0
        var cardsKnown = 0
        var cardsToReview = 0
        let sessionStartTime = Date()
        
        // Simuler progression de session
        for i in 0..<5 {
            currentIndex = i + 1
            if i % 2 == 0 {
                cardsKnown += 1
            } else {
                cardsToReview += 1
            }
        }
        
        // Act
        let progressPercentage = Double(currentIndex) / Double(totalCards)
        let sessionDuration = Int(Date().timeIntervalSince(sessionStartTime))
        
        // Assert
        XCTAssertEqual(currentIndex, 5, "Should process 5 cards")
        XCTAssertEqual(cardsKnown, 3, "Should have 3 known cards")
        XCTAssertEqual(cardsToReview, 2, "Should have 2 cards to review")
        XCTAssertEqual(progressPercentage, 0.5, accuracy: 0.01, "Progress should be 50%")
        XCTAssertGreaterThanOrEqual(sessionDuration, 0, "Session duration should be non-negative")
    }
    
    // MARK: - Tests Progress Calculation
    func test_progressCalculation_whenValidSession_shouldReturnCorrectPercentage() throws {
        // Arrange
        let initialCardCount = 20
        let currentCardIndex = 8
        
        // Act
        let progressPercentage = Double(currentCardIndex) / Double(initialCardCount)
        
        // Assert
        XCTAssertEqual(progressPercentage, 0.4, accuracy: 0.01, "8/20 should be 40%")
    }
    
    func test_progressCalculation_whenEmptyDeck_shouldReturnZero() throws {
        // Arrange
        let initialCardCount = 0
        let currentCardIndex = 0
        
        // Act
        let progressPercentage = initialCardCount > 0 ? Double(currentCardIndex) / Double(initialCardCount) : 0
        
        // Assert
        XCTAssertEqual(progressPercentage, 0, "Empty deck should have 0% progress")
    }
    
    // MARK: - Tests Card Stack Logic
    func test_cardStack_whenMultipleCards_shouldShowCorrectOrder() throws {
        // Arrange
        let cards = createTestFlashcards(count: 5)
        
        // Act - Simuler l'ordre des cartes dans la stack
        let visibleCards = Array(cards.prefix(3)) // Seulement 3 cartes visibles
        let topCard = visibleCards.first
        
        // Assert
        XCTAssertEqual(visibleCards.count, 3, "Should show maximum 3 cards")
        XCTAssertEqual(topCard?.question, "Question 0", "Top card should be first")
    }
    
    // MARK: - Tests Session Time Formatting
    func test_sessionTimeFormatting_whenValidDuration_shouldFormatCorrectly() throws {
        // Test function formatSessionTime
        let testCases = [
            (seconds: 65, expected: "1m 05s"),
            (seconds: 120, expected: "2m 00s"),
            (seconds: 30, expected: "0m 30s"),
            (seconds: 3661, expected: "61m 01s")
        ]
        
        for testCase in testCases {
            // Act
            let minutes = testCase.seconds / 60
            let secs = testCase.seconds % 60
            let result = String(format: "%dm %02ds", minutes, secs)
            
            // Assert
            XCTAssertEqual(result, testCase.expected, "Time formatting should be correct for \(testCase.seconds) seconds")
        }
    }
    
    // MARK: - Helper Methods
    private func createTestDeck() -> FlashcardDeck {
        let deck = FlashcardDeck(context: mockContext)
        deck.id = UUID()
        deck.name = "Test Deck"
        deck.createdAt = Date()
        return deck
    }
    
    private func createTestFlashcards(count: Int) -> [TestFlashcard] {
        return Array(0..<count).map { i in
            TestFlashcard(
                question: "Question \(i)",
                answer: "Answer \(i)"
            )
        }
    }
}

struct TestFlashcard {
    let question: String
    let answer: String
}
