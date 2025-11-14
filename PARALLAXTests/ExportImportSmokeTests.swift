//
//  ExportImportSmokeTests.swift
//  PARALLAXTests
//
//  Tests manuels documentés pour l'export/import des decks
//

import XCTest
import CoreData
@testable import PARALLAX

final class ExportImportSmokeTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        context = PersistenceController.preview.container.viewContext
    }
    
    override func tearDownWithError() throws {
        try clearAllData()
    }
    
    // MARK: - Smoke Tests Manuels Documentés
    
    /// 🔥 SMOKE TEST 1: Export/Import complet avec progression SM-2
    /// 
    /// Objectif: Vérifier qu'une session complète d'apprentissage est préservée
    /// 
    /// Étapes:
    /// 1. Créer un deck avec 2 cartes
    /// 2. Simuler une progression SM-2 (révisions, échecs, succès)
    /// 3. Exporter les données
    /// 4. Nettoyer complètement
    /// 5. Réimporter
    /// 6. Vérifier que la progression est identique
    func testSmoke_CompleteLearningSessionPreserved() throws {
        // Given - Deck avec progression SM-2
        let deck = createTestDeck(name: "Mathématiques")
        let card1 = createTestCard(question: "2+2=?", answer: "4", deck: deck)
        let card2 = createTestCard(question: "3×3=?", answer: "9", deck: deck)
        
        // Simuler progression SM-2
        card1.interval = 5.0
        card1.easeFactor = 2.1
        card1.correctCount = 3
        card1.reviewCount = 4
        card1.nextReviewDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        card1.lastReviewDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        
        card2.interval = 1.0
        card2.easeFactor = 1.8
        card2.correctCount = 0
        card2.reviewCount = 2
        card2.nextReviewDate = Date() // Due aujourd'hui
        card2.lastReviewDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        
        try context.save()
        
        // When - Export/Import round-trip
        let manager = DataImportExportManager()
        manager.setContext(context)
        
        let exportData = try await manager.exportAllData()
        try clearAllData()
        try await manager.importAllData(from: exportData)
        
        // Then - Progression préservée
        let importedCards = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(importedCards.count, 2)
        
        let importedCard1 = importedCards.first { $0.question == "2+2=?" }
        XCTAssertNotNil(importedCard1)
        XCTAssertEqual(importedCard1?.interval, 5.0)
        XCTAssertEqual(importedCard1?.easeFactor, 2.1)
        XCTAssertEqual(importedCard1?.correctCount, 3)
        XCTAssertEqual(importedCard1?.reviewCount, 4)
        
        let importedCard2 = importedCards.first { $0.question == "3×3=?" }
        XCTAssertNotNil(importedCard2)
        XCTAssertEqual(importedCard2?.interval, 1.0)
        XCTAssertEqual(importedCard2?.easeFactor, 1.8)
        XCTAssertEqual(importedCard2?.correctCount, 0)
        XCTAssertEqual(importedCard2?.reviewCount, 2)
        
        // Vérifier les statuts
        let status1 = SimpleSRSManager.shared.getCardStatusMessage(card: importedCard1!)
        let status2 = SimpleSRSManager.shared.getCardStatusMessage(card: importedCard2!)
        
        XCTAssertEqual(status1.message, "À réviser")
        XCTAssertEqual(status2.message, "À réviser")
    }
    
    /// 🔥 SMOKE TEST 2: Fusion de données partielles
    /// 
    /// Objectif: Vérifier que l'import fusionne correctement avec des données existantes
    /// 
    /// Étapes:
    /// 1. Créer des cartes locales avec progression
    /// 2. Préparer un JSON d'import avec des données différentes pour les mêmes cartes
    /// 3. Importer (fusion)
    /// 4. Vérifier que les données du JSON ont écrasé les locales
    func testSmoke_MergePartialData() throws {
        // Given - Cartes locales existantes
        let deck = createTestDeck(name: "Histoire")
        let card1 = createTestCard(question: "Qui était Napoléon?", answer: "Empereur français", deck: deck)
        let card2 = createTestCard(question: "Quand 1789?", answer: "Révolution française", deck: deck)
        
        // Progression locale
        card1.interval = 1.0
        card1.correctCount = 0
        card1.reviewCount = 1
        
        card2.interval = 3.0
        card2.correctCount = 2
        card2.reviewCount = 3
        
        try context.save()
        
        // JSON d'import avec progression différente
        let importJSON: [String: Any] = [
            "metadata": [
                "export_date": "2024-01-01T00:00:00Z",
                "app_version": "1.0",
                "format_version": "2.0"
            ],
            "flashcard_decks": [
                [
                    "id": deck.id!.uuidString,
                    "name": "Histoire",
                    "createdAt": "2024-01-01T00:00:00Z"
                ]
            ],
            "flashcards": [
                [
                    "id": card1.id!.uuidString,
                    "question": "Qui était Napoléon?",
                    "answer": "Empereur français",
                    "intervalDays": 7.0,
                    "easeFactor": 2.5,
                    "correctCount": 5,
                    "reviewCount": 6,
                    "nextReviewDate": "2024-01-10T00:00:00Z",
                    "lastReviewDate": "2024-01-03T00:00:00Z",
                    "createdAt": "2024-01-01T00:00:00Z",
                    "deckId": deck.id!.uuidString,
                    "schemaVersion": "2.0"
                ],
                [
                    "id": card2.id!.uuidString,
                    "question": "Quand 1789?",
                    "answer": "Révolution française",
                    "intervalDays": 1.0,
                    "easeFactor": 1.5,
                    "correctCount": 0,
                    "reviewCount": 3,
                    "nextReviewDate": "2024-01-02T00:00:00Z",
                    "lastReviewDate": "2024-01-01T00:00:00Z",
                    "createdAt": "2024-01-01T00:00:00Z",
                    "deckId": deck.id!.uuidString,
                    "schemaVersion": "2.0"
                ]
            ]
        ]
        
        // When - Import avec fusion
        let manager = DataImportExportManager()
        manager.setContext(context)
        let importData = try JSONSerialization.data(withJSONObject: importJSON)
        try await manager.importAllData(from: importData)
        
        // Then - Données du JSON ont écrasé les locales
        let updatedCards = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(updatedCards.count, 2)
        
        let updatedCard1 = updatedCards.first { $0.question == "Qui était Napoléon?" }
        XCTAssertEqual(updatedCard1?.interval, 7.0) // Écrasé par JSON
        XCTAssertEqual(updatedCard1?.correctCount, 5) // Écrasé par JSON
        XCTAssertEqual(updatedCard1?.reviewCount, 6) // Écrasé par JSON
        
        let updatedCard2 = updatedCards.first { $0.question == "Quand 1789?" }
        XCTAssertEqual(updatedCard2?.interval, 1.0) // Écrasé par JSON
        XCTAssertEqual(updatedCard2?.correctCount, 0) // Écrasé par JSON
        XCTAssertEqual(updatedCard2?.reviewCount, 3) // Écrasé par JSON
    }
    
    /// 🔥 SMOKE TEST 3: Gestion des champs manquants
    /// 
    /// Objectif: Vérifier que les fallbacks sont correctement appliqués
    /// 
    /// Étapes:
    /// 1. Préparer un JSON avec des champs SM-2 manquants
    /// 2. Importer
    /// 3. Vérifier que les valeurs par défaut sont appliquées
    func testSmoke_MissingFieldsHandling() throws {
        // Given - JSON avec champs manquants
        let deck = createTestDeck(name: "Test Deck")
        try context.save()
        
        let importJSON: [String: Any] = [
            "metadata": [
                "export_date": "2024-01-01T00:00:00Z",
                "app_version": "1.0",
                "format_version": "2.0"
            ],
            "flashcard_decks": [
                [
                    "id": deck.id!.uuidString,
                    "name": "Test Deck",
                    "createdAt": "2024-01-01T00:00:00Z"
                ]
            ],
            "flashcards": [
                [
                    "id": UUID().uuidString,
                    "question": "Question sans données SM-2",
                    "answer": "Réponse"
                    // Tous les champs SM-2 manquants
                ],
                [
                    "id": UUID().uuidString,
                    "question": "Question partielle",
                    "answer": "Réponse",
                    "intervalDays": 5.0
                    // Autres champs SM-2 manquants
                ]
            ]
        ]
        
        // When - Import
        let manager = DataImportExportManager()
        manager.setContext(context)
        let importData = try JSONSerialization.data(withJSONObject: importJSON)
        try await manager.importAllData(from: importData)
        
        // Then - Fallbacks appliqués
        let cards = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(cards.count, 2)
        
        let card1 = cards.first { $0.question == "Question sans données SM-2" }
        XCTAssertEqual(card1?.interval, 1.0) // Fallback
        XCTAssertEqual(card1?.easeFactor, SRSConfiguration.defaultEaseFactor) // Fallback
        XCTAssertEqual(card1?.correctCount, 0) // Fallback
        XCTAssertEqual(card1?.reviewCount, 0) // Fallback
        XCTAssertNil(card1?.nextReviewDate) // Fallback "nouvelle"
        
        let card2 = cards.first { $0.question == "Question partielle" }
        XCTAssertEqual(card2?.interval, 5.0) // Préservé
        XCTAssertEqual(card2?.easeFactor, SRSConfiguration.defaultEaseFactor) // Fallback
        XCTAssertEqual(card2?.correctCount, 0) // Fallback
        XCTAssertEqual(card2?.reviewCount, 0) // Fallback
    }
    
    /// 🔥 SMOKE TEST 4: Cohérence multi-devices
    /// 
    /// Objectif: Vérifier que l'export/import fonctionne entre différents appareils
    /// 
    /// Étapes:
    /// 1. Créer des données complexes (multiples decks, cartes avec différents statuts)
    /// 2. Exporter
    /// 3. Simuler un nouvel appareil (contexte vide)
    /// 4. Importer
    /// 5. Vérifier que tout est cohérent
    func testSmoke_MultiDeviceConsistency() throws {
        // Given - Données complexes
        let deck1 = createTestDeck(name: "Mathématiques")
        let deck2 = createTestDeck(name: "Histoire")
        
        // Cartes avec différents statuts
        let newCard = createTestCard(question: "Nouvelle carte", answer: "Réponse", deck: deck1)
        newCard.reviewCount = 0
        newCard.nextReviewDate = nil
        
        let dueCard = createTestCard(question: "Carte due", answer: "Réponse", deck: deck1)
        dueCard.interval = 1.0
        dueCard.correctCount = 2
        dueCard.reviewCount = 3
        dueCard.nextReviewDate = Date() // Due aujourd'hui
        
        let overdueCard = createTestCard(question: "Carte en retard", answer: "Réponse", deck: deck2)
        overdueCard.interval = 5.0
        overdueCard.correctCount = 1
        overdueCard.reviewCount = 2
        overdueCard.nextReviewDate = Calendar.current.date(byAdding: .day, value: -3, to: Date()) // 3 jours en retard
        
        let masteredCard = createTestCard(question: "Carte maîtrisée", answer: "Réponse", deck: deck2)
        masteredCard.interval = 10.0
        masteredCard.correctCount = 5
        masteredCard.reviewCount = 6
        masteredCard.nextReviewDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())
        
        try context.save()
        
        // When - Export puis import sur "nouvel appareil"
        let manager = DataImportExportManager()
        manager.setContext(context)
        
        let exportData = try await manager.exportAllData()
        
        // Simuler nouvel appareil
        try clearAllData()
        
        // Réimporter
        try await manager.importAllData(from: exportData)
        
        // Then - Cohérence parfaite
        let importedCards = try context.fetch(Flashcard.fetchRequest())
        XCTAssertEqual(importedCards.count, 4)
        
        // Vérifier les statuts
        let newCardImported = importedCards.first { $0.question == "Nouvelle carte" }
        let dueCardImported = importedCards.first { $0.question == "Carte due" }
        let overdueCardImported = importedCards.first { $0.question == "Carte en retard" }
        let masteredCardImported = importedCards.first { $0.question == "Carte maîtrisée" }
        
        XCTAssertNotNil(newCardImported)
        XCTAssertNotNil(dueCardImported)
        XCTAssertNotNil(overdueCardImported)
        XCTAssertNotNil(masteredCardImported)
        
        // Vérifier les statuts calculés
        let statusNew = SimpleSRSManager.shared.getCardStatusMessage(card: newCardImported!)
        let statusDue = SimpleSRSManager.shared.getCardStatusMessage(card: dueCardImported!)
        let statusOverdue = SimpleSRSManager.shared.getCardStatusMessage(card: overdueCardImported!)
        let statusMastered = SimpleSRSManager.shared.getCardStatusMessage(card: masteredCardImported!)
        
        XCTAssertEqual(statusNew.message, "Nouvelle")
        XCTAssertEqual(statusDue.message, "À réviser")
        XCTAssertTrue(statusOverdue.message.hasPrefix("En retard"))
        XCTAssertEqual(statusMastered.message, "Maîtrisée")
    }
    
    // MARK: - Méthodes utilitaires
    
    private func createTestDeck(name: String) -> FlashcardDeck {
        let deck = FlashcardDeck(context: context)
        deck.id = UUID()
        deck.name = name
        deck.createdAt = Date()
        return deck
    }
    
    private func createTestCard(question: String, answer: String, deck: FlashcardDeck) -> Flashcard {
        let card = Flashcard(context: context)
        card.id = UUID()
        card.question = question
        card.answer = answer
        card.deck = deck
        card.createdAt = Date()
        return card
    }
    
    private func clearAllData() throws {
        let entities = ["Flashcard", "FlashcardDeck", "Subject", "Period", "Evaluation", "UserConfiguration"]
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        }
        try context.save()
    }
}

// MARK: - Exemple JSON d'export réel
/*
 
 EXEMPLE JSON D'EXPORT RÉEL (1 deck, 2 cartes)
 
 {
   "metadata": {
     "export_date": "2024-01-15T14:30:00.000Z",
     "app_version": "1.0.0",
     "format_version": "2.0",
     "ios_version": "17.2"
   },
   "user_defaults": {
     "username": "Utilisateur",
     "GradingSystem": "French",
     "enableHaptics": true,
     "darkModeEnabled": false
   },
   "user_configuration": [
     {
       "id": "12345678-1234-1234-1234-123456789012",
       "username": "Utilisateur",
       "hasCompletedOnboarding": true,
       "selectedSystem": "French",
       "profileGradientStart": "#FF6B6B",
       "profileGradientEnd": "#4ECDC4",
       "createdDate": "2024-01-01T00:00:00.000Z",
       "lastModifiedDate": "2024-01-15T14:30:00.000Z"
     }
   ],
   "periods": [
     {
       "id": "87654321-4321-4321-4321-210987654321",
       "name": "Semestre 1",
       "startDate": "2024-09-01T00:00:00.000Z",
       "endDate": "2025-01-31T00:00:00.000Z",
       "createdAt": "2024-09-01T00:00:00.000Z"
     }
   ],
   "subjects": [
     {
       "id": "11111111-1111-1111-1111-111111111111",
       "name": "Mathématiques",
       "code": "MATH101",
       "creditHours": 6.0,
       "periodId": "87654321-4321-4321-4321-210987654321",
       "createdAt": "2024-09-01T00:00:00.000Z"
     }
   ],
   "evaluations": [
     {
       "id": "22222222-2222-2222-2222-222222222222",
       "title": "Contrôle 1",
       "grade": 85.0,
       "coefficient": 1.0,
       "date": "2024-10-15T00:00:00.000Z",
       "subjectId": "11111111-1111-1111-1111-111111111111"
     }
   ],
   "flashcard_decks": [
     {
       "id": "33333333-3333-3333-3333-333333333333",
       "name": "Mathématiques - Chapitre 1",
       "createdAt": "2024-09-15T00:00:00.000Z"
     }
   ],
   "flashcards": [
     {
       "id": "44444444-4444-4444-4444-444444444444",
       "question": "Qu'est-ce que 2 + 2 ?",
       "answer": "4",
       "intervalDays": 5.0,
       "easeFactor": 2.1,
       "correctCount": 3,
       "reviewCount": 4,
       "nextReviewDate": "2024-01-20T12:00:00.000Z",
       "lastReviewDate": "2024-01-15T10:30:00.000Z",
       "createdAt": "2024-09-15T00:00:00.000Z",
       "deckId": "33333333-3333-3333-3333-333333333333",
       "schemaVersion": "2.0"
     },
     {
       "id": "55555555-5555-5555-5555-555555555555",
       "question": "Qu'est-ce que 3 × 3 ?",
       "answer": "9",
       "intervalDays": 1.0,
       "easeFactor": 1.8,
       "correctCount": 0,
       "reviewCount": 2,
       "nextReviewDate": "2024-01-16T12:00:00.000Z",
       "lastReviewDate": "2024-01-15T11:00:00.000Z",
       "createdAt": "2024-09-15T00:00:00.000Z",
       "deckId": "33333333-3333-3333-3333-333333333333",
       "schemaVersion": "2.0"
     }
   ]
 }
 
 NOTES SUR LE FORMAT :
 
 ✅ CHAMPS SM-2 COMPLETS :
 - intervalDays : Intervalle en jours (Double)
 - easeFactor : Facteur de facilité (Double)
 - correctCount : Nombre de réponses correctes (Int32)
 - reviewCount : Nombre total de révisions (Int32)
 
 ✅ DATES ISO8601 UTC :
 - nextReviewDate : Prochaine date de révision
 - lastReviewDate : Dernière date de révision
 - createdAt : Date de création de la carte
 
 ✅ VERSIONNEMENT :
 - schemaVersion : "2.0" pour le nouveau format
 - format_version : Version globale de l'export
 
 ✅ FUSION PAR ID :
 - Les cartes existantes sont mises à jour par leur ID
 - Les nouvelles cartes sont créées
 - Fallback "nouvelle" pour les champs manquants
 
 */
