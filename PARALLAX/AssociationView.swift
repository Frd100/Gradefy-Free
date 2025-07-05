//
//  AssociationView.swift
//  PARALLAX
//
//  Created by Farid on 6/29/25.
//

import UIKit
import Foundation
import SwiftUI


struct AssociationView: View {
    @ObservedObject var deck: FlashcardDeck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var allCards: [AssociationCard] = []
    @State private var selectedCards: Set<UUID> = []
    @State private var matchedPairs: Set<UUID> = []
    @State private var wrongSelectionCards: Set<UUID> = []
    @State private var correctMatches = 0
    @State private var attempts = 0
    @State private var showResult = false
    @State private var startTime = Date()
    @State private var showCompletionElements = false
    @State private var showStatsElements = false
    
    // ✅ BACKGROUND ADAPTATIF
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    private var flashcards: [Flashcard] {
        (deck.flashcards as? Set<Flashcard>)?.compactMap { $0 } ?? []
    }
    
    private var totalPairs: Int {
        6 // ✅ FIXE : toujours 6 paires parfaites
    }
    
    private var progress: Double {
        guard totalPairs > 0 else { return 0 }
        return Double(correctMatches) / Double(totalPairs)
    }
    
    private var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    private var formattedDuration: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    
    var body: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if !showResult {
                    headerSection
                }
                
                if showResult {
                    associationCompletionView
                } else {
                    associationContentView
                }
            }
        }
        .navigationBarHidden(true) // ✅ IMPORTANT : Cache la barre de navigation
        .onAppear {
            startTime = Date()
            generateAssociationCards()
        }
    }
    
    // ✅ HEADER AVEC ESPACEMENT RÉDUIT
    private var headerSection: some View {
        VStack(spacing: 10) { // ✅ RÉDUIT de 12 à 10
            HStack {
                Text(deck.name ?? "Association")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    HapticFeedbackManager.shared.impact(style: .light)
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color(.systemGray5)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            HStack {
                ProgressBar2(progress: progress)
                    .frame(width: UIScreen.main.bounds.width * 0.45)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            HStack {
                Text("\(correctMatches)/\(totalPairs)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20) // ✅ RÉDUIT de 30 à 20
    }
    
    // ✅ CONTENU PRINCIPAL AVEC POSITION AJUSTÉE POUR 12 CARTES
    private var associationContentView: some View {
        VStack {
            Spacer().frame(height: 20) // ✅ AJUSTÉ : moins d'espace en haut pour faire de la place
            
            LazyVGrid(columns: columns, spacing: 14) { // ✅ AJUSTÉ : espacement réduit de 16 à 14
                ForEach(allCards) { card in
                    AssociationCardView(
                        card: card,
                        isSelected: selectedCards.contains(card.id),
                        isMatched: matchedPairs.contains(card.matchId),
                        showWrongIndicator: wrongSelectionCards.contains(card.id)
                    ) {
                        selectCard(card)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer().frame(height: 20) // ✅ AJUSTÉ : moins d'espace en bas
        }
    }
    
    // ✅ RESTE DU CODE IDENTIQUE...
    private var associationCompletionView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            completionHeader
            completionStats
            
            Spacer()
            
            completionButtons
        }
        .padding(.horizontal, 24)
        .onAppear {
            HapticFeedbackManager.shared.notification(type: .success)
            
            withAnimation(.easeOut(duration: 0.6)) {
                showCompletionElements = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showStatsElements = true
                }
            }
        }
    }
    
    private var completionHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.primary)
                .opacity(showCompletionElements ? 1 : 0)
                .scaleEffect(showCompletionElements ? 1.0 : 0.9)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showCompletionElements)
            
            Text("Association terminée")
                .font(.title.weight(.medium))
                .foregroundColor(.primary)
                .opacity(showCompletionElements ? 1 : 0)
                .offset(y: showCompletionElements ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: showCompletionElements)
        }
    }
    
    private var completionStats: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(correctMatches)")
                            .font(.title.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("associations")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formattedDuration)
                            .font(.title.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("temps total")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
                    .opacity(0.3)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(attempts)")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.primary)
                        Text("tentatives")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(totalPairs)")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.primary)
                        Text("paires")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
                    )
            )
            .opacity(showStatsElements ? 1 : 0)
            .scaleEffect(showStatsElements ? 1 : 0.95)
            .animation(.easeOut(duration: 0.5), value: showStatsElements)
        }
    }
    
    private var completionButtons: some View {
        VStack(spacing: 16) {
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                restartAssociation()
            }) {
                Text("Refaire l'association")
                    .font(.headline.weight(.medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 30)
                                    .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                dismiss()
            }) {
                Text("Terminer")
                    .font(.headline.weight(.medium))
                    .foregroundColor(colorScheme == .light ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(colorScheme == .light ? .black : Color(.tertiarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 30)
                                    .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .opacity(showCompletionElements ? 1 : 0)
        .scaleEffect(showCompletionElements ? 1 : 0.95)
        .animation(.easeOut(duration: 0.6).delay(0.8), value: showCompletionElements)
        .padding(.bottom, 24)
    }
    
    // ✅ LOGIQUE DE JEU POUR 12 CARTES (6 PAIRES PARFAITES)
    private func generateAssociationCards() {
        let validFlashcards = flashcards.filter { card in
            guard let question = card.question, !question.isEmpty,
                  let answer = card.answer, !answer.isEmpty else {
                return false
            }
            return true
        }
        
        // ✅ ÉLIMINER LES DOUBLONS BASÉS SUR LE CONTENU
        var uniqueFlashcards: [Flashcard] = []
        var seenContent: Set<String> = []
        
        for flashcard in validFlashcards {
            let contentKey = "\(flashcard.question ?? "")|\(flashcard.answer ?? "")"
            if !seenContent.contains(contentKey) {
                seenContent.insert(contentKey)
                uniqueFlashcards.append(flashcard)
            }
        }
        
        print("🔍 Flashcards uniques trouvées: \(uniqueFlashcards.count)")
        
        // ✅ PRENDRE EXACTEMENT 6 PAIRES POUR 12 CARTES
        let cardsToUse = Array(uniqueFlashcards.shuffled().prefix(6))
        
        var cards: [AssociationCard] = []
        
        for flashcard in cardsToUse {
            // ✅ CRÉER UN ID UNIQUE POUR CHAQUE PAIRE
            let uniquePairId = UUID()
            
            cards.append(AssociationCard(
                id: UUID(),
                text: flashcard.question ?? "",
                matchId: uniquePairId,
                cardType: .question
            ))
            
            cards.append(AssociationCard(
                id: UUID(),
                text: flashcard.answer ?? "",
                matchId: uniquePairId,
                cardType: .answer
            ))
        }
        
        // ✅ Mélanger toutes les 12 cartes ensemble
        allCards = cards.shuffled()
        print("✅ 12 cartes générées (6 paires parfaites)")
    }

    
    private func selectCard(_ card: AssociationCard) {
        guard !matchedPairs.contains(card.matchId) else { return }
        
        if selectedCards.contains(card.id) {
            selectedCards.remove(card.id)
            HapticFeedbackManager.shared.selection()
        } else if selectedCards.count < 2 {
            selectedCards.insert(card.id)
            HapticFeedbackManager.shared.selection()
            
            if selectedCards.count == 2 {
                checkMatch()
            }
        }
    }
    
    private func checkMatch() {
        attempts += 1
        
        let selectedCardsList = allCards.filter { selectedCards.contains($0.id) }
        guard selectedCardsList.count == 2 else { return }
        
        let card1 = selectedCardsList[0]
        let card2 = selectedCardsList[1]
        
        if card1.matchId == card2.matchId && card1.cardType != card2.cardType {
            HapticFeedbackManager.shared.notification(type: .success)
            
            matchedPairs.insert(card1.matchId)
            correctMatches += 1
            selectedCards.removeAll()
            
            if correctMatches == totalPairs {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showResult = true
                }
            }
        } else {
            HapticFeedbackManager.shared.notification(type: .error)
            
            wrongSelectionCards = selectedCards
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    wrongSelectionCards.removeAll()
                    selectedCards.removeAll()
                }
            }
        }
    }
    
    private func restartAssociation() {
        correctMatches = 0
        attempts = 0
        selectedCards.removeAll()
        matchedPairs.removeAll()
        wrongSelectionCards.removeAll()
        showResult = false
        showCompletionElements = false
        showStatsElements = false
        startTime = Date()
        generateAssociationCards()
    }
}


// ✅ MODÈLES DE DONNÉES RÉVISÉS
struct AssociationCard: Identifiable {
    let id: UUID
    let text: String
    let matchId: UUID
    let cardType: CardType
}

enum CardType {
    case question, answer
}
struct AssociationCardView: View {
    let card: AssociationCard
    let isSelected: Bool
    let isMatched: Bool
    let showWrongIndicator: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackground: Color {
        if isMatched {
            return .green.opacity(0.1)
        } else if showWrongIndicator {
            return .red.opacity(0.1)
        } else if isSelected {
            return .blue.opacity(0.1)
        } else {
            return Color(.secondarySystemGroupedBackground)
        }
    }
    
    private var borderColor: Color {
        if isMatched {
            return .green
        } else if showWrongIndicator {
            return .red
        } else if isSelected {
            return .blue
        } else {
            return Color(.separator).opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        (isSelected || isMatched || showWrongIndicator) ? 2 : 1
    }
    
    var body: some View {
        Button(action: {
            guard !isMatched else { return }
            onTap()
        }) {
            ZStack {
                // ✅ FOND DE LA CARTE
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
                
                VStack {
                    // ✅ ZONE INDICATEUR AVEC HAUTEUR FIXE
                    ZStack {
                        // ✅ Espace réservé toujours présent (invisible)
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .opacity(0) // ✅ INVISIBLE mais prend l'espace
                        
                        // ✅ Indicateur visible uniquement si nécessaire
                        if showWrongIndicator {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(height: 20) // ✅ HAUTEUR FIXE pour la zone indicateur
                    .padding(.top, 8)
                    
                    // ✅ TEXTE PARFAITEMENT CENTRÉ (position fixe)
                    Text(card.text)
                        .font(.caption.weight(.medium))
                        .foregroundColor(isMatched ? .green : (showWrongIndicator ? .red : .primary))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                    
                    Spacer()
                }
            }
            .frame(width: 110, height: 140) // ✅ TAILLE FIXE CONSERVÉE
        }
        .buttonStyle(.plain)
        .disabled(isMatched)
        .opacity(isMatched ? 0.6 : 1.0)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isMatched)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: showWrongIndicator)
    }
}
