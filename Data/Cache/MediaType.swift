//
//  MediaCacheManager.swift
//  PARALLAX
//
//  Created by Farid on 7/31/25.
//

import Foundation
import UIKit
import AVFoundation
import Combine

// MARK: - Media Types & Configuration

enum MediaType {
    case image(UIImage)
    case audio(Data)
    case thumbnail(UIImage)
    case compressed(Data)
}

enum MediaCacheExpiration {
    case images(days: Int = 30)
    case audio(days: Int = 7)
    case thumbnails(days: Int = 60)
    case compressed(days: Int = 14)
    
    var timeInterval: TimeInterval {
        switch self {
        case .images(let days): return TimeInterval(days * 24 * 60 * 60)
        case .audio(let days): return TimeInterval(days * 24 * 60 * 60)
        case .thumbnails(let days): return TimeInterval(days * 24 * 60 * 60)
        case .compressed(let days): return TimeInterval(days * 24 * 60 * 60)
        }
    }
}

struct MediaCacheConfiguration {
    let imageMemoryLimit: Int
    let imageCostLimit: Int
    let audioMemoryLimit: Int
    let audioCostLimit: Int
    let thumbnailMemoryLimit: Int
    let thumbnailCostLimit: Int
    let diskCacheLimit: Int
    
    static func configuration(for deviceMemory: Int) -> MediaCacheConfiguration {
        switch deviceMemory {
        case 0...2: // iPhone SE, anciens modèles
            return MediaCacheConfiguration(
                imageMemoryLimit: 15, // ↓ Optimisé pour 300-2000 flashcards
                imageCostLimit: 30 * 1024 * 1024, // ↓ 30MB (60 médias × 500KB)
                audioMemoryLimit: 5, // ↓ Optimisé pour usage limité
                audioCostLimit: 15 * 1024 * 1024, // ↓ 15MB (30 audios × 500KB)
                thumbnailMemoryLimit: 30, // ↓ Optimisé pour navigation
                thumbnailCostLimit: 10 * 1024 * 1024, // ↓ 10MB
                diskCacheLimit: 150 * 1024 * 1024 // ↓ 150MB (marge sécurité)
            )
        case 3...4: // iPhone standard
            return MediaCacheConfiguration(
                imageMemoryLimit: 50,
                imageCostLimit: 100 * 1024 * 1024, // 100MB
                audioMemoryLimit: 20,
                audioCostLimit: 50 * 1024 * 1024, // 50MB
                thumbnailMemoryLimit: 100,
                thumbnailCostLimit: 40 * 1024 * 1024, // 40MB
                diskCacheLimit: 500 * 1024 * 1024 // 500MB
            )
        case 5...8: // iPhone Pro
            return MediaCacheConfiguration(
                imageMemoryLimit: 100,
                imageCostLimit: 200 * 1024 * 1024, // 200MB
                audioMemoryLimit: 40,
                audioCostLimit: 100 * 1024 * 1024, // 100MB
                thumbnailMemoryLimit: 200,
                thumbnailCostLimit: 80 * 1024 * 1024, // 80MB
                diskCacheLimit: 1024 * 1024 * 1024 // 1GB
            )
        default: // iPad Pro et plus
            return MediaCacheConfiguration(
                imageMemoryLimit: 200,
                imageCostLimit: 400 * 1024 * 1024, // 400MB
                audioMemoryLimit: 80,
                audioCostLimit: 200 * 1024 * 1024, // 200MB
                thumbnailMemoryLimit: 400,
                thumbnailCostLimit: 160 * 1024 * 1024, // 160MB
                diskCacheLimit: 2048 * 1024 * 1024 // 2GB
            )
        }
    }
}

// MARK: - Media Disk Cache

// ✅ CORRECTION 1 : Enlever @MainActor de MediaDiskCache
final class MediaDiskCache: Sendable {  // Option 1 : final class
    private let cacheDirectory: URL
    private let maxDiskSize: Int
    private let queue = DispatchQueue(label: "com.parallax.media.disk.cache", qos: .utility)
    
    // ✅ CORRECTION 2 : fileManager local au lieu de propriété
    private var fileManager: FileManager { FileManager.default }
    
    init(cacheDirectory: URL, maxSize: Int) {
        self.cacheDirectory = cacheDirectory
        self.maxDiskSize = maxSize
        createCacheDirectoryIfNeeded()
    }
    
    private func createCacheDirectoryIfNeeded() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: cacheDirectory.path) else { return }
        
        do {
            try fm.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            print("✅ [MEDIA_CACHE] Dossier cache créé: \(cacheDirectory.path)")
        } catch {
            print("❌ [MEDIA_CACHE] Erreur création dossier: \(error)")
        }
    }
    
    func store(_ data: Data, forKey key: String, expiration: MediaCacheExpiration) {
        // ✅ CORRECTION 2 : Supprimer maxDiskSize de la capture car non utilisé
        queue.async { [cacheDirectory] in
            // ✅ CORRECTION 3 : Supprimer 'let fm' car non utilisé, utiliser directement FileManager.default
            let fileURL = cacheDirectory.appendingPathComponent(key)
            let metadataURL = cacheDirectory.appendingPathComponent("\(key).meta")
            
            do {
                // Stocker les données
                try data.write(to: fileURL, options: .atomic)
                
                // Stocker les métadonnées d'expiration
                let metadata = ["expiration": Date().addingTimeInterval(expiration.timeInterval)]
                let metadataData = try PropertyListSerialization.data(fromPropertyList: metadata, format: .binary, options: 0)
                try metadataData.write(to: metadataURL, options: .atomic)
                
                print("💾 [MEDIA_CACHE] Stocké sur disque: \(key) (\(Self.formatBytes(data.count)))")
                
                // Nettoyage si nécessaire
                Task {
                    await self.cleanupIfNeeded()
                }
            } catch {
                print("❌ [MEDIA_CACHE] Erreur stockage disque: \(error)")
            }
        }
    }
    
    func retrieve(forKey key: String) -> Data? {
        let fm = FileManager.default
        let fileURL = cacheDirectory.appendingPathComponent(key)
        let metadataURL = cacheDirectory.appendingPathComponent("\(key).meta")
        
        guard fm.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // Vérifier l'expiration
        if let metadataData = try? Data(contentsOf: metadataURL),
           let metadata = try? PropertyListSerialization.propertyList(from: metadataData, options: [], format: nil) as? [String: Date],
           let expirationDate = metadata["expiration"],
           Date() > expirationDate {
            
            // Fichier expiré, le supprimer
            try? fm.removeItem(at: fileURL)
            try? fm.removeItem(at: metadataURL)
            print("🗑️ [MEDIA_CACHE] Fichier expiré supprimé: \(key)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            print("✅ [MEDIA_CACHE] Récupéré du disque: \(key) (\(Self.formatBytes(data.count)))")
            return data
        } catch {
            print("❌ [MEDIA_CACHE] Erreur lecture disque: \(error)")
            return nil
        }
    }
    
    func remove(forKey key: String) {
        queue.async { [cacheDirectory] in
            let fm = FileManager.default
            let fileURL = cacheDirectory.appendingPathComponent(key)
            let metadataURL = cacheDirectory.appendingPathComponent("\(key).meta")
            
            try? fm.removeItem(at: fileURL)
            try? fm.removeItem(at: metadataURL)
        }
    }
    
    private func cleanupIfNeeded() async {
        let currentSize = await getCurrentDiskSize()
        
        if currentSize > maxDiskSize {
            await performCleanup(targetSize: Int(Double(maxDiskSize) * 0.7)) // Nettoyer jusqu'à 70% (plus agressif iPhone SE)
        }
    }
    
    private func getCurrentDiskSize() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async { [cacheDirectory] in
                let fm = FileManager.default
                
                do {
                    let files = try fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
                    let totalSize = files.compactMap { url -> Int? in
                        try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
                    }.reduce(0, +)
                    
                    continuation.resume(returning: totalSize)
                } catch {
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    private func performCleanup(targetSize: Int) async {
        await withCheckedContinuation { continuation in
            queue.async { [cacheDirectory] in
                let fm = FileManager.default
                
                do {
                    let files = try fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
                    
                    // Trier par date de modification (LRU)
                    let sortedFiles = files.compactMap { url -> (URL, Int, Date)? in
                        let resources = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                        guard let size = resources?.fileSize,
                              let date = resources?.contentModificationDate else { return nil }
                        return (url, size, date)
                    }.sorted { $0.2 < $1.2 }
                    
                    var currentSize = sortedFiles.map { $0.1 }.reduce(0, +)
                    var deletedCount = 0
                    
                    for (fileURL, fileSize, _) in sortedFiles {
                        if currentSize <= targetSize { break }
                        
                        try? fm.removeItem(at: fileURL)
                        
                        // Supprimer aussi les métadonnées si elles existent
                        let metadataURL = fileURL.appendingPathExtension("meta")
                        try? fm.removeItem(at: metadataURL)
                        
                        currentSize -= fileSize
                        deletedCount += 1
                    }
                    
                    if deletedCount > 0 {
                        print("🧹 [MEDIA_CACHE] Nettoyage: \(deletedCount) fichiers supprimés")
                    }
                } catch {
                    print("❌ [MEDIA_CACHE] Erreur nettoyage: \(error)")
                }
                
                continuation.resume()
            }
        }
    }
    
    // ✅ CORRECTION 3 : Fonction statique pour éviter l'isolation MainActor
    static func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Media Cache Manager

@MainActor
class MediaCacheManager: ObservableObject {
    static let shared = MediaCacheManager()
    
    // Caches mémoire spécialisés
    private let imageMemoryCache = NSCache<NSString, UIImage>()
    private let audioMemoryCache = NSCache<NSString, NSData>()
    private let thumbnailMemoryCache = NSCache<NSString, UIImage>()
    
    // Cache disque
    private let diskCache: MediaDiskCache
    
    // Configuration
    private let configuration: MediaCacheConfiguration
    
    // Préchargement
    private var preloadTasks: [String: Task<Void, Never>] = [:]
    private var invalidationQueue = DispatchQueue(label: "com.parallax.media.invalidation", qos: .utility)
    private var dependencyGraph: [String: Set<String>] = [:]
    
    // Monitoring
    @Published var cacheStats = MediaCacheStats()
    
    private init() {
        // Configuration adaptative selon le device
        let deviceMemory = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024) // GB
        self.configuration = MediaCacheConfiguration.configuration(for: Int(deviceMemory))
        
        // Setup disk cache
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GradefyMediaCache", isDirectory: true)
        self.diskCache = MediaDiskCache(cacheDirectory: cacheDirectory, maxSize: configuration.diskCacheLimit)
        
        setupMemoryCaches()
        setupMemoryWarningObserver()
        
        print("🚀 [MEDIA_CACHE] Initialisation - Images: \(configuration.imageMemoryLimit), Audio: \(configuration.audioMemoryLimit), Thumbnails: \(configuration.thumbnailMemoryLimit)")
    }
    
    private func setupMemoryCaches() {
        // Cache images
        imageMemoryCache.countLimit = configuration.imageMemoryLimit
        imageMemoryCache.totalCostLimit = configuration.imageCostLimit
        imageMemoryCache.name = "GradefyImageCache"
        
        // Cache audio
        audioMemoryCache.countLimit = configuration.audioMemoryLimit
        audioMemoryCache.totalCostLimit = configuration.audioCostLimit
        audioMemoryCache.name = "GradefyAudioCache"
        
        // Cache thumbnails
        thumbnailMemoryCache.countLimit = configuration.thumbnailMemoryLimit
        thumbnailMemoryCache.totalCostLimit = configuration.thumbnailCostLimit
        thumbnailMemoryCache.name = "GradefyThumbnailCache"
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // ✅ CORRECTION 4 : Task pour gérer l'async
            Task { @MainActor in
                await self?.handleMemoryWarning()
            }
        }
    }
    
    // ✅ CORRECTION 5 : Méthode async
    private func handleMemoryWarning() async {
        print("⚠️ [MEDIA_CACHE] Memory warning - clearing caches")
        imageMemoryCache.removeAllObjects()
        audioMemoryCache.removeAllObjects()
        thumbnailMemoryCache.removeAllObjects()
        
        // Annuler les tâches de préchargement
        preloadTasks.values.forEach { $0.cancel() }
        preloadTasks.removeAll()
        
        cacheStats.memoryWarnings += 1
    }
}

// MARK: - Image Management

extension MediaCacheManager {
    
    func storeImage(_ image: UIImage, forKey key: String, quality: CGFloat = 0.7) { // ↓ Qualité par défaut réduite
        // Compression adaptative selon la taille
        let imageSize = image.size.width * image.size.height
        let adaptiveQuality = imageSize > 500_000 ? 0.5 : quality // ↓ Seuil réduit pour iPhone SE
        
        guard let compressedData = image.jpegData(compressionQuality: adaptiveQuality) else {
            print("❌ [MEDIA_CACHE] Impossible de compresser l'image: \(key)")
            return
        }
        
        let imageCost = compressedData.count
        
        // Stockage mémoire pour les images moyennes
        if compressedData.count < 1_500_000 { // < 1.5MB (optimisé iPhone SE)
            imageMemoryCache.setObject(image, forKey: key as NSString, cost: imageCost)
            print("💾 [MEDIA_CACHE] Image stockée en mémoire: \(key) (\(formatBytes(imageCost)))")
            cacheStats.memoryHits += 1
        }
        
        // Stockage disque pour toutes les images
        diskCache.store(compressedData, forKey: "img_\(key)", expiration: .images())
        cacheStats.diskWrites += 1
    }
    
    func retrieveImage(forKey key: String) -> UIImage? {
        // 1. Chercher en mémoire
        if let cachedImage = imageMemoryCache.object(forKey: key as NSString) {
            print("✅ [MEDIA_CACHE] Image trouvée en mémoire: \(key)")
            cacheStats.memoryHits += 1
            return cachedImage
        }
        
        // 2. Chercher sur disque
        if let diskData = diskCache.retrieve(forKey: "img_\(key)"),
           let diskImage = UIImage(data: diskData) {
            
            // Remettre en mémoire si pas trop grande
            if diskData.count < 1_500_000 { // Optimisé iPhone SE
                imageMemoryCache.setObject(diskImage, forKey: key as NSString, cost: diskData.count)
            }
            
            print("✅ [MEDIA_CACHE] Image trouvée sur disque: \(key)")
            cacheStats.diskHits += 1
            return diskImage
        }
        
        cacheStats.misses += 1
        return nil
    }
    
    func generateThumbnail(from image: UIImage, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage? {
        let thumbnailKey = "thumb_\(image.hashValue)_\(Int(size.width))x\(Int(size.height))"
        
        // Vérifier si le thumbnail existe déjà
        if let cachedThumbnail = thumbnailMemoryCache.object(forKey: thumbnailKey as NSString) {
            return cachedThumbnail
        }
        
        // Générer le thumbnail
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        
        // Stocker le thumbnail
        if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
            thumbnailMemoryCache.setObject(thumbnail, forKey: thumbnailKey as NSString, cost: thumbnailData.count)
            diskCache.store(thumbnailData, forKey: "thumb_\(thumbnailKey)", expiration: .thumbnails())
        }
        
        return thumbnail
    }
}

// MARK: - Audio Management

extension MediaCacheManager {
    
    func storeAudio(_ audioData: Data, forKey key: String) {
        let audioCost = audioData.count
        
        // Audio en mémoire seulement si < 2MB (optimisé iPhone SE)
        if audioCost < 2_000_000 {
            audioMemoryCache.setObject(audioData as NSData, forKey: key as NSString, cost: audioCost)
            print("💾 [MEDIA_CACHE] Audio stocké en mémoire: \(key) (\(formatBytes(audioCost)))")
            cacheStats.memoryHits += 1
        }
        
        // Toujours stocker sur disque
        diskCache.store(audioData, forKey: "audio_\(key)", expiration: .audio())
        cacheStats.diskWrites += 1
    }
    
    func retrieveAudio(forKey key: String) -> Data? {
        // 1. Chercher en mémoire
        if let cachedAudio = audioMemoryCache.object(forKey: key as NSString) {
            print("✅ [MEDIA_CACHE] Audio trouvé en mémoire: \(key)")
            cacheStats.memoryHits += 1
            return cachedAudio as Data
        }
        
        // 2. Chercher sur disque
        if let diskData = diskCache.retrieve(forKey: "audio_\(key)") {
            // Remettre en mémoire si pas trop gros
            if diskData.count < 2_000_000 { // Optimisé iPhone SE
                audioMemoryCache.setObject(diskData as NSData, forKey: key as NSString, cost: diskData.count)
            }
            
            print("✅ [MEDIA_CACHE] Audio trouvé sur disque: \(key)")
            cacheStats.diskHits += 1
            return diskData
        }
        
        cacheStats.misses += 1
        return nil
    }
}

// MARK: - Preloading

extension MediaCacheManager {
    
    func preloadMedia(keys: [String], priority: TaskPriority = .utility) {
        for key in keys {
            guard preloadTasks[key] == nil else { continue }
            
            preloadTasks[key] = Task(priority: priority) {
                await preloadSingleMedia(key: key)
            }
        }
    }
    
    func preloadMediaForDeck(_ deck: FlashcardDeck, startIndex: Int = 0) {
        guard let flashcards = deck.flashcards as? Set<Flashcard> else { return }
        let flashcardArray = Array(flashcards)
        let preloadRange = startIndex..<min(startIndex + 10, flashcardArray.count)
        
        for index in preloadRange {
            let flashcard = flashcardArray[index]
            preloadFlashcardMedia(flashcard)
        }
    }
    
    private func preloadFlashcardMedia(_ flashcard: Flashcard) {
        // Précharger les images
        if flashcard.questionContentType == .image, let fileName = flashcard.questionImageFileName {
            preloadImage(fileName: fileName, data: flashcard.questionImageData)
        }
        
        if flashcard.answerContentType == .image, let fileName = flashcard.answerImageFileName {
            preloadImage(fileName: fileName, data: flashcard.answerImageData)
        }
        
        // Précharger les audios
        if flashcard.questionContentType == .audio, let fileName = flashcard.questionAudioFileName {
            preloadAudio(fileName: fileName)
        }
        
        if flashcard.answerContentType == .audio, let fileName = flashcard.answerAudioFileName {
            preloadAudio(fileName: fileName)
        }
    }
    
    private func preloadImage(fileName: String, data: Data?) {
        let key = generateImageCacheKey(fileName: fileName, size: "thumbnail")
        preloadTasks[key] = Task {
            // Précharger l'image en arrière-plan
            if let data = data, let image = UIImage(data: data) {
                await MainActor.run {
                    self.storeImage(image, forKey: key)
                }
            }
        }
    }
    
    private func generateImageCacheKey(fileName: String, size: String) -> String {
        // Clé incluant la taille pour éviter la re-compression
        return "img_\(fileName)_\(size)"
    }
    
    private func preloadAudio(fileName: String) {
        let key = generateAudioCacheKey(fileName: fileName, quality: "standard")
        preloadTasks[key] = Task {
            // Précharger l'audio en arrière-plan
            let audioURL = MediaStorageManager.shared.getAudioURL(fileName: fileName)
            if let audioData = try? Data(contentsOf: audioURL) {
                await MainActor.run {
                    self.storeAudio(audioData, forKey: key)
                }
            }
        }
    }
    
    private func generateAudioCacheKey(fileName: String, quality: String) -> String {
        // Clé incluant la qualité pour éviter la re-compression
        return "audio_\(fileName)_\(quality)"
    }
    
    private func preloadSingleMedia(key: String) async {
        // Vérifier si déjà en cache
        if retrieveImage(forKey: key) != nil || retrieveAudio(forKey: key) != nil {
            return
        }
        
        // Simuler le préchargement depuis MediaStorageManager
        // Dans votre implémentation, vous appelleriez MediaStorageManager.shared.loadImage()
        print("🔄 [MEDIA_CACHE] Préchargement: \(key)")
        
        // Attendre un peu pour éviter la surcharge
        try? await Task.sleep(for: .milliseconds(100))
    }
    
    func cancelPreloading(for key: String) {
        preloadTasks[key]?.cancel()
        preloadTasks.removeValue(forKey: key)
    }
    
    func cancelAllPreloading() {
        preloadTasks.values.forEach { $0.cancel() }
        preloadTasks.removeAll()
    }
}

// MARK: - Cache Invalidation

extension MediaCacheManager {
    
    func registerDependency(key: String, dependsOn: String) {
        invalidationQueue.async { [weak self] in
            Task { @MainActor in
                self?.dependencyGraph[dependsOn, default: []].insert(key)
            }
        }
    }
    
    func invalidateCascade(startingFrom key: String) {
        invalidationQueue.async { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                
                var keysToInvalidate: Set<String> = [key]
                var processedKeys: Set<String> = []
                
                while !keysToInvalidate.isEmpty {
                    let currentKey = keysToInvalidate.removeFirst()
                    processedKeys.insert(currentKey)
                    
                    // Invalider le cache pour cette clé
                    self.invalidateCache(for: currentKey)
                    
                    // Ajouter les dépendances à invalider
                    if let dependencies = self.dependencyGraph[currentKey] {
                        for dependency in dependencies {
                            if !processedKeys.contains(dependency) {
                                keysToInvalidate.insert(dependency)
                            }
                        }
                    }
                }
                
                print("🗑️ [MEDIA_CACHE] Invalidation en cascade terminée pour: \(key)")
            }
        }
    }
    
    private func invalidateCache(for key: String) {
        // Invalider le cache mémoire
        imageMemoryCache.removeObject(forKey: key as NSString)
        audioMemoryCache.removeObject(forKey: key as NSString)
        thumbnailMemoryCache.removeObject(forKey: key as NSString)
        
        // Annuler le préchargement
        preloadTasks[key]?.cancel()
        preloadTasks.removeValue(forKey: key)
        
        // Invalider le cache disque
        diskCache.remove(forKey: key)
        
        print("🗑️ [MEDIA_CACHE] Cache invalidé pour: \(key)")
    }
    
    func invalidateAllCache() {
        imageMemoryCache.removeAllObjects()
        audioMemoryCache.removeAllObjects()
        thumbnailMemoryCache.removeAllObjects()
        
        preloadTasks.values.forEach { $0.cancel() }
        preloadTasks.removeAll()
        
        dependencyGraph.removeAll()
        
        print("🗑️ [MEDIA_CACHE] Tout le cache invalidé")
    }
}

// MARK: - Cache Management

extension MediaCacheManager {
    
    func clearMemoryCache() {
        imageMemoryCache.removeAllObjects()
        audioMemoryCache.removeAllObjects()
        thumbnailMemoryCache.removeAllObjects()
        
        print("🧹 [MEDIA_CACHE] Cache mémoire vidé")
    }
    
    func clearDiskCache() {
        // Implémenter le nettoyage du cache disque
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GradefyMediaCache", isDirectory: true)
        
        do {
            try FileManager.default.removeItem(at: cacheDirectory)
            print("🧹 [MEDIA_CACHE] Cache disque vidé")
        } catch {
            print("❌ [MEDIA_CACHE] Erreur nettoyage disque: \(error)")
        }
    }
    
    func getCacheSize() -> (memory: String, disk: String) {
        let memorySize = imageMemoryCache.totalCostLimit + audioMemoryCache.totalCostLimit + thumbnailMemoryCache.totalCostLimit
        
        // Calculer la taille disque (approximation)
        let diskSize = configuration.diskCacheLimit
        
        return (
            memory: formatBytes(memorySize),
            disk: formatBytes(diskSize)
        )
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Cache Statistics

struct MediaCacheStats {
    var memoryHits: Int = 0
    var diskHits: Int = 0
    var misses: Int = 0
    var diskWrites: Int = 0
    var memoryWarnings: Int = 0
    
    var hitRatio: Double {
        let totalRequests = memoryHits + diskHits + misses
        guard totalRequests > 0 else { return 0.0 }
        return Double(memoryHits + diskHits) / Double(totalRequests)
    }
}

// MARK: - Integration Extensions

extension MediaCacheManager {
    
    /// Intégration avec MediaStorageManager
    func cacheFromMediaStorage(fileName: String, data: Data?) -> UIImage? {
        if let image = retrieveImage(forKey: fileName) {
            return image
        }
        
        // Charger depuis MediaStorageManager si pas en cache
        if let cachedImage = MediaStorageManager.shared.loadImage(fileName: fileName, data: data) {
            storeImage(cachedImage, forKey: fileName)
            return cachedImage
        }
        
        return nil
    }
    
    /// Préchargement intelligent pour les flashcards
    func preloadFlashcardMedia(currentIndex: Int, flashcards: [Any], preloadDistance: Int = 3) {
        let startIndex = max(0, currentIndex - preloadDistance)
        let endIndex = min(flashcards.count - 1, currentIndex + preloadDistance)
        
        // ✅ CORRECTION 6 : Utiliser 'let' au lieu de 'var'
        let keysToPreload: [String] = []
        
        // ✅ CORRECTION 7 : Utiliser '_' pour la variable non utilisée
        for _ in startIndex...endIndex {
            // Dans votre implémentation, extraire les noms de fichiers des flashcards
            // keysToPreload.append(flashcards[index].questionImageFileName)
            // keysToPreload.append(flashcards[index].answerImageFileName)
        }
        
        preloadMedia(keys: keysToPreload.compactMap { $0 })
    }
}
