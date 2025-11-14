//
//  ImportDeckView.swift
//  PARALLAX
//
//  Created by  on 7/17/25.
//

import SwiftUI
import CoreData

// MARK: - Import Deck View
struct ImportDeckView: View {
    let shareableDeck: ShareableDeck
    let onImport: (ShareableDeck, Bool) -> Void
    let onCancel: () -> Void
    
    @State private var premiumManager = PremiumManager.shared
    @State private var showingPremiumView = false
    @State private var currentDeckCount: Int = 0
    @State private var currentFlashcardCount: Int = 0
    @Environment(\.colorScheme) private var colorScheme
    
    private var canImportDeck: Bool {
        premiumManager.canCreateDeck(currentDeckCount: currentDeckCount)
    }
    
    private var maxCardsCanImport: Int {
        let maxTotal = premiumManager.isPremium ? 2000 : 300
        let remaining = max(0, maxTotal - currentFlashcardCount)
        return min(remaining, shareableDeck.flashcards.count)
    }
    
    private var canImportAll: Bool {
        maxCardsCanImport >= shareableDeck.flashcards.count
    }
    
    private var hasReachedGlobalLimit: Bool {
        maxCardsCanImport <= 0
    }
    
    private var willExceedLimit: Bool {
        !canImportAll && maxCardsCanImport > 0
    }
    
    private func updateCounts() {
        let context = PersistenceController.shared.container.viewContext
        
        // Compter les decks
        let deckRequest: NSFetchRequest<FlashcardDeck> = FlashcardDeck.fetchRequest()
        do {
            currentDeckCount = try context.count(for: deckRequest)
        } catch {
            print("Erreur comptage decks: \(error)")
            currentDeckCount = 0
        }
        
        // Compter les flashcards
        let flashcardRequest: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
        do {
            currentFlashcardCount = try context.count(for: flashcardRequest)
        } catch {
            print("Erreur comptage flashcards: \(error)")
            currentFlashcardCount = 0
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header avec X
            HStack {
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Contenu principal
            VStack(spacing: 5) {
                
                AdaptiveLottieView(
                    animationName: "download",
                    isAnimated: false // ✅ Mode statique
                )
                .frame(width: 70, height: 70)

                VStack(spacing: 8) {
                    Text(shareableDeck.metadata.name)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    if let creatorName = shareableDeck.metadata.creatorName {
                        Text(String(localized: "shared_by").replacingOccurrences(of: "%@", with: creatorName))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 5)
                
                // Texte descriptif
                VStack(spacing: 16) {
                    if hasReachedGlobalLimit {
                        Text("Cette liste contient \(shareableDeck.flashcards.count) cartes.")
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        if premiumManager.isPremium {
                            Text("Limite de 2000 cartes atteinte. Vous ne pouvez plus importer de cartes.")
                                .font(.callout.weight(.medium))
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Limite de 300 cartes atteinte. Importez jusqu'à 2000 cartes avec Gradefy Pro.")
                                .font(.callout.weight(.medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    } else if willExceedLimit {
                        Text("Cette liste contient \(shareableDeck.flashcards.count) cartes.")
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        if premiumManager.isPremium {
                            Text("Vous pouvez importer \(maxCardsCanImport) cartes (limite 2000).")
                                .font(.callout.weight(.medium))
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Vous pouvez importer \(maxCardsCanImport) cartes. Importez jusqu'à 2000 cartes avec Gradefy Pro.")
                                .font(.callout.weight(.medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        Text("Cette liste contient \(shareableDeck.flashcards.count) cartes.")
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 30)
                Spacer()
                // Boutons d'action
                VStack(spacing: 12) {
                    if !hasReachedGlobalLimit && canImportDeck {
                        Button(action: {
                            HapticFeedbackManager.shared.impact(style: .medium)
                            onImport(shareableDeck, canImportAll)
                        }) {
                            Text(canImportAll ? "Importer toutes les cartes" : "Importer \(maxCardsCanImport) cartes")
                                .font(.headline.weight(.medium))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 5)
                        .padding(.horizontal, 15)
                    }
                    
                    // Message si limite de decks atteinte
                    if !canImportDeck {
                        Text("Limite de listes atteinte. Créez des listes illimitées avec Gradefy Pro.")
                            .font(.callout.weight(.medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Bouton Premium si nécessaire (gratuit uniquement)
                    if !premiumManager.isPremium && (willExceedLimit || hasReachedGlobalLimit || !canImportDeck) {
                        Button(action: {
                            HapticFeedbackManager.shared.impact(style: .light)
                            showingPremiumView = true
                        }) {
                            Text("En savoir plus sur Gradefy Pro")
                                .font(.callout.weight(.medium))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 0)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            updateCounts()
        }

        .background(
            (colorScheme == .light ? Color(.systemBackground) : Color(.systemBackground))
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showingPremiumView) {
            PremiumView()
                .onDisappear {
                    if premiumManager.isPremium {
                    }
                }
        }
    }
}
