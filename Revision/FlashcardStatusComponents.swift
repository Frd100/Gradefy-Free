//
//  FlashcardStatusComponents.swift
//  PARALLAX
//
//  Composants pour afficher les statuts des flashcards
//

import SwiftUI
import CoreData

// ✅ Vue pour afficher le statut d'une carte
struct FlashcardStatusView: View {
    let card: Flashcard
    @AppStorage("showCardStatus") private var showCardStatus = true
    @AppStorage("isFreeMode") private var isFreeMode = false

    @ViewBuilder
    var body: some View {
        if showCardStatus {
            if isFreeMode {
                FreeModeStatusView(card: card)
            } else {
                let srsData = SimpleSRSManager.shared.getSRSData(card: card)
                let status = CardStatusUI.getStatus(from: srsData)

                HStack(spacing: 4) {
                    Image(systemName: status.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(status.color)

                    if let timeUntilNext = status.timeUntilNext {
                        Text(timeUntilNext)
                            .font(.subheadline)
                            .foregroundColor(status.color)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
}

private struct FreeModeStatusView: View {
    let card: Flashcard

    var body: some View {
        let status = SimpleSRSManager.shared.getFreeModeStatus(for: card)
        let baseStatus: SimpleSRSManager.FreeModeStatus = (status == .mastered) ? .mastered : .toStudy

        HStack(spacing: 6) {
            if status == .new {
                iconView(for: .new)
            }
            iconView(for: baseStatus)
        }
    }

    private func iconView(for status: SimpleSRSManager.FreeModeStatus) -> some View {
        Image(systemName: status.icon)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(status.color)
    }
}

// ✅ Sheet des paramètres pour l'affichage des statuts
struct FlashcardSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("showCardStatus") private var showCardStatus = true
    @AppStorage("isFreeMode") private var isFreeMode = false

    
    // ✅ NOUVEAU : Paramètre deck pour afficher les vraies statistiques
    let deck: FlashcardDeck?
    
    // ✅ NOUVEAU : Initialiseur avec deck optionnel
    init(deck: FlashcardDeck? = nil) {
        self.deck = deck
    }
    
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                adaptiveBackground.ignoresSafeArea()
                
                Form {
                    // ✅ SECTION COMPACTE : Mode de révision (Style Sheet iOS)
                    Section {
                                                 // Mode SM-2
                         Button(action: {
                             HapticFeedbackManager.shared.impact(style: .light)
                             isFreeMode = false
                         }) {
                             HStack(spacing: 12) {
                                 Image(systemName: "arrow.up.circle.badge.clock")
                                     .font(.system(size: 16, weight: .medium))
                                     .foregroundColor(isFreeMode ? .secondary : .blue)
                                     .frame(width: 24)
                                 
                                 VStack(alignment: .leading, spacing: 2) {
                                     HStack {
                                         Text("Mode répétition espacée")
                                             .font(.body.weight(.medium))
                                             .foregroundColor(isFreeMode ? .secondary : .primary)
                                     }
                                     
                                     Text("Algorithme de répétition espacée")
                                         .font(.caption)
                                         .foregroundColor(.secondary)
                                 }
                                 
                                 Spacer()
                                 
                                 if !isFreeMode {
                                     Image(systemName: "checkmark.circle.fill")
                                         .font(.system(size: 16, weight: .medium))
                                         .foregroundColor(.blue)
                                 }
                             }
                             .contentShape(Rectangle())
                         }
                        
                                                 // Mode libre
                         Button(action: {
                             HapticFeedbackManager.shared.impact(style: .light)
                             isFreeMode = true
                         }) {
                             HStack(spacing: 12) {
                                 Image(systemName: "leaf")
                                     .font(.system(size: 16, weight: .medium))
                                     .foregroundColor(isFreeMode ? .blue : .secondary)
                                     .frame(width: 24)
                                 
                                 VStack(alignment: .leading, spacing: 2) {
                                     HStack {
                                         Text("Mode libre")
                                             .font(.body.weight(.medium))
                                             .foregroundColor(isFreeMode ? .primary : .secondary)
                                     }
                                     
                                     Text("Révision sans contraintes")
                                         .font(.caption)
                                         .foregroundColor(.secondary)
                                 }
                                 
                                 Spacer()
                                 
                                 if isFreeMode {
                                     Image(systemName: "checkmark.circle.fill")
                                         .font(.system(size: 16, weight: .medium))
                                         .foregroundColor(.blue)
                                 }
                             }
                             .contentShape(Rectangle())
                         }
                    } header: {
                        Text("Mode de révision")
                    } footer: {
                        Text("La répétition espacée optimise vos révisions. Le mode libre permet de pratiquer sans contraintes.")
                    }
                    
                    Section {
                        Toggle("Afficher les statuts des cartes", isOn: $showCardStatus)
                    } header: {
                        Text("Affichage")
                    } footer: {
                        Text("Permet de voir le statut d'une carte")
                    }
                    

                    
                    // ✅ WIDGET LIMITES DU DECK - Maintenant avec vraies données
                    if let deck = deck {
                        Section {
                            DeckLimitsWidget(deck: deck)
                        } header: {
                            Text("Limites de cette liste")
                        } footer: {
                            Text("Limites de cette liste")
                        }
                    }
                    
                    // ✅ STATUTS SRS : Structure améliorée et alignée
                    Section {
                        VStack(spacing: 0) {
                            StatusExampleRow(
                                status: CardStatus(message: "Nouvelle", color: Color.cyan, icon: "sparkles"),
                                description: "Carte que vous n'avez jamais étudiée"
                            )
                            Divider()
                            StatusExampleRow(
                                status: CardStatus(message: "À étudier", color: Color.orange, icon: "clock"),
                                description: "Il est temps d'étudier cette carte"
                            )
                            Divider()
                            StatusExampleRow(
                                status: CardStatus(message: "Acquis", color: Color.blue, icon: "star"),
                                description: "Vous commencez à bien connaître cette carte"
                            )
                            Divider()
                            StatusExampleRow(
                                status: CardStatus(message: "Maîtrisé", color: Color.purple, icon: "checkmark.circle", timeUntilNext: "2j"),
                                description: "Vous maîtrisez cette carte"
                            )
                            Divider()
                            StatusExampleRow(
                                status: CardStatus(message: "En retard", color: Color.red, icon: "exclamationmark.triangle"),
                                description: "Vous avez du retard sur l'étude de cette carte"
                            )
                        }
                    } header: {
                        Text("Signification des statuts")
                    } footer: {
                        Text("Les délais affichés sont approximatifs. Une carte à réviser aujourd'hui apparaît toujours en \"À réviser\".")
                    }


                }
            }
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminé") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// ✅ Ligne d'exemple pour expliquer les statuts - Icône simple
struct StatusExampleRow: View {
    let status: CardStatus
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            // ✅ Icône simple avec couleur
            Image(systemName: status.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(status.color)
                .frame(width: 20, height: 20)
            
            // ✅ Contenu textuel aligné
            VStack(alignment: .leading, spacing: 2) {
                Text(status.message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}



// ✅ Bouton Settings à ajouter dans la toolbar
struct FlashcardSettingsButton: View {
    @State private var showingSettings = false
    
    // ✅ NOUVEAU : Paramètre deck optionnel
    let deck: FlashcardDeck?
    
    // ✅ NOUVEAU : Initialiseur avec deck optionnel
    init(deck: FlashcardDeck? = nil) {
        self.deck = deck
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.impact(style: .light)
            showingSettings = true
        }) {
            Image(systemName: "gear")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 20, height: 20)
        }
        .sheet(isPresented: $showingSettings) {
            FlashcardSettingsSheet(deck: deck)
        }
    }
}
