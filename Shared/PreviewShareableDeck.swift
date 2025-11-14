//
//  PreviewShareableDeck.swift
//  PARALLAX
//
//  Created by  on 7/17/25.
//


import SwiftUI

// MARK: - Preview Models
struct PreviewShareableDeck {
    let metadata: Metadata
    let flashcards: [ShareableFlashcard]
    
    struct Metadata {
        let id: String
        let name: String
        let totalCards: Int
        let createdAt: Date
        let creatorName: String?
        let appVersion: String
        let shareVersion: String
    }
    
    struct ShareableFlashcard {
        let question: String
        let answer: String
        let createdAt: Date
    }
}

// MARK: - Import Sheet Preview
struct ImportDeckPreviewView: View {
    let shareableDeck: PreviewShareableDeck
    let isPremium: Bool
    let onImport: (Bool) -> Void
    let onCancel: () -> Void
    
    // Note: Cette logique simplifiée ne prend pas en compte les limites globales
    // car c'est seulement une preview. La vraie logique est dans ImportDeckView
    private var canImportAll: Bool {
        isPremium // Premium peut tout importer, gratuit sera limité par la logique globale
    }
    
    private var hasMoreCards: Bool {
        !isPremium && shareableDeck.metadata.totalCards > 100 // Seuil indicatif pour la preview
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
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Contenu principal
            VStack(spacing: 24) {
                // Titre et sous-titre
                VStack(spacing: 8) {
                    Text(shareableDeck.metadata.name)
                        .font(.title.bold())
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    if let creatorName = shareableDeck.metadata.creatorName {
                        Text(String(localized: "shared_by").replacingOccurrences(of: "%@", with: creatorName))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                // Texte descriptif
                VStack(spacing: 16) {
                    Text("Ce deck contient \(shareableDeck.metadata.totalCards) cartes.")
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    if hasMoreCards {
                        Text("Gradefy Pro vous permet d'importer toutes les cartes selon vos limites globales.")
                            .font(.callout.weight(.medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
                
                // Boutons d'action
                VStack(spacing: 12) {
                    // Bouton principal d'import
                    Button(action: {
                        onImport(canImportAll)
                    }) {
                        Text(canImportAll ? "Importer toutes les cartes" : "Importer selon limite")
                            .font(.headline.weight(.medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.blue)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // Bouton Premium si nécessaire
                    if hasMoreCards {
                        Button(action: {
                            // Action premium
                        }) {
                            Text("Voir Premium")
                                .font(.headline.weight(.medium))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Previews
struct ImportDeckPreview_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Version Premium
            ImportDeckPreviewView(
                shareableDeck: PreviewShareableDeck(
                    metadata: .init(
                        id: "premium-deck",
                        name: "Histoire de France",
                        totalCards: 150,
                        createdAt: Date(),
                        creatorName: "Alice",
                        appVersion: "1.0",
                        shareVersion: "1.0"
                    ),
                    flashcards: []
                ),
                isPremium: true,
                onImport: { _ in },
                onCancel: {}
            )
            .previewDisplayName("Version Premium")
            
            // Version Gratuite
            ImportDeckPreviewView(
                shareableDeck: PreviewShareableDeck(
                    metadata: .init(
                        id: "free-deck",
                        name: "Mathématiques",
                        totalCards: 200,
                        createdAt: Date(),
                        creatorName: "Bob",
                        appVersion: "1.0",
                        shareVersion: "1.0"
                    ),
                    flashcards: []
                ),
                isPremium: false,
                onImport: { _ in },
                onCancel: {}
            )
            .previewDisplayName("Version Gratuite")
            
            // Version sans nom de créateur
            ImportDeckPreviewView(
                shareableDeck: PreviewShareableDeck(
                    metadata: .init(
                        id: "anonymous-deck",
                        name: "Sciences Physiques",
                        totalCards: 75,
                        createdAt: Date(),
                        creatorName: nil,
                        appVersion: "1.0",
                        shareVersion: "1.0"
                    ),
                    flashcards: []
                ),
                isPremium: false,
                onImport: { _ in },
                onCancel: {}
            )
            .previewDisplayName("Sans Créateur")
        }
    }
}
