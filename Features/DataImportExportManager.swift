//
// DataImportExportManager.swift
// PARALLAX
//

import Combine
import CoreData
import Foundation
import SwiftUI
import ZIPFoundation

@MainActor
class DataImportExportManager: ObservableObject {
    private var viewContext: NSManagedObjectContext?

    @Published var isExporting = false
    @Published var isImporting: Bool = false
    @Published var lastExportURL: URL?

    init() {}

    func setContext(_ context: NSManagedObjectContext) {
        viewContext = context
        print("✅ Contexte DataImportExportManager configuré")
    }

    // MARK: - Export Data (iOS 17 optimisé avec médias)

    func exportAllData() async throws -> Data {
        print("🔍 [EXPORT] Début de l'export avec médias - viewContext = \(String(describing: viewContext))")

        guard viewContext != nil else {
            print("❌ [EXPORT] ERROR: viewContext est nil lors de l'export")
            throw DataError.missingRequiredData
        }

        guard !isExporting else {
            print("❌ [EXPORT] Opération déjà en cours")
            throw DataError.operationInProgress
        }

        isExporting = true
        defer { isExporting = false }

        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    print("🔄 [EXPORT] Création du package d'export avec médias...")
                    let zipData = try await createExportPackage()

                    print("✅ [EXPORT] Package ZIP créé: \(zipData.count) bytes")
                    continuation.resume(returning: zipData)
                } catch {
                    print("❌ [EXPORT] Erreur lors de l'export: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func importAllData(from data: Data) async throws {
        guard viewContext != nil else {
            throw ImportExportError.contextNotConfigured
        }

        // ✅ OPTIMISATION 1 : Validation de taille avant import
        try validateImportSize(data)

        // Détecter si c'est un package ZIP ou un JSON simple
        if isZipData(data) {
            try await importFromZipPackage(data)
        } else {
            try await importFromJsonData(data)
        }
    }

    private func isZipData(_ data: Data) -> Bool {
        // Vérifier les signatures ZIP (PK)
        guard data.count >= 4 else { return false }
        let signature = data.prefix(4)
        return signature[0] == 0x50 && signature[1] == 0x4B // "PK"
    }

    // ✅ OPTIMISATION 1 : Validation de taille avant import
    private func validateImportSize(_ data: Data) throws {
        let fileSize = data.count
        let maxSize = 500 * 1024 * 1024 // 500MB

        if fileSize > maxSize {
            print("❌ [IMPORT] Fichier trop volumineux: \(fileSize) bytes (limite: \(maxSize) bytes)")
            throw ImportExportError.fileTooLarge(maxSize: maxSize, actualSize: fileSize)
        }

        // Vérifier l'espace disque disponible
        let availableSpace = try getAvailableDiskSpace()
        let requiredSpace = fileSize * 2 // Besoin de 2x l'espace pour extraction

        if availableSpace < requiredSpace {
            print("❌ [IMPORT] Espace disque insuffisant: \(availableSpace) bytes disponibles (besoin: \(requiredSpace) bytes)")
            throw ImportExportError.insufficientDiskSpace(required: Int64(requiredSpace), available: availableSpace)
        }

        print("✅ [IMPORT] Validation de taille réussie: \(fileSize) bytes")
    }

    private func getAvailableDiskSpace() throws -> Int64 {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let resourceValues = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return Int64(resourceValues.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    private func importFromZipPackage(_ data: Data) async throws {
        print("📦 [IMPORT] Détection d'un package ZIP avec médias")

        // 1. Créer un fichier temporaire pour le ZIP
        let tempDir = FileManager.default.temporaryDirectory
        let zipURL = tempDir.appendingPathComponent("import_\(Date().timeIntervalSince1970).zip")

        do {
            try data.write(to: zipURL)
            print("📁 [IMPORT] Fichier ZIP temporaire créé")

            // 2. Extraire le ZIP
            let extractDir = tempDir.appendingPathComponent("extract_\(Date().timeIntervalSince1970)")
            try FileManager.default.unzipItem(at: zipURL, to: extractDir)
            print("📁 [IMPORT] ZIP extrait vers: \(extractDir.path)")

            // 3. Charger les données JSON
            let jsonURL = extractDir.appendingPathComponent("data.json")
            print("🔍 [IMPORT] Recherche de data.json à: \(jsonURL.path)")
            print("🔍 [IMPORT] Fichier existe: \(FileManager.default.fileExists(atPath: jsonURL.path))")

            // Lister le contenu du dossier extrait pour debug
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: extractDir.path)
                print("📁 [IMPORT] Contenu du dossier extrait: \(contents)")
            } catch {
                print("❌ [IMPORT] Erreur lecture dossier: \(error)")
            }

            guard FileManager.default.fileExists(atPath: jsonURL.path) else {
                print("❌ [IMPORT] data.json introuvable dans le ZIP")
                throw ImportExportError.invalidFormat
            }

            let jsonData = try Data(contentsOf: jsonURL)
            let importData = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
            guard let importData = importData else {
                throw ImportExportError.invalidFormat
            }

            // 4. Importer les médias
            let mediaDir = extractDir.appendingPathComponent("media")
            if FileManager.default.fileExists(atPath: mediaDir.path) {
                try await importMediaFiles(from: mediaDir)
            }

            // 5. Importer les données Core Data
            try await importCoreData(from: importData)

            // 6. Nettoyer
            try FileManager.default.removeItem(at: zipURL)
            try FileManager.default.removeItem(at: extractDir)

            print("✅ [IMPORT] Package ZIP importé avec succès")

        } catch {
            // Nettoyer en cas d'erreur
            try? FileManager.default.removeItem(at: zipURL)
            try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("extract_\(Date().timeIntervalSince1970)"))
            throw error
        }
    }

    private func importFromJsonData(_ data: Data) async throws {
        print("📄 [IMPORT] Import de données JSON simples")

        let importData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let importData = importData else {
            throw ImportExportError.invalidFormat
        }

        try await importCoreData(from: importData)
        print("✅ [IMPORT] Données JSON importées avec succès")
    }

    private func importMediaFiles(from mediaDir: URL) async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let targetMediaDir = documentsPath.appendingPathComponent("GradefyMedia")

        // Créer le dossier de destination s'il n'existe pas
        if !FileManager.default.fileExists(atPath: targetMediaDir.path) {
            try FileManager.default.createDirectory(at: targetMediaDir, withIntermediateDirectories: true)
        }

        // ✅ OPTIMISATION 3 : Import par chunks pour éviter les pics mémoire
        try await importMediaFilesInChunks(from: mediaDir, to: targetMediaDir)

        print("📁 [IMPORT] Médias importés avec succès")
    }

    // ✅ OPTIMISATION 3 : Import par chunks (10 fichiers max par chunk)
    private func importMediaFilesInChunks(from mediaDir: URL, to targetMediaDir: URL) async throws {
        let chunkSize = 10
        var totalProcessed = 0

        print("🔍 [IMPORT] Dossier média source: \(mediaDir.path)")
        print("🔍 [IMPORT] Dossier média cible: \(targetMediaDir.path)")

        // Lister le contenu du dossier media
        if let mediaContents = try? FileManager.default.contentsOfDirectory(atPath: mediaDir.path) {
            print("📁 [IMPORT] Contenu dossier media: \(mediaContents)")
        } else {
            print("❌ [IMPORT] Impossible de lister le dossier media")
        }

        // Traiter les images par chunks
        let imagesDir = mediaDir.appendingPathComponent("images")
        print("🔍 [IMPORT] Vérification dossier images: \(imagesDir.path)")
        print("🔍 [IMPORT] Dossier images existe: \(FileManager.default.fileExists(atPath: imagesDir.path))")

        if FileManager.default.fileExists(atPath: imagesDir.path) {
            let imageFiles = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)
            print("📷 [IMPORT] \(imageFiles.count) images trouvées")
            totalProcessed += try await processMediaChunk(files: imageFiles, targetDir: targetMediaDir, chunkSize: chunkSize, fileType: "Image")
        } else {
            print("⚠️ [IMPORT] Dossier images introuvable")
        }

        // Traiter les audios par chunks
        let audioDir = mediaDir.appendingPathComponent("audio")
        print("🔍 [IMPORT] Vérification dossier audio: \(audioDir.path)")
        print("🔍 [IMPORT] Dossier audio existe: \(FileManager.default.fileExists(atPath: audioDir.path))")

        if FileManager.default.fileExists(atPath: audioDir.path) {
            let audioFiles = try FileManager.default.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil)
            print("🎵 [IMPORT] \(audioFiles.count) audios trouvés")
            totalProcessed += try await processMediaChunk(files: audioFiles, targetDir: targetMediaDir, chunkSize: chunkSize, fileType: "Audio")
        } else {
            print("⚠️ [IMPORT] Dossier audio introuvable")
        }

        print("📁 [IMPORT] \(totalProcessed) fichiers médias traités par chunks")
    }

    private func processMediaChunk(files: [URL], targetDir: URL, chunkSize: Int, fileType: String) async throws -> Int {
        var processedCount = 0

        for startIndex in stride(from: 0, to: files.count, by: chunkSize) {
            let chunk = Array(files[startIndex ..< min(startIndex + chunkSize, files.count)])

            // Traiter le chunk
            for file in chunk {
                // ✅ CORRECTION CRITIQUE : Garder le nom original pour correspondre à Core Data
                let targetFile = targetDir.appendingPathComponent(file.lastPathComponent)

                // ✅ Si le fichier existe déjà, le supprimer avant de copier
                if FileManager.default.fileExists(atPath: targetFile.path) {
                    try FileManager.default.removeItem(at: targetFile)
                    print("🗑️ [IMPORT] Ancien fichier supprimé: \(file.lastPathComponent)")
                }

                try FileManager.default.copyItem(at: file, to: targetFile)
                print("📷 [IMPORT] \(fileType) copié: \(targetFile.lastPathComponent)")
                processedCount += 1
            }

            // ✅ Libérer la mémoire entre les chunks
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            print("📁 [IMPORT] Chunk \(startIndex / chunkSize + 1) traité (\(chunk.count) fichiers)")
        }

        return processedCount
    }

    // ✅ OPTIMISATION 4 : Système de noms uniques pour éviter conflits
    private func generateUniqueFileName(for originalURL: URL, in targetDir: URL) -> URL {
        let originalName = originalURL.lastPathComponent
        let nameWithoutExt = originalURL.deletingPathExtension().lastPathComponent
        let fileExtension = originalURL.pathExtension

        var finalURL = targetDir.appendingPathComponent(originalName)
        var counter = 1

        // Tant que le fichier existe, ajouter un suffixe numérique
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let newName = "\(nameWithoutExt)_\(counter).\(fileExtension)"
            finalURL = targetDir.appendingPathComponent(newName)
            counter += 1
        }

        return finalURL
    }

    private func importCoreData(from data: [String: Any]) async throws {
        guard !isImporting else {
            throw ImportExportError.operationInProgress
        }

        isImporting = true
        defer { isImporting = false }

        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    // Valider et importer
                    try validateImportData(data)
                    try await performImport(data)

                    continuation.resume()

                } catch let error as ImportExportError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: ImportExportError.transactionFailed(underlyingError: error))
                }
            }
        }
    }

    func importData(from url: URL) async throws {
        guard viewContext != nil else {
            throw ImportExportError.contextNotConfigured
        }

        guard !isImporting else {
            throw ImportExportError.operationInProgress
        }

        isImporting = true
        defer { isImporting = false }

        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    // Vérifier l'accès sécurisé
                    guard url.startAccessingSecurityScopedResource() else {
                        throw ImportExportError.securityScopedResourceFailed
                    }

                    defer { url.stopAccessingSecurityScopedResource() }

                    // Lire le fichier
                    let jsonData: Data
                    do {
                        jsonData = try Data(contentsOf: url)
                    } catch {
                        throw ImportExportError.importFileNotFound
                    }

                    // Parser JSON
                    guard let importData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                        throw ImportExportError.invalidFormat
                    }

                    // Valider et importer
                    try validateImportData(importData)
                    try await performImport(importData)

                    continuation.resume()

                } catch let error as ImportExportError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: ImportExportError.transactionFailed(underlyingError: error))
                }
            }
        }
    }

    // MARK: - Méthode d'accès avec bookmark (iOS 17)

    func accessFileWithBookmark(bookmarkKey: String) -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            print("❌ Aucun bookmark trouvé pour: \(bookmarkKey)")
            return nil
        }

        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)

            guard !isStale else {
                print("⚠️ Bookmark expiré pour: \(bookmarkKey)")
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
                return nil
            }

            return url
        } catch {
            print("❌ Erreur résolution bookmark: \(error)")
            return nil
        }
    }

    // MARK: - Create Export Data

    private func createExportData() async throws -> [String: Any] {
        guard let viewContext = viewContext else {
            throw DataError.missingRequiredData
        }

        return try await viewContext.perform {
            let exportDate = ISO8601DateFormatter().string(from: Date())
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

            // UserDefaults data
            let userDefaults = self.exportUserDefaults()

            // UserConfiguration
            let configRequest: NSFetchRequest<UserConfiguration> = UserConfiguration.fetchRequest()
            let configurations = try viewContext.fetch(configRequest)
            let configData = configurations.map { self.serializeUserConfiguration($0) }

            // Periods
            let periodsRequest: NSFetchRequest<Period> = Period.fetchRequest()
            let periods = try viewContext.fetch(periodsRequest)
            let periodsData = periods.map { self.serializePeriod($0) }

            // Subjects
            let subjectsRequest: NSFetchRequest<Subject> = Subject.fetchRequest()
            let subjects = try viewContext.fetch(subjectsRequest)
            let subjectsData = subjects.map { self.serializeSubject($0) }

            // Evaluations
            let evaluationsRequest: NSFetchRequest<Evaluation> = Evaluation.fetchRequest()
            let evaluations = try viewContext.fetch(evaluationsRequest)
            let evaluationsData = evaluations.map { self.serializeEvaluation($0) }

            // Flashcard Decks
            let decksRequest: NSFetchRequest<FlashcardDeck> = FlashcardDeck.fetchRequest()
            let decks = try viewContext.fetch(decksRequest)
            let decksData = decks.map { self.serializeFlashcardDeck($0) }

            // Flashcards
            let flashcardsRequest: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
            let flashcards = try viewContext.fetch(flashcardsRequest)
            let flashcardsData = flashcards.map { self.serializeFlashcard($0) }

            return [
                "metadata": [
                    "export_date": exportDate,
                    "app_version": appVersion,
                    "format_version": "1.0",
                    "ios_version": UIDevice.current.systemVersion,
                ],
                "user_defaults": userDefaults,
                "user_configuration": configData,
                "periods": periodsData,
                "subjects": subjectsData,
                "evaluations": evaluationsData,
                "flashcard_decks": decksData,
                "flashcards": flashcardsData,
            ]
        }
    }

    // MARK: - Export Package avec médias

    private func createExportPackage() async throws -> Data {
        guard let viewContext = viewContext else {
            throw DataError.missingRequiredData
        }

        return try await viewContext.perform {
            // 1. Créer le dossier temporaire d'export
            let tempDir = FileManager.default.temporaryDirectory
            let exportDir = tempDir.appendingPathComponent("Gradefy_Export_\(Date().timeIntervalSince1970)")

            do {
                try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
                print("📁 [EXPORT] Dossier d'export créé: \(exportDir.path)")

                // 2. Créer les sous-dossiers pour les médias
                let mediaDir = exportDir.appendingPathComponent("media")
                let imagesDir = mediaDir.appendingPathComponent("images")
                let audioDir = mediaDir.appendingPathComponent("audio")

                try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
                print("📁 [EXPORT] Dossiers médias créés")

                // 3. Créer les données JSON
                let exportData = try self.createExportDataSync()
                let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)

                // 4. Sauvegarder data.json
                let jsonURL = exportDir.appendingPathComponent("data.json")
                try jsonData.write(to: jsonURL)
                print("📄 [EXPORT] data.json sauvegardé: \(jsonData.count) bytes")

                // 5. Copier tous les fichiers médias
                try self.copyAllMediaFiles(to: mediaDir, context: viewContext)

                // 6. Créer le ZIP
                let zipURL = try self.createZipArchive(from: exportDir)
                let zipData = try Data(contentsOf: zipURL)

                // 7. Nettoyer le dossier temporaire
                try FileManager.default.removeItem(at: exportDir)
                try FileManager.default.removeItem(at: zipURL)

                print("✅ [EXPORT] Package ZIP créé avec succès: \(zipData.count) bytes")
                return zipData

            } catch {
                // Nettoyer en cas d'erreur
                try? FileManager.default.removeItem(at: exportDir)
                throw error
            }
        }
    }

    private func createExportDataSync() throws -> [String: Any] {
        guard let viewContext = viewContext else {
            throw DataError.missingRequiredData
        }

        let exportDate = ISO8601DateFormatter().string(from: Date())
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        // UserDefaults data
        let userDefaults = exportUserDefaults()

        // UserConfiguration
        let configRequest: NSFetchRequest<UserConfiguration> = UserConfiguration.fetchRequest()
        let configurations = try viewContext.fetch(configRequest)
        let configData = configurations.map { self.serializeUserConfiguration($0) }

        // Periods
        let periodsRequest: NSFetchRequest<Period> = Period.fetchRequest()
        let periods = try viewContext.fetch(periodsRequest)
        let periodsData = periods.map { self.serializePeriod($0) }

        // Subjects
        let subjectsRequest: NSFetchRequest<Subject> = Subject.fetchRequest()
        let subjects = try viewContext.fetch(subjectsRequest)
        let subjectsData = subjects.map { self.serializeSubject($0) }

        // Evaluations
        let evaluationsRequest: NSFetchRequest<Evaluation> = Evaluation.fetchRequest()
        let evaluations = try viewContext.fetch(evaluationsRequest)
        let evaluationsData = evaluations.map { self.serializeEvaluation($0) }

        // Flashcard Decks
        let decksRequest: NSFetchRequest<FlashcardDeck> = FlashcardDeck.fetchRequest()
        let decks = try viewContext.fetch(decksRequest)
        let decksData = decks.map { self.serializeFlashcardDeck($0) }

        // Flashcards
        let flashcardsRequest: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
        let flashcards = try viewContext.fetch(flashcardsRequest)
        let flashcardsData = flashcards.map { self.serializeFlashcard($0) }

        return [
            "metadata": [
                "export_date": exportDate,
                "app_version": appVersion,
                "format_version": "3.0",
                "ios_version": UIDevice.current.systemVersion,
            ],
            "user_defaults": userDefaults,
            "user_configuration": configData,
            "periods": periodsData,
            "subjects": subjectsData,
            "evaluations": evaluationsData,
            "flashcard_decks": decksData,
            "flashcards": flashcardsData,
        ]
    }

    private func copyAllMediaFiles(to mediaDir: URL, context: NSManagedObjectContext) throws {
        let flashcardsRequest: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
        let flashcards = try context.fetch(flashcardsRequest)

        _ = MediaStorageManager.shared
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sourceMediaDir = documentsPath.appendingPathComponent("GradefyMedia")

        var copiedFiles: Set<String> = []

        for flashcard in flashcards {
            // Copier les images de question
            if let imageFileName = flashcard.questionImageFileName, !imageFileName.isEmpty {
                if !copiedFiles.contains(imageFileName) {
                    try copyMediaFile(
                        from: sourceMediaDir.appendingPathComponent(imageFileName),
                        to: mediaDir.appendingPathComponent("images").appendingPathComponent(imageFileName)
                    )
                    copiedFiles.insert(imageFileName)
                }
            }

            // Copier les images de réponse
            if let imageFileName = flashcard.answerImageFileName, !imageFileName.isEmpty {
                if !copiedFiles.contains(imageFileName) {
                    try copyMediaFile(
                        from: sourceMediaDir.appendingPathComponent(imageFileName),
                        to: mediaDir.appendingPathComponent("images").appendingPathComponent(imageFileName)
                    )
                    copiedFiles.insert(imageFileName)
                }
            }

            // Copier les fichiers audio de question
            if let audioFileName = flashcard.questionAudioFileName, !audioFileName.isEmpty {
                if !copiedFiles.contains(audioFileName) {
                    try copyMediaFile(
                        from: sourceMediaDir.appendingPathComponent(audioFileName),
                        to: mediaDir.appendingPathComponent("audio").appendingPathComponent(audioFileName)
                    )
                    copiedFiles.insert(audioFileName)
                }
            }

            // Copier les fichiers audio de réponse
            if let audioFileName = flashcard.answerAudioFileName, !audioFileName.isEmpty {
                if !copiedFiles.contains(audioFileName) {
                    try copyMediaFile(
                        from: sourceMediaDir.appendingPathComponent(audioFileName),
                        to: mediaDir.appendingPathComponent("audio").appendingPathComponent(audioFileName)
                    )
                    copiedFiles.insert(audioFileName)
                }
            }
        }

        print("📁 [EXPORT] \(copiedFiles.count) fichiers médias copiés")
    }

    private func copyMediaFile(from sourceURL: URL, to destinationURL: URL) throws {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            print("⚠️ [EXPORT] Fichier source introuvable: \(sourceURL.path)")
            return
        }

        // ✅ OPTIMISATION 2 : Compression des médias pour export
        try compressMediaForExport(from: sourceURL, to: destinationURL)
        print("📄 [EXPORT] Fichier compressé: \(sourceURL.lastPathComponent)")
    }

    // ✅ OPTIMISATION 2 : Compression intelligente des médias
    private func compressMediaForExport(from sourceURL: URL, to destinationURL: URL) throws {
        let fileExtension = sourceURL.pathExtension.lowercased()

        switch fileExtension {
        case "jpg", "jpeg", "png":
            // Compresser les images pour l'export (qualité 0.5)
            try compressImageForExport(sourceURL: sourceURL, destinationURL: destinationURL)

        case "m4a", "aac", "mp3":
            // Compresser les audios pour l'export (bitrate réduit)
            try compressAudioForExport(sourceURL: sourceURL, destinationURL: destinationURL)

        default:
            // Copier tel quel pour les autres formats
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }
    }

    private func compressImageForExport(sourceURL: URL, destinationURL: URL) throws {
        guard let image = UIImage(contentsOfFile: sourceURL.path) else {
            // Si pas d'image, copier tel quel
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return
        }

        // Compression agressive pour l'export (qualité 0.5)
        let compressedData = image.jpegData(compressionQuality: 0.5)
        try compressedData?.write(to: destinationURL)
        print("🖼️ [EXPORT] Image compressée: \(sourceURL.lastPathComponent)")
    }

    private func compressAudioForExport(sourceURL: URL, destinationURL: URL) throws {
        // Pour l'instant, copier tel quel (compression audio complexe)
        // TODO: Implémenter compression audio avec AVAssetExportSession
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        print("🎵 [EXPORT] Audio copié: \(sourceURL.lastPathComponent)")
    }

    private func createZipArchive(from directory: URL) throws -> URL {
        let zipURL = directory.appendingPathExtension("zip")

        // Créer le ZIP avec le contenu du dossier, pas le dossier lui-même
        let archive: Archive
        do {
            archive = try Archive(url: zipURL, accessMode: .create)
        } catch {
            throw ImportExportError.exportFailed("Impossible de créer l'archive ZIP: \(error.localizedDescription)")
        }

        // Ajouter data.json
        let jsonURL = directory.appendingPathComponent("data.json")
        if FileManager.default.fileExists(atPath: jsonURL.path) {
            try archive.addEntry(with: "data.json", fileURL: jsonURL)
            print("📄 [EXPORT] data.json ajouté au ZIP")
        }

        // Ajouter le dossier media avec tous ses sous-dossiers
        let mediaDir = directory.appendingPathComponent("media")
        if FileManager.default.fileExists(atPath: mediaDir.path) {
            try addDirectoryToArchive(archive: archive, directoryURL: mediaDir, basePath: "media")
            print("📁 [EXPORT] Dossier media ajouté au ZIP")
        }

        print("📦 [EXPORT] Archive ZIP créée: \(zipURL.path)")
        return zipURL
    }

    // ✅ CORRECTION CRITIQUE : Fonction récursive pour ajouter un dossier complet au ZIP
    private func addDirectoryToArchive(archive: Archive, directoryURL: URL, basePath: String) throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey])

        for itemURL in contents {
            let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = resourceValues.isDirectory ?? false
            let relativePath = basePath + "/" + itemURL.lastPathComponent

            if isDirectory {
                // C'est un sous-dossier, le parcourir récursivement
                print("📁 [EXPORT] Ajout dossier: \(relativePath)")
                try addDirectoryToArchive(archive: archive, directoryURL: itemURL, basePath: relativePath)
            } else {
                // C'est un fichier, l'ajouter au ZIP
                try archive.addEntry(with: relativePath, fileURL: itemURL)
                print("📄 [EXPORT] Fichier ajouté au ZIP: \(relativePath)")
            }
        }
    }

    private func validateActivePeriodConsistency() {
        guard let viewContext = viewContext else { return }

        if let activePeriodID = UserDefaults.standard.string(forKey: "activePeriodID"),
           let periodUUID = UUID(uuidString: activePeriodID)
        {
            let request: NSFetchRequest<Period> = Period.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", periodUUID as CVarArg)

            do {
                let periods = try viewContext.fetch(request)
                if periods.isEmpty {
                    print("⚠️ Période active inexistante, mise à jour nécessaire")
                    try? updateActivePeriodAfterImport()
                }
            } catch {
                print("❌ Erreur validation période active : \(error)")
            }
        }
    }

    // MARK: - Serialization Methods

    private func exportUserDefaults() -> [String: Any] {
        var result: [String: Any] = [:]

        let keysToExport = [
            "username",
            "profileSubtitle",
            "profileGradientStartHex",
            "profileGradientEndHex",
            "enableHaptics",
            "darkModeEnabled",
            "GradingSystem",
            "activePeriodID",
        ]

        for key in keysToExport {
            if let value = UserDefaults.standard.object(forKey: key) {
                result[key] = value
            }
        }

        return result
    }

    private func serializeUserConfiguration(_ config: UserConfiguration) -> [String: Any] {
        return [
            "id": config.id?.uuidString ?? UUID().uuidString,
            "username": config.username ?? "",
            "hasCompletedOnboarding": config.hasCompletedOnboarding,
            "activePeriodID": config.activePeriodID ?? "",
            "selectedSystem": config.selectedSystem ?? "",
            "profileGradientStart": config.profileGradientStart ?? "",
            "profileGradientEnd": config.profileGradientEnd ?? "",
            "createdDate": ISO8601DateFormatter().string(from: config.createdDate ?? Date()),
            "lastModifiedDate": ISO8601DateFormatter().string(from: config.lastModifiedDate ?? Date()),
        ]
    }

    private func serializePeriod(_ period: Period) -> [String: Any] {
        return [
            "id": period.id?.uuidString ?? UUID().uuidString,
            "name": period.name ?? "",
            "startDate": ISO8601DateFormatter().string(from: period.startDate ?? Date()),
            "endDate": period.endDate != nil ? ISO8601DateFormatter().string(from: period.endDate!) : NSNull(),
            "createdAt": ISO8601DateFormatter().string(from: period.createdAt ?? Date()),
        ]
    }

    private func serializeSubject(_ subject: Subject) -> [String: Any] {
        return [
            "id": subject.id?.uuidString ?? UUID().uuidString,
            "name": subject.name ?? "",
            "code": subject.code ?? "",
            "coefficient": subject.coefficient,
            "grade": subject.grade,
            "periodId": subject.period?.id?.uuidString ?? "",
            "createdAt": ISO8601DateFormatter().string(from: subject.createdAt ?? Date()),
            "lastModified": ISO8601DateFormatter().string(from: subject.lastModified ?? Date()),
        ]
    }

    private func serializeEvaluation(_ evaluation: Evaluation) -> [String: Any] {
        return [
            "id": evaluation.id?.uuidString ?? UUID().uuidString,
            "title": evaluation.title ?? "",
            "grade": evaluation.grade,
            "coefficient": evaluation.coefficient,
            "date": ISO8601DateFormatter().string(from: evaluation.date ?? Date()),
            "subjectId": evaluation.subject?.id?.uuidString ?? "",
        ]
    }

    private func serializeFlashcardDeck(_ deck: FlashcardDeck) -> [String: Any] {
        return [
            "id": deck.id?.uuidString ?? UUID().uuidString,
            "name": deck.name ?? "",
            "createdAt": ISO8601DateFormatter().string(from: deck.createdAt ?? Date()),
        ]
    }

    private func serializeFlashcard(_ flashcard: Flashcard) -> [String: Any] {
        // ✅ NOUVEAU SCHÉMA VERSIONNÉ : Tous les champs SM-2 + médias inclus
        return [
            "id": flashcard.id?.uuidString ?? UUID().uuidString,
            "question": flashcard.question ?? "",
            "answer": flashcard.answer ?? "",

            // ✅ CHAMPS SM-2 COMPLETS
            "intervalDays": flashcard.interval,
            "easeFactor": flashcard.easeFactor,
            "correctCount": flashcard.correctCount,
            "reviewCount": flashcard.reviewCount,

            // ✅ DATES ISO8601 UTC
            "nextReviewDate": flashcard.nextReviewDate?.ISO8601String() ?? "",
            "lastReviewDate": flashcard.lastReviewDate?.ISO8601String() ?? "",
            "createdAt": flashcard.createdAt?.ISO8601String() ?? "",

            // ✅ MÉDIAS QUESTION
            "questionType": flashcard.questionType ?? "text",
            "questionImageFileName": flashcard.questionImageFileName ?? "",
            // ✅ OPTIMISATION APPLE : Plus de Base64, toutes les images en fichiers
            "questionImageData": flashcard.questionImageData?.base64EncodedString() ?? "", // Legacy uniquement
            "questionAudioFileName": flashcard.questionAudioFileName ?? "",
            "questionAudioDuration": flashcard.questionAudioDuration,

            // ✅ MÉDIAS RÉPONSE
            "answerType": flashcard.answerType ?? "text",
            "answerImageFileName": flashcard.answerImageFileName ?? "",
            // ✅ OPTIMISATION APPLE : Plus de Base64, toutes les images en fichiers
            "answerImageData": flashcard.answerImageData?.base64EncodedString() ?? "", // Legacy uniquement
            "answerAudioFileName": flashcard.answerAudioFileName ?? "",
            "answerAudioDuration": flashcard.answerAudioDuration,

            // ✅ RELATION
            "deckId": flashcard.deck?.id?.uuidString ?? "",

            // ✅ VERSION DU SCHÉMA
            "schemaVersion": "3.0",
        ]
    }

    // MARK: - Import Methods

    private func validateImportData(_ data: [String: Any]) throws {
        // Validation de la structure de base
        guard let metadata = data["metadata"] as? [String: Any],
              let _ = metadata["export_date"] as? String,
              let _ = metadata["app_version"] as? String
        else {
            throw ImportExportError.invalidFormat
        }

        guard let periodsData = data["periods"] as? [[String: Any]],
              let subjectsData = data["subjects"] as? [[String: Any]],
              let evaluationsData = data["evaluations"] as? [[String: Any]]
        else {
            throw ImportExportError.missingRequiredData
        }

        // ✅ NOUVEAU : Validation des UUID
        try validateUUIDs(periodsData, entityName: "periods")
        try validateUUIDs(subjectsData, entityName: "subjects")
        try validateUUIDs(evaluationsData, entityName: "evaluations")

        if let decksData = data["flashcard_decks"] as? [[String: Any]] {
            try validateUUIDs(decksData, entityName: "flashcard_decks")
        }

        if let flashcardsData = data["flashcards"] as? [[String: Any]] {
            try validateUUIDs(flashcardsData, entityName: "flashcards")
        }

        // ✅ NOUVEAU : Validation de l'intégrité référentielle
        try validateRelationalIntegrity(periodsData: periodsData,
                                        subjectsData: subjectsData,
                                        evaluationsData: evaluationsData,
                                        decksData: data["flashcard_decks"] as? [[String: Any]] ?? [],
                                        flashcardsData: data["flashcards"] as? [[String: Any]] ?? [])
    }

    // ✅ NOUVEAU : Fonction de validation des UUID
    private func validateUUIDs(_ items: [[String: Any]], entityName: String) throws {
        var seenUUIDs: Set<String> = []

        for (index, item) in items.enumerated() {
            guard let idString = item["id"] as? String,
                  !idString.isEmpty
            else {
                throw ImportExportError.invalidUUID(entityName: entityName, reason: "UUID manquant à l'index \(index)")
            }

            guard let uuid = UUID(uuidString: idString) else {
                throw ImportExportError.invalidUUID(entityName: entityName, reason: "UUID invalide à l'index \(index): \(idString)")
            }

            // Vérifier les doublons
            if seenUUIDs.contains(idString) {
                throw ImportExportError.duplicateUUID(entityName: entityName, uuid: idString)
            }

            seenUUIDs.insert(idString)
            print("✅ [IMPORT] UUID validé: \(uuid.uuidString.prefix(8))... pour \(entityName)")
        }
    }

    // ✅ NOUVELLE MÉTHODE : Validation de l'intégrité référentielle
    private func validateRelationalIntegrity(periodsData: [[String: Any]],
                                             subjectsData: [[String: Any]],
                                             evaluationsData: [[String: Any]],
                                             decksData: [[String: Any]],
                                             flashcardsData: [[String: Any]]) throws
    {
        // Collecter tous les IDs des périodes
        let periodIds = Set(periodsData.compactMap { $0["id"] as? String })

        // Vérifier que tous les subjects ont une période valide
        for subject in subjectsData {
            if let periodId = subject["periodId"] as? String,
               !periodId.isEmpty,
               !periodIds.contains(periodId)
            {
                throw ImportExportError.orphanedReference(
                    entityName: "subject",
                    entityId: subject["id"] as? String ?? "unknown",
                    referencedEntity: "period",
                    referencedId: periodId
                )
            }
        }

        // Collecter tous les IDs des subjects
        let subjectIds = Set(subjectsData.compactMap { $0["id"] as? String })

        // Vérifier que toutes les évaluations ont un subject valide
        for evaluation in evaluationsData {
            if let subjectId = evaluation["subjectId"] as? String,
               !subjectId.isEmpty,
               !subjectIds.contains(subjectId)
            {
                throw ImportExportError.orphanedReference(
                    entityName: "evaluation",
                    entityId: evaluation["id"] as? String ?? "unknown",
                    referencedEntity: "subject",
                    referencedId: subjectId
                )
            }
        }

        // Collecter tous les IDs des decks
        let deckIds = Set(decksData.compactMap { $0["id"] as? String })

        // Vérifier que toutes les flashcards ont un deck valide
        for flashcard in flashcardsData {
            if let deckId = flashcard["deckId"] as? String,
               !deckId.isEmpty,
               !deckIds.contains(deckId)
            {
                // ✅ STRATÉGIE : Créer le deck automatiquement au lieu d'erreur
                print("⚠️ [IMPORT] Deck manquant pour flashcard '\(flashcard["question"] ?? "")', sera créé automatiquement")
            }
        }

        print("✅ [IMPORT] Intégrité référentielle validée")
    }

    private func performImport(_ data: [String: Any]) async throws {
        guard let viewContext = viewContext else {
            throw ImportExportError.missingRequiredData
        }

        // ✅ NOUVEAU : Transaction atomique complète
        try await viewContext.perform {
            // Créer un savepoint pour rollback en cas d'erreur
            let hasUndoManager = viewContext.undoManager != nil
            if !hasUndoManager {
                viewContext.undoManager = UndoManager()
            }

            viewContext.undoManager?.beginUndoGrouping()

            do {
                // 1. Importer UserDefaults (pas dans la transaction Core Data)
                if let userDefaults = data["user_defaults"] as? [String: Any] {
                    // Stocker temporairement - sera appliqué après succès
                    self.pendingUserDefaults = userDefaults
                }

                // 2. Sauvegarder l'état actuel si nécessaire
                if viewContext.hasChanges {
                    try viewContext.save()
                }

                // 3. Suppression des données existantes
                print("🗑️ Début suppression des données existantes...")
                try self.clearExistingDataAtomic()

                // 4. Import dans l'ordre des dépendances
                print("📥 Début import des nouvelles données...")
                try self.importUserConfiguration(data["user_configuration"] as? [[String: Any]] ?? [])
                try self.importPeriods(data["periods"] as? [[String: Any]] ?? [])
                try self.importSubjects(data["subjects"] as? [[String: Any]] ?? [])
                try self.importEvaluations(data["evaluations"] as? [[String: Any]] ?? [])
                try self.importFlashcardDecks(data["flashcard_decks"] as? [[String: Any]] ?? [])
                try self.importFlashcards(data["flashcards"] as? [[String: Any]] ?? [])

                // 5. Mise à jour de la période active
                try self.updateActivePeriodAfterImport()

                // 6. Validation finale
                try self.validateImportResult()

                // 7. Sauvegarder tout
                try viewContext.save()

                // 8. Confirmer la transaction
                viewContext.undoManager?.endUndoGrouping()

                // 9. Appliquer les UserDefaults maintenant que tout est OK
                if let userDefaults = self.pendingUserDefaults {
                    DispatchQueue.main.async {
                        self.importUserDefaults(userDefaults)
                        self.pendingUserDefaults = nil
                    }
                }

                print("✅ Import atomique terminé avec succès")

            } catch {
                // ✅ ROLLBACK complet en cas d'erreur
                print("❌ Erreur durant l'import - Rollback en cours...")

                viewContext.undoManager?.endUndoGrouping()
                viewContext.undoManager?.undo()

                try viewContext.save()

                // Nettoyer les données temporaires
                self.pendingUserDefaults = nil

                print("🔄 Rollback terminé")
                throw error
            }
        }
    }

    // ✅ NOUVEAU : Variable pour UserDefaults temporaires
    private var pendingUserDefaults: [String: Any]?

    // ✅ NOUVEAU : Suppression atomique
    private func clearExistingDataAtomic() throws {
        guard let viewContext = viewContext else { return }

        let entities = ["Flashcard", "FlashcardDeck", "Evaluation", "Subject", "Period", "UserConfiguration"]
        var errors: [Error] = []

        for entityName in entities {
            do {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
                let objects = try viewContext.fetch(fetchRequest)

                for object in objects {
                    viewContext.delete(object)
                }

                print("✅ Entité \(entityName) marquée pour suppression")
            } catch {
                errors.append(error)
                print("❌ Erreur suppression \(entityName): \(error)")
            }
        }

        if !errors.isEmpty {
            throw ImportExportError.batchOperationFailed(errors: errors)
        }
    }

    // ✅ NOUVEAU : Validation post-import
    private func validateImportResult() throws {
        guard let viewContext = viewContext else { return }

        // Vérifier qu'au moins une période existe
        let periodsRequest: NSFetchRequest<Period> = Period.fetchRequest()
        let periodCount = try viewContext.count(for: periodsRequest)

        if periodCount == 0 {
            throw ImportExportError.validationFailed(reason: "Aucune période trouvée après import")
        }

        // Vérifier la cohérence des relations
        let subjectsRequest: NSFetchRequest<Subject> = Subject.fetchRequest()
        let subjects = try viewContext.fetch(subjectsRequest)

        for subject in subjects {
            if subject.period == nil {
                throw ImportExportError.validationFailed(reason: "Subject sans période: \(subject.name ?? "")")
            }
        }

        print("✅ Validation post-import réussie")
    }

    private func updateActivePeriodAfterImport() throws {
        guard let viewContext = viewContext else { return }

        // Récupérer la première période disponible
        let periodsRequest: NSFetchRequest<Period> = Period.fetchRequest()
        periodsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Period.startDate, ascending: false)]
        periodsRequest.fetchLimit = 1

        if let firstPeriod = try viewContext.fetch(periodsRequest).first {
            let periodIdString = firstPeriod.id?.uuidString ?? ""
            let periodName = firstPeriod.name ?? ""

            // Mettre à jour UserDefaults
            UserDefaults.standard.set(periodIdString, forKey: "activePeriodID")

            // Mettre à jour UserConfiguration si disponible
            let configRequest: NSFetchRequest<UserConfiguration> = UserConfiguration.fetchRequest()
            if let config = try viewContext.fetch(configRequest).first {
                config.activePeriodID = periodIdString
            }

            print("✅ Période active mise à jour : \(periodName)")

            // ✅ NOTIFICATION avec données complètes
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .activePeriodChanged,
                    object: nil,
                    userInfo: [
                        "newPeriodID": periodIdString,
                        "periodName": periodName,
                        "source": "import",
                    ]
                )
                print("📢 Notification activePeriodChanged envoyée avec ID: \(periodIdString)")
            }
        } else {
            print("⚠️ Aucune période trouvée après import")
        }
    }

    private func importPeriods(_ periodsData: [[String: Any]]) throws {
        guard let viewContext = viewContext else { return }

        for periodData in periodsData {
            let period = Period(context: viewContext)
            period.id = UUID(uuidString: periodData["id"] as? String ?? "") ?? UUID()
            period.name = periodData["name"] as? String ?? ""
            period.startDate = ISO8601DateFormatter().date(from: periodData["startDate"] as? String ?? "") ?? Date()
            period.endDate = ISO8601DateFormatter().date(from: periodData["endDate"] as? String ?? "")
            period.createdAt = ISO8601DateFormatter().date(from: periodData["createdAt"] as? String ?? "") ?? Date()
        }
    }

    private func importSubjects(_ subjectsData: [[String: Any]]) throws {
        guard let viewContext = viewContext else { return }

        // Précharger tous les Periods dans le contexte courant
        let periodsRequest: NSFetchRequest<Period> = Period.fetchRequest()
        let periods = try viewContext.fetch(periodsRequest)

        // ✅ CORRECTION : Spécifier explicitement les types génériques
        let periodsById = [UUID: Period](uniqueKeysWithValues: periods.compactMap { period in
            guard let id = period.id else { return nil }
            return (id, period)
        })

        print("✅ Préchargé \(periodsById.count) périodes dans le contexte")

        for subjectData in subjectsData {
            let subject = Subject(context: viewContext)
            subject.id = UUID(uuidString: subjectData["id"] as? String ?? "") ?? UUID()
            subject.name = subjectData["name"] as? String ?? ""
            subject.code = subjectData["code"] as? String
            subject.coefficient = subjectData["coefficient"] as? Double ?? 0.0
            subject.grade = subjectData["grade"] as? Double ?? 0.0
            subject.createdAt = ISO8601DateFormatter().date(from: subjectData["createdAt"] as? String ?? "") ?? Date()
            subject.lastModified = ISO8601DateFormatter().date(from: subjectData["lastModified"] as? String ?? "") ?? Date()

            // Utiliser le dictionnaire pré-chargé
            if let periodIdString = subjectData["periodId"] as? String,
               let periodId = UUID(uuidString: periodIdString),
               let period = periodsById[periodId]
            {
                subject.period = period
                print("✅ Relation établie pour matière '\(subject.name ?? "")' avec période '\(period.name ?? "")'")
            } else {
                print("⚠️ Période non trouvée pour la matière '\(subject.name ?? "")'")
            }
        }
    }

    private func importEvaluations(_ evaluationsData: [[String: Any]]) throws {
        guard let viewContext = viewContext else { return }

        // ✅ CORRECTION : Précharger tous les subjects
        let subjectsRequest: NSFetchRequest<Subject> = Subject.fetchRequest()
        let subjects = try viewContext.fetch(subjectsRequest)
        let subjectsById: [UUID: Subject] = Dictionary(uniqueKeysWithValues: subjects.compactMap { subject in
            guard let id = subject.id else { return nil }
            return (id, subject)
        })

        print("✅ Préchargé \(subjectsById.count) subjects dans le contexte")

        for evaluationData in evaluationsData {
            let evaluation = Evaluation(context: viewContext)
            evaluation.id = UUID(uuidString: evaluationData["id"] as? String ?? "") ?? UUID()
            evaluation.title = evaluationData["title"] as? String ?? ""
            evaluation.grade = evaluationData["grade"] as? Double ?? 0.0
            evaluation.coefficient = evaluationData["coefficient"] as? Double ?? 0.0
            evaluation.date = ISO8601DateFormatter().date(from: evaluationData["date"] as? String ?? "") ?? Date()

            // ✅ CORRECTION : Utiliser le dictionnaire pré-chargé
            if let subjectId = evaluationData["subjectId"] as? String,
               let subjectUUID = UUID(uuidString: subjectId),
               let subject = subjectsById[subjectUUID]
            {
                evaluation.subject = subject
                print("✅ Relation établie pour évaluation '\(evaluation.title ?? "")' avec subject '\(subject.name ?? "")'")
            } else {
                print("⚠️ Subject non trouvé pour l'évaluation '\(evaluation.title ?? "")'")
            }
        }
    }

    private func importFlashcardDecks(_ decksData: [[String: Any]]) throws {
        guard let viewContext = viewContext else { return }

        for deckData in decksData {
            let deck = FlashcardDeck(context: viewContext)
            deck.id = UUID(uuidString: deckData["id"] as? String ?? "") ?? UUID()
            deck.name = deckData["name"] as? String ?? ""
            deck.createdAt = ISO8601DateFormatter().date(from: deckData["createdAt"] as? String ?? "") ?? Date()

            // ✅ Aucune liaison avec les subjects - flashcards indépendantes
        }
    }

    private func importFlashcards(_ flashcardsData: [[String: Any]]) throws {
        guard let viewContext = viewContext else { return }

        // ✅ PRÉCHARGER TOUS LES DECKS
        let decksRequest: NSFetchRequest<FlashcardDeck> = FlashcardDeck.fetchRequest()
        let decks = try viewContext.fetch(decksRequest)
        let decksById: [UUID: FlashcardDeck] = Dictionary(uniqueKeysWithValues: decks.compactMap { deck in
            guard let id = deck.id else { return nil }
            return (id, deck)
        })

        // ✅ PRÉCHARGER TOUTES LES CARTES EXISTANTES POUR FUSION
        let existingFlashcardsRequest: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
        let existingFlashcards = try viewContext.fetch(existingFlashcardsRequest)
        let existingFlashcardsById: [UUID: Flashcard] = Dictionary(uniqueKeysWithValues: existingFlashcards.compactMap { card in
            guard let id = card.id else { return nil }
            return (id, card)
        })

        print("✅ [IMPORT] Préchargé \(decksById.count) decks et \(existingFlashcardsById.count) cartes existantes")

        var processedCount = 0
        var createdCount = 0
        var updatedCount = 0
        var errors: [String] = []

        for flashcardData in flashcardsData {
            guard let idString = flashcardData["id"] as? String,
                  let cardId = UUID(uuidString: idString)
            else {
                let error = "ID de carte invalide: \(flashcardData["id"] ?? "nil")"
                errors.append(error)
                print("❌ [IMPORT] \(error)")
                continue
            }

            // ✅ FUSION PAR ID : ÉCRASER SRS LOCAL PAR CELUI DU JSON
            let flashcard: Flashcard
            if let existingCard = existingFlashcardsById[cardId] {
                flashcard = existingCard
                updatedCount += 1
                print("🔄 [IMPORT] Fusion de la carte existante: '\(existingCard.question ?? "")'")
            } else {
                flashcard = Flashcard(context: viewContext)
                flashcard.id = cardId
                createdCount += 1
                print("🆕 [IMPORT] Création de nouvelle carte: '\(flashcardData["question"] as? String ?? "")'")
            }

            // ✅ DONNÉES DE BASE (toujours mises à jour)
            flashcard.question = flashcardData["question"] as? String ?? ""
            flashcard.answer = flashcardData["answer"] as? String ?? ""

            // ✅ CHAMPS SM-2 AVEC FALLBACK "NOUVELLE"
            flashcard.interval = flashcardData["intervalDays"] as? Double ?? 1.0
            flashcard.easeFactor = flashcardData["easeFactor"] as? Double ?? SRSConfiguration.defaultEaseFactor
            flashcard.correctCount = Int16(flashcardData["correctCount"] as? Int32 ?? 0)
            flashcard.reviewCount = flashcardData["reviewCount"] as? Int32 ?? 0

            // ✅ DATES ISO8601 AVEC FALLBACK
            if let nextReviewString = flashcardData["nextReviewDate"] as? String, !nextReviewString.isEmpty {
                flashcard.nextReviewDate = ISO8601DateFormatter().date(from: nextReviewString)
            } else {
                flashcard.nextReviewDate = nil // Fallback "nouvelle"
            }

            if let lastReviewString = flashcardData["lastReviewDate"] as? String, !lastReviewString.isEmpty {
                flashcard.lastReviewDate = ISO8601DateFormatter().date(from: lastReviewString)
            } else {
                flashcard.lastReviewDate = nil
            }

            if let createdAtString = flashcardData["createdAt"] as? String, !createdAtString.isEmpty {
                flashcard.createdAt = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
            } else {
                flashcard.createdAt = Date()
            }

            // ✅ RELATION DECK AVEC CRÉATION SI ABSENT
            if let deckId = flashcardData["deckId"] as? String,
               let deckUUID = UUID(uuidString: deckId)
            {
                if let existingDeck = decksById[deckUUID] {
                    flashcard.deck = existingDeck
                    print("✅ [IMPORT] Relation établie avec deck existant: '\(existingDeck.name ?? "")'")
                } else {
                    // ✅ CRÉER LE DECK S'IL N'EXISTE PAS
                    let newDeck = FlashcardDeck(context: viewContext)
                    newDeck.id = deckUUID
                    newDeck.name = "Deck importé" // Nom par défaut
                    newDeck.createdAt = Date()
                    flashcard.deck = newDeck
                    print("🆕 [IMPORT] Deck créé automatiquement: \(deckUUID)")
                }
            } else {
                let error = "Deck ID invalide pour carte '\(flashcard.question ?? "")'"
                errors.append(error)
                print("⚠️ [IMPORT] \(error)")
            }

            // ✅ IMPORT DES MÉDIAS QUESTION
            flashcard.questionType = flashcardData["questionType"] as? String ?? "text"
            flashcard.questionImageFileName = flashcardData["questionImageFileName"] as? String
            flashcard.questionAudioFileName = flashcardData["questionAudioFileName"] as? String
            flashcard.questionAudioDuration = flashcardData["questionAudioDuration"] as? Double ?? 0.0

            // Gérer les données d'image de question (petites images stockées en Base64)
            if let imageDataString = flashcardData["questionImageData"] as? String, !imageDataString.isEmpty {
                if let imageData = Data(base64Encoded: imageDataString) {
                    flashcard.questionImageData = imageData
                    print("📷 [IMPORT] Image question (Base64) importée pour: '\(flashcard.question ?? "")'")
                }
            }

            // ✅ IMPORT DES MÉDIAS RÉPONSE
            flashcard.answerType = flashcardData["answerType"] as? String ?? "text"
            flashcard.answerImageFileName = flashcardData["answerImageFileName"] as? String
            flashcard.answerAudioFileName = flashcardData["answerAudioFileName"] as? String
            flashcard.answerAudioDuration = flashcardData["answerAudioDuration"] as? Double ?? 0.0

            // Gérer les données d'image de réponse (petites images stockées en Base64)
            if let imageDataString = flashcardData["answerImageData"] as? String, !imageDataString.isEmpty {
                if let imageData = Data(base64Encoded: imageDataString) {
                    flashcard.answerImageData = imageData
                    print("📷 [IMPORT] Image réponse (Base64) importée pour: '\(flashcard.question ?? "")'")
                }
            }

            processedCount += 1

            // ✅ OPTIMISATION : Sauvegarde moins fréquente pour de meilleures performances
            if processedCount % 500 == 0 {
                try viewContext.save()
                print("💾 [IMPORT] Sauvegarde intermédiaire: \(processedCount) cartes traitées")
            }
        }

        // ✅ RECALCULER LES STATUTS APRÈS IMPORT
        try recalculateCardStatusesAfterImport()

        // ✅ RAPPORT FINAL
        print("✅ [IMPORT] Import terminé: \(processedCount) cartes traitées (\(createdCount) créées, \(updatedCount) mises à jour)")
        if !errors.isEmpty {
            print("⚠️ [IMPORT] \(errors.count) erreurs rencontrées:")
            for error in errors.prefix(5) { // Limiter l'affichage
                print("   - \(error)")
            }
            if errors.count > 5 {
                print("   ... et \(errors.count - 5) autres erreurs")
            }
        }
    }

    private func importUserDefaults(_ data: [String: Any]) {
        for (key, value) in data {
            UserDefaults.standard.set(value, forKey: key)
        }
        UserDefaults.standard.synchronize()
        print("✅ UserDefaults importés : \(data.keys.joined(separator: ", "))")
    }

    private func clearExistingData() throws {
        guard let viewContext = viewContext else { return }

        // ✅ CORRECTION : Sauvegarder avant suppression
        if viewContext.hasChanges {
            try viewContext.save()
        }

        // ✅ Effectuer les suppressions par batch avec reset
        let entities = ["Flashcard", "FlashcardDeck", "Evaluation", "Subject", "Period", "UserConfiguration"]

        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
                }
                print("✅ Entité \(entityName) supprimée")
            } catch {
                print("⚠️ Erreur suppression \(entityName): \(error)")
            }
        }

        // ✅ AJOUT : Reset complet du contexte
        viewContext.reset()

        // ✅ Sauvegarder après nettoyage
        try viewContext.save()

        print("✅ Données supprimées et contexte réinitialisé")
    }

    private func importUserConfiguration(_ configData: [[String: Any]]) throws {
        guard let viewContext = viewContext else { return }

        for configDataItem in configData {
            let config = UserConfiguration(context: viewContext)
            config.id = UUID(uuidString: configDataItem["id"] as? String ?? "") ?? UUID()
            config.username = configDataItem["username"] as? String
            config.hasCompletedOnboarding = configDataItem["hasCompletedOnboarding"] as? Bool ?? false
            config.activePeriodID = configDataItem["activePeriodID"] as? String
            config.selectedSystem = configDataItem["selectedSystem"] as? String
            config.profileGradientStart = configDataItem["profileGradientStart"] as? String
            config.profileGradientEnd = configDataItem["profileGradientEnd"] as? String
            config.createdDate = ISO8601DateFormatter().date(from: configDataItem["createdDate"] as? String ?? "") ?? Date()
            config.lastModifiedDate = ISO8601DateFormatter().date(from: configDataItem["lastModifiedDate"] as? String ?? "") ?? Date()
        }
    }

    // MARK: - Utilities

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }

    // ✅ NOUVELLE MÉTHODE : Recalculer les statuts après import
    private func recalculateCardStatusesAfterImport() throws {
        guard let viewContext = viewContext else { return }

        let flashcardsRequest: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
        let flashcards = try viewContext.fetch(flashcardsRequest)

        print("🔄 [IMPORT] Recalcul des statuts pour \(flashcards.count) cartes après import")

        for flashcard in flashcards {
            // ✅ VALIDATION ET CORRECTION DES DONNÉES SM-2
            let oldInterval = flashcard.interval
            let oldEF = flashcard.easeFactor

            // 1. Interval négatif/NaN → fallback à 1.0
            if flashcard.interval < 0 || flashcard.interval.isNaN {
                flashcard.interval = 1.0
                print("⚠️ [IMPORT] Intervalle invalide corrigé pour carte '\(flashcard.question ?? "")': \(oldInterval) → 1.0")
            }

            // 2. Ease factor hors bornes → clamp aux limites
            if flashcard.easeFactor < SRSConfiguration.minEaseFactor ||
                flashcard.easeFactor > SRSConfiguration.maxEaseFactor ||
                flashcard.easeFactor.isNaN
            {
                let clampedEF = max(SRSConfiguration.minEaseFactor, min(SRSConfiguration.maxEaseFactor, flashcard.easeFactor))
                flashcard.easeFactor = clampedEF
                print("⚠️ [IMPORT] Ease factor corrigé pour carte '\(flashcard.question ?? "")': \(oldEF) → \(clampedEF)")
            }

            // 3. Soft-cap sur interval (3 ans max)
            if flashcard.interval > SRSConfiguration.softCapThreshold {
                flashcard.interval = SRSConfiguration.softCapThreshold
                print("⚠️ [IMPORT] Intervalle soft-cap appliqué pour carte '\(flashcard.question ?? "")': \(oldInterval) → \(SRSConfiguration.softCapThreshold)")
            }

            // 4. Validation des dates
            if let nextReview = flashcard.nextReviewDate,
               let lastReview = flashcard.lastReviewDate,
               nextReview < lastReview
            {
                print("⚠️ [IMPORT] Dates incohérentes pour carte '\(flashcard.question ?? "")': nextReview (\(nextReview)) < lastReview (\(lastReview))")
                // Garder les deux dates mais log l'incohérence
            }

            // 5. Recalcul de la date de révision si nécessaire
            if flashcard.nextReviewDate == nil, flashcard.reviewCount > 0 {
                // Carte avec historique mais pas de date → recalculer
                let nextReview = Calendar.current.date(byAdding: .day, value: Int(flashcard.interval), to: Date()) ?? Date()
                flashcard.nextReviewDate = nextReview
                print("🔄 [IMPORT] Date de révision recalculée pour carte '\(flashcard.question ?? "")': \(nextReview)")
            }

            // 6. Validation des compteurs
            if flashcard.correctCount < 0 {
                flashcard.correctCount = 0
                print("⚠️ [IMPORT] Correct count négatif corrigé pour carte '\(flashcard.question ?? "")'")
            }

            if flashcard.reviewCount < 0 {
                flashcard.reviewCount = 0
                print("⚠️ [IMPORT] Review count négatif corrigé pour carte '\(flashcard.question ?? "")'")
            }
        }

        // ✅ SAUVEGARDE DES CORRECTIONS
        if viewContext.hasChanges {
            try viewContext.save()
            print("✅ [IMPORT] Statuts recalculés et sauvegardés")
        } else {
            print("ℹ️ [IMPORT] Aucune correction nécessaire")
        }
    }
}

// ✅ EXTENSION POUR ISO8601
extension Date {
    func ISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

enum ImportExportError: LocalizedError {
    case operationInProgress
    case invalidFormat
    case missingRequiredData
    case corruptedData
    case insufficientStorage
    case networkError
    case incompatibleVersion
    case fileExpired
    case invalidUUID(entityName: String, reason: String)
    case duplicateUUID(entityName: String, uuid: String)
    case orphanedReference(entityName: String, entityId: String, referencedEntity: String, referencedId: String)
    case batchOperationFailed(errors: [Error])
    case validationFailed(reason: String)
    case transactionFailed(underlyingError: Error)
    case securityScopedResourceFailed
    case bookmarkResolutionFailed
    case contextNotConfigured
    case exportLocationUnavailable
    case importFileNotFound
    case fileTooLarge(maxSize: Int, actualSize: Int)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case importFileCorrupted
    case unsupportedFileVersion(version: String)
    case relationshipIntegrityViolation(details: String)
    case dataConsistencyError(entity: String, details: String)

    var errorDescription: String? {
        switch self {
        case .operationInProgress:
            return String(localized: "error_operation_in_progress")
        case .invalidFormat:
            return String(localized: "error_invalid_format")
        case .missingRequiredData:
            return String(localized: "error_missing_required_data")
        case .corruptedData:
            return String(localized: "error_corrupted_data")
        case .insufficientStorage:
            return String(localized: "error_insufficient_storage")
        case .networkError:
            return String(localized: "error_network_error")
        case .incompatibleVersion:
            return String(localized: "error_incompatible_version")
        case .fileExpired:
            return String(localized: "error_file_expired")
        case let .invalidUUID(entityName, reason):
            return String(localized: "error_invalid_uuid")
                .replacingOccurrences(of: "%@", with: entityName)
                .replacingOccurrences(of: "%@", with: reason)
        case let .duplicateUUID(entityName, uuid):
            return String(localized: "error_duplicate_uuid")
                .replacingOccurrences(of: "%@", with: entityName)
                .replacingOccurrences(of: "%@", with: uuid)
        case let .orphanedReference(entityName, entityId, referencedEntity, referencedId):
            return String(localized: "error_orphaned_reference")
                .replacingOccurrences(of: "%@", with: entityName)
                .replacingOccurrences(of: "%@", with: entityId)
                .replacingOccurrences(of: "%@", with: referencedEntity)
                .replacingOccurrences(of: "%@", with: referencedId)
        case let .batchOperationFailed(errors):
            let errorMessages = errors.map { $0.localizedDescription }.joined(separator: ", ")
            return String(localized: "error_batch_operation_failed")
                .replacingOccurrences(of: "%@", with: errorMessages)
        case let .validationFailed(reason):
            return String(localized: "error_validation_failed")
                .replacingOccurrences(of: "%@", with: reason)
        case let .transactionFailed(underlyingError):
            return String(localized: "error_transaction_failed")
                .replacingOccurrences(of: "%@", with: underlyingError.localizedDescription)
        case .securityScopedResourceFailed:
            return String(localized: "error_security_scoped_resource_failed")
        case .bookmarkResolutionFailed:
            return String(localized: "error_bookmark_resolution_failed")
        case .contextNotConfigured:
            return String(localized: "error_context_not_configured")
        case .exportLocationUnavailable:
            return String(localized: "error_export_location_unavailable")
        case .importFileNotFound:
            return String(localized: "error_import_file_not_found")
        case let .fileTooLarge(maxSize, actualSize):
            return "Fichier trop volumineux: \(actualSize) bytes (limite: \(maxSize) bytes)"
        case let .insufficientDiskSpace(required, available):
            return "Espace disque insuffisant: \(available) bytes disponibles (besoin: \(required) bytes)"
        case .importFileCorrupted:
            return String(localized: "error_import_file_corrupted")
        case let .unsupportedFileVersion(version):
            return String(localized: "error_unsupported_file_version")
                .replacingOccurrences(of: "%@", with: version)
        case let .relationshipIntegrityViolation(details):
            return String(localized: "error_relationship_integrity_violation")
                .replacingOccurrences(of: "%@", with: details)
        case let .dataConsistencyError(entity, details):
            return String(localized: "error_data_consistency_error")
                .replacingOccurrences(of: "%@", with: entity)
                .replacingOccurrences(of: "%@", with: details)
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .operationInProgress:
            return String(localized: "recovery_wait_operation")
        case .invalidFormat:
            return String(localized: "recovery_verify_file")
        case .missingRequiredData:
            return String(localized: "recovery_contact_support")
        case .corruptedData:
            return String(localized: "recovery_try_another_file")
        case .insufficientStorage:
            return String(localized: "recovery_free_storage")
        case .incompatibleVersion:
            return String(localized: "recovery_update_app")
        case .invalidUUID, .duplicateUUID:
            return String(localized: "recovery_file_corrupted")
        case .orphanedReference:
            return String(localized: "recovery_verify_integrity")
        case .contextNotConfigured:
            return String(localized: "recovery_restart_app")
        case .securityScopedResourceFailed:
            return String(localized: "recovery_reselect_file")
        default:
            return String(localized: "recovery_try_again")
        }
    }
}

enum DataError: LocalizedError {
    case operationInProgress
    case invalidFormat
    case missingRequiredData
    case corruptedData
    case insufficientStorage
    case networkError
    case incompatibleVersion
    case fileExpired
    case orphanedData(String)

    var errorDescription: String? {
        switch self {
        case .operationInProgress:
            return String(localized: "error_simple_operation_in_progress")
        case .invalidFormat:
            return String(localized: "error_invalid_format")
        case .missingRequiredData:
            return String(localized: "error_missing_required_data")
        case .corruptedData:
            return String(localized: "error_corrupted_data")
        case .insufficientStorage:
            return String(localized: "error_insufficient_storage")
        case .networkError:
            return String(localized: "error_network_error")
        case .incompatibleVersion:
            return String(localized: "error_incompatible_version")
        case .fileExpired:
            return String(localized: "error_file_expired")
        case let .orphanedData(details):
            return String(localized: "error_orphaned_data")
                .replacingOccurrences(of: "%@", with: details)
        }
    }
}
