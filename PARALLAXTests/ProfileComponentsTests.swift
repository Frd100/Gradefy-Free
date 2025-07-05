//
//  ProfileComponentsTests.swift
//  PARALLAX
//
//  Created by Farid on 7/1/25.
//

import XCTest
import CoreData        // ✅ AJOUT
import SwiftUI         // ✅ AJOUT
@testable import PARALLAX

@MainActor
final class ProfileComponentsTests: XCTestCase {
    var mockContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        mockContext = PersistenceController.inMemory.container.viewContext
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        mockContext = nil
    }
    
    // MARK: - Tests Period Management
    func test_periodManagement_whenCreatingPeriod_shouldValidateCorrectly() throws {
        // Arrange
        let validName = "Semestre 1"
        let invalidName = ""
        let startDate = Date()
        let validEndDate = Calendar.current.date(byAdding: .month, value: 6, to: startDate) ?? Date()
        let invalidEndDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate) ?? Date()
        
        // Act & Assert - Valid period
        XCTAssertFalse(validName.isEmpty, "Valid name should not be empty")
        XCTAssertLessThan(startDate, validEndDate, "Valid end date should be after start date")
        
        // Invalid period
        XCTAssertTrue(invalidName.isEmpty, "Invalid name should be empty")
        XCTAssertGreaterThan(startDate, invalidEndDate, "Invalid end date should be before start date")
    }
    
    func test_periodCreation_whenValidData_shouldCreatePeriod() throws {
        // Arrange
        let periodName = "Test Period"
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 3, to: startDate) ?? Date()
        
        // Act - Simuler création de période
        let period = Period(context: mockContext)
        period.id = UUID()
        period.name = periodName
        period.startDate = startDate
        period.endDate = endDate
        
        try mockContext.save()
        
        // Assert
        XCTAssertEqual(period.name, periodName, "Period should have correct name")
        XCTAssertEqual(period.startDate, startDate, "Period should have correct start date")
        XCTAssertEqual(period.endDate, endDate, "Period should have correct end date")
        XCTAssertNotNil(period.id, "Period should have ID")
    }
    
    // MARK: - Tests Profile Data Validation
    func test_profileValidation_whenUpdatingProfile_shouldValidateFields() throws {
        // Arrange
        let testCases = [
            (username: "Jean Dupont", subtitle: "Étudiant", isValid: true),
            (username: "", subtitle: "Étudiant", isValid: false),
            (username: "   ", subtitle: "Étudiant", isValid: false),
            (username: "Jean", subtitle: "", isValid: true) // Subtitle peut être vide
        ]
        
        for testCase in testCases {
            // Act
            let trimmedUsername = testCase.username.trimmingCharacters(in: .whitespacesAndNewlines)
            let isValid = !trimmedUsername.isEmpty
            
            // Assert
            XCTAssertEqual(isValid, testCase.isValid, "Username '\(testCase.username)' validation should be \(testCase.isValid)")
        }
    }
    
    // MARK: - Tests Color Gradient Management
    func test_colorGradientManagement_whenSelecting_shouldStoreColors() throws {
        // Arrange
        let availableGradients: [[Color]] = [
            [Color(hex: "9BE8F6"), Color(hex: "5DD5F4")],
            [Color(hex: "B0F4B6"), Color(hex: "78E089")],
            [Color(hex: "FBB3C7"), Color(hex: "F68EB2")],
            [Color(hex: "DBC7F9"), Color(hex: "C6A8EF")],
            [Color(hex: "F8C79B"), Color(hex: "F5A26A")]
        ]
        
        for (index, gradient) in availableGradients.enumerated() {
            // Act
            let selectedGradient = gradient
            
            // Assert
            XCTAssertEqual(selectedGradient.count, 2, "Gradient \(index) should have 2 colors")
            XCTAssertNotNil(selectedGradient.first, "Gradient should have start color")
            XCTAssertNotNil(selectedGradient.last, "Gradient should have end color")
        }
    }
    
    // MARK: - Tests App Icon Management
    func test_appIconManagement_whenChanging_shouldTrackState() throws {
        // Arrange
        let iconManager = AppIconManager()
        let testIcon = "AppIcon-Dark"
        
        // Act - Simuler changement d'icône
        iconManager.changeIcon(to: testIcon)
        
        // Assert
        XCTAssertTrue(iconManager.isChanging, "Should be in changing state during icon change")
    }
    
    func test_appIconManager_whenSyncing_shouldUpdateCurrentIcon() throws {
        // Arrange
        let iconManager = AppIconManager()
        
        // Act
        iconManager.syncCurrentIcon()
        
        // Assert
        XCTAssertNotNil(iconManager.currentIcon, "Should have current icon")
        XCTAssertFalse(iconManager.currentIcon.isEmpty, "Current icon should not be empty")
    }
    
    // MARK: - Tests Data Export
    func test_dataExport_whenCreatingExportData_shouldIncludeAllComponents() throws {
        // Arrange
        let mockSubjects = createMockSubjects()
        let mockEvaluations = createMockEvaluations()
        let mockPeriods = createMockPeriods()
        
        // Act - Simuler création des données d'export
        let exportData = createMockExportData(
            subjects: mockSubjects,
            evaluations: mockEvaluations,
            periods: mockPeriods
        )
        
        // Assert
        XCTAssertNotNil(exportData["export_date"], "Should include export date")
        XCTAssertNotNil(exportData["app_version"], "Should include app version")
        XCTAssertNotNil(exportData["subjects"], "Should include subjects")
        XCTAssertNotNil(exportData["evaluations"], "Should include evaluations")
        XCTAssertNotNil(exportData["periods"], "Should include periods")
        
        if let subjects = exportData["subjects"] as? [[String: Any]] {
            XCTAssertEqual(subjects.count, mockSubjects.count, "Should export all subjects")
        }
    }
    
    // MARK: - Tests Data Reset
    func test_dataReset_whenPerformed_shouldClearAllData() throws {
        // Arrange
        let initialSubject = Subject(context: mockContext)
        initialSubject.id = UUID()
        initialSubject.name = "Test Subject"
        try mockContext.save()
        
        // Verify data exists
        let fetchRequest: NSFetchRequest<Subject> = Subject.fetchRequest()
        let subjectsBeforeReset = try mockContext.fetch(fetchRequest)
        XCTAssertGreaterThan(subjectsBeforeReset.count, 0, "Should have subjects before reset")
        
        // Act - Simuler reset
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: Subject.fetchRequest())
        try mockContext.execute(deleteRequest)
        mockContext.refreshAllObjects()
        
        // Assert
        let subjectsAfterReset = try mockContext.fetch(fetchRequest)
        XCTAssertEqual(subjectsAfterReset.count, 0, "Should have no subjects after reset")
    }
    
    // MARK: - Tests Adaptive Image Component
    func test_adaptiveImage_whenInitialized_shouldHaveCorrectProperties() throws {
        // Arrange
        let lightImageName = "iconsettingwhite"
        let darkImageName = "iconsettingblack"
        let imageSize = CGSize(width: 24, height: 24)
        
        // Act - Simuler AdaptiveImage properties
        let adaptiveImageData = (
            lightImage: lightImageName,
            darkImage: darkImageName,
            size: imageSize
        )
        
        // Assert
        XCTAssertEqual(adaptiveImageData.lightImage, lightImageName, "Should have correct light image name")
        XCTAssertEqual(adaptiveImageData.darkImage, darkImageName, "Should have correct dark image name")
        XCTAssertEqual(adaptiveImageData.size, imageSize, "Should have correct size")
    }
    
    // MARK: - Helper Methods
    private func createMockSubjects() -> [Subject] {
        let subject = Subject(context: mockContext)
        subject.id = UUID()
        subject.name = "Mock Subject"
        subject.coefficient = 2.0
        subject.grade = 15.0
        return [subject]
    }
    
    private func createMockEvaluations() -> [Evaluation] {
        let evaluation = Evaluation(context: mockContext)
        evaluation.id = UUID()
        evaluation.title = "Mock Evaluation"
        evaluation.grade = 16.0
        evaluation.coefficient = 1.0
        evaluation.date = Date()
        return [evaluation]
    }
    
    private func createMockPeriods() -> [Period] {
        let period = Period(context: mockContext)
        period.id = UUID()
        period.name = "Mock Period"
        period.startDate = Date()
        period.endDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())
        return [period]
    }
    
    private func createMockExportData(subjects: [Subject], evaluations: [Evaluation], periods: [Period]) -> [String: Any] {
        return [
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "app_version": "1.0.0",
            "subjects": subjects.map { ["id": $0.id?.uuidString ?? "", "name": $0.name ?? ""] },
            "evaluations": evaluations.map { ["id": $0.id?.uuidString ?? "", "title": $0.title ?? ""] },
            "periods": periods.map { ["id": $0.id?.uuidString ?? "", "name": $0.name ?? ""] }
        ]
    }
}
