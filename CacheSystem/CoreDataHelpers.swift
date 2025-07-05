import Foundation
import CoreData
import os.log

// MARK: - Core Data Context Extensions
extension NSManagedObjectContext {
    
    /// Récupère un objet dans ce contexte à partir de son objectID
    func object<T: NSManagedObject>(with objectID: NSManagedObjectID, as type: T.Type) -> T? {
        do {
            return try existingObject(with: objectID) as? T
        } catch {
            let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "CoreDataHelpers")
            logger.error("❌ Erreur récupération objet dans contexte: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Sauvegarde sécurisée avec gestion d'erreur et logs
    func safeSave() -> Bool {
        guard hasChanges else {
            return true
        }
        
        let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "CoreDataHelpers")
        
        do {
            try save()
            logger.info("✅ Sauvegarde contexte réussie")
            return true
        } catch {
            logger.error("❌ Erreur sauvegarde contexte: \(error.localizedDescription)")
            rollback()
            return false
        }
    }
    
    /// Récupère un objet par ID avec type safety
    func fetchObject<T: NSManagedObject>(_ type: T.Type, with objectID: NSManagedObjectID) -> T? {
        return object(with: objectID, as: type)
    }
    
    /// Exécute une opération de manière sécurisée avec sauvegarde
    func performSafeOperation(_ operation: () throws -> Void) -> Bool {
        do {
            try operation()
            return safeSave()
        } catch {
            let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "CoreDataHelpers")
            logger.error("❌ Erreur opération: \(error.localizedDescription)")
            rollback()
            return false
        }
    }
}

// MARK: - Flashcard Specific Helpers
extension NSManagedObjectContext {
    
    /// Crée une flashcard en s'assurant que tous les objets sont dans le bon contexte
    func createFlashcard(
        question: String,
        answer: String,
        subjectObjectID: NSManagedObjectID? = nil,
        deckObjectID: NSManagedObjectID? = nil
    ) -> Bool {
        let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "FlashcardHelpers")
        
        return performSafeOperation {
            let flashcard = Flashcard(context: self)
            flashcard.id = UUID()
            flashcard.question = question
            flashcard.answer = answer
            flashcard.createdAt = Date()
            flashcard.correctCount = 0
            flashcard.reviewCount = 0
            flashcard.interval = 1
            
            // Assigner le subject si fourni
            if let subjectID = subjectObjectID,
               let contextSubject = self.object(with: subjectID, as: Subject.self) {
                flashcard.subject = contextSubject
                logger.debug("✅ Subject assigné à la flashcard")
            }
            
            // Assigner le deck si fourni
            if let deckID = deckObjectID,
               let contextDeck = self.object(with: deckID, as: FlashcardDeck.self) {
                flashcard.deck = contextDeck
                // Si pas de subject mais deck avec subject, utiliser celui du deck
                if flashcard.subject == nil {
                    flashcard.subject = contextDeck.subject
                }
                logger.debug("✅ Deck assigné à la flashcard")
            }
            
            logger.info("✅ Flashcard créée: \(question)")
        }
    }
    
    /// Crée un deck de flashcards de manière sécurisée
    func createFlashcardDeck(
        name: String,
        subjectObjectID: NSManagedObjectID
    ) -> FlashcardDeck? {
        let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "FlashcardHelpers")
        
        guard let contextSubject = self.object(with: subjectObjectID, as: Subject.self) else {
            logger.error("❌ Impossible de récupérer subject pour créer deck")
            return nil
        }
        
        let success = performSafeOperation {
            let deck = FlashcardDeck(context: self)
            deck.id = UUID()
            deck.name = name
            deck.createdAt = Date()
            deck.subject = contextSubject
            logger.info("✅ Deck créé: \(name)")
        }
        
        if success {
            // Récupérer le deck créé
            let request: NSFetchRequest<FlashcardDeck> = FlashcardDeck.fetchRequest()
            request.predicate = NSPredicate(format: "name == %@ AND subject == %@", name, contextSubject)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \FlashcardDeck.createdAt, ascending: false)]
            request.fetchLimit = 1
            
            do {
                return try fetch(request).first
            } catch {
                logger.error("❌ Erreur récupération deck créé: \(error)")
                return nil
            }
        }
        
        return nil
    }
}

// MARK: - Generic Core Data Utilities
extension NSManagedObjectContext {
    
    /// Supprime un objet de manière sécurisée
    func safeDelete(_ object: NSManagedObject) -> Bool {
        let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "CoreDataHelpers")
        
        return performSafeOperation {
            delete(object)
            logger.debug("🗑️ Objet supprimé: \(object.entity.name ?? "Unknown")")
        }
    }
    
    /// Supprime plusieurs objets de manière sécurisée
    func safeDelete<T: NSManagedObject>(_ objects: [T]) -> Bool {
        let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "CoreDataHelpers")
        
        return performSafeOperation {
            objects.forEach { delete($0) }
            logger.debug("🗑️ \(objects.count) objets supprimés")
        }
    }
    
    /// Fetch sécurisé avec gestion d'erreur
    func safeFetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> [T] {
        do {
            return try fetch(request)
        } catch {
            let logger = Logger(subsystem: "com.Coefficient.PARALLAX2", category: "CoreDataHelpers")
            logger.error("❌ Erreur fetch: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Gradefy Specific Extensions
extension NSManagedObjectContext {
    
    /// Valide qu'un objet appartient bien à ce contexte
    func validateObjectContext<T: NSManagedObject>(_ object: T) -> Bool {
        return object.managedObjectContext == self
    }
    
    /// Récupère un objet dans ce contexte ou nil si incompatible
    func ensureObjectInContext<T: NSManagedObject>(_ object: T) -> T? {
        if validateObjectContext(object) {
            return object
        } else {
            return self.object(with: object.objectID, as: T.self)
        }
    }
}
