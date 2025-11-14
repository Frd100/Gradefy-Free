//
//  MediaStorageManager.swift
//  PARALLAX
//
//  Created by Farid on 7/27/25.
//

import Foundation
import ImageIO
import UIKit

@MainActor
class MediaStorageManager: ObservableObject {
    static let shared = MediaStorageManager()

    private let fileManager = FileManager.default
    private let mediaDirectory: URL

    // ✅ OPTIMISATION APPLE : Toutes les images en fichiers (recommandation officielle)
    private enum Constants {
        static let imageCompressionQuality: CGFloat = 0.7
        static let mediaDirectoryName = "GradefyMedia"
    }

    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        mediaDirectory = documentsPath.appendingPathComponent(Constants.mediaDirectoryName, isDirectory: true)
        createMediaDirectoryIfNeeded()
    }

    private func createMediaDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: mediaDirectory.path) else { return }

        do {
            try fileManager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true, attributes: nil)
            print("✅ Dossier médias créé: \(mediaDirectory.path)")
        } catch {
            print("❌ Erreur création dossier médias: \(error.localizedDescription)")
        }
    }

    // MARK: - Images Management

    /// Stocke une image et retourne les informations de stockage
    /// - Parameters:
    ///   - image: L'image à stocker
    ///   - usage: Type d'usage pour la compression adaptative
    /// - Returns: Tuple contenant les données, nom du fichier et méthode de stockage
    func storeImage(_ image: UIImage, usage: ImageCompressor.ImageUsage = .flashcard) -> (data: Data?, fileName: String, shouldStoreInFileManager: Bool)? {
        // ✅ OPTIMISATION APPLE : Toujours stocker en fichier (recommandation officielle)
        // "It is better to store BLOBs as resources on the file system" - Apple Core Data Performance Guide
        guard let imageData = ImageCompressor.shared.compressImage(image, for: usage) else {
            print("❌ Impossible de compresser l'image")
            return nil
        }

        let fileName = generateUniqueFileName(extension: "jpg")

        // Toujours stocker sur disque (pas de Base64 en Core Data)
        return storeImageToFile(data: imageData, fileName: fileName)
    }

    private func storeImageToFile(data: Data, fileName: String) -> (data: Data?, fileName: String, shouldStoreInFileManager: Bool)? {
        let fileURL = mediaDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL, options: .atomic)
            print("✅ Image sauvegardée dans fichier: \(fileName) (\(formatFileSize(data.count)))")
            return (data: nil, fileName: fileName, shouldStoreInFileManager: true)
        } catch {
            print("❌ Erreur sauvegarde image: \(error.localizedDescription)")
            return nil
        }
    }

    /// Charge une image depuis les données ou le fichier
    /// - Parameters:
    ///   - fileName: Nom du fichier
    ///   - data: Données optionnelles (legacy - maintenant toujours nil)
    /// - Returns: UIImage si le chargement réussit
    func loadImage(fileName: String, data: Data?) -> UIImage? {
        // ✅ OPTIMISATION APPLE : Toutes les images sont maintenant en fichiers
        // Le paramètre 'data' est conservé pour compatibilité mais toujours nil
        if let data = data {
            // Legacy : anciennes images en Base64 (migration progressive)
            return UIImage(data: data)
        } else {
            // Nouveau comportement : toujours charger depuis le fichier
            return loadImageFromFile(fileName: fileName)
        }
    }

    func getImageURL(fileName: String) -> URL? {
        let imageURL = mediaDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: imageURL.path) else {
            print("❌ Image non trouvée: \(imageURL.path)")
            return nil
        }
        return imageURL
    }

    // ✅ MÉTHODE SIMPLIFIÉE : Utiliser le nouveau système de compression
    func compressImage(_ image: UIImage, maxSizeKB: Int = 300) -> UIImage {
        // Déléguer au nouveau système de compression
        let usage: ImageCompressor.ImageUsage = maxSizeKB <= 100 ? .thumbnail : .flashcard
        let resizedImage = ImageCompressor.shared.resizeImage(image, maxDimension: usage.maxDimension)
        return resizedImage
    }

    // ✅ MÉTHODE SIMPLIFIÉE : Compression adaptative
    func adaptiveCompressImage(_ image: UIImage) -> UIImage {
        // Utiliser le système de compression simplifié
        return ImageCompressor.shared.compressImage(image, for: .flashcard) != nil ? image : compressImage(image)
    }

    private func loadImageFromFile(fileName: String) -> UIImage? {
        let fileURL = mediaDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("⚠️ Fichier image introuvable: \(fileName)")
            return nil
        }

        do {
            let fileData = try Data(contentsOf: fileURL)
            return UIImage(data: fileData)
        } catch {
            print("❌ Erreur chargement image: \(fileName) - \(error.localizedDescription)")
            return nil
        }
    }

    /// Supprime une image du stockage
    /// - Parameters:
    ///   - fileName: Nom du fichier à supprimer
    ///   - hasFileManagerData: Indique si l'image est stockée sur disque
    func deleteImage(fileName: String, hasFileManagerData: Bool) {
        guard hasFileManagerData else {
            print("✅ Image en mémoire - pas de fichier à supprimer: \(fileName)")
            return
        }

        let fileURL = mediaDirectory.appendingPathComponent(fileName)
        deleteFileIfExists(at: fileURL, type: "image")
    }

    // MARK: - Audio Management

    /// Retourne l'URL pour un fichier audio
    /// - Parameter fileName: Nom du fichier audio
    /// - Returns: URL complète du fichier
    func getAudioURL(fileName: String) -> URL {
        return mediaDirectory.appendingPathComponent(fileName)
    }

    /// Supprime un fichier audio
    /// - Parameter fileName: Nom du fichier à supprimer
    func deleteAudio(fileName: String) {
        let audioURL = getAudioURL(fileName: fileName)
        deleteFileIfExists(at: audioURL, type: "audio")
    }

    // ✅ CORRECTION 2 : Alias pour compatibilité (si utilisé ailleurs)
    func deleteAudioFile(fileName: String) {
        deleteAudio(fileName: fileName)
    }

    // MARK: - Utility Methods

    /// Génère un nom de fichier unique avec extension
    private func generateUniqueFileName(extension: String) -> String {
        return "\(UUID().uuidString).\(`extension`)"
    }

    /// Supprime un fichier s'il existe
    private func deleteFileIfExists(at url: URL, type: String) {
        guard fileManager.fileExists(atPath: url.path) else {
            print("⚠️ Fichier \(type) introuvable: \(url.lastPathComponent)")
            return
        }

        // ✅ CORRECTION : Opération I/O asynchrone sans capturer self
        let targetURL = url
        Task.detached(priority: .utility) {
            do {
                try FileManager.default.removeItem(at: targetURL)
                print("✅ Fichier \(type) supprimé: \(targetURL.lastPathComponent)")
            } catch {
                print("❌ Erreur suppression \(type): \(error.localizedDescription)")
            }
        }
    }

    /// Formate la taille d'un fichier pour l'affichage
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - Storage Info

    /// Retourne des informations sur l'utilisation du stockage
    func getStorageInfo() -> (totalFiles: Int, totalSize: String) {
        do {
            let files = try fileManager.contentsOfDirectory(at: mediaDirectory, includingPropertiesForKeys: [.fileSizeKey])
            var totalSize: Int64 = 0

            for file in files {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }

            return (totalFiles: files.count, totalSize: formatFileSize(Int(totalSize)))
        } catch {
            print("❌ Erreur calcul stockage: \(error.localizedDescription)")
            return (totalFiles: 0, totalSize: "0 KB")
        }
    }

    /// Nettoie les fichiers orphelins (optionnel pour maintenance)
    func cleanupOrphanedFiles(validFileNames: Set<String>) {
        // ✅ CORRECTION : Opération I/O asynchrone sans capturer self
        let dir = mediaDirectory
        let valid = validFileNames
        Task.detached(priority: .utility) {
            do {
                let allFiles = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                let orphanedFiles = allFiles.filter { !valid.contains($0.lastPathComponent) }

                for orphanedFile in orphanedFiles {
                    try FileManager.default.removeItem(at: orphanedFile)
                    print("🧹 Fichier orphelin supprimé: \(orphanedFile.lastPathComponent)")
                }

                if !orphanedFiles.isEmpty {
                    print("✅ Nettoyage terminé: \(orphanedFiles.count) fichiers supprimés")
                }
            } catch {
                print("❌ Erreur nettoyage: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Async Support

extension MediaStorageManager {
    /// Version async pour le stockage d'image (si nécessaire pour de gros traitements)
    func storeImageAsync(_ image: UIImage, usage: ImageCompressor.ImageUsage = .flashcard) async -> (data: Data?, fileName: String, shouldStoreInFileManager: Bool)? {
        return await Task.detached {
            await MainActor.run {
                self.storeImage(image, usage: usage)
            }
        }.value
    }

    /// Version async pour le chargement d'image
    func loadImageAsync(fileName: String, data: Data?) async -> UIImage? {
        if let data = data {
            return UIImage(data: data)
        } else {
            return await Task.detached {
                let fileURL = self.mediaDirectory.appendingPathComponent(fileName)
                guard let fileData = try? Data(contentsOf: fileURL) else { return nil }
                return UIImage(data: fileData)
            }.value
        }
    }
}
