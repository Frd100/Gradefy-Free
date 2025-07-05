//
//  InternationalLocaleTests.swift
//  PARALLAX
//
//  Created by Farid on 6/30/25.
//


import XCTest
import Foundation
@testable import PARALLAX

final class InternationalLocaleTests: XCTestCase {
    var systems: [GradingSystemPlugin]!
    
    override func setUpWithError() throws {
        systems = [FrenchSystem(), USASystem(), GermanSystem(), UKSystem()]
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        systems = nil
    }
    
    // MARK: - Tests Parsing Universel (évite duplication selon [2])
    func test_allSystems_whenCommaAndDotInput_shouldParseConsistently() throws {
        let testInputs = [
            ("15,5", 15.5),
            ("15.5", 15.5),
            ("3,7", 3.7),
            ("3.7", 3.7)
        ]
        
        for system in systems {
            for (input, expected) in testInputs {
                // Skip si pas dans la plage du système
                guard system.validate(expected) else { continue }
                
                let result = system.parse(input)
                XCTAssertEqual(result, expected, 
                              "System \(system.id) should parse \(input) as \(expected)")
            }
        }
    }
    
    // MARK: - Tests Format selon Locale Courante
    func test_allSystems_whenFormatting_shouldRespectCurrentLocale() throws {
        for system in systems {
            let testGrade = system.min + (system.max - system.min) / 2
            let formatted = system.format(testGrade)
            
            XCTAssertFalse(formatted.isEmpty, "System \(system.id) should format grade")
            XCTAssertNotEqual(formatted, "—", "Valid grade should not format as dash")
        }
    }
    
    // MARK: - Tests Couleurs Cohérentes
    func test_allSystems_whenExcellentGrades_shouldReturnGreenColor() throws {
        // Arrange - Notes excellentes dans chaque système
        let excellentGrades = [
            "french": 18.0,
            "usa": 4.0,
            "germany": 1.0, // Inversé
            "uk": 85.0
        ]
        
        for system in systems {
            guard let excellentGrade = excellentGrades[system.id] else { continue }
            
            // Act & Assert
            XCTAssertEqual(system.gradeColor(for: excellentGrade), GradeColor.excellent,
                          "System \(system.id) should return excellent color for \(excellentGrade)")
        }
    }
    
    // MARK: - Tests Messages d'Erreur (selon [1])
    func test_allSystems_whenEmptyInput_shouldProvideErrorMessage() throws {
        for system in systems {
            let errorMessage = system.validationErrorMessage(for: "")
            XCTAssertFalse(errorMessage.isEmpty, "System \(system.id) should provide error message")
        }
    }
}
