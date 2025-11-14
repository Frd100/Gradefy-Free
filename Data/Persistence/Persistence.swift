import Foundation
import CoreData
import os.log

@MainActor
class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    // MARK: - Core Data Container
    let container: NSPersistentContainer
    
    // MARK: - Local Status
    @Published var isReady = false
    @Published var lastSaveDate: Date?
    
    // MARK: - Advanced Cache System
    private let smartAverageCache = SmartAverageCache.shared
    private let cacheQueue = DispatchQueue(label: "com.gradefy.cache", qos: .userInitiated)
    
    // MARK: - Debouncing Configuration
    private var lastChangeTime = Date.distantPast
    private let changeDebounceInterval: TimeInterval = 2.0
    private var lastCacheClear = Date.distantPast
    private let cacheDebounceInterval: TimeInterval = 2.0
    
    // MARK: - Logging
    private let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "Persistence")
    
    // MARK: - Backup System
    private let backupQueue = DispatchQueue(label: "com.gradefy.backup", qos: .utility)
    
    // MARK: - Initialization
    init(inMemory: Bool = false) {
        print("🚀 [PERSISTENCE] === INITIALISATION DÉBUT ===")
        print("🚀 [PERSISTENCE] Mode mémoire: \(inMemory)")
        logger.info("🚀 Initialisation de PersistenceController")
        
        container = NSPersistentContainer(name: "PARALLAX")
        print("✅ [PERSISTENCE] Container PARALLAX créé")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
            print("💾 [PERSISTENCE] Mode en mémoire configuré (/dev/null)")
            logger.debug("💾 Mode en mémoire activé")
        }
        
        print("⚙️ [PERSISTENCE] Configuration en cours...")
        setupPersistentStore()
        loadPersistentStores()
        configureContext()
        setupLocalNotifications()
        Task { @MainActor in
            setupAdvancedCaching()
        }
        
        isReady = true
        print("🚀 [PERSISTENCE] === INITIALISATION TERMINÉE ===")
        print("✅ [PERSISTENCE] PersistenceController prêt")
    }
    
    // MARK: - Store Configuration
    private func setupPersistentStore() {
        print("⚙️ [PERSISTENCE] === SETUP STORE DÉBUT ===")
        
        guard let description = container.persistentStoreDescriptions.first else {
            print("❌ [PERSISTENCE] Impossible d'obtenir la description du store")
            logger.error("❌ Impossible d'obtenir la description du store")
            return
        }
        
        print("⚙️ [PERSISTENCE] Description store obtenue")
        print("⚙️ [PERSISTENCE] URL: \(description.url?.path ?? "nil")")
        print("⚙️ [PERSISTENCE] Type: \(description.type)")
        
        // Configuration Core Data locale uniquement
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        print("✅ [PERSISTENCE] Persistent History Tracking activé")
        
        // ✅ MIGRATION AUTOMATIQUE - ESSENTIEL pour le versioning
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        print("✅ [PERSISTENCE] Migration automatique activée")
        
        logger.info("✅ Configuration du store local terminée")
        print("✅ [PERSISTENCE] === SETUP STORE TERMINÉ ===")
    }
    
    // MARK: - Backup Functions
    func createBackup() async {
        await withCheckedContinuation { continuation in
            backupQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                do {
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let backupPath = documentsPath.appendingPathComponent("Gradefy_Backup_\(Date().timeIntervalSince1970).sqlite")
                    
                    // Créer une copie du store
                    if let storeURL = self.container.persistentStoreDescriptions.first?.url {
                        try FileManager.default.copyItem(at: storeURL, to: backupPath)
                        print("💾 [BACKUP] Sauvegarde créée: \(backupPath.path)")
                        self.logger.info("💾 Backup créé avec succès")
                    }
                } catch {
                    print("❌ [BACKUP] Erreur création backup: \(error)")
                    self.logger.error("❌ Erreur backup: \(error.localizedDescription)")
                }
                
                continuation.resume()
            }
        }
    }
    
    private func loadPersistentStores() {
        print("📂 [PERSISTENCE] === CHARGEMENT STORES DÉBUT ===")
        
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                print("❌ [PERSISTENCE] Erreur chargement store:")
                print("❌ [PERSISTENCE]   - Code: \(error.code)")
                print("❌ [PERSISTENCE]   - Description: \(error.localizedDescription)")
                print("❌ [PERSISTENCE]   - UserInfo: \(error.userInfo)")
                self?.logger.error("❌ Erreur de chargement du store: \(error.localizedDescription)")
                fatalError("Erreur de chargement Core Data: \(error), \(error.userInfo)")
            } else {
                print("✅ [PERSISTENCE] Store chargé avec succès:")
                print("✅ [PERSISTENCE]   - URL: \(storeDescription.url?.path ?? "nil")")
                print("✅ [PERSISTENCE]   - Type: \(storeDescription.type)")
                print("✅ [PERSISTENCE]   - Options: \(storeDescription.options)")
                self?.logger.info("✅ Store persistant local chargé avec succès")
                self?.lastSaveDate = Date()
                print("📅 [PERSISTENCE] lastSaveDate initialisée: \(Date())")
            }
        }
        
        print("✅ [PERSISTENCE] === CHARGEMENT STORES TERMINÉ ===")
    }
    
    private func configureContext() {
        print("⚙️ [PERSISTENCE] === CONFIGURATION CONTEXT DÉBUT ===")
        
        let context = container.viewContext
        print("⚙️ [PERSISTENCE] ViewContext obtenu")
        
        // Configuration de la fusion automatique
        context.automaticallyMergesChangesFromParent = true
        print("✅ [PERSISTENCE] AutomaticMerge activé")
        
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        print("✅ [PERSISTENCE] MergePolicy configuré: ObjectTrump")
        
        // Configuration des notifications
        context.name = "MainContext"
        print("✅ [PERSISTENCE] Context nommé: MainContext")
        
        logger.info("✅ Contexte principal configuré")
        print("✅ [PERSISTENCE] === CONFIGURATION CONTEXT TERMINÉ ===")
    }
    
    // MARK: - Advanced Cache Management
    @MainActor
    private func setupAdvancedCaching() {
        print("🚀 [PERSISTENCE] === SETUP CACHE AVANCÉ DÉBUT ===")
        
        // Configuration du cache intelligent GradefyCacheManager
        print("🚀 [PERSISTENCE] Initialisation GradefyCacheManager...")
        Task { @MainActor in
            let _ = GradefyCacheManager.shared // Force l'initialisation
        }
        print("✅ [PERSISTENCE] GradefyCacheManager initialisé")
        
        // Écouter les notifications de batch local
        print("👂 [PERSISTENCE] Configuration observer batchChangeCompleted...")
        NotificationCenter.default.addObserver(
            forName: .batchChangeCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("📢 [PERSISTENCE] Notification batchChangeCompleted reçue")
            if let objectIDs = notification.object as? Set<NSManagedObjectID> {
                print("📢 [PERSISTENCE] ObjectIDs dans notification: \(objectIDs.count)")
                Task { @MainActor in
                    self?.handleBatchChangeCompletion(objectIDs)
                }
            } else {
                print("⚠️ [PERSISTENCE] Notification sans objectIDs valides")
            }
        }
        
        logger.info("🚀 Système de cache avancé configuré")
        print("✅ [PERSISTENCE] === SETUP CACHE AVANCÉ TERMINÉ ===")
    }
    
    func cacheAverage(forKey key: String, value: Double, dependencies: Set<String> = []) {
        print("💾 [PERSISTENCE] CACHE_AVERAGE_REQUEST: '\(key)' = \(value)")
        print("💾 [PERSISTENCE] Dependencies: \(dependencies.count) items")
        
        smartAverageCache.cacheAverage(value, forKey: key, dependencies: dependencies)
        print("✅ [PERSISTENCE] SmartAverageCache updated")
        
        // Cache également dans le cache principal pour compatibilité
        Task { @MainActor in
            GradefyCacheManager.shared.cacheAverage(value, forKey: key)
        }
        print("✅ [PERSISTENCE] GradefyCacheManager updated")
        
        print("✅ [PERSISTENCE] CACHE_AVERAGE_DONE: '\(key)'")
    }
    
    func getCachedAverage(forKey key: String) async -> Double? {
        print("🔍 [PERSISTENCE] GET_CACHED_AVERAGE: '\(key)'")
        
        // Vérifier d'abord le cache intelligent
        if let smartValue = smartAverageCache.getCachedAverage(forKey: key) {
            print("🟢 [PERSISTENCE] SmartCache HIT: '\(key)' = \(smartValue)")
            return smartValue
        }
        
        print("🔍 [PERSISTENCE] SmartCache MISS, trying GradefyCache...")
        
        // Fallback sur le cache principal
        let fallbackValue = await Task { @MainActor in
            GradefyCacheManager.shared.getCachedAverage(forKey: key)
        }.value
        if let value = fallbackValue {
            print("🟡 [PERSISTENCE] GradefyCache HIT: '\(key)' = \(value)")
        } else {
            print("🔴 [PERSISTENCE] Complete MISS: '\(key)'")
        }
        
        return fallbackValue
    }
    
    func clearCache() {
        print("🧹 [PERSISTENCE] === CLEAR_CACHE DÉBUT ===")
        
        smartAverageCache.clearCache()
        print("✅ [PERSISTENCE] SmartAverageCache cleared")
        
        Task { @MainActor in
            GradefyCacheManager.shared.clearAllCaches()
        }
        print("✅ [PERSISTENCE] GradefyCacheManager cleared")
        
        logger.debug("🗑️ Tous les caches vidés")
        print("✅ [PERSISTENCE] === CLEAR_CACHE TERMINÉ ===")
    }
    
    // MARK: - Save Operations
    func save() {
        print("💾 [PERSISTENCE] === SAVE DÉBUT ===")
        let context = container.viewContext
        
        guard context.hasChanges else {
            print("💾 [PERSISTENCE] Aucune modification à sauvegarder")
            logger.debug("💾 Aucune modification à sauvegarder")
            return
        }
        
        print("💾 [PERSISTENCE] Modifications détectées:")
        print("💾 [PERSISTENCE]   - Inserted: \(context.insertedObjects.count)")
        print("💾 [PERSISTENCE]   - Updated: \(context.updatedObjects.count)")
        print("💾 [PERSISTENCE]   - Deleted: \(context.deletedObjects.count)")
        
        // Détail des objets modifiés
        if !context.insertedObjects.isEmpty {
            let entityNames = context.insertedObjects.map { $0.entity.name ?? "Unknown" }
            print("💾 [PERSISTENCE]   - Inserted entities: \(Set(entityNames))")
        }
        
        if !context.updatedObjects.isEmpty {
            let entityNames = context.updatedObjects.map { $0.entity.name ?? "Unknown" }
            print("💾 [PERSISTENCE]   - Updated entities: \(Set(entityNames))")
        }
        
        if !context.deletedObjects.isEmpty {
            let entityNames = context.deletedObjects.map { $0.entity.name ?? "Unknown" }
            print("💾 [PERSISTENCE]   - Deleted entities: \(Set(entityNames))")
        }
        
        do {
            let startTime = Date()
            try context.save()
            let duration = Date().timeIntervalSince(startTime)
            
            print("✅ [PERSISTENCE] Sauvegarde réussie (\(String(format: "%.3f", duration * 1000))ms)")
            logger.info("✅ Sauvegarde locale réussie")
            lastSaveDate = Date()
            print("📅 [PERSISTENCE] lastSaveDate mise à jour: \(Date())")
            
            // Invalidation intelligente du cache après sauvegarde
            print("🔄 [PERSISTENCE] Début invalidation cache post-save...")
            smartInvalidateCache(after: context)
            print("✅ [PERSISTENCE] Invalidation cache terminée")
            
        } catch {
            let nsError = error as NSError
            print("❌ [PERSISTENCE] Erreur sauvegarde:")
            print("❌ [PERSISTENCE]   - Code: \(nsError.code)")
            print("❌ [PERSISTENCE]   - Description: \(nsError.localizedDescription)")
            print("❌ [PERSISTENCE]   - UserInfo: \(nsError.userInfo)")
            logger.error("❌ Erreur de sauvegarde: \(nsError.localizedDescription)")
            
            // Gestion des conflits de merge
            if nsError.code == NSManagedObjectMergeError {
                print("⚠️ [PERSISTENCE] Conflit de merge détecté")
                handleMergeConflict(error: nsError)
            } else {
                print("💀 [PERSISTENCE] Erreur fatale de sauvegarde")
                fatalError("Erreur de sauvegarde: \(nsError), \(nsError.userInfo)")
            }
        }
        
        print("✅ [PERSISTENCE] === SAVE TERMINÉ ===")
    }
    
    private func smartInvalidateCache(after context: NSManagedObjectContext) {
        print("🔄 [PERSISTENCE] === SMART INVALIDATION DÉBUT ===")
        
        // Invalider les caches pour les objets insérés
        if !context.insertedObjects.isEmpty {
            print("🔄 [PERSISTENCE] Invalidation pour \(context.insertedObjects.count) objets insérés")
            invalidateCacheForObjects(context.insertedObjects)
        }
        
        // Invalider les caches pour les objets modifiés
        if !context.updatedObjects.isEmpty {
            print("🔄 [PERSISTENCE] Invalidation pour \(context.updatedObjects.count) objets modifiés")
            invalidateCacheForObjects(context.updatedObjects)
        }
        
        // Invalider les caches pour les objets supprimés
        if !context.deletedObjects.isEmpty {
            print("🔄 [PERSISTENCE] Invalidation pour \(context.deletedObjects.count) objets supprimés")
            invalidateCacheForObjects(context.deletedObjects)
        }
        
        print("✅ [PERSISTENCE] === SMART INVALIDATION TERMINÉ ===")
    }
    
    private func invalidateCacheForObjects(_ objects: Set<NSManagedObject>) {
        print("🗑️ [PERSISTENCE] INVALIDATE_OBJECTS: \(objects.count) objets")
        
        for object in objects {
            let objectIDString = object.objectID.uriRepresentation().absoluteString
            let entityName = object.entity.name ?? "Unknown"
            print("🗑️ [PERSISTENCE] Invalidating: \(entityName) - \(objectIDString)")
            smartAverageCache.invalidateIfNeeded(changedObjectID: objectIDString)
        }
        
        print("✅ [PERSISTENCE] INVALIDATE_OBJECTS_DONE: \(objects.count) objets traités")
    }
    
    // MARK: - Local Notifications
    private func setupLocalNotifications() {
        print("👂 [PERSISTENCE] === SETUP NOTIFICATIONS DÉBUT ===")
        
        // Surveillance des changements de contexte
        print("👂 [PERSISTENCE] Configuration observer NSManagedObjectContextDidSave...")
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: container.viewContext,
            queue: .main
        ) { [weak self] notification in
            print("📢 [PERSISTENCE] NSManagedObjectContextDidSave notification reçue")
            self?.logger.info("🔄 Changement local détecté")
            Task { @MainActor in
                self?.handleLocalChange(notification)
            }
        }
        
        logger.info("👂 Notifications locales configurées")
        print("✅ [PERSISTENCE] === SETUP NOTIFICATIONS TERMINÉ ===")
    }
    
    // MARK: - Local Change Handling
    @MainActor
    private func handleLocalChange(_ notification: Notification) {
        print("🔄 [PERSISTENCE] === HANDLE_LOCAL_CHANGE DÉBUT ===")
        let now = Date()
        let timeSinceLastChange = now.timeIntervalSince(lastChangeTime)
        
        print("🔄 [PERSISTENCE] Temps depuis dernier changement: \(String(format: "%.2f", timeSinceLastChange))s")
        print("🔄 [PERSISTENCE] Seuil debounce: \(changeDebounceInterval)s")
        
        // Debouncing intelligent avec extraction des objets modifiés
        if timeSinceLastChange > changeDebounceInterval {
            print("✅ [PERSISTENCE] Debounce OK - traitement du changement")
            logger.info("🔄 Changement local détecté - traitement")
            
            if let userInfo = notification.userInfo {
                print("🔍 [PERSISTENCE] Extraction des objectIDs...")
                let objectIDs = extractObjectIDs(from: userInfo)
                if !objectIDs.isEmpty {
                    print("📢 [PERSISTENCE] Notification des changements (\(objectIDs.count) objets)")
                    // Notifier les changements
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .dataDidChange, object: objectIDs)
                        print("📢 [PERSISTENCE] Notification dataDidChange envoyée")
                    }
                } else {
                    print("⚠️ [PERSISTENCE] Aucun objet modifié détecté")
                    logger.debug("📊 Aucun objet modifié détecté")
                }
            } else {
                print("⚠️ [PERSISTENCE] Notification sans userInfo")
            }
            
            lastChangeTime = now
            lastSaveDate = Date()
            print("📅 [PERSISTENCE] lastChangeTime mis à jour: \(now)")
        } else {
            print("⏭️ [PERSISTENCE] Changement ignoré (debounce actif)")
            logger.debug("🔄 Changement local ignoré (debounce actif)")
        }
        
        print("✅ [PERSISTENCE] === HANDLE_LOCAL_CHANGE TERMINÉ ===")
    }
    
    private func extractObjectIDs(from userInfo: [AnyHashable: Any]) -> Set<NSManagedObjectID> {
        print("🔍 [PERSISTENCE] === EXTRACT_OBJECT_IDS DÉBUT ===")
        var objectIDs = Set<NSManagedObjectID>()
        
        // Extraire les IDs des objets modifiés selon les clés Core Data
        if let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
            objectIDs.formUnion(insertedObjects.map { $0.objectID })
            print("🔍 [PERSISTENCE] Objets insérés: \(insertedObjects.count)")
        }
        
        if let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            objectIDs.formUnion(updatedObjects.map { $0.objectID })
            print("🔍 [PERSISTENCE] Objets modifiés: \(updatedObjects.count)")
        }
        
        if let deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> {
            objectIDs.formUnion(deletedObjects.map { $0.objectID })
            print("🔍 [PERSISTENCE] Objets supprimés: \(deletedObjects.count)")
        }
        
        logger.debug("📊 Extraction: \(objectIDs.count) objets modifiés")
        print("✅ [PERSISTENCE] === EXTRACT_OBJECT_IDS TERMINÉ: \(objectIDs.count) objets ===")
        return objectIDs
    }
    
    @MainActor
    private func handleBatchChangeCompletion(_ objectIDs: Set<NSManagedObjectID>) {
        print("🔄 [PERSISTENCE] === BATCH_CHANGE_COMPLETION DÉBUT ===")
        print("🔄 [PERSISTENCE] ObjectIDs reçus: \(objectIDs.count)")
        logger.info("🔄 Traitement batch local de \(objectIDs.count) objets")
        
        // Invalider les caches affectés de manière intelligente
        print("🗑️ [PERSISTENCE] Invalidation cache pour batch changes...")
        for objectID in objectIDs {
            let objectIDString = objectID.uriRepresentation().absoluteString
            print("🗑️ [PERSISTENCE] Processing objectID: \(objectIDString)")
            smartAverageCache.invalidateIfNeeded(changedObjectID: objectIDString)
        }
        print("✅ [PERSISTENCE] Invalidation cache terminée")
        
        // Notifier l'UI des changements batch
        print("📢 [PERSISTENCE] Notification UI des changements batch...")
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dataDidChange, object: objectIDs)
            print("📢 [PERSISTENCE] Notification dataDidChange envoyée (batch)")
        }
        
        print("✅ [PERSISTENCE] === BATCH_CHANGE_COMPLETION TERMINÉ ===")
    }
    
    // MARK: - Error Handling
    private func handleMergeConflict(error: NSError) {
        print("⚠️ [PERSISTENCE] === MERGE_CONFLICT DÉBUT ===")
        print("⚠️ [PERSISTENCE] Erreur: \(error.localizedDescription)")
        print("⚠️ [PERSISTENCE] UserInfo: \(error.userInfo)")
        logger.warning("⚠️ Conflit de fusion détecté - résolution automatique")
        
        // Recharger les données depuis le store persistant
        print("🔄 [PERSISTENCE] Rollback du contexte...")
        container.viewContext.rollback()
        print("✅ [PERSISTENCE] Rollback terminé")
        
        // Vider les caches car les données ont changé
        print("🧹 [PERSISTENCE] Nettoyage des caches...")
        clearCache()
        print("✅ [PERSISTENCE] Caches nettoyés")
        
        // Notifier l'UI du conflit résolu
        print("📢 [PERSISTENCE] Notification résolution conflit...")
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .mergeConflictResolved, object: error)
            print("📢 [PERSISTENCE] Notification mergeConflictResolved envoyée")
        }
        
        print("✅ [PERSISTENCE] === MERGE_CONFLICT TERMINÉ ===")
    }
    
    // MARK: - Utility Methods
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) -> T) async -> T {
        print("🔧 [PERSISTENCE] BACKGROUND_TASK_START")
        
        return await withCheckedContinuation { continuation in
            container.performBackgroundTask { context in
                print("🔧 [PERSISTENCE] Executing background task...")
                let result = block(context)
                print("✅ [PERSISTENCE] Background task completed")
                continuation.resume(returning: result)
            }
        }
    }
    
    func resetPersistentStore() async {
        print("🗑️ [PERSISTENCE] === RESET_STORE DÉBUT ===")
        logger.warning("🗑️ Réinitialisation du store persistant")
        
        let coordinator = container.persistentStoreCoordinator
        print("🗑️ [PERSISTENCE] Stores à détruire: \(coordinator.persistentStores.count)")
        
        for store in coordinator.persistentStores {
            print("🗑️ [PERSISTENCE] Destruction store: \(store.url?.lastPathComponent ?? "inconnu")")
            do {
                try coordinator.destroyPersistentStore(
                    at: store.url!,
                    ofType: store.type,
                    options: nil
                )
                print("✅ [PERSISTENCE] Store détruit: \(store.url?.lastPathComponent ?? "inconnu")")
                logger.info("✅ Store détruit: \(store.url?.lastPathComponent ?? "inconnu")")
            } catch {
                print("❌ [PERSISTENCE] Erreur destruction: \(error.localizedDescription)")
                logger.error("❌ Erreur destruction store: \(error.localizedDescription)")
            }
        }
        
        // Recharger les stores
        print("🔄 [PERSISTENCE] Rechargement des stores...")
        loadPersistentStores()
        print("✅ [PERSISTENCE] Stores rechargés")
        
        print("🧹 [PERSISTENCE] Nettoyage des caches...")
        clearCache()
        print("✅ [PERSISTENCE] Caches nettoyés")
        
        await MainActor.run {
            NotificationCenter.default.post(name: .storeDidReset, object: nil)
            print("📢 [PERSISTENCE] Notification storeDidReset envoyée")
        }
        
        print("✅ [PERSISTENCE] === RESET_STORE TERMINÉ ===")
    }
    
    // MARK: - Cache Performance Monitoring
    func getCachePerformanceReport() -> String {
        print("📊 [PERSISTENCE] Génération rapport performance...")
        let _ = GradefyCacheManager.shared
        let report = """
        📊 Rapport Performance Cache Local:
        - Cache intelligent SmartAverageCache actif
        - Debouncing local: \(changeDebounceInterval)s
        - Dernière sauvegarde: \(lastSaveDate?.formatted() ?? "Jamais")
        - Mode: Core Data local uniquement
        """
        print("📊 [PERSISTENCE] Rapport généré (\(report.count) caractères)")
        return report
    }
}

// MARK: - Notification Names
extension NSNotification.Name {
    static let dataDidChange = NSNotification.Name("dataDidChange")
    static let mergeConflictResolved = NSNotification.Name("mergeConflictResolved")
    static let storeDidReset = NSNotification.Name("storeDidReset")
    static let systemChanged = NSNotification.Name("systemChanged")
    // NOUVELLES NOTIFICATIONS pour le cache avancé
    static let batchChangeCompleted = NSNotification.Name("batchChangeCompleted")
    static let memoryPressure = NSNotification.Name("memoryPressure")
    static let cacheOptimizationNeeded = NSNotification.Name("cacheOptimizationNeeded")
}
