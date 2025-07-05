//
//  USASystemTests.swift
//  PARALLAX
//
//  Created by Farid on 6/30/25.
//


import XCTest
import Foundation
@testable import PARALLAX

final class USASystemTests: XCTestCase {
    var system: USASystem!
    
    override func setUpWithError() throws {
        system = USASystem()
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        system = nil
    }
    
    // MARK: - Tests Lettres → GPA (Data-driven selon [5])
    func test_parse_whenLetterGrades_shouldConvertToGPA() throws {
        let letterToGPATests = [
            ("A+", 4.0), ("A", 4.0), ("A-", 3.7),
            ("B+", 3.3), ("B", 3.0), ("B-", 2.7),
            ("C+", 2.3), ("C", 2.0), ("C-", 1.7),
            ("D+", 1.3), ("D", 1.0), ("D-", 0.7),
            ("F", 0.0)
        ]
        
        for (letter, expectedGPA) in letterToGPATests {
            XCTAssertEqual(system.parse(letter), expectedGPA, "Letter \(letter) should convert to \(expectedGPA)")
        }
    }
    
    // MARK: - Tests Parsing International
    func test_parse_whenNumericWithComma_shouldParseCorrectly() throws {
        XCTAssertEqual(system.parse("3,7"), 3.7)
    }
    
    func test_parse_whenNumericWithDot_shouldParseCorrectly() throws {
        XCTAssertEqual(system.parse("3.7"), 3.7)
    }
    
    func test_parse_whenInvalidGPA_shouldReturnNil() throws {
        let invalidInputs = ["4.1", "-0.1", "Z", ""]
        
        for input in invalidInputs {
            XCTAssertNil(system.parse(input), "Should return nil for: \(input)")
        }
    }
    
    // MARK: - Tests Format International (évite duplication)
    func test_format_whenValidGPA_shouldFormatWithCurrentLocale() throws {
        let testCases = [(3.7, "3"), (4.0, "4"), (2.0, "2")]
        
        for (gpa, expectedPrefix) in testCases {
            let result = system.format(gpa)
            XCTAssertTrue(result.hasPrefix(expectedPrefix), "GPA \(gpa) should start with \(expectedPrefix)")
        }
    }
    
    // MARK: - Tests Display Grade
    func test_displayGrade_whenCompactMode_shouldShowLetter() throws {
        XCTAssertEqual(system.displayGrade(4.0, compact: true), "A")
        XCTAssertEqual(system.displayGrade(3.3, compact: true), "B+")
    }
    
    func test_displayGrade_whenFullMode_shouldShowNumeric() throws {
        let result = system.displayGrade(3.7, compact: false)
        XCTAssertTrue(result.contains("3"), "Should contain numeric value")
    }
    
    // MARK: - Tests Validation Crédits
    func test_validateCoefficient_whenValidCredits_shouldReturnTrue() throws {
        let validCredits = [0.5, 1.0, 3.0, 6.0, 8.0]
        
        for credit in validCredits {
            XCTAssertTrue(system.validateCoefficient(credit), "Credit \(credit) should be valid")
        }
    }
    
    func test_validateCoefficient_whenInvalidCredits_shouldReturnFalse() throws {
        let invalidCredits = [0.0, 0.4, 8.1, 10.0]
        
        for credit in invalidCredits {
            XCTAssertFalse(system.validateCoefficient(credit), "Credit \(credit) should be invalid")
        }
    }
}
