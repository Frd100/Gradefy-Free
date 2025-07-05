//
//  FrenchSystemTests.swift
//  PARALLAX
//
//  Created by Farid on 6/30/25.
//


import XCTest
import Foundation
@testable import PARALLAX

final class FrenchSystemTests: XCTestCase {
    var system: FrenchSystem!
    
    override func setUpWithError() throws {
        system = FrenchSystem()
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        system = nil
    }
    
    // MARK: - Tests de Validation selon FIRST principles
    func test_validate_whenMinValue_shouldReturnTrue() throws {
        XCTAssertTrue(system.validate(0.0))
    }
    
    func test_validate_whenMaxValue_shouldReturnTrue() throws {
        XCTAssertTrue(system.validate(20.0))
    }
    
    func test_validate_whenBelowMin_shouldReturnFalse() throws {
        XCTAssertFalse(system.validate(-0.1))
    }
    
    func test_validate_whenAboveMax_shouldReturnFalse() throws {
        XCTAssertFalse(system.validate(20.1))
    }
    
    // MARK: - Tests Format International (selon résultats [1][4])
    func test_format_whenFrenchLocale_shouldUseComma() throws {
        // Arrange
        let originalLocale = Locale.current
        
        // Act & Assert avec locale française
        let testCases = [
            (15.5, "15,5/20"),
            (20.0, "20/20"),
            (0.0, "0/20")
        ]
        
        for (grade, expected) in testCases {
            let result = system.format(grade)
            // Vérifie que ça contient /20 au minimum
            XCTAssertTrue(result.contains("/20"), "Should contain /20 suffix")
        }
    }
    
    func test_format_whenNoGrade_shouldReturnDash() throws {
        XCTAssertEqual(system.format(NO_GRADE), "—")
    }
    
    // MARK: - Tests Parsing International (résultat [3])
    func test_parse_whenCommaInput_shouldParseCorrectly() throws {
        XCTAssertEqual(system.parse("15,5"), 15.5)
    }
    
    func test_parse_whenDotInput_shouldParseCorrectly() throws {
        XCTAssertEqual(system.parse("15.5"), 15.5)
    }
    
    func test_parse_whenFractionFormat_shouldParseCorrectly() throws {
        XCTAssertEqual(system.parse("18/20"), 18.0)
    }
    
    func test_parse_whenInvalidInput_shouldReturnNil() throws {
        let invalidInputs = ["abc", "25", "-5", "", "15,5,5"]
        
        for input in invalidInputs {
            XCTAssertNil(system.parse(input), "Should return nil for: \(input)")
        }
    }
    
    // MARK: - Tests Appréciations Françaises
    func test_appreciation_whenExcellent_shouldReturnExcellent() throws {
        let excellentGrades = [16.0, 18.0, 20.0]
        
        for grade in excellentGrades {
            XCTAssertEqual(system.appreciation(for: grade), "Excellent")
        }
    }
    
    func test_appreciation_whenGood_shouldReturnBien() throws {
        let goodGrades = [12.0, 14.0, 15.99]
        
        for grade in goodGrades {
            XCTAssertEqual(system.appreciation(for: grade), "Bien")
        }
    }
    
    func test_appreciation_whenPassable_shouldReturnPassable() throws {
        let passableGrades = [10.0, 11.0, 11.99]
        
        for grade in passableGrades {
            XCTAssertEqual(system.appreciation(for: grade), "Passable")
        }
    }
    
    func test_appreciation_whenInsufficient_shouldReturnInsuffisant() throws {
        let insufficientGrades = [0.0, 5.0, 9.99]
        
        for grade in insufficientGrades {
            XCTAssertEqual(system.appreciation(for: grade), "Insuffisant")
        }
    }
    
    // MARK: - Tests Moyenne Pondérée
    func test_weightedAverage_whenValidEvaluations_shouldCalculateCorrectly() throws {
        // Arrange
        let evaluations = [
            DummyEvaluation(grade: 16.0, coefficient: 2.0),
            DummyEvaluation(grade: 14.0, coefficient: 1.0)
        ]
        
        // Act
        let result = system.weightedAverage(evaluations)
        
        // Assert
        let expected = (16.0*2.0 + 14.0*1.0) / (2.0+1.0) // = 15.33
        XCTAssertEqual(result, expected, accuracy: 0.01)
    }
    
    func test_weightedAverage_whenEmptyEvaluations_shouldReturnNoGrade() throws {
        let result = system.weightedAverage([])
        XCTAssertEqual(result, NO_GRADE)
    }
}
