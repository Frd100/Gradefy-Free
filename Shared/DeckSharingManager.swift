import CoreData
import Foundation
import os.log
import SwiftUI

// MARK: - Deck Sharing Manager

@MainActor
class DeckSharingManager: ObservableObject {
    static let shared = DeckSharingManager()

    private let logger = Logger(subsystem: "com.gradefy.app", category: "DeckSharing")
    private let cacheManager = GradefyCacheManager.shared
    @AppStorage("showCreatorInShare") private var showCreatorInShare: Bool = true

    private init() {}

    // MARK: - Export Functions

    func exportDeck(deck: FlashcardDeck, context: NSManagedObjectContext) async throws -> Data {
        // ✅ Clé de cache simple
        let cacheKey = "shared_deck_\(deck.id?.uuidString ?? "")"

        // Vérifier cache avec la clé simple
        if let cachedNSData = cacheManager.getCachedObject(forKey: cacheKey) as? NSData {
            logger.info("📦 Export depuis cache pour deck: \(deck.name ?? "")")
            return cachedNSData as Data
        }

        // Générer le deck partageable
        let shareableDeck = try await createShareableDeck(from: deck, context: context)

        // Encoder en JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(shareableDeck)

        // Mettre en cache avec la clé simple
        cacheManager.cacheObject(data as NSData, forKey: cacheKey)

        logger.info("✅ Export terminé pour deck: \(deck.name ?? "") - \(shareableDeck.flashcards.count) cartes")
        return data
    }

    private func createShareableDeck(from deck: FlashcardDeck, context: NSManagedObjectContext) async throws -> ShareableDeck {
        return await context.perform { // ✅ RETIRÉ : "try await" → "await"
            // Récupérer les flashcards triées par date de création
            let flashcards = (deck.flashcards?.allObjects as? [Flashcard] ?? [])
                .sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }

            // Convertir en ShareableFlashcard
            let shareableFlashcards = flashcards.map { card in
                ShareableDeck.ShareableFlashcard(
                    question: card.question ?? "",
                    answer: card.answer ?? "",
                    createdAt: card.createdAt ?? Date()
                )
            }

            // Récupérer le nom du créateur
            let creatorName = self.getCreatorName(context: context)

            // Créer les métadonnées
            let metadata = ShareableDeck.DeckMetadata(
                id: deck.id?.uuidString ?? UUID().uuidString,
                name: deck.name ?? "",
                totalCards: shareableFlashcards.count,
                createdAt: deck.createdAt ?? Date(),
                creatorName: creatorName,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            )

            return ShareableDeck(
                metadata: metadata,
                flashcards: shareableFlashcards
            )
        }
    }

    private func getCreatorName(context _: NSManagedObjectContext) -> String? {
        print("🔍 [DEBUG] showCreatorInShare = \(showCreatorInShare)")
        guard showCreatorInShare else {
            print("🔍 [DEBUG] Nom du créateur masqué par préférence utilisateur")
            logger.info("👤 Nom du créateur masqué par préférence utilisateur")
            return nil
        }

        // ✅ Lire depuis UserDefaults au lieu de Core Data
        let creatorName = UserDefaults.standard.string(forKey: "username")
        logger.info("👤 Nom du créateur: \(creatorName ?? "non défini")")
        return creatorName?.isEmpty == true ? nil : creatorName
    }

    func createTemporaryFile(data: Data, fileName: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("\(fileName).gradefy") // ✅ Forcer .gradefy

        // Nettoyer le fichier existant si nécessaire
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.removeItem(at: tempURL)
        }

        // ✅ NOUVEAU : Encoder le JSON en Base64 pour masquer le contenu
        let encodedData = data.base64EncodedData()

        // Écrire les données encodées dans le fichier temporaire
        try encodedData.write(to: tempURL)
        logger.info("📁 Fichier .gradefy créé (Base64 encodé): \(tempURL.lastPathComponent)")

        return tempURL
    }

    // MARK: - Import Functions

    func importDeck(from data: Data, context: NSManagedObjectContext, limitToFreeQuota _: Bool = false) async throws -> FlashcardDeck {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let shareableDeck = try decoder.decode(ShareableDeck.self, from: data)

        return try await context.perform {
            // Créer le nouveau deck
            let newDeck = FlashcardDeck(context: context)
            newDeck.id = UUID()
            newDeck.name = shareableDeck.metadata.name
            newDeck.createdAt = Date()

            // ✅ MODIFIÉ : Plus de limite - Application entièrement gratuite
            // Toujours importer toutes les cartes
            let cardLimit = shareableDeck.flashcards.count
            let cardsToImport = Array(shareableDeck.flashcards.prefix(cardLimit))

            // Créer les flashcards
            for shareableCard in cardsToImport {
                let flashcard = Flashcard(context: context)
                flashcard.id = UUID()
                flashcard.question = shareableCard.question
                flashcard.answer = shareableCard.answer
                flashcard.createdAt = Date()
                flashcard.deck = newDeck

                // Initialiser les valeurs de révision
                flashcard.reviewCount = 0
                flashcard.correctCount = 0
                flashcard.interval = 1.0
                flashcard.lastReviewDate = nil
                flashcard.nextReviewDate = nil
            }

            // Sauvegarder
            try context.save()

            self.logger.info("✅ Deck importé: \(shareableDeck.metadata.name) - \(cardLimit) cartes")
            return newDeck
        }
    }

    // AJOUTER cette nouvelle fonction dans DeckSharingManager.swift
    func importDeckDirect(shareableDeck: ShareableDeck, context: NSManagedObjectContext, limitToFreeQuota _: Bool = false) async throws -> FlashcardDeck {
        return try await context.perform {
            print("📥 Import direct du deck : \(shareableDeck.metadata.name)")

            // Créer le nouveau deck
            let newDeck = FlashcardDeck(context: context)
            newDeck.id = UUID()
            newDeck.name = shareableDeck.metadata.name
            newDeck.createdAt = Date()

            // ✅ MODIFIÉ : Plus de limite - Application entièrement gratuite
            // Toujours importer toutes les cartes
            let cardLimit = shareableDeck.flashcards.count
            let cardsToImport = Array(shareableDeck.flashcards.prefix(cardLimit))

            print("📊 Import de \(cardLimit) cartes sur \(shareableDeck.flashcards.count) disponibles")

            // Créer les flashcards
            for shareableCard in cardsToImport {
                let flashcard = Flashcard(context: context)
                flashcard.id = UUID()
                flashcard.question = shareableCard.question
                flashcard.answer = shareableCard.answer
                flashcard.createdAt = Date()
                flashcard.deck = newDeck

                // Initialiser les valeurs de révision
                flashcard.reviewCount = 0
                flashcard.correctCount = 0
                flashcard.interval = 1.0
                flashcard.lastReviewDate = nil
                flashcard.nextReviewDate = nil
            }

            // Sauvegarder
            try context.save()

            self.logger.info("✅ Deck importé directement: \(shareableDeck.metadata.name) - \(cardLimit) cartes")
            return newDeck
        }
    }

    func invalidateDeckCache(for deck: FlashcardDeck) {
        guard let deckId = deck.id?.uuidString else { return }

        // Invalider tous les caches de ce deck (toutes les versions)
        let baseKey = "shared_deck_\(deckId)"
        cacheManager.invalidateObject(key: baseKey)

        logger.info("🗑️ Cache deck invalidé: \(deck.name ?? "")")
    }

    func parseSharedFile(url: URL) throws -> ShareableDeck {
        print("📖 Parsing fichier : \(url.lastPathComponent)")

        let rawData = try Data(contentsOf: url)
        print("📊 Données brutes lues : \(rawData.count) bytes")

        // ✅ NOUVEAU : Déterminer le format du fichier
        let data: Data
        let isBase64Encoded = url.pathExtension.lowercased() == "gradefy"

        if isBase64Encoded {
            // Décoder le Base64 pour les fichiers .gradefy
            guard let decodedData = Data(base64Encoded: rawData) else {
                throw NSError(domain: "DecodingError", code: 50, userInfo: [
                    NSLocalizedDescriptionKey: "Impossible de décoder le fichier .gradefy",
                ])
            }
            data = decodedData
            print("📊 Fichier .gradefy décodé : \(data.count) bytes JSON")
        } else {
            // Fichier .json direct (rétrocompatibilité)
            data = rawData
            print("📊 Fichier .json direct : \(data.count) bytes")
        }

        // Afficher un échantillon du JSON pour debug
        if let jsonString = String(data: data.prefix(500), encoding: .utf8) {
            print("📝 Aperçu JSON : \(jsonString)")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let shareableDeck = try decoder.decode(ShareableDeck.self, from: data)
            print("✅ Décodage réussi : \(shareableDeck.metadata.name)")
            return shareableDeck
        } catch {
            print("❌ Erreur décodage ISO8601 : \(error)")

            // Fallback : essayer avec une stratégie de date différente
            let fallbackDecoder = JSONDecoder()
            fallbackDecoder.dateDecodingStrategy = .secondsSince1970

            do {
                let shareableDeck = try fallbackDecoder.decode(ShareableDeck.self, from: data)
                print("✅ Décodage réussi avec fallback : \(shareableDeck.metadata.name)")
                return shareableDeck
            } catch {
                print("❌ Erreur décodage secondsSince1970 : \(error)")

                // Dernier essai avec deferredToDate
                let lastDecoder = JSONDecoder()
                lastDecoder.dateDecodingStrategy = .deferredToDate

                let shareableDeck = try lastDecoder.decode(ShareableDeck.self, from: data)
                print("✅ Décodage réussi avec deferredToDate : \(shareableDeck.metadata.name)")
                return shareableDeck
            }
        }
    }
}

extension DeckSharingManager {
    // ✅ CORRIGÉ : Méthode à appeler après modification d'un deck
    func notifyDeckModification(deck: FlashcardDeck) {
        // ✅ Ne pas essayer de modifier modifiedAt (n'existe pas)
        // Invalider le cache automatiquement
        invalidateDeckCache(for: deck)

        logger.info("🔄 Deck modifié et cache invalidé: \(deck.name ?? "")")
    }

    // ✅ CORRIGÉ : Méthode à appeler après ajout/suppression de flashcards
    func notifyFlashcardModification(deck: FlashcardDeck) {
        notifyDeckModification(deck: deck)

        // ✅ SOLUTION : Notification pour rafraîchir l'UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("FlashcardModified"),
                object: deck
            )
        }
    }
}
