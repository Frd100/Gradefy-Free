//
//  GermanSystemTests.swift
//  PARALLAX
//
//  Created by Farid on 6/30/25.
//


import XCTest
import Foundation
@testable import PARALLAX

final class GermanSystemTests: XCTestCase {
    var system: GermanSystem!
    
    override func setUpWithError() throws {
        system = GermanSystem()
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        system = nil
    }
    
    // MARK: - Tests Système Inversé
    func test_systemProperties_whenGermanSystem_shouldBeInverted() throws {
        XCTAssertTrue(system.isInverted)
        XCTAssertEqual(system.min, 1.0)
        XCTAssertEqual(system.max, 6.0)
        XCTAssertEqual(system.passingGrade, 4.0)
    }
    
    // MARK: - Tests Parsing Mots Allemands (évite duplication selon [2])
    func test_parse_whenGermanWords_shouldConvertToGrades() throws {
        let wordToGradeTests = [
            ("SEHR GUT", 1.0), ("SEHRGUT", 1.0),
            ("GUT", 2.0), ("BEFRIEDIGEND", 3.0),
            ("AUSREICHEND", 4.0), ("MANGELHAFT", 5.0),
            ("UNGENÜGEND", 6.0), ("UNGENUGEND", 6.0)
        ]
        
        for (word, expectedGrade) in wordToGradeTests {
            XCTAssertEqual(system.parse(word), expectedGrade, "Word \(word) should convert to \(expectedGrade)")
        }
    }
    
    // MARK: - Tests Décimales Allemandes Spéciales
    func test_parse_whenValidDecimals_shouldParseCorrectly() throws {
        let validDecimals = [
            ("1,0", 1.0), ("1.0", 1.0),
            ("1,3", 1.3), ("1.3", 1.3),
            ("1,7", 1.7), ("1.7", 1.7),
            ("2,3", 2.3), ("6,0", 6.0)
        ]
        
        for (input, expected) in validDecimals {
            XCTAssertEqual(system.parse(input), expected, "Input \(input) should parse to \(expected)")
        }
    }
    
    func test_parse_whenInvalidDecimals_shouldReturnNil() throws {
        let invalidDecimals = ["1.5", "2,2", "3.8", "0.9", "6.1"]
        
        for input in invalidDecimals {
            XCTAssertNil(system.parse(input), "Invalid decimal \(input) should return nil")
        }
    }
    
    // MARK: - Tests Appréciations Inversées
    func test_appreciation_whenInvertedSystem_shouldReturnCorrectAppreciation() throws {
        // Système inversé : 1.0 = excellent, 6.0 = insuffisant
        let appreciationTests = [
            (1.0, "Excellent"), (2.0, "Excellent"),
            (3.0, "Bien"), (4.0, "Passable"),
            (5.0, "Insuffisant"), (6.0, "Insuffisant")
        ]
        
        for (grade, expectedAppreciation) in appreciationTests {
            XCTAssertEqual(system.appreciation(for: grade), expectedAppreciation)
        }
    }
    
    // MARK: - Tests Moyenne Pondérée avec Arrondi Allemand
    func test_weightedAverage_whenGermanGrades_shouldRoundToValidDecimals() throws {
        // Arrange
        let evaluations = [
            DummyEvaluation(grade: 1.3, coefficient: 1.0),
            DummyEvaluation(grade: 2.0, coefficient: 1.0)
        ]
        
        // Act
        let result = system.weightedAverage(evaluations)
        
        // Assert - Doit être arrondi selon règles allemandes (.0, .3, .7)
        let decimal = result.truncatingRemainder(dividingBy: 1)
        let validDecimals: [Double] = [0.0, 0.3, 0.7]
        
        XCTAssertTrue(validDecimals.contains { abs(decimal - $0) < 0.01 }, 
                     "Result \(result) should have valid German decimal")
    }
}
