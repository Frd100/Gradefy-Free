//
//  SRSBoundaryTests.swift
//  PARALLAXTests
//
//  Created by Claude on 8/18/25.
//

import XCTest
@testable import PARALLAX
import CoreData

@MainActor
class SRSBoundaryTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    var testCard: Flashcard!
    
    // ✅ Calendar figé pour éviter le flakiness
    let testCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()
    
    override func setUp() {
        super.setUp()
        
        // Créer un contexte Core Data en mémoire pour les tests
        let model = NSManagedObjectModel.mergedModel(from: [Bundle.main])!
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try! coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        
        // Créer une carte de test avec les bonnes propriétés Core Data
        testCard = Flashcard(context: context)
        testCard.id = UUID()
        testCard.reviewCount = 1
        testCard.correctCount = 1
        testCard.easeFactor = 2.5
        testCard.interval = 1.0
    }
    
    override func tearDown() {
        context = nil
        testCard = nil
        super.tearDown()
    }
    
    // MARK: - Tests de frontière temporelle (Option 2)
    
    func testCardDueTodayIsNotOverdue() {
        // Arrange : Carte due aujourd'hui à 14:00
        let now = Date()
        let todayAfternoon = testCalendar.date(bySettingHour: 14, minute: 0, second: 0, of: now)!
        testCard.nextReviewDate = todayAfternoon
        
        // Act
        let srsData = SRSData(from: testCard, calendar: testCalendar, now: now)
        let status = CardStatusUI.getStatus(from: srsData)
        
        // Assert : Doit être "due today" et PAS "overdue"
        XCTAssertTrue(srsData.isDueToday, "Carte due aujourd'hui = 'due today'")
        XCTAssertFalse(srsData.isOverdue, "Carte due aujourd'hui ≠ 'overdue'")
        XCTAssertEqual(status.message, "À réviser", "Carte due aujourd'hui = 'À réviser'")
    }
    
    func testCardOverdueIsNotDueToday() {
        // Arrange : Carte due hier
        let now = Date()
        let yesterday = testCalendar.date(byAdding: .day, value: -1, to: now)!
        testCard.nextReviewDate = yesterday
        
        // Act
        let srsData = SRSData(from: testCard, calendar: testCalendar, now: now)
        let status = CardStatusUI.getStatus(from: srsData)
        
        // Assert : Doit être "overdue" et PAS "due today"
        XCTAssertTrue(srsData.isOverdue, "Carte due hier = 'overdue'")
        XCTAssertFalse(srsData.isDueToday, "Carte due hier ≠ 'due today'")
        XCTAssertEqual(status.message, "En retard", "Carte due hier = 'En retard'")
    }
    
    func testCardDueTomorrowIsNeither() {
        // Arrange : Carte due demain
        let now = Date()
        let tomorrow = testCalendar.date(byAdding: .day, value: 1, to: now)!
        testCard.nextReviewDate = tomorrow
        
        // Act
        let srsData = SRSData(from: testCard, calendar: testCalendar, now: now)
        let status = CardStatusUI.getStatus(from: srsData)
        
        // Assert : Ne doit être ni "due today" ni "overdue"
        XCTAssertFalse(srsData.isOverdue, "Carte due demain ≠ 'overdue'")
        XCTAssertFalse(srsData.isDueToday, "Carte due demain ≠ 'due today'")
        XCTAssertGreaterThan(srsData.daysUntilNext, 0, "Carte due demain a des jours restants")
    }
    
    // MARK: - Tests de frontière critique (Minuit)
    
    func testCardDueAtMidnightToday() {
        // Arrange : Carte due exactement à 00:00 aujourd'hui
        let now = Date()
        let todayMidnight = testCalendar.startOfDay(for: now)
        testCard.nextReviewDate = todayMidnight
        
        // Act
        let srsData = SRSData(from: testCard, calendar: testCalendar, now: now)
        let status = CardStatusUI.getStatus(from: srsData)
        
        // Assert : À 00:00, la carte doit être "due today" et pas "overdue"
        XCTAssertTrue(srsData.isDueToday, "À 00:00, carte due = 'due today'")
        XCTAssertFalse(srsData.isOverdue, "À 00:00, carte due ≠ 'overdue'")
        XCTAssertEqual(status.message, "À réviser", "À 00:00 = statut 'À réviser'")
    }
    
    func testCardDueAtMidnightYesterday() {
        // Arrange : Carte due exactement à 00:00 hier
        let now = Date()
        let yesterday = testCalendar.date(byAdding: .day, value: -1, to: now)!
        let yesterdayMidnight = testCalendar.startOfDay(for: yesterday)
        testCard.nextReviewDate = yesterdayMidnight
        
        // Act
        let srsData = SRSData(from: testCard, calendar: testCalendar, now: now)
        let status = CardStatusUI.getStatus(from: srsData)
        
        // Assert : Carte due hier à 00:00 = "overdue" et pas "due today"
        XCTAssertTrue(srsData.isOverdue, "Carte due hier à 00:00 = 'overdue'")
        XCTAssertFalse(srsData.isDueToday, "Carte due hier à 00:00 ≠ 'due today'")
        XCTAssertEqual(status.message, "En retard", "Carte due hier à 00:00 = 'En retard'")
    }
    
    // MARK: - Tests de priorité d'affichage
    
    func testOverduePriorityOverDueToday() {
        // Arrange : Carte due hier (devrait être "overdue" même si techniquement "due today" dans l'ancienne logique)
        let now = Date()
        let yesterday = testCalendar.date(byAdding: .day, value: -1, to: now)!
        testCard.nextReviewDate = yesterday
        
        // Act
        let srsData = SRSData(from: testCard, calendar: testCalendar, now: now)
        let status = CardStatusUI.getStatus(from: srsData)
        
        // Assert : Priorité "overdue" > "due today"
        XCTAssertTrue(srsData.isOverdue, "Carte due hier = overdue")
        XCTAssertFalse(srsData.isDueToday, "Carte due hier ≠ due today")
        XCTAssertEqual(status.message, "En retard", "Priorité : overdue > due today")
    }
    
    func testNewCardHasCorrectStatus() {
        // Arrange
        testCard.reviewCount = 0
        testCard.nextReviewDate = nil
        
        // Act
        let srsData = SRSData(from: testCard, calendar: testCalendar, now: Date())
        let status = CardStatusUI.getStatus(from: srsData)
        
        // Assert
        XCTAssertEqual(srsData.reviewCount, 0, "Une nouvelle carte doit avoir reviewCount = 0")
        XCTAssertNil(srsData.nextReviewDate, "Une nouvelle carte doit avoir nextReviewDate = nil")
        XCTAssertEqual(status.message, "Nouvelle", "Une nouvelle carte doit avoir le statut 'Nouvelle'")
    }
}
