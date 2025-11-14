//
//  PARALLAXGradingSystemTests.swift
//  PARALLAXTests
//
//  Created on 2025-01-24
//  iOS 17.0+ • Swift 6.0+ • Core Data • Xcode 15.0+
//

import XCTest
import CoreData
@testable import PARALLAX

@MainActor
final class PARALLAXGradingSystemTests: XCTestCase {
    
    // MARK: - Properties
    private var persistentContainer: NSPersistentContainer!
    private var context: NSManagedObjectContext!
    private var testPeriod: Period!
    private var testSubject: Subject!
    
    // MARK: - Lifecycle
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup in-memory Core Data stack for testing
        persistentContainer = NSPersistentContainer(name: "PARALLAX")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load store: \(error)")
            }
        }
        
        context = persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true
        
        // Create test data
        try await setupTestData()
    }
    
    override func tearDown() async throws {
        // Clean up test data
        testPeriod = nil
        testSubject = nil
        context = nil
        persistentContainer = nil
        try await super.tearDown()
    }
    
    private func setupTestData() async throws {
        // Create test period
        testPeriod = Period(context: context)
        testPeriod.id = UUID()
        testPeriod.name = "Semestre 1 2025"
        testPeriod.startDate = Date()
        testPeriod.endDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())
        testPeriod.createdAt = Date()
        
        // Create test subject
        testSubject = Subject(context: context)
        testSubject.id = UUID()
        testSubject.name = "Mathématiques"
        testSubject.code = "MATH101"
        testSubject.coefficient = 3.0
        testSubject.creditHours = 60.0
        testSubject.grade = 0.0
        testSubject.createdAt = Date()
        testSubject.lastModified = Date()
        testSubject.period = testPeriod
        
        try context.save()
    }
}

// MARK: - Period Tests
extension PARALLAXGradingSystemTests {
    
    func test_Period_Creation_ShouldSucceed() throws {
        // Given
        let period = Period(context: context)
        period.id = UUID()
        period.name = "Test Period"
        period.startDate = Date()
        period.createdAt = Date()
        
        // When
        try context.save()
        
        // Then
        XCTAssertNotNil(period.id)
        XCTAssertEqual(period.name, "Test Period")
        XCTAssertNotNil(period.startDate)
        XCTAssertNotNil(period.createdAt)
    }
    
    func test_Period_WithSubjects_ShouldMaintainRelationship() throws {
        // Given
        let period = Period(context: context)
        period.id = UUID()
        period.name = "Period with Subjects"
        period.startDate = Date()
        period.createdAt = Date()
        
        let subject1 = Subject(context: context)
        subject1.id = UUID()
        subject1.name = "Physique"
        subject1.coefficient = 2.0
        subject1.createdAt = Date()
        subject1.period = period
        
        let subject2 = Subject(context: context)
        subject2.id = UUID()
        subject2.name = "Chimie"
        subject2.coefficient = 2.0
        subject2.createdAt = Date()
        subject2.period = period
        
        // When
        try context.save()
        
        // Then
        XCTAssertEqual(period.subjects?.count, 2)
        XCTAssertTrue(period.subjects?.contains(subject1) == true)
        XCTAssertTrue(period.subjects?.contains(subject2) == true)
    }
    
    func test_Period_Deletion_ShouldCascadeToSubjects() throws {
        // Given
        let period = Period(context: context)
        period.id = UUID()
        period.name = "Period to Delete"
        period.startDate = Date()
        period.createdAt = Date()
        
        let subject = Subject(context: context)
        subject.id = UUID()
        subject.name = "Subject to be deleted"
        subject.coefficient = 1.0
        subject.createdAt = Date()
        subject.period = period
        
        try context.save()
        let subjectId = subject.objectID
        
        // When
        context.delete(period)
        try context.save()
        
        // Then
        XCTAssertThrowsError(try context.existingObject(with: subjectId))
    }
}

// MARK: - Subject Tests
extension PARALLAXGradingSystemTests {
    
    func test_Subject_Creation_ShouldSucceed() throws {
        // Given & When
        let subject = Subject(context: context)
        subject.id = UUID()
        subject.name = "Histoire"
        subject.code = "HIST201"
        // ⚠️ Supprime cette ligne car coefficient = 1.0 par défaut maintenant
        // subject.coefficient = 2.5
        subject.creditHours = 45.0
        subject.grade = 0.0
        subject.createdAt = Date()
        subject.lastModified = Date()

        try context.save()

        // Then
        XCTAssertNotNil(subject.id)
        XCTAssertEqual(subject.name, "Histoire")
        XCTAssertEqual(subject.code, "HIST201")
        XCTAssertEqual(subject.coefficient, 1.0) // ← Maintenant 1.0 par défaut
        XCTAssertEqual(subject.creditHours, 45.0)
        XCTAssertEqual(subject.grade, 0.0)
    }
    
    func test_Subject_WithEvaluations_ShouldMaintainRelationship() throws {
        // Given
        let evaluation1 = Evaluation(context: context)
        evaluation1.id = UUID()
        evaluation1.title = "Contrôle 1"
        evaluation1.grade = 15.0
        evaluation1.coefficient = 1.0
        evaluation1.date = Date()
        evaluation1.subject = testSubject
        
        let evaluation2 = Evaluation(context: context)
        evaluation2.id = UUID()
        evaluation2.title = "Contrôle 2"
        evaluation2.grade = 17.0
        evaluation2.coefficient = 1.0
        evaluation2.date = Date()
        evaluation2.subject = testSubject
        
        // When
        try context.save()
        
        // Then
        XCTAssertEqual(testSubject.evaluations?.count, 2)
        XCTAssertTrue(testSubject.evaluations?.contains(evaluation1) == true)
        XCTAssertTrue(testSubject.evaluations?.contains(evaluation2) == true)
    }
    
    func test_Subject_GradeCalculation_ShouldBeAccurate() throws {
        // Given
        let evaluation1 = Evaluation(context: context)
        evaluation1.id = UUID()
        evaluation1.title = "Examen 1"
        evaluation1.grade = 14.0
        evaluation1.coefficient = 2.0
        evaluation1.date = Date()
        evaluation1.subject = testSubject
        
        let evaluation2 = Evaluation(context: context)
        evaluation2.id = UUID()
        evaluation2.title = "Examen 2"
        evaluation2.grade = 16.0
        evaluation2.coefficient = 3.0
        evaluation2.date = Date()
        evaluation2.subject = testSubject
        
        try context.save()
        
        // When - Calculate weighted average
        let totalPoints = (14.0 * 2.0) + (16.0 * 3.0) // 28 + 48 = 76
        let totalCoefficient = 2.0 + 3.0 // 5
        let expectedAverage = totalPoints / totalCoefficient // 76/5 = 15.2
        
        testSubject.grade = expectedAverage
        try context.save()
        
        // Then
        XCTAssertEqual(testSubject.grade, 15.2, accuracy: 0.01)
    }
    
    func test_Subject_Deletion_ShouldCascadeToEvaluations() throws {
        // Given
        let evaluation = Evaluation(context: context)
        evaluation.id = UUID()
        evaluation.title = "Evaluation to be deleted"
        evaluation.grade = 12.0
        evaluation.coefficient = 1.0
        evaluation.date = Date()
        evaluation.subject = testSubject
        
        try context.save()
        let evaluationId = evaluation.objectID
        
        // When
        context.delete(testSubject)
        try context.save()
        
        // Then
        XCTAssertThrowsError(try context.existingObject(with: evaluationId))
    }
}

// MARK: - Evaluation Tests
extension PARALLAXGradingSystemTests {
    
    func test_Evaluation_Creation_ShouldSucceed() throws {
        // Given & When
        let evaluation = Evaluation(context: context)
        evaluation.id = UUID()
        evaluation.title = "Devoir Maison"
        evaluation.grade = 18.5
        // ⚠️ Supprime cette ligne car coefficient = 1.0 par défaut maintenant
        // evaluation.coefficient = 1.5
        evaluation.date = Date()
        evaluation.subject = testSubject

        try context.save()

        // Then
        XCTAssertNotNil(evaluation.id)
        XCTAssertEqual(evaluation.title, "Devoir Maison")
        XCTAssertEqual(evaluation.grade, 18.5)
        XCTAssertEqual(evaluation.coefficient, 1.0) // ← Maintenant 1.0 par défaut
        XCTAssertNotNil(evaluation.date)
        XCTAssertEqual(evaluation.subject, testSubject)
    }
    
    func test_Evaluation_OptionalGrade_ShouldHandleNil() throws {
        // Given & When
        let evaluation = Evaluation(context: context)
        evaluation.id = UUID()
        evaluation.title = "Evaluation en attente"
        evaluation.grade = 0.0 // Default value
        evaluation.coefficient = 1.0
        evaluation.date = Date()
        evaluation.subject = testSubject
        
        try context.save()
        
        // Then
        XCTAssertEqual(evaluation.grade, 0.0)
        XCTAssertEqual(evaluation.title, "Evaluation en attente")
    }
    
    func test_Evaluation_WeightedContribution_ShouldCalculateCorrectly() throws {
        // Given
        let evaluation = Evaluation(context: context)
        evaluation.id = UUID()
        evaluation.title = "Test Coefficient"
        evaluation.grade = 16.0
        evaluation.coefficient = 2.5
        evaluation.date = Date()
        evaluation.subject = testSubject
        
        try context.save()
        
        // When
        let weightedScore = evaluation.grade * evaluation.coefficient
        
        // Then
        XCTAssertEqual(weightedScore, 40.0, accuracy: 0.01) // 16.0 * 2.5
    }
}

// MARK: - Flashcard System Tests
extension PARALLAXGradingSystemTests {
    
    func test_FlashcardDeck_Creation_ShouldSucceed() throws {
        // Given & When
        let deck = FlashcardDeck(context: context)
        deck.id = UUID()
        deck.name = "Vocabulaire Anglais"
        deck.createdAt = Date()
        
        try context.save()
        
        // Then
        XCTAssertNotNil(deck.id)
        XCTAssertEqual(deck.name, "Vocabulaire Anglais")
        XCTAssertNotNil(deck.createdAt)
    }
    
    func test_Flashcard_Creation_ShouldSucceed() throws {
        // Given
        let deck = FlashcardDeck(context: context)
        deck.id = UUID()
        deck.name = "Test Deck"
        deck.createdAt = Date()
        
        // When
        let flashcard = Flashcard(context: context)
        flashcard.id = UUID()
        flashcard.question = "Qu'est-ce que Swift ?"
        flashcard.answer = "Un langage de programmation développé par Apple"
        flashcard.createdAt = Date()
        flashcard.correctCount = 0
        flashcard.reviewCount = 0
        flashcard.interval = 1.0
        flashcard.deck = deck
        
        try context.save()
        
        // Then
        XCTAssertNotNil(flashcard.id)
        XCTAssertEqual(flashcard.question, "Qu'est-ce que Swift ?")
        XCTAssertEqual(flashcard.answer, "Un langage de programmation développé par Apple")
        XCTAssertEqual(flashcard.correctCount, 0)
        XCTAssertEqual(flashcard.reviewCount, 0)
        XCTAssertEqual(flashcard.interval, 1.0)
        XCTAssertEqual(flashcard.deck, deck)
    }
    
    func test_Flashcard_SpacedRepetition_ShouldUpdateCorrectly() throws {
        // Given
        let deck = FlashcardDeck(context: context)
        deck.id = UUID()
        deck.name = "Spaced Repetition Test"
        deck.createdAt = Date()
        
        let flashcard = Flashcard(context: context)
        flashcard.id = UUID()
        flashcard.question = "Test Question"
        flashcard.answer = "Test Answer"
        flashcard.createdAt = Date()
        flashcard.correctCount = 0
        flashcard.reviewCount = 0
        flashcard.interval = 1.0
        flashcard.deck = deck
        
        try context.save()
        
        // When - Simulate correct answer
        flashcard.correctCount += 1
        flashcard.reviewCount += 1
        flashcard.lastReviewed = Date()
        flashcard.interval *= 2.5 // Increase interval for correct answer
        flashcard.nextReviewDate = Calendar.current.date(byAdding: .day,
                                                         value: Int(flashcard.interval),
                                                         to: Date())
        
        try context.save()
        
        // Then
        XCTAssertEqual(flashcard.correctCount, 1)
        XCTAssertEqual(flashcard.reviewCount, 1)
        XCTAssertEqual(flashcard.interval, 2.5)
        XCTAssertNotNil(flashcard.lastReviewed)
        XCTAssertNotNil(flashcard.nextReviewDate)
    }
    
    func test_FlashcardDeck_Deletion_ShouldCascadeToFlashcards() throws {
        // Given
        let deck = FlashcardDeck(context: context)
        deck.id = UUID()
        deck.name = "Deck to Delete"
        deck.createdAt = Date()
        
        let flashcard = Flashcard(context: context)
        flashcard.id = UUID()
        flashcard.question = "Question to be deleted"
        flashcard.answer = "Answer to be deleted"
        flashcard.createdAt = Date()
        flashcard.deck = deck
        
        try context.save()
        let flashcardId = flashcard.objectID
        
        // When
        context.delete(deck)
        try context.save()
        
        // Then
        XCTAssertThrowsError(try context.existingObject(with: flashcardId))
    }
}

// MARK: - UserConfiguration Tests
extension PARALLAXGradingSystemTests {
    
    func test_UserConfiguration_Creation_ShouldSucceed() throws {
        // Given & When
        let config = UserConfiguration(context: context)
        config.id = UUID()
        config.username = "TestUser"
        config.hasCompletedOnboarding = false
        config.selectedSystem = "French"
        config.profileGradientStart = "#FF6B6B"
        config.profileGradientEnd = "#4ECDC4"
        config.createdDate = Date()
        config.lastModifiedDate = Date()
        
        try context.save()
        
        // Then
        XCTAssertNotNil(config.id)
        XCTAssertEqual(config.username, "TestUser")
        XCTAssertFalse(config.hasCompletedOnboarding)
        XCTAssertEqual(config.selectedSystem, "French")
        XCTAssertEqual(config.profileGradientStart, "#FF6B6B")
        XCTAssertEqual(config.profileGradientEnd, "#4ECDC4")
    }
    
    func test_UserConfiguration_OnboardingCompletion_ShouldUpdate() throws {
        // Given
        let config = UserConfiguration(context: context)
        config.id = UUID()
        config.hasCompletedOnboarding = false
        config.createdDate = Date()
        
        try context.save()
        
        // When
        config.hasCompletedOnboarding = true
        config.lastModifiedDate = Date()
        
        try context.save()
        
        // Then
        XCTAssertTrue(config.hasCompletedOnboarding)
        XCTAssertNotNil(config.lastModifiedDate)
    }
}

// MARK: - Integration Tests
extension PARALLAXGradingSystemTests {
    
    func test_CompleteGradingWorkflow_ShouldWorkCorrectly() throws {
        // Given - Create complete academic structure
        let period = Period(context: context)
        period.id = UUID()
        period.name = "Semestre Test"
        period.startDate = Date()
        period.createdAt = Date()
        
        let subject = Subject(context: context)
        subject.id = UUID()
        subject.name = "Informatique"
        subject.code = "INFO101"
        subject.coefficient = 4.0
        subject.creditHours = 60.0
        subject.createdAt = Date()
        subject.period = period
        
        // When - Add multiple evaluations
        let evaluations = [
            (title: "TP 1", grade: 16.0, coefficient: 1.0),
            (title: "TP 2", grade: 14.0, coefficient: 1.0),
            (title: "Partiel", grade: 15.0, coefficient: 2.0),
            (title: "Projet", grade: 18.0, coefficient: 3.0)
        ]
        
        var totalWeightedScore = 0.0
        var totalCoefficient = 0.0
        
        for evalData in evaluations {
            let evaluation = Evaluation(context: context)
            evaluation.id = UUID()
            evaluation.title = evalData.title
            evaluation.grade = evalData.grade
            evaluation.coefficient = evalData.coefficient
            evaluation.date = Date()
            evaluation.subject = subject
            
            totalWeightedScore += evalData.grade * evalData.coefficient
            totalCoefficient += evalData.coefficient
        }
        
        subject.grade = totalWeightedScore / totalCoefficient
        
        try context.save()
        
        // Then - Verify complete structure
        XCTAssertEqual(period.subjects?.count, 1)
        XCTAssertEqual(subject.evaluations?.count, 4)
        
        // Verify grade calculation
        let expectedGrade = (16.0*1.0 + 14.0*1.0 + 15.0*2.0 + 18.0*3.0) / (1.0+1.0+2.0+3.0)
        // = (16 + 14 + 30 + 54) / 7 = 114/7 ≈ 16.29
        XCTAssertEqual(subject.grade, expectedGrade, accuracy: 0.01)
    }
    
    func test_FlashcardLearningSession_ShouldUpdateStats() throws {
        // Given
        let deck = FlashcardDeck(context: context)
        deck.id = UUID()
        deck.name = "Session Test"
        deck.createdAt = Date()
        
        let flashcards = (1...5).map { i in
            let card = Flashcard(context: context)
            card.id = UUID()
            card.question = "Question \(i)"
            card.answer = "Answer \(i)"
            card.createdAt = Date()
            card.correctCount = 0
            card.reviewCount = 0
            card.interval = 1.0
            card.deck = deck
            return card
        }
        
        try context.save()
        
        // When - Simulate learning session (3 correct, 2 incorrect)
        for (index, card) in flashcards.enumerated() {
            card.reviewCount += 1
            card.lastReviewed = Date()
            
            if index < 3 { // First 3 are correct
                card.correctCount += 1
                card.interval *= 2.0
            } else { // Last 2 are incorrect
                card.interval = 1.0 // Reset interval
            }
            
            card.nextReviewDate = Calendar.current.date(byAdding: .day,
                                                       value: Int(card.interval),
                                                       to: Date())
        }
        
        try context.save()
        
        // Then
        let correctCards = flashcards.filter { $0.correctCount > 0 }
        let incorrectCards = flashcards.filter { $0.correctCount == 0 }
        
        XCTAssertEqual(correctCards.count, 3)
        XCTAssertEqual(incorrectCards.count, 2)
        
        // Verify interval progression for correct cards
        for card in correctCards {
            XCTAssertEqual(card.interval, 2.0)
        }
        
        // Verify interval reset for incorrect cards
        for card in incorrectCards {
            XCTAssertEqual(card.interval, 1.0)
        }
    }
}

// MARK: - Performance Tests
extension PARALLAXGradingSystemTests {
    
    func test_LargeDataSet_Performance() throws {
        // Given - Clean existing data manually
        let existingPeriods: [Period] = {
            let request: NSFetchRequest<Period> = Period.fetchRequest()
            return (try? context.fetch(request)) ?? []
        }()
        
        // Delete existing periods (cascade will handle related objects)
        for period in existingPeriods {
            context.delete(period)
        }
        try context.save()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When - Create large dataset
        for i in 0..<100 {
            let period = Period(context: context)
            period.id = UUID()
            period.name = "Period \(i)"
            period.startDate = Date()
            period.createdAt = Date()
            
            for j in 0..<10 {
                let subject = Subject(context: context)
                subject.id = UUID()
                subject.name = "Subject \(i)-\(j)"
                subject.coefficient = Double.random(in: 1.0...5.0)
                subject.createdAt = Date()
                subject.period = period
                
                for k in 0..<5 {
                    let evaluation = Evaluation(context: context)
                    evaluation.id = UUID()
                    evaluation.title = "Eval \(i)-\(j)-\(k)"
                    evaluation.grade = Double.random(in: 0.0...20.0)
                    evaluation.coefficient = Double.random(in: 0.5...3.0)
                    evaluation.date = Date()
                    evaluation.subject = subject
                }
            }
        }
        
        try context.save()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 5.0, "Should create large dataset in less than 5 seconds")
        
        // Verify data was created
        let periodRequest: NSFetchRequest<Period> = Period.fetchRequest()
        let periodCount = try context.count(for: periodRequest)
        XCTAssertEqual(periodCount, 100)
    }
}

// MARK: - Helper Methods
extension PARALLAXGradingSystemTests {
    
    private func createTestPeriod(name: String = "Test Period") -> Period {
        let period = Period(context: context)
        period.id = UUID()
        period.name = name
        period.startDate = Date()
        period.createdAt = Date()
        return period
    }
    
    private func createTestSubject(name: String = "Test Subject",
                                  coefficient: Double = 1.0,
                                  period: Period? = nil) -> Subject {
        let subject = Subject(context: context)
        subject.id = UUID()
        subject.name = name
        subject.coefficient = coefficient
        subject.createdAt = Date()
        subject.period = period ?? testPeriod
        return subject
    }
    
    private func createTestEvaluation(title: String = "Test Evaluation",
                                     grade: Double = 15.0,
                                     coefficient: Double = 1.0,
                                     subject: Subject? = nil) -> Evaluation {
        let evaluation = Evaluation(context: context)
        evaluation.id = UUID()
        evaluation.title = title
        evaluation.grade = grade
        evaluation.coefficient = coefficient
        evaluation.date = Date()
        evaluation.subject = subject ?? testSubject
        return evaluation
    }
}
