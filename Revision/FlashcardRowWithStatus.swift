//
//  FlashcardRowWithStatus.swift
//  PARALLAX
//
//  Exemple d'intégration des statuts dans une row de flashcard
//

import SwiftUI
import CoreData

// ✅ Exemple de row de flashcard avec statut
struct FlashcardRowWithStatus: View {
    let flashcard: Flashcard
    @Environment(\.colorScheme) private var colorScheme
    
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Contenu principal de la carte
            VStack(alignment: .leading, spacing: 4) {
                // Question
                if let question = flashcard.question, !question.isEmpty {
                    Text(question)
                        .font(.headline)
                        .lineLimit(2)
                } else {
                    Text("Question audio/image")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                // Réponse
                if let answer = flashcard.answer, !answer.isEmpty {
                    Text(answer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Réponse audio/image")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
            
            // ✅ Statut de la carte (nouveau)
            FlashcardStatusView(card: flashcard)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// ✅ Exemple de vue de liste complète avec toolbar
struct FlashcardListExample: View {
    let deck: FlashcardDeck
    @Environment(\.colorScheme) private var colorScheme
    
    private var flashcards: [Flashcard] {
        (deck.flashcards as? Set<Flashcard>)?.sorted { 
            ($0.question ?? "") < ($1.question ?? "")
        } ?? []
    }
    
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                adaptiveBackground.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(flashcards, id: \.objectID) { flashcard in
                            FlashcardRowWithStatus(flashcard: flashcard)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(deck.name ?? "Deck")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Bouton Share (existant)
                    Button(action: {
                        // Action de partage existante
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    // ✅ NOUVEAU : Bouton Settings
                    FlashcardSettingsButton()
                }
            }
        }
    }
}

// ✅ Preview pour tester
struct FlashcardStatusPreviews: PreviewProvider {
    static var previews: some View {
        // Preview du composant statut seul
        VStack(spacing: 16) {
            FlashcardStatusView(card: sampleFlashcard)
            
            StatusExampleRow(
                status: CardStatus(message: "À réviser", color: Color.orange, icon: "clock"),
                description: "Carte prête à être révisée"
            )
        }
        .padding()
        .previewDisplayName("Statuts")
        
        // Preview de la sheet settings
        FlashcardSettingsSheet()
            .previewDisplayName("Settings Sheet")
    }
    
    static var sampleFlashcard: Flashcard {
        // Création d'un sample flashcard pour preview
        let card = Flashcard()
        card.question = "Cat"
        card.answer = "Chat"
        card.nextReviewDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())
        return card
    }
}
