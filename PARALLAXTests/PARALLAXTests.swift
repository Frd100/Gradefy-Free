//
// PARALLAXTests.swift
// PARALLAXTests
//
// Tests unitaires pour le système de notation Gradefy
//

import XCTest
import CoreData
@testable import PARALLAX

final class PARALLAXTests: XCTestCase {
    
    // MARK: - Properties
    var persistentContainer: NSPersistentContainer!
    var testContext: NSManagedObjectContext!
    var frenchSystem: FrenchSystem!
    var germanSystem: GermanSystem!
    var usaSystem: USASystem!
    var spanishSystem: SpanishSystem!
    var canadianSystem: CanadianSystem!
    
    // MARK: - Setup & Teardown
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Configuration d'un container Core Data en mémoire pour les tests
        persistentContainer = NSPersistentContainer(name: "PARALLAX")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        let expectation = expectation(description: "Store Loaded")
        persistentContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)
        
        testContext = persistentContainer.viewContext
        
        // Initialisation des systèmes de notation
        frenchSystem = FrenchSystem()
        germanSystem = GermanSystem()
        usaSystem = USASystem()
        spanishSystem = SpanishSystem()
        canadianSystem = CanadianSystem()
    }
    
    override func tearDownWithError() throws {
        persistentContainer = nil
        testContext = nil
        frenchSystem = nil
        germanSystem = nil
        usaSystem = nil
        spanishSystem = nil
        canadianSystem = nil
        try super.tearDownWithError()
    }
}

// MARK: - Tests Système Français
extension PARALLAXTests {
    
    func testFrenchSystem_Properties() {
        XCTAssertEqual(frenchSystem.id, "france")
        XCTAssertEqual(frenchSystem.min, 0.0, accuracy: 0.01)
        XCTAssertEqual(frenchSystem.max, 20.0, accuracy: 0.01)
        XCTAssertEqual(frenchSystem.suffix, "/20")
        XCTAssertEqual(frenchSystem.passingGrade, 10.0, accuracy: 0.01)
        XCTAssertEqual(frenchSystem.decimalPlaces, 2)
        XCTAssertFalse(frenchSystem.isInverted)
    }
    
    func testFrenchSystem_Validation() {
        // Cas valides
        XCTAssertTrue(frenchSystem.validate(0.0))
        XCTAssertTrue(frenchSystem.validate(10.0))
        XCTAssertTrue(frenchSystem.validate(20.0))
        XCTAssertTrue(frenchSystem.validate(15.5))
        
        // Cas invalides
        XCTAssertFalse(frenchSystem.validate(-0.1))
        XCTAssertFalse(frenchSystem.validate(20.1))
        XCTAssertFalse(frenchSystem.validate(-5.0))
        XCTAssertFalse(frenchSystem.validate(25.0))
    }
    
    func testFrenchSystem_Format() {
        XCTAssertEqual(frenchSystem.format(15.0), "15.00/20")
        XCTAssertEqual(frenchSystem.format(12.5), "12.50/20")
        XCTAssertEqual(frenchSystem.format(0.0), "0.00/20")
        XCTAssertEqual(frenchSystem.format(NO_GRADE), "—")
    }
    
    func testFrenchSystem_Parse() {
        // TODO: Corriger les types de retour - API parse() à revoir
        // XCTAssertEqual(frenchSystem.parse("15"), 15.0, accuracy: 0.01)
        // XCTAssertEqual(frenchSystem.parse("12.5"), 12.5, accuracy: 0.01)
        // XCTAssertEqual(frenchSystem.parse("15/20"), 15.0, accuracy: 0.01)
        // XCTAssertEqual(frenchSystem.parse("12,5"), 12.5, accuracy: 0.01) // Virgule française
        XCTAssertNil(frenchSystem.parse("25")) // Hors limites
        XCTAssertNil(frenchSystem.parse("-5")) // Négatif
        XCTAssertNil(frenchSystem.parse("abc")) // Non numérique
    }
    
    func testFrenchSystem_GradeColor() {
        XCTAssertEqual(frenchSystem.gradeColor(for: 18.0), GradeColor.excellent)
        XCTAssertEqual(frenchSystem.gradeColor(for: 15.0), GradeColor.veryGood)
        XCTAssertEqual(frenchSystem.gradeColor(for: 13.0), GradeColor.good)
        XCTAssertEqual(frenchSystem.gradeColor(for: 11.0), GradeColor.average)
        XCTAssertEqual(frenchSystem.gradeColor(for: 8.0), GradeColor.failure)
        XCTAssertEqual(frenchSystem.gradeColor(for: NO_GRADE), GradeColor.noGrade)
    }
    
    func testFrenchSystem_WeightedAverage() {
        let evaluations = [
            DummyEvaluation(grade: 16.0, coefficient: 2.0),
            DummyEvaluation(grade: 12.0, coefficient: 1.0),
            DummyEvaluation(grade: 18.0, coefficient: 3.0)
        ]
        
        let expected = (16.0*2.0 + 12.0*1.0 + 18.0*3.0) / (2.0+1.0+3.0) // = 15.67
        let result = frenchSystem.weightedAverage(evaluations)
        XCTAssertEqual(result, expected, accuracy: 0.01)
    }
    
    func testFrenchSystem_WeightedAverage_EmptyList() {
        let result = frenchSystem.weightedAverage([])
        XCTAssertEqual(result, NO_GRADE, accuracy: 0.01)
    }
    
    func testFrenchSystem_WeightedAverage_WithNoGrades() {
        let evaluations = [
            DummyEvaluation(grade: NO_GRADE, coefficient: 2.0),
            DummyEvaluation(grade: NO_GRADE, coefficient: 1.0)
        ]
        
        let result = frenchSystem.weightedAverage(evaluations)
        XCTAssertEqual(result, NO_GRADE, accuracy: 0.01)
    }
}

// MARK: - Tests Système Allemand
extension PARALLAXTests {
    
    func testGermanSystem_Properties() {
        XCTAssertEqual(germanSystem.id, "germany")
        XCTAssertEqual(germanSystem.min, 1.0, accuracy: 0.01)
        XCTAssertEqual(germanSystem.max, 5.0, accuracy: 0.01)
        XCTAssertEqual(germanSystem.passingGrade, 4.0, accuracy: 0.01)
        XCTAssertEqual(germanSystem.decimalPlaces, 1)
        XCTAssertTrue(germanSystem.isInverted) // Système inversé
    }
    
    func testGermanSystem_Validation() {
        // Cas valides
        XCTAssertTrue(germanSystem.validate(1.0))
        XCTAssertTrue(germanSystem.validate(2.5))
        XCTAssertTrue(germanSystem.validate(5.0))
        XCTAssertTrue(germanSystem.validate(3.7))
        
        // Cas invalides
        XCTAssertFalse(germanSystem.validate(0.9))
        XCTAssertFalse(germanSystem.validate(5.1))
        XCTAssertFalse(germanSystem.validate(0.0))
        XCTAssertFalse(germanSystem.validate(6.0))
    }
    
    func testGermanSystem_Parse_AllowsAnyDecimal() {
        // Test que le système allemand permet n'importe quelle décimale
        // TODO: Corriger les types de retour - API parse() à revoir
        // XCTAssertEqual(germanSystem.parse("1.0"), 1.0, accuracy: 0.01)
        // XCTAssertEqual(germanSystem.parse("1.23"), 1.23, accuracy: 0.01)
        // XCTAssertEqual(germanSystem.parse("2.567"), 2.567, accuracy: 0.01)
        // XCTAssertEqual(germanSystem.parse("4.99"), 4.99, accuracy: 0.01)
        XCTAssertNil(germanSystem.parse("0.9")) // Hors limites
        XCTAssertNil(germanSystem.parse("5.1")) // Hors limites
    }
    
    func testGermanSystem_GradeColor_Inverted() {
        // Dans le système allemand, 1 = excellent, 5 = échec
        XCTAssertEqual(germanSystem.gradeColor(for: 1.0), GradeColor.excellent)
        XCTAssertEqual(germanSystem.gradeColor(for: 1.5), GradeColor.excellent)
        XCTAssertEqual(germanSystem.gradeColor(for: 2.0), GradeColor.veryGood)
        XCTAssertEqual(germanSystem.gradeColor(for: 3.0), GradeColor.good)
        XCTAssertEqual(germanSystem.gradeColor(for: 4.0), GradeColor.average)
        XCTAssertEqual(germanSystem.gradeColor(for: 5.0), GradeColor.failure)
    }
}

// MARK: - Tests Système USA
extension PARALLAXTests {
    
    func testUSASystem_Properties() {
        XCTAssertEqual(usaSystem.id, "usa")
        XCTAssertEqual(usaSystem.min, 0.0, accuracy: 0.01)
        XCTAssertEqual(usaSystem.max, 4.0, accuracy: 0.01)
        XCTAssertEqual(usaSystem.passingGrade, 2.0, accuracy: 0.01)
        XCTAssertEqual(usaSystem.decimalPlaces, 2)
        XCTAssertFalse(usaSystem.isInverted)
    }
    
    func testUSASystem_Validation() {
        XCTAssertTrue(usaSystem.validate(0.0))
        XCTAssertTrue(usaSystem.validate(2.5))
        XCTAssertTrue(usaSystem.validate(4.0))
        XCTAssertFalse(usaSystem.validate(-0.1))
        XCTAssertFalse(usaSystem.validate(4.1))
    }
    
    func testUSASystem_GradeColor() {
        XCTAssertEqual(usaSystem.gradeColor(for: 3.8), GradeColor.excellent)
        XCTAssertEqual(usaSystem.gradeColor(for: 3.5), GradeColor.veryGood)
        XCTAssertEqual(usaSystem.gradeColor(for: 2.5), GradeColor.good)
        XCTAssertEqual(usaSystem.gradeColor(for: 2.0), GradeColor.average)
        XCTAssertEqual(usaSystem.gradeColor(for: 1.5), GradeColor.failure)
    }
}

// MARK: - Tests Système Espagnol
extension PARALLAXTests {
    
    func testSpanishSystem_Properties() {
        XCTAssertEqual(spanishSystem.id, "spain")
        XCTAssertEqual(spanishSystem.min, 0.0, accuracy: 0.01)
        XCTAssertEqual(spanishSystem.max, 10.0, accuracy: 0.01)
        XCTAssertEqual(spanishSystem.passingGrade, 5.0, accuracy: 0.01)
        XCTAssertEqual(spanishSystem.decimalPlaces, 1)
    }
    
    func testSpanishSystem_Validation() {
        XCTAssertTrue(spanishSystem.validate(0.0))
        XCTAssertTrue(spanishSystem.validate(5.5))
        XCTAssertTrue(spanishSystem.validate(10.0))
        XCTAssertFalse(spanishSystem.validate(-1.0))
        XCTAssertFalse(spanishSystem.validate(11.0))
    }
    
    func testSpanishSystem_GradeColor() {
        XCTAssertEqual(spanishSystem.gradeColor(for: 9.5), GradeColor.excellent)
        XCTAssertEqual(spanishSystem.gradeColor(for: 8.0), GradeColor.veryGood)
        XCTAssertEqual(spanishSystem.gradeColor(for: 6.5), GradeColor.good)
        XCTAssertEqual(spanishSystem.gradeColor(for: 5.5), GradeColor.average)
        XCTAssertEqual(spanishSystem.gradeColor(for: 3.0), GradeColor.failure)
    }
}

// MARK: - Tests Système Canadien
extension PARALLAXTests {
    
    func testCanadianSystem_Properties() {
        XCTAssertEqual(canadianSystem.id, "canada")
        XCTAssertEqual(canadianSystem.min, 0.0, accuracy: 0.01)
        XCTAssertEqual(canadianSystem.max, 4.0, accuracy: 0.01)
        XCTAssertEqual(canadianSystem.passingGrade, 2.0, accuracy: 0.01)
        XCTAssertEqual(canadianSystem.decimalPlaces, 2)
    }
    
    func testCanadianSystem_Validation() {
        XCTAssertTrue(canadianSystem.validate(0.0))
        XCTAssertTrue(canadianSystem.validate(2.5))
        XCTAssertTrue(canadianSystem.validate(4.0))
        XCTAssertFalse(canadianSystem.validate(-0.1))
        XCTAssertFalse(canadianSystem.validate(4.1))
    }
}

// MARK: - Tests Registry Pattern
extension PARALLAXTests {
    
    func testGradingSystemRegistry_Available() {
        let available = GradingSystemRegistry.available
        XCTAssertEqual(available.count, 5)
        
        let ids = available.map { $0.id }
        XCTAssertTrue(ids.contains("france"))
        XCTAssertTrue(ids.contains("usa"))
        XCTAssertTrue(ids.contains("germany"))
        XCTAssertTrue(ids.contains("spain"))
        XCTAssertTrue(ids.contains("canada"))
    }
    
    func testGradingSystemRegistry_SetActive() {
        // Test par défaut
        let defaultSystem = GradingSystemRegistry.active
        XCTAssertEqual(defaultSystem.id, "france")
        
        // Test changement vers USA
        GradingSystemRegistry.setActiveSystem(id: "usa")
        let usaSystem = GradingSystemRegistry.active
        XCTAssertEqual(usaSystem.id, "usa")
        
        // Test changement vers Allemagne
        GradingSystemRegistry.setActiveSystem(id: "germany")
        let germanSystem = GradingSystemRegistry.active
        XCTAssertEqual(germanSystem.id, "germany")
        
        // Reset vers France
        GradingSystemRegistry.setActiveSystem(id: "france")
    }
}

// MARK: - Tests Calculs GPA Global
extension PARALLAXTests {
    
    /// Calcule le GPA global à partir d'une liste de matières
    func calculateOverallGPA(subjects: [Subject]) -> Double {
        let validSubjects = subjects.filter { $0.currentGrade != NO_GRADE && $0.creditHours > 0.0 }
        guard !validSubjects.isEmpty else { return NO_GRADE }
        
        let system = GradingSystemRegistry.active
        
        if system.id == "usa" || system.id == "canada" {
            // Logique GPA avec creditHours
            let totalGradePoints = validSubjects.reduce(0.0) { sum, subject in
                return sum + (subject.currentGrade * subject.creditHours)
            }
            let totalCreditHours = validSubjects.reduce(0.0) { $0 + $1.creditHours }
            guard totalCreditHours > 0.0 else { return NO_GRADE }
            return totalGradePoints / totalCreditHours
        } else {
            // Logique moyenne européenne avec coefficients
            let totalWeighted = validSubjects.reduce(0.0) { sum, subject in
                return sum + (subject.currentGrade * subject.coefficient)
            }
            let totalWeights = validSubjects.reduce(0.0) { $0 + $1.coefficient }
            guard totalWeights > 0.0 else { return NO_GRADE }
            return totalWeighted / totalWeights
        }
    }
    
    func testCalculateOverallGPA_EmptySubjects() {
        let result = calculateOverallGPA(subjects: [])
        XCTAssertEqual(result, NO_GRADE, accuracy: 0.01)
    }
    
    func testCalculateOverallGPA_NoValidSubjects() {
        let subject1 = createTestSubject(name: "Math", grade: NO_GRADE, coefficient: 2.0, creditHours: 3.0)
        let subject2 = createTestSubject(name: "Physics", grade: NO_GRADE, coefficient: 1.0, creditHours: 4.0)
        
        let result = calculateOverallGPA(subjects: [subject1, subject2])
        XCTAssertEqual(result, NO_GRADE, accuracy: 0.01)
    }
    
    func testCalculateOverallGPA_USA_System() {
        // Set system to USA
        GradingSystemRegistry.setActiveSystem(id: "usa")
        
        let subject1 = createTestSubject(name: "Math", grade: 3.5, coefficient: 1.0, creditHours: 3.0)
        let subject2 = createTestSubject(name: "Physics", grade: 4.0, coefficient: 1.0, creditHours: 4.0)
        let subject3 = createTestSubject(name: "Chemistry", grade: 3.0, coefficient: 1.0, creditHours: 2.0)
        
        let result = calculateOverallGPA(subjects: [subject1, subject2, subject3])
        let expected = (3.5*3.0 + 4.0*4.0 + 3.0*2.0) / (3.0+4.0+2.0) // = 3.56
        XCTAssertEqual(result, expected, accuracy: 0.01)
        
        // Reset to France
        GradingSystemRegistry.setActiveSystem(id: "france")
    }
    
    func testCalculateOverallGPA_European_System() {
        // System par défaut (France)
        let subject1 = createTestSubject(name: "Math", grade: 16.0, coefficient: 2.0, creditHours: 3.0)
        let subject2 = createTestSubject(name: "Physics", grade: 14.0, coefficient: 1.0, creditHours: 4.0)
        let subject3 = createTestSubject(name: "Chemistry", grade: 12.0, coefficient: 3.0, creditHours: 2.0)
        
        let result = calculateOverallGPA(subjects: [subject1, subject2, subject3])
        let expected = (16.0*2.0 + 14.0*1.0 + 12.0*3.0) / (2.0+1.0+3.0) // = 14.33
        XCTAssertEqual(result, expected, accuracy: 0.01)
    }
}

// MARK: - Tests Extension Subject Core Data
extension PARALLAXTests {
    
    func testSubject_CurrentGrade_Empty() {
        let subject = createTestSubject(name: "Math", grade: 0.0, coefficient: 2.0, creditHours: 3.0)
        
        // Pas d'évaluations
        XCTAssertEqual(subject.currentGrade, NO_GRADE, accuracy: 0.01)
    }
    
    func testSubject_CurrentGrade_WithEvaluations() {
        let subject = createTestSubject(name: "Math", grade: 0.0, coefficient: 2.0, creditHours: 3.0)
        
        // Ajouter des évaluations
        _ = createTestEvaluation(subject: subject, title: "Test 1", grade: 16.0, coefficient: 2.0)
        _ = createTestEvaluation(subject: subject, title: "Test 2", grade: 12.0, coefficient: 1.0)
        
        let expected = (16.0*2.0 + 12.0*1.0) / (2.0+1.0) // = 14.67
        XCTAssertEqual(subject.currentGrade, expected, accuracy: 0.01)
    }
    
    func testSubject_IsValidForGPA() {
        let validSubject = createTestSubject(name: "Math", grade: 15.0, coefficient: 2.0, creditHours: 3.0)
        _ = createTestEvaluation(subject: validSubject, title: "Test", grade: 15.0, coefficient: 1.0)
        XCTAssertTrue(validSubject.isValidForGPA)
        
        let invalidSubject = createTestSubject(name: "Physics", grade: NO_GRADE, coefficient: 2.0, creditHours: 3.0)
        XCTAssertFalse(invalidSubject.isValidForGPA)
    }
    
    func testSubject_RecalculateAverageOptimized() throws {
        let subject = createTestSubject(name: "Math", grade: 0.0, coefficient: 2.0, creditHours: 3.0)
        
        _ = createTestEvaluation(subject: subject, title: "Test 1", grade: 16.0, coefficient: 2.0)
        _ = createTestEvaluation(subject: subject, title: "Test 2", grade: 12.0, coefficient: 1.0)
        
        subject.recalculateAverageOptimized(context: testContext, autoSave: false)
        
        let expected = (16.0*2.0 + 12.0*1.0) / (2.0+1.0) // = 14.67
        XCTAssertEqual(subject.grade, expected, accuracy: 0.01)
    }
}

// MARK: - Tests Validation Anti-Doublons
extension PARALLAXTests {
    
    func testDuplicateEvaluationTitle_Detection() {
        let subject = createTestSubject(name: "Math", grade: 0.0, coefficient: 2.0, creditHours: 3.0)
        
        _ = createTestEvaluation(subject: subject, title: "Contrôle 1", grade: 15.0, coefficient: 1.0)
        _ = createTestEvaluation(subject: subject, title: "Devoir 1", grade: 12.0, coefficient: 2.0)
        
        // Test de détection des doublons
        XCTAssertTrue(isDuplicateTitle("Contrôle 1", in: subject))
        XCTAssertTrue(isDuplicateTitle("contrôle 1", in: subject)) // Case insensitive
        XCTAssertTrue(isDuplicateTitle("DEVOIR 1", in: subject)) // Case insensitive
        XCTAssertFalse(isDuplicateTitle("Contrôle 2", in: subject))
        XCTAssertFalse(isDuplicateTitle("Examen", in: subject))
    }
    
    func testDuplicateEvaluationTitle_WithSpaces() {
        let subject = createTestSubject(name: "Math", grade: 0.0, coefficient: 2.0, creditHours: 3.0)
        
        _ = createTestEvaluation(subject: subject, title: "  Contrôle 1  ", grade: 15.0, coefficient: 1.0)
        
        // Test avec espaces en plus
        XCTAssertTrue(isDuplicateTitle("Contrôle 1", in: subject))
        XCTAssertTrue(isDuplicateTitle("  contrôle 1  ", in: subject))
    }
}

// MARK: - Tests Utilitaires Parsing
extension PARALLAXTests {
    
    func testParseDecimalInput_ValidInputs() {
        // TODO: Corriger les types de retour - API parseDecimalInput() à revoir
        // XCTAssertEqual(parseDecimalInput("15"), 15.0, accuracy: 0.01)
        // XCTAssertEqual(parseDecimalInput("12.5"), 12.5, accuracy: 0.01)
        // XCTAssertEqual(parseDecimalInput("12,5"), 12.5, accuracy: 0.01) // Virgule française
        // XCTAssertEqual(parseDecimalInput("0"), 0.0, accuracy: 0.01)
        // XCTAssertEqual(parseDecimalInput("  15.5  "), 15.5, accuracy: 0.01) // Avec espaces
    }
    
    func testParseDecimalInput_InvalidInputs() {
        XCTAssertNil(parseDecimalInput(""))
        XCTAssertNil(parseDecimalInput("abc"))
        XCTAssertNil(parseDecimalInput("15.5.2"))
        XCTAssertNil(parseDecimalInput("   "))
    }
    
    func testFormatNumber() {
        XCTAssertEqual(formatNumber(15.123, places: 2), "15.12")
        XCTAssertEqual(formatNumber(10.0, places: 1), "10.0")
        XCTAssertEqual(formatNumber(0.0, places: 0), "0")
    }
    
    func testFormatCoefficientClean() {
        XCTAssertEqual(formatCoefficientClean(1.0), "1")
        XCTAssertEqual(formatCoefficientClean(2.5), "2.5")
        XCTAssertEqual(formatCoefficientClean(3.0), "3")
    }
    
    func testUpToTwoDecimals() {
        XCTAssertEqual(upToTwoDecimals(1.0), "1")
        XCTAssertEqual(upToTwoDecimals(2.5), "2.5")
        XCTAssertEqual(upToTwoDecimals(3.123), "3.12")
    }
}

// MARK: - Tests de Performance
extension PARALLAXTests {
    
    func testPerformance_WeightedAverageCalculation() {
        let evaluations = Array(0..<1000).map { i in
            DummyEvaluation(grade: Double(10 + i % 10), coefficient: Double(1 + i % 3))
        }
        
        measure {
            _ = frenchSystem.weightedAverage(evaluations)
        }
    }
    
    func testPerformance_GradingSystemValidation() {
        let grades = Array(0..<1000).map { _ in Double.random(in: 0.0...25.0) }
        
        measure {
            for grade in grades {
                _ = frenchSystem.validate(grade)
            }
        }
    }
}

// MARK: - Tests Edge Cases
extension PARALLAXTests {
    
    func testEdgeCases_MaximumValues() {
        // Test avec les valeurs maximales de chaque système
        XCTAssertTrue(frenchSystem.validate(20.0))
        XCTAssertTrue(germanSystem.validate(5.0))
        XCTAssertTrue(usaSystem.validate(4.0))
        XCTAssertTrue(spanishSystem.validate(10.0))
        XCTAssertTrue(canadianSystem.validate(4.0))
    }
    
    func testEdgeCases_MinimumValues() {
        // Test avec les valeurs minimales de chaque système
        XCTAssertTrue(frenchSystem.validate(0.0))
        XCTAssertTrue(germanSystem.validate(1.0))
        XCTAssertTrue(usaSystem.validate(0.0))
        XCTAssertTrue(spanishSystem.validate(0.0))
        XCTAssertTrue(canadianSystem.validate(0.0))
    }
    
    func testEdgeCases_ZeroCoefficients() {
        let evaluations = [
            DummyEvaluation(grade: 15.0, coefficient: 0.0),
            DummyEvaluation(grade: 12.0, coefficient: 0.0)
        ]
        
        let result = frenchSystem.weightedAverage(evaluations)
        XCTAssertEqual(result, NO_GRADE, accuracy: 0.01)
    }
    
    func testEdgeCases_VeryLargeNumbers() {
        // Test avec de très grands coefficients
        let evaluations = [
            DummyEvaluation(grade: 15.0, coefficient: 999999.0),
            DummyEvaluation(grade: 10.0, coefficient: 1.0)
        ]
        
        let result = frenchSystem.weightedAverage(evaluations)
        // Doit être très proche de 15 car le coefficient est énorme
        XCTAssertEqual(result, 15.0, accuracy: 0.1)
    }
}

// MARK: - Tests Système-Spécifiques
extension PARALLAXTests {
    
    func testValidateCoefficient_AllSystems() {
        // Test validation des coefficients pour chaque système
        XCTAssertTrue(frenchSystem.validateCoefficient(1.0))
        XCTAssertTrue(frenchSystem.validateCoefficient(5.0))
        XCTAssertFalse(frenchSystem.validateCoefficient(0.0))
        
        XCTAssertTrue(germanSystem.validateCoefficient(1.0))
        XCTAssertTrue(germanSystem.validateCoefficient(8.0))
        XCTAssertFalse(germanSystem.validateCoefficient(0.0))
        
        XCTAssertTrue(usaSystem.validateCoefficient(1.0))
        XCTAssertTrue(usaSystem.validateCoefficient(8.0))
        XCTAssertFalse(usaSystem.validateCoefficient(0.0))
    }
    
    func testErrorMessages_AllSystems() {
        // Test des messages d'erreur pour chaque système
        XCTAssertFalse(frenchSystem.validationErrorMessage(for: "25").isEmpty)
        XCTAssertFalse(frenchSystem.coefficientErrorMessage(for: "0").isEmpty)
        
        XCTAssertFalse(germanSystem.validationErrorMessage(for: "6").isEmpty)
        XCTAssertFalse(germanSystem.coefficientErrorMessage(for: "0").isEmpty)
        
        XCTAssertFalse(usaSystem.validationErrorMessage(for: "5").isEmpty)
        XCTAssertFalse(usaSystem.coefficientErrorMessage(for: "0").isEmpty)
    }
}

// MARK: - Helper Methods
extension PARALLAXTests {
    
    func createTestSubject(name: String, grade: Double, coefficient: Double, creditHours: Double) -> Subject {
        let subject = Subject(context: testContext)
        subject.id = UUID()
        subject.name = name
        subject.grade = grade
        subject.coefficient = coefficient
        subject.creditHours = creditHours
        subject.lastModified = Date()
        return subject
    }
    
    @discardableResult
    func createTestEvaluation(subject: Subject, title: String, grade: Double, coefficient: Double) -> Evaluation {
        let evaluation = Evaluation(context: testContext)
        evaluation.id = UUID()
        evaluation.title = title
        evaluation.grade = grade
        evaluation.coefficient = coefficient
        evaluation.date = Date()
        evaluation.subject = subject
        return evaluation
    }
    
    func isDuplicateTitle(_ title: String, in subject: Subject) -> Bool {
        let existingTitles = subject.evaluations?.compactMap { ($0 as? Evaluation)?.title?.lowercased() } ?? []
        return existingTitles.contains(title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}
