//
//  UKSystemTests.swift
//  PARALLAX
//
//  Created by Farid on 6/30/25.
//


import XCTest
import Foundation
@testable import PARALLAX

final class UKSystemTests: XCTestCase {
    var system: UKSystem!
    
    override func setUpWithError() throws {
        system = UKSystem()
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        system = nil
    }
    
    // MARK: - Tests Validation Pourcentages
    func test_validate_whenValidPercentages_shouldReturnTrue() throws {
        let validPercentages = [0.0, 40.0, 75.5, 100.0]
        
        for percentage in validPercentages {
            XCTAssertTrue(system.validate(percentage), "Percentage \(percentage) should be valid")
        }
    }
    
    func test_validate_whenInvalidPercentages_shouldReturnFalse() throws {
        let invalidPercentages = [-0.1, 100.1, 150.0]
        
        for percentage in invalidPercentages {
            XCTAssertFalse(system.validate(percentage), "Percentage \(percentage) should be invalid")
        }
    }
    
    // MARK: - Tests Parsing International
    func test_parse_whenPercentageFormats_shouldParseCorrectly() throws {
        let parseTests = [
            ("75", 75.0), ("75%", 75.0),
            ("85,5", 85.5), ("85.5", 85.5),
            ("100", 100.0), ("0", 0.0)
        ]
        
        for (input, expected) in parseTests {
            XCTAssertEqual(system.parse(input), expected, "Input \(input) should parse to \(expected)")
        }
    }
    
    // MARK: - Tests Système Britannique Classifications
    func test_appreciation_whenBritishGrades_shouldReturnCorrectClassification() throws {
        let classificationTests = [
            (85.0, "Excellent"), // First Class
            (70.0, "Excellent"), // First Class boundary
            (65.0, "Bien"),      // Upper Second (2:1)
            (55.0, "Bien"),      // Lower Second (2:2)
            (45.0, "Passable"),  // Third Class
            (40.0, "Passable"),  // Third Class boundary
            (35.0, "Insuffisant") // Fail
        ]
        
        for (grade, expectedClassification) in classificationTests {
            XCTAssertEqual(system.appreciation(for: grade), expectedClassification)
        }
    }
    
    // MARK: - Tests ECTS Credits (nouvelle limite 30)
    func test_validateCoefficient_whenECTSCredits_shouldValidateCorrectly() throws {
        // Arrange & Act & Assert
        let validECTS = [5.0, 10.0, 15.0, 20.0, 30.0] // ✅ Nouvelle limite
        let invalidECTS = [0.4, 30.1, 35.0]
        
        for credit in validECTS {
            XCTAssertTrue(system.validateCoefficient(credit), "ECTS \(credit) should be valid")
        }
        
        for credit in invalidECTS {
            XCTAssertFalse(system.validateCoefficient(credit), "ECTS \(credit) should be invalid")
        }
    }
    
    // MARK: - Tests Format avec Locale
    func test_format_whenValidGrade_shouldIncludePercentSymbol() throws {
        let result = system.format(75.5)
        XCTAssertTrue(result.contains("%"), "Result should contain % symbol")
    }
    
    func test_displayGrade_whenCompactMode_shouldShowIntegerPercent() throws {
        let result = system.displayGrade(75.7, compact: true)
        XCTAssertTrue(result.contains("%"), "Compact display should include %")
    }
}
