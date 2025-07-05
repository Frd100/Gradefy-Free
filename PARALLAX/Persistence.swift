import Foundation
import CoreData
import CloudKit
import os.log

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    // MARK: - Core Data Container
    let container: NSPersistentCloudKitContainer
    
    // MARK: - CloudKit Status
    @Published var cloudKitStatus: CKAccountStatus = .couldNotDetermine
    @Published var isCloudKitReady: Bool = false
    @Published var lastSyncDate: Date?
    
    // MARK: - Advanced Cache System
    private let smartAverageCache = SmartAverageCache()
    private let syncDebouncer = CloudKitSyncDebouncer()
    private let cacheQueue = DispatchQueue(label: "com.gradefy.cache", qos: .userInitiated)
    
    // MARK: - Debouncing Configuration
    private var lastRemoteChangeTime = Date.distantPast
    private let remoteChangeDebounceInterval: TimeInterval = 5.0
    private var lastCacheClear = Date.distantPast
    private let cacheDebounceInterval: TimeInterval = 2.0
    
    // MARK: - Logging
    private let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "Persistence")
    
    // MARK: - Initialization
    init(inMemory: Bool = false) {
        logger.info("🚀 Initialisation de PersistenceController")
        
        container = NSPersistentCloudKitContainer(name: "PARALLAX")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
            logger.debug("💾 Mode en mémoire activé")
        }
        
        setupPersistentStore()
        loadPersistentStores()
        configureContext()
        setupCloudKitNotifications()
        setupAdvancedCaching() // ✅ NOUVEAU : Système de cache avancé
        
        // Vérification initiale du statut CloudKit
        Task {
            await checkCloudKitStatus()
        }
    }
    
    // MARK: - Store Configuration
    private func setupPersistentStore() {
        guard let description = container.persistentStoreDescriptions.first else {
            logger.error("❌ Impossible d'obtenir la description du store")
            return
        }
        
        // ✅ Configuration CloudKit simplifiée (correction du bug 134402)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.Coefficient.PARALLAX2"
        )
        
        // Options de synchronisation
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        logger.info("✅ Configuration du store CloudKit terminée")
    }
    
    private func loadPersistentStores() {
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                self?.logger.error("❌ Erreur de chargement du store: \(error.localizedDescription)")
                
                // Gestion des erreurs spécifiques CloudKit
                if error.domain == CKErrorDomain {
                    self?.handleCloudKitError(error)
                } else {
                    // Erreur critique - l'app ne peut pas continuer
                    fatalError("Erreur de chargement Core Data: \(error), \(error.userInfo)")
                }
            } else {
                self?.logger.info("✅ Store persistant chargé avec succès")
                self?.lastSyncDate = Date()
            }
        }
    }
    
    private func configureContext() {
        let context = container.viewContext
        
        // Configuration de la fusion automatique
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Configuration des notifications
        context.name = "MainContext"
        
        logger.info("✅ Contexte principal configuré")
    }
    
    // MARK: - Advanced Cache Management
    private func setupAdvancedCaching() {
        // Configuration du cache intelligent GradefyCacheManager
        let _ = GradefyCacheManager.shared // Force l'initialisation
        
        // Écouter les notifications de sync batch
        NotificationCenter.default.addObserver(
            forName: .batchSyncCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let objectIDs = notification.object as? Set<NSManagedObjectID> {
                self?.handleBatchSyncCompletion(objectIDs)
            }
        }
        
        logger.info("🚀 Système de cache avancé configuré")
    }
    
    func cacheAverage(forKey key: String, value: Double, dependencies: Set<String> = []) {
        smartAverageCache.cacheAverage(value, forKey: key, dependencies: dependencies)
        
        // Cache également dans le cache principal pour compatibilité
        GradefyCacheManager.shared.cacheAverage(value, forKey: key)
    }
    
    func getCachedAverage(forKey key: String) -> Double? {
        // Vérifier d'abord le cache intelligent
        if let smartValue = smartAverageCache.getCachedAverage(forKey: key) {
            return smartValue
        }
        
        // Fallback sur le cache principal
        return GradefyCacheManager.shared.getCachedAverage(forKey: key)
    }
    
    func clearCache() {
        smartAverageCache.clearCache()
        GradefyCacheManager.shared.clearAllCaches()
        logger.debug("🗑️ Tous les caches vidés")
    }
    
    // MARK: - Save Operations
    func save() {
        let context = container.viewContext
        
        guard context.hasChanges else {
            logger.debug("💾 Aucune modification à sauvegarder")
            return
        }
        
        do {
            try context.save()
            logger.info("✅ Sauvegarde réussie")
            
            // Invalidation intelligente du cache après sauvegarde
            smartInvalidateCache(after: context)
            
        } catch {
            let nsError = error as NSError
            logger.error("❌ Erreur de sauvegarde: \(nsError.localizedDescription)")
            
            // Gestion des conflits de merge
            if nsError.code == NSManagedObjectMergeError {
                handleMergeConflict(error: nsError)
            } else {
                fatalError("Erreur de sauvegarde: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func smartInvalidateCache(after context: NSManagedObjectContext) {
        // ✅ CORRECTION - Supprimer les casts redondants
        
        // Invalider les caches pour les objets insérés
        if !context.insertedObjects.isEmpty {
            invalidateCacheForObjects(context.insertedObjects)
        }
        
        // Invalider les caches pour les objets modifiés
        if !context.updatedObjects.isEmpty {
            invalidateCacheForObjects(context.updatedObjects)
        }
        
        // Invalider les caches pour les objets supprimés
        if !context.deletedObjects.isEmpty {
            invalidateCacheForObjects(context.deletedObjects)
        }
    }
    
    private func invalidateCacheForObjects(_ objects: Set<NSManagedObject>) {
        for object in objects {
            let objectIDString = object.objectID.uriRepresentation().absoluteString
            smartAverageCache.invalidateIfNeeded(changedObjectID: objectIDString)
        }
    }
    
    // MARK: - CloudKit Status Management
    func checkCloudKitStatus() async -> Bool {
        let container = CKContainer(identifier: "iCloud.com.Coefficient.PARALLAX2")
        
        do {
            let status = try await container.accountStatus()
            
            await MainActor.run {
                self.cloudKitStatus = status
                self.isCloudKitReady = (status == .available)
                
                switch status {
                case .available:
                    self.logger.info("✅ CloudKit disponible")
                case .noAccount:
                    self.logger.warning("⚠️ Aucun compte iCloud configuré")
                case .restricted:
                    self.logger.warning("⚠️ CloudKit restreint")
                case .couldNotDetermine:
                    self.logger.warning("⚠️ Statut CloudKit indéterminé")
                case .temporarilyUnavailable:
                    self.logger.warning("⚠️ CloudKit temporairement indisponible")
                @unknown default:
                    self.logger.error("❌ Statut CloudKit inconnu")
                }
            }
            
            return status == .available
            
        } catch {
            logger.error("❌ Erreur vérification CloudKit: \(error.localizedDescription)")
            
            await MainActor.run {
                self.isCloudKitReady = false
                self.cloudKitStatus = .couldNotDetermine
            }
            
            return false
        }
    }
    
    // MARK: - CloudKit Notifications
    private func setupCloudKitNotifications() {
        // Surveillance des changements de compte iCloud
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.info("🔄 Changement de compte iCloud détecté")
            Task {
                await self?.checkCloudKitStatus()
            }
        }
        
        // Surveillance des changements distants (avec debouncing intelligent optimisé)
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.logger.info("🔄 Changement distant détecté")
            self?.handleRemoteChange(notification)
        }
        
        logger.info("👂 Notifications CloudKit configurées")
    }
    
    // MARK: - Optimized Remote Change Handling
    private func handleRemoteChange(_ notification: Notification) {
        let now = Date()
        
        // Debouncing intelligent avec extraction des objets modifiés
        if now.timeIntervalSince(lastRemoteChangeTime) > remoteChangeDebounceInterval {
            logger.info("🔄 Changement distant détecté - traitement différé")
            
            // ✅ CORRECTION - Vérification en deux étapes
            if let userInfo = notification.userInfo {
                let objectIDs = extractObjectIDs(from: userInfo)
                if !objectIDs.isEmpty {
                    for objectID in objectIDs {
                        syncDebouncer.scheduleSync(for: objectID)
                    }
                } else {
                    logger.debug("📊 Aucun objet modifié détecté")
                }
            }
            
            lastRemoteChangeTime = now
            lastSyncDate = Date()
        } else {
            logger.debug("🔄 Changement distant ignoré (debounce actif)")
        }
    }
    
    private func extractObjectIDs(from userInfo: [AnyHashable: Any]) -> Set<NSManagedObjectID> {
        var objectIDs = Set<NSManagedObjectID>()
        
        // Extraire les IDs des objets modifiés selon les clés Core Data
        if let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
            objectIDs.formUnion(insertedObjects.map { $0.objectID })
        }
        
        if let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            objectIDs.formUnion(updatedObjects.map { $0.objectID })
        }
        
        if let deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> {
            objectIDs.formUnion(deletedObjects.map { $0.objectID })
        }
        
        logger.debug("📊 Extraction: \(objectIDs.count) objets modifiés")
        return objectIDs
    }
    
    private func handleBatchSyncCompletion(_ objectIDs: Set<NSManagedObjectID>) {
        logger.info("🔄 Traitement batch sync de \(objectIDs.count) objets")
        
        // Invalider les caches affectés de manière intelligente
        for objectID in objectIDs {
            let objectIDString = objectID.uriRepresentation().absoluteString
            smartAverageCache.invalidateIfNeeded(changedObjectID: objectIDString)
        }
        
        // Notifier l'UI des changements batch
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dataDidChange, object: objectIDs)
        }
    }
    
    // MARK: - Error Handling
    private func handleCloudKitError(_ error: NSError) {
        guard error.domain == CKErrorDomain else { return }
        
        switch CKError.Code(rawValue: error.code) {
        case .quotaExceeded:
            logger.error("❌ Quota iCloud dépassé")
            // Nettoyer les caches pour libérer de l'espace
            clearCache()
        case .networkFailure, .networkUnavailable:
            logger.warning("⚠️ Problème réseau CloudKit")
        case .serviceUnavailable:
            logger.warning("⚠️ Service CloudKit indisponible")
        case .requestRateLimited:
            logger.warning("⚠️ Limite de taux CloudKit atteinte")
        case .zoneNotFound:
            logger.error("❌ Zone CloudKit introuvable")
        default:
            logger.error("❌ Erreur CloudKit inconnue: \(error.localizedDescription)")
        }
    }
    
    private func handleMergeConflict(error: NSError) {
        logger.warning("⚠️ Conflit de fusion détecté - résolution automatique")
        
        // Recharger les données depuis le store persistant
        container.viewContext.rollback()
        
        // Vider les caches car les données ont changé
        clearCache()
        
        // Notifier l'UI du conflit résolu
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .mergeConflictResolved, object: error)
        }
    }
    
    // MARK: - Utility Methods
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) -> T) async -> T {
        return await withCheckedContinuation { continuation in
            container.performBackgroundTask { context in
                let result = block(context)
                continuation.resume(returning: result)
            }
        }
    }
    
    func resetPersistentStore() async {
        logger.warning("🗑️ Réinitialisation du store persistant")
        
        let coordinator = container.persistentStoreCoordinator
        
        for store in coordinator.persistentStores {
            do {
                try coordinator.destroyPersistentStore(
                    at: store.url!,
                    ofType: store.type,
                    options: nil
                )
                logger.info("✅ Store détruit: \(store.url?.lastPathComponent ?? "inconnu")")
            } catch {
                logger.error("❌ Erreur destruction store: \(error.localizedDescription)")
            }
        }
        
        // Recharger les stores
        loadPersistentStores()
        clearCache()
        
        await MainActor.run {
            NotificationCenter.default.post(name: .storeDidReset, object: nil)
        }
    }
    
    // MARK: - Cache Performance Monitoring
    func getCachePerformanceReport() -> String {
        let monitor = GradefyCacheManager.shared
        return """
        📊 Rapport Performance Cache Gradefy:
        - Cache intelligent SmartAverageCache actif
        - Debouncing CloudKit: \(remoteChangeDebounceInterval)s
        - Dernière sync: \(lastSyncDate?.formatted() ?? "Jamais")
        - Statut CloudKit: \(cloudKitStatus.rawValue)
        """
    }
}

// MARK: - Notification Names
extension NSNotification.Name {
    static let dataDidChange = NSNotification.Name("dataDidChange")
    static let mergeConflictResolved = NSNotification.Name("mergeConflictResolved")
    static let storeDidReset = NSNotification.Name("storeDidReset")
    static let systemChanged = NSNotification.Name("systemChanged")
    
    // ✅ NOUVELLES NOTIFICATIONS pour le cache avancé
    static let batchSyncCompleted = NSNotification.Name("batchSyncCompleted")
    static let memoryPressure = NSNotification.Name("memoryPressure")
    static let cacheOptimizationNeeded = NSNotification.Name("cacheOptimizationNeeded")
}

// MARK: - Preview Support
extension PersistenceController {
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Ajoutez ici des données de test pour les previews
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Erreur preview: \(nsError), \(nsError.userInfo)")
        }
        
        return result
    }()
}
