//
//  ColorExtensionTests.swift
//  PARALLAX
//
//  Created by Farid on 7/1/25.
//


import XCTest
import SwiftUI         // ✅ AJOUTEZ CETTE LIGNE
import CoreData
@testable import PARALLAX

final class ColorExtensionTests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    // MARK: - Tests Conversion Hex
    func test_colorFromHex_whenValidHex_shouldCreateCorrectColor() throws {
        // Arrange & Act
        let redColor = Color(hex: "FF0000")
        let greenColor = Color(hex: "00FF00")
        let blueColor = Color(hex: "0000FF")
        let _ = Color(hex: "5AC8FA")
        
        // Assert - Vérification via UIColor
        let uiRed = UIColor(redColor)
        let uiGreen = UIColor(greenColor)
        let uiBlue = UIColor(blueColor)
        
        XCTAssertNotNil(uiRed)
        XCTAssertNotNil(uiGreen)
        XCTAssertNotNil(uiBlue)
    }
    
    func test_colorFromHex_whenShortHex_shouldCreateCorrectColor() throws {
        // Arrange & Act
        let shortRedColor = Color(hex: "F00") // RGB 12-bit
        let shortWhiteColor = Color(hex: "FFF")
        
        // Assert
        let uiRed = UIColor(shortRedColor)
        let uiWhite = UIColor(shortWhiteColor)
        
        XCTAssertNotNil(uiRed)
        XCTAssertNotNil(uiWhite)
    }
    
    func test_colorFromHex_whenInvalidHex_shouldCreateDefaultColor() throws {
        // Arrange & Act
        let invalidColor = Color(hex: "INVALID")
        let emptyColor = Color(hex: "")
        
        // Assert - Devrait créer une couleur par défaut
        let uiInvalid = UIColor(invalidColor)
        let uiEmpty = UIColor(emptyColor)
        
        XCTAssertNotNil(uiInvalid)
        XCTAssertNotNil(uiEmpty)
    }
    
    // MARK: - Tests Conversion vers Hex
    func test_colorToHex_whenStandardColors_shouldReturnCorrectHex() throws {
        // Arrange
        let redColor = Color.red
        let blueColor = Color.blue
        let blackColor = Color.black
        
        // Act
        let redHex = redColor.toHex()
        let blueHex = blueColor.toHex()
        let blackHex = blackColor.toHex()
        
        // Assert
        XCTAssertEqual(redHex.count, 6, "Hex should be 6 characters")
        XCTAssertEqual(blueHex.count, 6, "Hex should be 6 characters")
        XCTAssertEqual(blackHex, "000000", "Black should be 000000")
    }
    
    func test_colorToHexWithAlpha_whenColorWithTransparency_shouldIncludeAlpha() throws {
        // Arrange
        let transparentRed = Color.red.opacity(0.5)
        
        // Act
        let hexWithAlpha = transparentRed.toHexWithAlpha()
        
        // Assert
        XCTAssertEqual(hexWithAlpha.count, 8, "Hex with alpha should be 8 characters")
    }
    
    // MARK: - Tests Couleurs App Theme
    func test_appThemeColors_whenAccessed_shouldReturnValidColors() throws {
        // Act
        let appBackground = Color.appBackground
        let cardBackground = Color.cardBackground
        let gradeBluePrimary = Color.gradeBluePrimary
        let gradeGreenSecondary = Color.gradeGreenSecondary
        
        // Assert
        XCTAssertNotNil(UIColor(appBackground))
        XCTAssertNotNil(UIColor(cardBackground))
        XCTAssertNotNil(UIColor(gradeBluePrimary))
        XCTAssertNotNil(UIColor(gradeGreenSecondary))
    }
    
    // MARK: - Tests isDark Property
    func test_isDark_whenDarkColors_shouldReturnTrue() throws {
        // Arrange
        let blackColor = Color.black
        let darkGray = Color(hex: "333333")
        
        // Act & Assert
        XCTAssertTrue(blackColor.isDark, "Black should be considered dark")
        XCTAssertTrue(darkGray.isDark, "Dark gray should be considered dark")
    }
    
    func test_isDark_whenLightColors_shouldReturnFalse() throws {
        // Arrange
        let whiteColor = Color.white
        let lightGray = Color(hex: "CCCCCC")
        
        // Act & Assert
        XCTAssertFalse(whiteColor.isDark, "White should not be considered dark")
        XCTAssertFalse(lightGray.isDark, "Light gray should not be considered dark")
    }
    
    // MARK: - Tests Contrasting Color
    func test_contrastingColor_whenDarkColor_shouldReturnWhite() throws {
        // Arrange
        let darkColor = Color.black
        
        // Act
        let contrasting = darkColor.contrastingColor
        
        // Assert
        XCTAssertEqual(contrasting, Color.white, "Dark color should contrast with white")
    }
    
    func test_contrastingColor_whenLightColor_shouldReturnBlack() throws {
        // Arrange
        let lightColor = Color.white
        
        // Act
        let contrasting = lightColor.contrastingColor
        
        // Assert
        XCTAssertEqual(contrasting, Color.black, "Light color should contrast with black")
    }
}
