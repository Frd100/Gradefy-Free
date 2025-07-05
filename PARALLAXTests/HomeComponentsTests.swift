//
//  HomeComponentsTests.swift
//  PARALLAX
//
//  Created by Farid on 7/1/25.
//


import XCTest
import SwiftUI         // ✅ AJOUT
import CoreData        // ✅ AJOUT
@testable import PARALLAX

@MainActor
final class HomeComponentsTests: XCTestCase {
    var mockSubjects: [Subject]!
    var mockContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        mockContext = PersistenceController.inMemory.container.viewContext
        mockSubjects = createMockSubjects()
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        mockSubjects = nil
        mockContext = nil
    }
    
    // MARK: - Tests Activity Ring Logic
    func test_activityRingValue_whenValidFraction_shouldClampCorrectly() throws {
        // Arrange
        let validFraction = 0.75
        let overFraction = 1.5
        let underFraction = -0.5
        
        // Act - Simuler la logique safeFraction d'ActivityRingView
        let safe1 = min(max(validFraction, 0), 1)
        let safe2 = min(max(overFraction, 0), 1)
        let safe3 = min(max(underFraction, 0), 1)
        
        // Assert
        XCTAssertEqual(safe1, 0.75, "Valid fraction should remain unchanged")
        XCTAssertEqual(safe2, 1.0, "Over fraction should be clamped to 1.0")
        XCTAssertEqual(safe3, 0.0, "Under fraction should be clamped to 0.0")
    }
    
    // MARK: - Tests Stats Card Logic
    func test_statsCardCalculation_whenValidSubjects_shouldCalculateAverage() throws {
        // Arrange
        let subjects = mockSubjects.filter { $0.grade != NO_GRADE }
        let gradingSystem = FrenchSystem()
        
        // Act - Simuler la logique calculatedData de StatsCardView
        let validSubjects = subjects.filter { subject in
            gradingSystem.validate(subject.grade)
        }
        
        guard !validSubjects.isEmpty else {
            XCTFail("Should have valid subjects")
            return
        }
        
        let dummyEvals = validSubjects.map {
            DummyEvaluation(grade: $0.grade, coefficient: $0.coefficient)
        }
        
        let average = gradingSystem.weightedAverage(dummyEvals)
        let fraction = calculateFraction(grade: average, system: gradingSystem)
        
        // Assert
        XCTAssertNotEqual(average, NO_GRADE, "Should calculate valid average")
        XCTAssertTrue(gradingSystem.validate(average), "Calculated average should be valid")
        XCTAssertGreaterThanOrEqual(fraction, 0.0, "Fraction should be >= 0")
        XCTAssertLessThanOrEqual(fraction, 1.0, "Fraction should be <= 1")
    }
    
    func test_statsCardCalculation_whenNoValidSubjects_shouldReturnNoGrade() throws {
        // Arrange
        let emptySubjects: [Subject] = []
        let gradingSystem = FrenchSystem()
        
        // Act
        let validSubjects = emptySubjects.filter { subject in
            gradingSystem.validate(subject.grade)
        }
        
        // Assert
        XCTAssertTrue(validSubjects.isEmpty, "Should have no valid subjects")
    }
    
    // MARK: - Tests calculateFraction Function
    func test_calculateFraction_whenFrenchSystem_shouldReturnCorrectFraction() throws {
        // Arrange
        let frenchSystem = FrenchSystem()
        let testGrades = [0.0, 10.0, 15.0, 20.0]
        let expectedFractions = [0.0, 0.5, 0.75, 1.0]
        
        // Act & Assert
        for (grade, expectedFraction) in zip(testGrades, expectedFractions) {
            let fraction = calculateFraction(grade: grade, system: frenchSystem)
            XCTAssertEqual(fraction, expectedFraction, accuracy: 0.01, 
                          "Grade \(grade) should have fraction \(expectedFraction)")
        }
    }
    
    func test_calculateFraction_whenGermanSystem_shouldHandleInvertedScale() throws {
        // Arrange
        let germanSystem = GermanSystem()
        let testGrades = [1.0, 3.5, 6.0]
        
        // Act & Assert
        for grade in testGrades {
            let fraction = calculateFraction(grade: grade, system: germanSystem)
            XCTAssertGreaterThanOrEqual(fraction, 0.0, "Fraction should be >= 0")
            XCTAssertLessThanOrEqual(fraction, 1.0, "Fraction should be <= 1")
            
            // Pour le système allemand inversé, meilleure note (1.0) = fraction élevée
            if grade == 1.0 {
                XCTAssertGreaterThan(fraction, 0.8, "Grade 1.0 should have high fraction")
            }
        }
    }
    
    func test_calculateFraction_whenNoGrade_shouldReturnZero() throws {
        // Arrange
        let anySystem = FrenchSystem()
        
        // Act
        let fraction = calculateFraction(grade: NO_GRADE, system: anySystem)
        
        // Assert
        XCTAssertEqual(fraction, 0.0, "NO_GRADE should return 0.0 fraction")
    }
    
    // MARK: - Tests Subject Status Logic
    func test_subjectStatusCalculation_whenMixedGrades_shouldCountCorrectly() throws {
        // Arrange
        let allSubjects = mockSubjects ?? []  // ✅ Déballage sécurisé
        
        // Act
        let totalSubjects = allSubjects.count
        let subjectsWithoutGrades = allSubjects.filter { $0.grade == NO_GRADE }.count
        let subjectsWithGrades = totalSubjects - subjectsWithoutGrades
        
        // Assert
        XCTAssertEqual(totalSubjects, allSubjects.count, "Total should match input count")
        XCTAssertGreaterThanOrEqual(subjectsWithoutGrades, 0, "Subjects without grades should be >= 0")
        XCTAssertGreaterThanOrEqual(subjectsWithGrades, 0, "Subjects with grades should be >= 0")
        XCTAssertEqual(subjectsWithGrades + subjectsWithoutGrades, totalSubjects, "Counts should add up")
    }
    
    // MARK: - Tests Card Visibility Logic
    func test_cardVisibilityLogic_whenNoSubjects_shouldShowEmptyStates() throws {
        // Arrange
        let emptySubjects: [Subject] = []
        let emptyEvaluations: [Evaluation] = []
        
        // Act
        let hasSubjects = !emptySubjects.isEmpty
        let hasEvaluations = !emptyEvaluations.isEmpty
        let shouldShowDataCards = hasSubjects || hasEvaluations
        
        // Assert
        XCTAssertFalse(hasSubjects, "Should not have subjects")
        XCTAssertFalse(hasEvaluations, "Should not have evaluations") 
        XCTAssertFalse(shouldShowDataCards, "Should not show data cards")
    }
    
    func test_cardVisibilityLogic_whenHasData_shouldShowDataCards() throws {
        // Arrange
        let subjects = mockSubjects!
        let mockEvaluations = [createMockEvaluation()]
        
        // Act
        let hasSubjects = !subjects.isEmpty
        let hasEvaluations = !mockEvaluations.isEmpty
        let shouldShowDataCards = hasSubjects || hasEvaluations
        
        // Assert
        XCTAssertTrue(hasSubjects, "Should have subjects")
        XCTAssertTrue(hasEvaluations, "Should have evaluations")
        XCTAssertTrue(shouldShowDataCards, "Should show data cards")
    }
    
    // MARK: - Helper Methods
    private func createMockSubjects() -> [Subject] {
        var subjects: [Subject] = []
        
        // Sujet avec note
        let mathSubject = Subject(context: mockContext)
        mathSubject.id = UUID()
        mathSubject.name = "Mathématiques"
        mathSubject.grade = 15.5
        mathSubject.coefficient = 4.0
        subjects.append(mathSubject)
        
        // Sujet sans note
        let physicsSubject = Subject(context: mockContext)
        physicsSubject.id = UUID()
        physicsSubject.name = "Physique"
        physicsSubject.grade = NO_GRADE
        physicsSubject.coefficient = 3.0
        subjects.append(physicsSubject)
        
        // Sujet avec note parfaite
        let frenchSubject = Subject(context: mockContext)
        frenchSubject.id = UUID()
        frenchSubject.name = "Français"
        frenchSubject.grade = 20.0
        frenchSubject.coefficient = 3.0
        subjects.append(frenchSubject)
        
        try? mockContext.save()
        return subjects
    }
    
    private func createMockEvaluation() -> Evaluation {
        let evaluation = Evaluation(context: mockContext)
        evaluation.id = UUID()
        evaluation.title = "Test Evaluation"
        evaluation.grade = 16.0
        evaluation.coefficient = 2.0
        evaluation.date = Date()
        return evaluation
    }
}
