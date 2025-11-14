//
//  ImportDeckView.swift
//  PARALLAX
//
//  Created by  on 7/17/25.
//

import CoreData
import SwiftUI

// MARK: - Import Deck View

struct ImportDeckView: View {
    let shareableDeck: ShareableDeck
    let onImport: (ShareableDeck, Bool) -> Void
    let onCancel: () -> Void

    @State private var featureManager = FeatureManager.shared
    @State private var showingPremiumView = false
    @State private var currentDeckCount: Int = 0
    @State private var currentFlashcardCount: Int = 0
    @Environment(\.colorScheme) private var colorScheme

    // ✅ MODIFIÉ : Toujours autoriser - Application entièrement gratuite
    private var canImportDeck: Bool {
        true // Toujours autorisé
    }

    private var maxCardsCanImport: Int {
        shareableDeck.flashcards.count // Peut tout importer
    }

    private var canImportAll: Bool {
        true // Toujours autorisé
    }

    private var hasReachedGlobalLimit: Bool {
        false // Plus de limite
    }

    private var willExceedLimit: Bool {
        false // Plus de limite
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
                    // ✅ MODIFIÉ : Toujours autoriser - Application entièrement gratuite
                    Text("Cette liste contient \(shareableDeck.flashcards.count) cartes.")
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
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

                    // ✅ MODIFIÉ : Plus de message de limite - Application entièrement gratuite
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
        // ✅ MODIFIÉ : Supprimé - Application entièrement gratuite
    }
}
