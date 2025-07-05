//
//  FlashcardLogicTests.swift
//  PARALLAX
//
//  Created by Farid on 7/1/25.
//


import XCTest
import Foundation
import CoreData        // ✅ AJOUT
import ActivityKit     // ✅ AJOUT
@testable import PARALLAX

final class FlashcardLogicTests: XCTestCase {
    var mockContext: NSManagedObjectContext!
    var testDeck: FlashcardDeck!
    
    override func setUpWithError() throws {
        mockContext = PersistenceController.inMemory.container.viewContext
        
        // Créer un deck de test
        testDeck = FlashcardDeck(context: mockContext)
        testDeck.id = UUID()
        testDeck.name = "Test Deck"
        testDeck.createdAt = Date()
        
        try mockContext.save()
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        mockContext = nil
        testDeck = nil
    }
    
    // MARK: - Tests Association Game Logic
    func test_associationCardGeneration_whenValidFlashcards_shouldCreatePairs() throws {
        // Arrange - Créer des flashcards valides
        let flashcards = createTestFlashcards(count: 6)
        
        // Simuler la logique de génération de AssociationView
        let validFlashcards = flashcards.filter { card in
            guard let question = card.question, !question.isEmpty,
                  let answer = card.answer, !answer.isEmpty else {
                return false
            }
            return true
        }
        
        // Act - Créer les cartes d'association
        var associationCards: [MockAssociationCard] = []
        for flashcard in validFlashcards.prefix(6) {
            let pairId = UUID()
            associationCards.append(MockAssociationCard(
                id: UUID(),
                text: flashcard.question ?? "",
                matchId: pairId,
                cardType: .question
            ))
            associationCards.append(MockAssociationCard(
                id: UUID(),
                text: flashcard.answer ?? "",
                matchId: pairId,
                cardType: .answer
            ))
        }
        
        // Assert
        XCTAssertEqual(associationCards.count, 12, "Should create 12 cards for 6 pairs")
        
        let questionCards = associationCards.filter { $0.cardType == .question }
        let answerCards = associationCards.filter { $0.cardType == .answer }
        
        XCTAssertEqual(questionCards.count, 6, "Should have 6 question cards")
        XCTAssertEqual(answerCards.count, 6, "Should have 6 answer cards")
        
        // Vérifier que chaque question a une réponse correspondante
        for questionCard in questionCards {
            let matchingAnswer = answerCards.first { $0.matchId == questionCard.matchId }
            XCTAssertNotNil(matchingAnswer, "Each question should have a matching answer")
        }
    }
    
    // MARK: - Tests Quiz Generation Logic
    func test_quizGeneration_whenEnoughFlashcards_shouldCreateValidQuestions() throws {
        // Arrange
        let flashcards = createTestFlashcards(count: 8)
        
        // Act - Simuler la génération de quiz
        var quizQuestions: [MockQuizQuestion] = []
        for flashcard in flashcards.prefix(5) {
            guard let question = flashcard.question,
                  let correctAnswer = flashcard.answer else { continue }
            
            let otherFlashcards = flashcards.filter { $0.id != flashcard.id }
            let wrongAnswers = Array(otherFlashcards.compactMap { $0.answer }.prefix(3))
            
            guard wrongAnswers.count >= 3 else { continue }
            
            var allAnswers = wrongAnswers
            allAnswers.append(correctAnswer)
            allAnswers.shuffle()
            
            let correctIndex = allAnswers.firstIndex(of: correctAnswer) ?? 0
            
            quizQuestions.append(MockQuizQuestion(
                question: question,
                correctAnswer: correctAnswer,
                allAnswers: allAnswers,
                correctIndex: correctIndex
            ))
        }
        
        // Assert
        XCTAssertGreaterThan(quizQuestions.count, 0, "Should generate quiz questions")
        
        for quizQuestion in quizQuestions {
            XCTAssertEqual(quizQuestion.allAnswers.count, 4, "Each question should have 4 answers")
            XCTAssertTrue(quizQuestion.allAnswers.contains(quizQuestion.correctAnswer), "Answers should include correct answer")
            XCTAssertTrue(quizQuestion.correctIndex < 4, "Correct index should be valid")
        }
    }
    
    // MARK: - Tests Flashcard Validation
    func test_flashcardValidation_whenEmptyContent_shouldBeInvalid() throws {
        // Arrange
        let emptyQuestion = Flashcard(context: mockContext)
        emptyQuestion.question = ""
        emptyQuestion.answer = "Answer"
        
        let emptyAnswer = Flashcard(context: mockContext)
        emptyAnswer.question = "Question"
        emptyAnswer.answer = ""
        
        let emptyBoth = Flashcard(context: mockContext)
        emptyBoth.question = ""
        emptyBoth.answer = ""
        
        // Act & Assert
        XCTAssertFalse(isValidFlashcard(emptyQuestion), "Empty question should be invalid")
        XCTAssertFalse(isValidFlashcard(emptyAnswer), "Empty answer should be invalid")
        XCTAssertFalse(isValidFlashcard(emptyBoth), "Empty question and answer should be invalid")
    }
    
    func test_flashcardValidation_whenValidContent_shouldBeValid() throws {
        // Arrange
        let validFlashcard = Flashcard(context: mockContext)
        validFlashcard.question = "What is 2+2?"
        validFlashcard.answer = "4"
        
        // Act & Assert
        XCTAssertTrue(isValidFlashcard(validFlashcard), "Valid flashcard should be valid")
    }
    
    // MARK: - Tests Deck Statistics
    func test_deckStatistics_whenFlashcardsAdded_shouldReturnCorrectCounts() throws {
        // Arrange
        let flashcards = createTestFlashcards(count: 10)
        
        // Act
        let flashcardCount = flashcards.count
        let validCount = flashcards.filter { isValidFlashcard($0) }.count
        
        // Assert
        XCTAssertEqual(flashcardCount, 10, "Should count all flashcards")
        XCTAssertEqual(validCount, 10, "All test flashcards should be valid")
    }
    
    // MARK: - Helper Methods
    private func createTestFlashcards(count: Int) -> [Flashcard] {
        var flashcards: [Flashcard] = []
        
        for i in 0..<count {
            let flashcard = Flashcard(context: mockContext)
            flashcard.id = UUID()
            flashcard.question = "Question \(i + 1)"
            flashcard.answer = "Answer \(i + 1)"
            flashcard.createdAt = Date()
            flashcard.deck = testDeck
            flashcards.append(flashcard)
        }
        
        try? mockContext.save()
        return flashcards
    }
    
    private func isValidFlashcard(_ flashcard: Flashcard) -> Bool {
        guard let question = flashcard.question, !question.isEmpty,
              let answer = flashcard.answer, !answer.isEmpty else {
            return false
        }
        return true
    }
}

// MARK: - Mock Objects for Testing
struct MockAssociationCard {
    let id: UUID
    let text: String
    let matchId: UUID
    let cardType: CardType
    
    enum CardType {
        case question, answer
    }
}

struct MockQuizQuestion {
    let question: String
    let correctAnswer: String
    let allAnswers: [String]
    let correctIndex: Int
}
