//
//  Extensions.swift
//  PARALLAX
//
//  Created by  on 7/21/25.
//

import CoreData
import Foundation
import SwiftUI
import UIKit

extension FlashcardDeck {
    var flashcardCount: Int {
        (flashcards as? Set<Flashcard>)?.count ?? 0
    }

    var hasFlashcards: Bool {
        flashcardCount > 0
    }

    // ✅ Propriété calculée pour accéder aux flashcards comme un array
    var flashcardsArray: [Flashcard] {
        if let flashcardsSet = flashcards as? Set<Flashcard> {
            return Array(flashcardsSet).sorted { $0.createdAt ?? Date() < $1.createdAt ?? Date() }
        }
        return []
    }
}

extension Subject {
    var flashcardCount: Int {
        return 0 // Plus de relation avec les flashcards
    }

    var deckCount: Int {
        return 0 // Plus de relation avec les decks
    }
}

extension Notification.Name {
    static let forceClosePopovers = Notification.Name("forceClosePopovers")
    static let deckStatsUpdated = Notification.Name("deckStatsUpdated")
}
