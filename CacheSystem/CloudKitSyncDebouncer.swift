//
//  CloudKitSyncDebouncer.swift
//  PARALLAX
//
//  Created by Farid on 7/1/25.
//


import Foundation
import CoreData
import os.log

class CloudKitSyncDebouncer {
    private var syncWorkItem: DispatchWorkItem?
    private var batchedChanges: Set<NSManagedObjectID> = []
    private let syncQueue = DispatchQueue(label: "gradefy.sync", qos: .utility)
    private let debounceInterval: TimeInterval = 3.0
    private let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "SyncDebouncer")
    
    func scheduleSync(for objectID: NSManagedObjectID) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Ajouter à la batch
            self.batchedChanges.insert(objectID)
            
            // Annuler le sync précédent
            self.syncWorkItem?.cancel()
            
            // Programmer nouveau sync
            let workItem = DispatchWorkItem { [weak self] in
                self?.executeBatchSync()
            }
            
            self.syncWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + self.debounceInterval, execute: workItem)
        }
    }
    
    private func executeBatchSync() {
        let changesToSync = batchedChanges
        batchedChanges.removeAll()
        
        logger.info("🔄 Sync batch de \(changesToSync.count) changements")
        
        // Notifier le système principal
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .batchSyncCompleted,
                object: changesToSync
            )
        }
    }
}
