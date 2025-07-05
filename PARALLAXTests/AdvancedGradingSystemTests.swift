//
//  AdvancedGradingSystemTests.swift
//  PARALLAX
//
//  Created by Farid on 7/1/25.
//


import XCTest
import CoreData        // ✅ AJOUT
@testable import PARALLAX

final class AdvancedGradingSystemTests: XCTestCase {
    var mockContext: NSManagedObjectContext!
    var testSubject: Subject!
    
    override func setUpWithError() throws {
        mockContext = PersistenceController.inMemory.container.viewContext
        testSubject = createTestSubject()
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        mockContext = nil
        testSubject = nil
    }
    
    // MARK: - Tests Recalcul Optimisé
    func test_recalculateAverageOptimized_whenValidEvaluations_shouldCalculateCorrectly() throws {
        // Arrange
        createTestEvaluations()
        
        // Act
        testSubject.recalculateAverageOptimized(context: mockContext)
        
        // Attendre que le recalcul asynchrone se termine
        let expectation = XCTestExpectation(description: "Recalculation completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Assert
        XCTAssertNotEqual(testSubject.grade, NO_GRADE, "Should calculate valid average")
        XCTAssertTrue(GradingSystemRegistry.active.validate(testSubject.grade), "Calculated grade should be valid for current system")
    }
    
    func test_recalculateAverageOptimized_whenNoEvaluations_shouldSetNoGrade() throws {
        // Arrange - Pas d'évaluations
        
        // Act
        testSubject.recalculateAverageOptimized(context: mockContext)
        
        // Wait for async completion
        let expectation = XCTestExpectation(description: "Recalculation completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Assert
        XCTAssertEqual(testSubject.grade, NO_GRADE, "Should set NO_GRADE when no evaluations exist")
    }
    
    // MARK: - Tests Weighted Average Complex
    func test_weightedAverage_whenComplexCoefficients_shouldCalculateAccurately() throws {
        // Arrange
        let system = FrenchSystem()
        let evaluations = [
            DummyEvaluation(grade: 16.0, coefficient: 4.0), // Maths
            DummyEvaluation(grade: 14.5, coefficient: 3.0), // Physique
            DummyEvaluation(grade: 18.0, coefficient: 2.0), // Français
            DummyEvaluation(grade: 12.0, coefficient: 1.5), // Histoire
            DummyEvaluation(grade: 15.5, coefficient: 2.5)  // Anglais
        ]
        
        // Act
        let average = system.weightedAverage(evaluations)
        
        // Calcul manuel pour vérification
        let totalWeighted = 16.0*4.0 + 14.5*3.0 + 18.0*2.0 + 12.0*1.5 + 15.5*2.5
        let totalCoeff = 4.0 + 3.0 + 2.0 + 1.5 + 2.5
        let expected = totalWeighted / totalCoeff
        
        // Assert
        XCTAssertEqual(average, expected, accuracy: 0.01, "Complex weighted average should be calculated correctly")
    }
    
    // MARK: - Tests Edge Cases NO_GRADE
    func test_weightedAverage_whenMixedWithNoGrade_shouldIgnoreNoGrades() throws {
        // Arrange
        let system = FrenchSystem()
        let evaluations = [
            DummyEvaluation(grade: 16.0, coefficient: 2.0),
            DummyEvaluation(grade: NO_GRADE, coefficient: 3.0), // Ignoré
            DummyEvaluation(grade: 14.0, coefficient: 1.0),
            DummyEvaluation(grade: NO_GRADE, coefficient: 2.0)  // Ignoré
        ]
        
        // Act
        let average = system.weightedAverage(evaluations)
        
        // Expected: (16.0*2.0 + 14.0*1.0) / (2.0+1.0) = 46/3 = 15.33
        let expected = (16.0*2.0 + 14.0*1.0) / (2.0+1.0)
        
        // Assert
        XCTAssertEqual(average, expected, accuracy: 0.01, "Should ignore NO_GRADE evaluations")
    }
    
    // MARK: - Tests Format Grade Clean
    func test_formatGradeClean_whenDifferentSystems_shouldFormatCorrectly() throws {
        // Arrange
        let testGrade = 15.75
        let systems: [GradingSystemPlugin] = [
            FrenchSystem(),
            USASystem(),
            UKSystem(),
            GermanSystem()
        ]
        
        for system in systems {
            // Convertir la note au système approprié
            let convertedGrade = convertGradeToSystem(testGrade, system: system)
            
            // Act
            let formatted = formatGradeClean(convertedGrade, system: system)
            
            // Assert
            XCTAssertFalse(formatted.isEmpty, "Formatted grade should not be empty for \(system.id)")
            if system.suffix.isEmpty {
                XCTAssertFalse(formatted.contains("/"), "System \(system.id) should not contain / in format")
            } else {
                XCTAssertTrue(formatted.contains(system.suffix), "Formatted grade should contain system suffix for \(system.id)")
            }
        }
    }
    
    // MARK: - Tests Calculate Fraction Advanced
    func test_calculateFraction_whenInvertedSystem_shouldCalculateCorrectly() throws {
        // Arrange
        let germanSystem = GermanSystem()
        let testCases = [
            (grade: 1.0, expectedFraction: 1.0), // Meilleure note
            (grade: 3.5, expectedFraction: 0.5), // Milieu
            (grade: 6.0, expectedFraction: 0.0), // Pire note
            (grade: NO_GRADE, expectedFraction: 0.0)
        ]
        
        for testCase in testCases {
            // Act
            let fraction = calculateFraction(grade: testCase.grade, system: germanSystem)
            
            // Assert
            XCTAssertEqual(fraction, testCase.expectedFraction, accuracy: 0.01, 
                          "Grade \(testCase.grade) should have fraction \(testCase.expectedFraction) in inverted system")
        }
    }
    
    // MARK: - Tests Subject Data Structure
    func test_subjectData_whenCreated_shouldBeHashable() throws {
        // Arrange
        let subject1 = SubjectData(code: "MATH", name: "Mathématiques", grade: 15.0, coefficient: 2.0, periodName: "S1")
        let subject2 = SubjectData(code: "MATH", name: "Mathématiques", grade: 15.0, coefficient: 2.0, periodName: "S1")
        let subject3 = SubjectData(code: "PHYS", name: "Physique", grade: 15.0, coefficient: 2.0, periodName: "S1")
        
        // Act
        let set = Set([subject1, subject2, subject3])
        
        // Assert
        XCTAssertEqual(set.count, 2, "Set should contain 2 unique subjects (subject1 == subject2)")
    }
    
    // MARK: - Tests Performance avec Large Dataset
    func test_performance_whenLargeDataset_shouldMaintainSpeed() throws {
        // Arrange
        let largeEvaluationSet = Array(0..<1000).map { i in
            DummyEvaluation(grade: Double(10 + i % 10), coefficient: Double(1 + i % 3))
        }
        let system = FrenchSystem()
        
        // Act & Assert
        measure {
            _ = system.weightedAverage(largeEvaluationSet)
        }
    }
    
    // MARK: - Tests Thread Safety
    func test_threadSafety_whenConcurrentAccess_shouldNotCrash() throws {
        // Arrange
        let system = FrenchSystem()
        let evaluations = [
            DummyEvaluation(grade: 15.0, coefficient: 2.0),
            DummyEvaluation(grade: 17.0, coefficient: 3.0)
        ]
        let expectation = XCTestExpectation(description: "Concurrent calculations")
        expectation.expectedFulfillmentCount = 10
        
        // Act - Calculs concurrents
        for _ in 0..<10 {
            DispatchQueue.global(qos: .background).async {
                let average = system.weightedAverage(evaluations)
                XCTAssertNotEqual(average, NO_GRADE, "Should calculate valid average")
                expectation.fulfill()
            }
        }
        
        // Assert
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Helper Methods
    private func createTestSubject() -> Subject {
        let subject = Subject(context: mockContext)
        subject.id = UUID()
        subject.name = "Test Subject"
        subject.coefficient = 2.0
        subject.grade = NO_GRADE
        return subject
    }
    
    private func createTestEvaluations() {
        let evaluations = [
            (grade: 16.0, coeff: 2.0),
            (grade: 14.0, coeff: 1.0),
            (grade: 18.0, coeff: 3.0)
        ]
        
        for evalData in evaluations {
            let evaluation = Evaluation(context: mockContext)
            evaluation.id = UUID()
            evaluation.grade = evalData.grade
            evaluation.coefficient = evalData.coeff
            evaluation.subject = testSubject
            evaluation.date = Date()
        }
        
        try? mockContext.save()
    }
    
    private func convertGradeToSystem(_ frenchGrade: Double, system: GradingSystemPlugin) -> Double {
        guard frenchGrade != NO_GRADE else { return NO_GRADE }
        
        switch system.id {
        case "usa":
            return (frenchGrade / 20.0) * 4.0
        case "germany":
            let percentage = frenchGrade / 20.0
            return 6.0 - (percentage * 5.0)
        case "uk":
            return (frenchGrade / 20.0) * 100.0
        default:
            return frenchGrade
        }
    }
}
