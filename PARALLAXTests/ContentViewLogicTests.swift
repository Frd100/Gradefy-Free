//
//  ContentViewLogicTests.swift
//  PARALLAX
//
//  Created by Farid on 7/1/25.
//


import XCTest
import CoreData        // ✅ AJOUT
@testable import PARALLAX

@MainActor
final class ContentViewLogicTests: XCTestCase {
    var mockContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        mockContext = PersistenceController.inMemory.container.viewContext
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        mockContext = nil
    }
    
    // MARK: - Tests Period Selection Logic
    func test_periodSelection_whenMultiplePeriods_shouldSelectCorrectly() throws {
        // Arrange
        let period1 = createMockPeriod(name: "Semester 1")
        let period2 = createMockPeriod(name: "Semester 2")
        let periods = [period1, period2]
        
        // Act - Simuler la logique d'activePeriod
        let firstPeriod = periods.first
        
        // Assert
        XCTAssertEqual(firstPeriod?.name, "Semester 1", "Should select first period by default")
    }
    
    // MARK: - Tests Subject Filtering Logic
    func test_subjectFiltering_whenFilterByPeriod_shouldReturnCorrectSubjects() throws {
        // Arrange
        let period1 = createMockPeriod(name: "S1")
        let period2 = createMockPeriod(name: "S2")
        
        let subject1 = createMockSubject(name: "Math", period: period1)
        let subject2 = createMockSubject(name: "Physics", period: period2)
        let subject3 = createMockSubject(name: "Chemistry", period: period1)
        
        let allSubjects = [subject1, subject2, subject3]
        
        // Act - Simuler displayedSubjects logic
        let filteredByPeriod1 = allSubjects.filter { $0.period == period1 }
        let filteredByPeriod2 = allSubjects.filter { $0.period == period2 }
        
        // Assert
        XCTAssertEqual(filteredByPeriod1.count, 2, "Period 1 should have 2 subjects")
        XCTAssertEqual(filteredByPeriod2.count, 1, "Period 2 should have 1 subject")
        
        XCTAssertTrue(filteredByPeriod1.contains(subject1), "Should contain Math")
        XCTAssertTrue(filteredByPeriod1.contains(subject3), "Should contain Chemistry")
        XCTAssertTrue(filteredByPeriod2.contains(subject2), "Should contain Physics")
    }
    
    // MARK: - Tests Sort Options Logic
    func test_sortingLogic_whenSortByName_shouldSortAlphabetically() throws {
        // Arrange
        let subjects = [
            createMockSubject(name: "Physique", grade: 15.0),
            createMockSubject(name: "Anglais", grade: 17.0),
            createMockSubject(name: "Mathématiques", grade: 14.0)
        ]
        
        // Act - Simuler tri alphabétique
        let sortedSubjects = subjects.sorted { subject1, subject2 in
            let name1 = subject1.name?.lowercased() ?? ""
            let name2 = subject2.name?.lowercased() ?? ""
            return name1 < name2
        }
        
        // Assert
        XCTAssertEqual(sortedSubjects[0].name, "Anglais", "First should be Anglais")
        XCTAssertEqual(sortedSubjects[1].name, "Mathématiques", "Second should be Mathématiques")
        XCTAssertEqual(sortedSubjects[2].name, "Physique", "Third should be Physique")
    }
    
    func test_sortingLogic_whenSortByGrade_shouldSortByPerformance() throws {
        // Arrange
        let subjects = [
            createMockSubject(name: "Math", grade: 12.0),
            createMockSubject(name: "Physics", grade: 18.0),
            createMockSubject(name: "Chemistry", grade: 15.0),
            createMockSubject(name: "English", grade: NO_GRADE)
        ]
        
        let system = FrenchSystem()
        
        // Act - Simuler tri par note (meilleure → pire)
        let sortedSubjects = subjects.sorted { subject1, subject2 in
            let grade1 = subject1.grade
            let grade2 = subject2.grade
            
            let isGrade1Valid = grade1 != NO_GRADE && system.validate(grade1)
            let isGrade2Valid = grade2 != NO_GRADE && system.validate(grade2)
            
            if !isGrade1Valid && !isGrade2Valid {
                return (subject1.name ?? "") < (subject2.name ?? "")
            } else if !isGrade1Valid {
                return false  // Sujets sans note à la fin
            } else if !isGrade2Valid {
                return true   // Sujets avec note en premier
            } else {
                return grade1 > grade2  // Meilleure note en premier
            }
        }
        
        // Assert
        XCTAssertEqual(sortedSubjects[0].name, "Physics", "Physics (18.0) should be first")
        XCTAssertEqual(sortedSubjects[1].name, "Chemistry", "Chemistry (15.0) should be second")
        XCTAssertEqual(sortedSubjects[2].name, "Math", "Math (12.0) should be third")
        XCTAssertEqual(sortedSubjects[3].name, "English", "English (no grade) should be last")
    }
    
    // MARK: - Tests Next Evaluation Logic
    func test_nextEvaluationLogic_whenFutureEvaluations_shouldSelectNearest() throws {
        // Arrange
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: now)!
        
        let eval1 = createMockEvaluation(title: "Test 1", date: nextWeek)
        let eval2 = createMockEvaluation(title: "Test 2", date: tomorrow)
        let evaluations = [eval1, eval2]
        
        // Act - Simuler nextEvaluation logic
        let futureEvals = evaluations.filter { eval in
            guard let evaluationDate = eval.date else { return false }
            return evaluationDate > now
        }
        
        let nextEvaluation = futureEvals.min { first, second in
            guard let date1 = first.date, let date2 = second.date else { return false }
            return date1 < date2
        }
        
        // Assert
        XCTAssertEqual(nextEvaluation?.title, "Test 2", "Should select nearest future evaluation")
        XCTAssertEqual(nextEvaluation?.date, tomorrow, "Should have tomorrow's date")
    }
    
    // MARK: - Tests Time Until Evaluation
    func test_timeUntilEvaluation_whenFutureDate_shouldCalculateCorrectly() throws {
        // Arrange
        let now = Date()
        let futureDate = Calendar.current.date(byAdding: .hour, value: 25, to: now)! // 1 jour et 1 heure
        
        // Act - Simuler timeUntilNextEvaluation logic
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        
        let timeString = formatter.string(from: now, to: futureDate)
        
        // Assert
        XCTAssertNotNil(timeString, "Should calculate time string")
        XCTAssertTrue(timeString?.contains("d") ?? false, "Should contain day abbreviation")
    }
    
    // MARK: - Helper Methods
    private func createMockPeriod(name: String) -> Period {
        let period = Period(context: mockContext)
        period.id = UUID()
        period.name = name
        period.startDate = Date()
        period.endDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())
        return period
    }
    
    private func createMockSubject(name: String, period: Period? = nil, grade: Double = NO_GRADE) -> Subject {
        let subject = Subject(context: mockContext)
        subject.id = UUID()
        subject.name = name
        subject.grade = grade
        subject.coefficient = 1.0
        subject.period = period
        return subject
    }
    
    private func createMockEvaluation(title: String, date: Date) -> Evaluation {
        let evaluation = Evaluation(context: mockContext)
        evaluation.id = UUID()
        evaluation.title = title
        evaluation.date = date
        evaluation.grade = 15.0
        evaluation.coefficient = 1.0
        return evaluation
    }
}
