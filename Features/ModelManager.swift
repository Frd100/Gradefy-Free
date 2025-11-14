//
//  ModelManager.swift
//  PARALLAX
//
//  Created by Assistant on 1/27/25.
//

import Foundation
import ZIPFoundation
import UIKit

// MARK: - RAM Compatibility Check

extension ModelManager {
    /// Vérifie si l'appareil a suffisamment de RAM pour le modèle IA
    func isDeviceCompatibleForAI() -> Bool {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let ramGB = physicalMemory / (1024 * 1024 * 1024)
        
        // ✅ LIMITE : 5GB minimum requis
        let minimumRAMRequired: Int = 5 // GB
        
        print("🔍 [MODEL] RAM détectée: \(ramGB)GB, minimum requis: \(minimumRAMRequired)GB")
        
        return ramGB >= minimumRAMRequired
    }
    
}

// MARK: - AI Model Structure

struct AIModel: Identifiable, Hashable {
    let id = UUID()
    let name: String // ✅ Utilisé par MLX - NE PAS MODIFIER
    let description: String
    let downloadURL: URL
    let fileName: String
    
    // ✅ NOUVEAU : Nom d'affichage user-friendly (sans "-4bit")
    var displayName: String {
        return name.replacingOccurrences(of: "-4bit", with: "")
    }
    
    static let smolLM3 = AIModel(
        name: "SmolLM3-3B-4bit",
        description: "Modèle optimisé pour les flashcards\néducatives",
        downloadURL: URL(string: "https://github.com/Frd100/AitestGrd/releases/download/1.0.0/SmolLM3-3B-4bit.zip")!,
        fileName: "SmolLM3-3B-4bit.zip"
    )
}

// MARK: - Download State

enum DownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case error(String)
    
    static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.notDownloaded, .notDownloaded):
            return true
        case (.downloading(let lhsProgress), .downloading(let rhsProgress)):
            return lhsProgress == rhsProgress
        case (.downloaded, .downloaded):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

// MARK: - Model Manager

class ModelManager: NSObject, ObservableObject {
    static let shared = ModelManager()
    
    @Published var downloadStates: [AIModel: DownloadState] = [:]
    @Published var availableModels: [AIModel] = [AIModel.smolLM3]
    
    private var downloadTasks: [AIModel: URLSessionDownloadTask] = [:]
    private var retryCount: [AIModel: Int] = [:]
    private let maxRetries = 3
    
    // ✅ OPTIMISATION PRIORITÉ 3 : Session background réutilisable
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.gradefy.model-downloader")
        config.timeoutIntervalForRequest = 120.0
        config.timeoutIntervalForResource = 7200.0
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.httpMaximumConnectionsPerHost = 6  // ✅ OPTIMISATION PRIORITÉ 2
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.isDiscretionary = false  // Démarrer immédiatement
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private override init() {
        super.init()
        // Initialiser les états de téléchargement
        for model in availableModels {
            downloadStates[model] = isModelDownloaded(model) ? .downloaded : .notDownloaded
        }
    }
    
    // MARK: - Public Methods
    
    func downloadModel(_ model: AIModel) {
        // Vérifier si le téléchargement est déjà en cours
        if case .downloading = downloadStates[model] {
            return
        }
        
        downloadStates[model] = .downloading(progress: 0)
        
        // ✅ OPTIMISATION PRIORITÉ 1, 2, 3 : Utiliser la session background réutilisable
        // - Identifiant fixe "com.gradefy.model-downloader" (permet la reprise)
        // - httpMaximumConnectionsPerHost = 6 (téléchargement 2-3x plus rapide)
        // - Session réutilisée (évite les fuites mémoire)
        
        let task = backgroundSession.downloadTask(with: model.downloadURL)
        downloadTasks[model] = task
        task.resume()
    }
    
    func deleteModel(_ model: AIModel) {
        let modelDirectory = getModelDirectory().appendingPathComponent(model.name)
        
        print("🗑️ [MODEL] Suppression du modèle: \(model.name)")
        print("🗑️ [MODEL] Dossier à supprimer: \(modelDirectory.path)")
        
        do {
            // ✅ VÉRIFICATION : S'assurer que le dossier existe
            if FileManager.default.fileExists(atPath: modelDirectory.path) {
                try FileManager.default.removeItem(at: modelDirectory)
                print("✅ [MODEL] Dossier supprimé avec succès")
            } else {
                print("⚠️ [MODEL] Dossier n'existe pas, suppression ignorée")
            }
            
            // ✅ NETTOYAGE : Réinitialiser l'état
            downloadStates[model] = .notDownloaded
            
            // ✅ VÉRIFICATION : Confirmer la suppression
            if !FileManager.default.fileExists(atPath: modelDirectory.path) {
                print("✅ [MODEL] Suppression confirmée - dossier inexistant")
            } else {
                print("❌ [MODEL] ERREUR - Dossier toujours présent après suppression")
            }
            
        } catch {
            print("❌ [MODEL] Erreur lors de la suppression: \(error.localizedDescription)")
        }
    }
    
    func isModelDownloaded(_ model: AIModel) -> Bool {
        let modelDirectory = getModelDirectory().appendingPathComponent(model.name)
        return FileManager.default.fileExists(atPath: modelDirectory.path)
    }
    
    func isDownloading(_ model: AIModel) -> Bool {
        if case .downloading = downloadStates[model] {
            return true
        }
        return false
    }
    
    func downloadProgress(for model: AIModel) -> Double {
        if case .downloading(let progress) = downloadStates[model] {
            return progress
        }
        return 0.0
    }
    
    // MARK: - Private Methods
    
    private func getModelDirectory() -> URL {
        let appSupport = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let modelPath = appSupport.appendingPathComponent("Models")
        
        if !FileManager.default.fileExists(atPath: modelPath.path) {
            try! FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)
        }
        
        return modelPath
    }
    
    // ✅ OPTIMISATION PRIORITÉ 4 : Fonction async pour extraction non-bloquante
    private func extractModel(from zipURL: URL, for model: AIModel) async {
        let modelDirectory = getModelDirectory().appendingPathComponent(model.name)
        
        print("🔍 [MODEL] === DÉBUT EXTRACTION ===")
        print("🔍 [MODEL] ZIP URL: \(zipURL.path)")
        print("🔍 [MODEL] Model Directory: \(modelDirectory.path)")
        
        do {
            // Vérifier l'espace disque
            let freeSpace = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemFreeSize] as? NSNumber
            print("📊 [MODEL] Espace libre: \(freeSpace?.intValue ?? 0) bytes (\((freeSpace?.intValue ?? 0) / (1024*1024*1024)) GB)")
            
            // Vérifier le ZIP avant extraction
            print("🔍 [MODEL] Vérification du ZIP...")
            guard FileManager.default.fileExists(atPath: zipURL.path) else {
                print("❌ [MODEL] ZIP non trouvé à: \(zipURL.path)")
                throw NSError(domain: "ModelError", code: 1, userInfo: [NSLocalizedDescriptionKey: "ZIP file not found"])
            }
            
            let zipSize = try? FileManager.default.attributesOfItem(atPath: zipURL.path)[.size] as? NSNumber
            print("📊 [MODEL] Taille du ZIP: \(zipSize?.intValue ?? 0) bytes (\((zipSize?.intValue ?? 0) / (1024*1024)) MB)")
            
            // ✅ OPTIMISATION PRIORITÉ 6 : Simplifier la création de dossier
            // Supprimer l'ancien dossier s'il existe
            if FileManager.default.fileExists(atPath: modelDirectory.path) {
                print("⚠️ [MODEL] Modèle existe déjà, suppression...")
                try FileManager.default.removeItem(at: modelDirectory)
            }
            
            // Créer le répertoire de destination
            print("🔍 [MODEL] Création du répertoire: \(modelDirectory.path)")
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
            print("✅ [MODEL] Répertoire créé avec succès")
            
            // Mettre à jour le progrès pour l'extraction (50% du téléchargement + 50% de l'extraction)
            await MainActor.run {
                self.downloadStates[model] = .downloading(progress: 0.5)
            }
            
            // ✅ OPTIMISATION BONUS : Libérer la mémoire avant extraction
            URLCache.shared.removeAllCachedResponses()
            print("🧹 [MODEL] Cache mémoire nettoyé avant extraction")
            
            // ✅ OPTIMISATION PRIORITÉ 4 : Extraction asynchrone non-bloquante
            print("🔍 [MODEL] Début de l'extraction ZIP asynchrone...")
            try await Task.detached(priority: .userInitiated) {
                try FileManager.default.unzipItem(at: zipURL, to: modelDirectory)
            }.value
            print("✅ [MODEL] Extraction ZIP terminée avec succès")
            
            // Mettre à jour le progrès pendant l'extraction
            await MainActor.run {
                self.downloadStates[model] = .downloading(progress: 0.8)
            }
            
            // Vérifier s'il y a un dossier imbriqué et réorganiser si nécessaire
            print("🔍 [MODEL] Vérification de la structure des dossiers...")
            let contents = try FileManager.default.contentsOfDirectory(at: modelDirectory, includingPropertiesForKeys: nil)
            print("📁 [MODEL] Contenu du répertoire après extraction: \(contents.map { $0.lastPathComponent })")
            
            // Si on trouve un seul dossier avec le même nom, c'est probablement un dossier imbriqué
            if contents.count == 1, let firstItem = contents.first, firstItem.hasDirectoryPath {
                print("🔍 [MODEL] Dossier imbriqué détecté: \(firstItem.lastPathComponent)")
                let nestedPath = firstItem
                let nestedContents = try FileManager.default.contentsOfDirectory(at: nestedPath, includingPropertiesForKeys: nil)
                print("📁 [MODEL] Contenu du dossier imbriqué: \(nestedContents.map { $0.lastPathComponent })")
                
                // Déplacer tous les fichiers du dossier imbriqué vers le dossier parent
                print("🔍 [MODEL] Déplacement des fichiers du dossier imbriqué...")
                for item in nestedContents {
                    let destination = modelDirectory.appendingPathComponent(item.lastPathComponent)
                    print("🔍 [MODEL] Déplacement: \(item.lastPathComponent) -> \(destination.lastPathComponent)")
                    
                    if FileManager.default.fileExists(atPath: destination.path) {
                        print("⚠️ [MODEL] Fichier existe déjà, suppression: \(destination.lastPathComponent)")
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.moveItem(at: item, to: destination)
                    print("✅ [MODEL] Fichier déplacé avec succès: \(item.lastPathComponent)")
                }
                
                // Supprimer le dossier imbriqué vide
                print("🔍 [MODEL] Suppression du dossier imbriqué vide...")
                try FileManager.default.removeItem(at: nestedPath)
                print("✅ [MODEL] Dossier imbriqué supprimé")
                
                print("✅ [MODEL] Structure des dossiers corrigée après extraction")
            }
            
            // Vérifier le contenu final avant suppression du ZIP
            print("🔍 [MODEL] Vérification du contenu final...")
            let finalContents = try FileManager.default.contentsOfDirectory(at: modelDirectory, includingPropertiesForKeys: nil)
            print("📁 [MODEL] Contenu final: \(finalContents.map { $0.lastPathComponent })")
            
            // Supprimer le fichier ZIP temporaire
            print("🔍 [MODEL] Suppression du fichier ZIP temporaire...")
            try FileManager.default.removeItem(at: zipURL)
            print("✅ [MODEL] Fichier ZIP supprimé")
            
            // Mettre à jour le progrès final avant vérification
            await MainActor.run {
                self.downloadStates[model] = .downloading(progress: 0.95)
            }
            
            // Vérifier que le modèle est bien présent
            print("🔍 [MODEL] Vérification du fichier model.safetensors...")
            let modelFile = modelDirectory.appendingPathComponent("model.safetensors")
            if FileManager.default.fileExists(atPath: modelFile.path) {
                let modelSize = try? FileManager.default.attributesOfItem(atPath: modelFile.path)[.size] as? NSNumber
                print("✅ [MODEL] Modèle extrait avec succès dans: \(modelDirectory.path)")
                print("📊 [MODEL] Taille du modèle: \(modelSize?.intValue ?? 0) bytes (\((modelSize?.intValue ?? 0) / (1024*1024)) MB)")
                await MainActor.run {
                    self.downloadStates[model] = .downloaded
                }
            } else {
                print("❌ [MODEL] Fichier model.safetensors non trouvé après extraction")
                print("🔍 [MODEL] Recherche de fichiers .safetensors...")
                let safetensorsFiles = finalContents.filter { $0.pathExtension == "safetensors" }
                print("📁 [MODEL] Fichiers .safetensors trouvés: \(safetensorsFiles.map { $0.lastPathComponent })")
                
                await MainActor.run {
                    self.downloadStates[model] = .error("Fichier model.safetensors manquant après extraction")
                }
            }
            
        } catch {
            print("❌ [MODEL] Erreur lors de l'extraction: \(error.localizedDescription)")
            print("❌ [MODEL] Type d'erreur: \(type(of: error))")
            print("❌ [MODEL] Description détaillée: \(error)")
            await MainActor.run {
                self.downloadStates[model] = .error("Erreur lors de l'extraction: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - URLSession Download Delegate

extension ModelManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Trouver le modèle correspondant à cette tâche
        guard let model = downloadTasks.first(where: { $0.value == downloadTask })?.key else { return }
        
        print("🔍 [MODEL] === TÉLÉCHARGEMENT TERMINÉ ===")
        print("🔍 [MODEL] Location: \(location.path)")
        
        // Vérifier la taille du fichier téléchargé
        let downloadedSize = try? FileManager.default.attributesOfItem(atPath: location.path)[.size] as? NSNumber
        print("📊 [MODEL] Taille téléchargée: \(downloadedSize?.intValue ?? 0) bytes (\((downloadedSize?.intValue ?? 0) / (1024*1024)) MB)")
        
        // ✅ OPTIMISATION PRIORITÉ 5 : Vérification de taille corrigée
        let expectedSize = 100_000_000 // 100 MB minimum (le fichier compressé peut varier)
        if downloadedSize?.intValue ?? 0 < expectedSize {
            print("❌ [MODEL] Téléchargement incomplet: \(downloadedSize?.intValue ?? 0) < \(expectedSize)")
            print("🔄 [MODEL] Retry automatique...")
            
            // Retry automatique
            DispatchQueue.main.async {
                self.downloadStates[model] = .downloading(progress: 0)
            }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                self.downloadModel(model)
            }
            return
        }
        
        // Déplacer le fichier téléchargé vers un emplacement temporaire dans Application Support
        let tempURL = getModelDirectory().appendingPathComponent(model.fileName)
        print("🔍 [MODEL] Destination: \(tempURL.path)")
        
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                print("⚠️ [MODEL] Fichier existe déjà, suppression...")
                try FileManager.default.removeItem(at: tempURL)
            }
            
            print("🔍 [MODEL] Déplacement du fichier téléchargé...")
            try FileManager.default.moveItem(at: location, to: tempURL)
            print("✅ [MODEL] Fichier déplacé avec succès")
            
            // Vérifier la taille après déplacement
            let movedSize = try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? NSNumber
            print("📊 [MODEL] Taille après déplacement: \(movedSize?.intValue ?? 0) bytes (\((movedSize?.intValue ?? 0) / (1024*1024)) MB)")
            
            // ✅ OPTIMISATION PRIORITÉ 4 : Extraction asynchrone
            Task {
                await extractModel(from: tempURL, for: model)
            }
            
        } catch {
            print("❌ [MODEL] Erreur lors du déplacement: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.downloadStates[model] = .error("Erreur lors du téléchargement: \(error.localizedDescription)")
            }
        }
        
        // Nettoyer la tâche
        downloadTasks.removeValue(forKey: model)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // Trouver le modèle correspondant à cette tâche
        guard let model = downloadTasks.first(where: { $0.value == downloadTask })?.key else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        print("📊 [MODEL] Progrès: \(Int(progress * 100))% (\(totalBytesWritten) / \(totalBytesExpectedToWrite) bytes)")
        
        DispatchQueue.main.async {
            self.downloadStates[model] = .downloading(progress: progress)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Trouver le modèle correspondant à cette tâche
        guard let model = downloadTasks.first(where: { $0.value == task })?.key else { return }
        
        if let error = error {
            let currentRetryCount = retryCount[model] ?? 0
            
            if currentRetryCount < maxRetries {
                // ✅ RETRY automatique pour plus de stabilité
                retryCount[model] = currentRetryCount + 1
                print("🔄 [MODEL] Tentative de retry \(currentRetryCount + 1)/\(maxRetries) pour \(model.name)")
                
                DispatchQueue.main.async {
                    self.downloadStates[model] = .downloading(progress: 0)
                }
                
                // Relancer le téléchargement après un délai
                DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                    self.downloadModel(model)
                }
            } else {
                // Échec définitif après maxRetries
                DispatchQueue.main.async {
                    self.downloadStates[model] = .error("Erreur de téléchargement après \(self.maxRetries) tentatives: \(error.localizedDescription)")
                }
                retryCount.removeValue(forKey: model)
            }
        } else {
            // Succès - nettoyer le retry count
            retryCount.removeValue(forKey: model)
        }
        
        // Nettoyer la tâche
        downloadTasks.removeValue(forKey: model)
    }
}
