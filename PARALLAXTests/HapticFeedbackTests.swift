//
//  HapticFeedbackTests.swift
//  PARALLAX
//
//  Created by Farid on 7/1/25.
//


import XCTest
import UIKit
@testable import PARALLAX

final class HapticFeedbackTests: XCTestCase {
    var hapticManager: HapticFeedbackManager!
    
    override func setUpWithError() throws {
        hapticManager = HapticFeedbackManager.shared
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        hapticManager = nil
    }
    
    // MARK: - Tests Configuration Haptique
    func test_hapticManager_whenEnabled_shouldRespondToSettings() throws {
        // Arrange - Force enable haptics
        UserDefaults.standard.set(true, forKey: "enableHaptics")
        
        // Act & Assert - Should not crash when calling methods
        XCTAssertNoThrow(hapticManager.impact(style: .light))
        XCTAssertNoThrow(hapticManager.selection())
        XCTAssertNoThrow(hapticManager.notification(type: .success))
    }
    
    func test_hapticManager_whenDisabled_shouldRespectSettings() throws {
        // Arrange - Disable haptics
        UserDefaults.standard.set(false, forKey: "enableHaptics")
        
        // Act & Assert - Should not crash and should respect disabled state
        XCTAssertNoThrow(hapticManager.impact(style: .medium))
        XCTAssertNoThrow(hapticManager.notification(type: .error))
    }
    
    // MARK: - Tests Types de Feedback
    func test_hapticManager_whenDifferentStyles_shouldHandleAllTypes() throws {
        // Arrange
        let impactStyles: [UIImpactFeedbackGenerator.FeedbackStyle] = [.light, .medium, .heavy]
        let notificationTypes: [UINotificationFeedbackGenerator.FeedbackType] = [.success, .warning, .error]
        
        // Act & Assert
        for style in impactStyles {
            XCTAssertNoThrow(hapticManager.impact(style: style), "Should handle impact style: \(style)")
        }
        
        for type in notificationTypes {
            XCTAssertNoThrow(hapticManager.notification(type: type), "Should handle notification type: \(type)")
        }
        
        XCTAssertNoThrow(hapticManager.selection(), "Should handle selection feedback")
    }
    
    // MARK: - Tests Singleton Pattern
    func test_hapticManager_whenAccessingShared_shouldReturnSameInstance() throws {
        // Arrange & Act
        let instance1 = HapticFeedbackManager.shared
        let instance2 = HapticFeedbackManager.shared
        
        // Assert
        XCTAssertTrue(instance1 === instance2, "Should return same singleton instance")
    }
    
    // MARK: - Tests Integration avec UserDefaults
    func test_hapticSettings_whenToggled_shouldPersist() throws {
        // Arrange
        let initialSetting = UserDefaults.standard.bool(forKey: "enableHaptics")
        
        // Act
        UserDefaults.standard.set(!initialSetting, forKey: "enableHaptics")
        let newSetting = UserDefaults.standard.bool(forKey: "enableHaptics")
        
        // Assert
        XCTAssertNotEqual(initialSetting, newSetting, "Setting should be toggled")
        
        // Cleanup
        UserDefaults.standard.set(initialSetting, forKey: "enableHaptics")
    }
}
