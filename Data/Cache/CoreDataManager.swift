import CoreData
import Foundation

// ✅ SOLUTION SIMPLIFIÉE : Core Data adapté aux limites
class CoreDataManager {
    static let shared = CoreDataManager()
    
    enum SortOption {
        case createdAt
        case name
        
        var sortDescriptors: [NSSortDescriptor] {
            switch self {
            case .createdAt:
                return [NSSortDescriptor(keyPath: \FlashcardDeck.createdAt, ascending: true)]
            case .name:
                return [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
            }
        }
    }
    
    // ✅ SIMPLIFICATION : Fetch simple sans pagination
    func fetchDecks(sort: SortOption, context: NSManagedObjectContext) -> [FlashcardDeck] {
        let request: NSFetchRequest<FlashcardDeck> = FlashcardDeck.fetchRequest()
        
        request.sortDescriptors = sort.sortDescriptors
        request.fetchBatchSize = 50  // ✅ ADAPTATION : Batch size adapté
        
        do {
            return try context.fetch(request)
        } catch {
            print("Erreur fetch decks: \(error)")
            return []
        }
    }
    
    // ✅ SIMPLIFICATION : Fetch flashcards simple
    func fetchFlashcards(for deck: FlashcardDeck, context: NSManagedObjectContext) -> [Flashcard] {
        let request: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
        request.predicate = NSPredicate(format: "deck == %@", deck)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Flashcard.createdAt, ascending: true)]
        request.fetchBatchSize = 50  // ✅ ADAPTATION : Batch size adapté
        
        do {
            return try context.fetch(request)
        } catch {
            print("Erreur fetch flashcards: \(error)")
            return []
        }
    }
    
    func countDecks(context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<FlashcardDeck> = FlashcardDeck.fetchRequest()
        
        do {
            return try context.count(for: request)
        } catch {
            print("Erreur comptage decks: \(error)")
            return 0
        }
    }
    
    func countFlashcards(for deck: FlashcardDeck, context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
        request.predicate = NSPredicate(format: "deck == %@", deck)
        
        do {
            return try context.count(for: request)
        } catch {
            print("Erreur comptage flashcards: \(error)")
            return 0
        }
    }
}
