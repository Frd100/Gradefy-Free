import SwiftUI

struct DeckLimitsWidget: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var premiumManager = PremiumManager.shared
    
    // ✅ NOUVEAU : Paramètre deck pour calculer les vraies statistiques
    let deck: FlashcardDeck?
    
    // ✅ NOUVEAU : Initialiseur avec deck optionnel
    init(deck: FlashcardDeck? = nil) {
        self.deck = deck
    }
    
    private var deckFlashcardInfo: (current: Int, max: Int, remaining: Int) {
        guard let deck = deck else {
            // Fallback si pas de deck fourni
            return (current: 0, max: 200, remaining: 200)
        }
        
        let currentCount = (deck.flashcards as? Set<Flashcard>)?.count ?? 0
        let maxCount = premiumManager.maxFlashcardsPerDeckProperty
        let remaining = max(0, maxCount - currentCount)
        
        return (current: currentCount, max: maxCount, remaining: remaining)
    }
    
    private var deckMediaInfo: (current: Int, max: Int, remaining: Int) {
        guard let deck = deck else {
            // Fallback si pas de deck fourni
            return (current: 0, max: premiumManager.maxMediaPerDeckProperty, remaining: premiumManager.maxMediaPerDeckProperty)
        }
        
        let flashcards = (deck.flashcards as? Set<Flashcard>) ?? []
        var mediaCount = 0
        
        for flashcard in flashcards {
            // Compter les médias de question
            if flashcard.questionContentType != .text { mediaCount += 1 }
            // Compter les médias de réponse
            if flashcard.answerContentType != .text { mediaCount += 1 }
        }
        
        let maxMedia = premiumManager.maxMediaPerDeckProperty // Utiliser la vraie limite
        let remaining = max(0, maxMedia - mediaCount)
        
        return (current: mediaCount, max: maxMedia, remaining: remaining)
    }
    
    private var flashcardProgress: Double {
        guard deckFlashcardInfo.max > 0 else { return 0 }
        let progress = Double(deckFlashcardInfo.current) / Double(deckFlashcardInfo.max)
        return min(progress, 1.0) // S'assurer que la valeur ne dépasse pas 1.0
    }
    
    private var mediaProgress: Double {
        guard deckMediaInfo.max > 0 else { return 0 }
        let progress = Double(deckMediaInfo.current) / Double(deckMediaInfo.max)
        return min(progress, 1.0) // S'assurer que la valeur ne dépasse pas 1.0
    }
    
    private var flashcardColor: Color {
        if deckFlashcardInfo.remaining <= 20 {
            return .orange
        } else if flashcardProgress >= 0.8 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var mediaColor: Color {
        if deckMediaInfo.remaining <= 1 {
            return .orange
        } else if mediaProgress >= 0.8 {
            return .yellow
        } else {
            return .purple
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Flashcards du deck
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Cartes")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(deckFlashcardInfo.current)/\(deckFlashcardInfo.max)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(flashcardColor)
                }
                ProgressView(value: flashcardProgress)
                    .tint(flashcardColor)
                    .scaleEffect(y: 0.6, anchor: .center)
            }
            
            // Section Médias du deck
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Médias")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(deckMediaInfo.current)/\(deckMediaInfo.max)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(mediaColor)
                }
                ProgressView(value: mediaProgress)
                    .tint(mediaColor)
                    .scaleEffect(y: 0.6, anchor: .center)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
