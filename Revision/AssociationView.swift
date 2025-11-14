//
//  AssociationView.swift
//  PARALLAX
//
//  Created by  on 6/29/25.
//

import UIKit
import Foundation
import SwiftUI

struct AssociationView: View {
    @ObservedObject var deck: FlashcardDeck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("isFreeMode") private var isFreeMode = false
    
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
    @State private var showIntroduction = true // ✅ NOUVEAU : Écran d'introduction
    
    // ✅ NOUVEAU : Système de sessions multiples
    @State private var currentBatch = 1
    @State private var usedCards: [Flashcard] = []
    @State private var showContinueOption = false
    @State private var showResetConfirmation = false // ✅ NOUVEAU : Confirmation reset
    @State private var totalBatches = 1
    @ObservedObject private var activityManager = RevisionActivityManager.shared
    
    // ✅ STATISTIQUES TOTALES POUR TOUTES LES SÉRIES
    @State private var totalCorrectMatches = 0
    @State private var totalAttempts = 0

    // ✅ BACKGROUND ADAPTATIF
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    private var flashcards: [Flashcard] {
        (deck.flashcards as? Set<Flashcard>)?.compactMap { $0 } ?? []
    }
    
    private var totalPairs: Int {
        allCards.count / 2 // Nombre réel de paires générées
    }
    
    private var debugInfo: String {
        "Flashcards: \(flashcards.count), Cartes: \(allCards.count), Paires: \(totalPairs)"
    }
    
    
    private func generateAssociationCards() {
        // 1️⃣ Filtrer les cartes valides
        let allValidCards = flashcards.filter { card in
            guard let question = card.question, !question.isEmpty,
                  let answer = card.answer, !answer.isEmpty else {
                return false
            }
            return true
        }
        
        // 2️⃣ Calculer le nombre total de batches possibles (avec minimum 3 cartes par série)
        let fullBatches = allValidCards.count / 6  // Batches complets de 6 cartes
        let remainingCards = allValidCards.count % 6
        let hasPartialBatch = remainingCards >= 3  // Batch partiel si au moins 3 cartes restantes
        totalBatches = max(1, fullBatches + (hasPartialBatch ? 1 : 0))
        
        // 3️⃣ INTÉGRATION SM-2 vs MODE LIBRE : Sélection intelligente pour ce batch
        // Calculer combien de cartes on peut encore utiliser
        let remainingValidCards = allValidCards.filter { !usedCards.contains($0) }
        let targetCardsForBatch = min(remainingValidCards.count, 6)
        let minCardsForBatch = min(targetCardsForBatch, 3)  // Minimum 3 cartes
        
        let selectedCards: [Flashcard]
        if isFreeMode {
            // Mode libre : cartes aléatoires parmi les non utilisées
            selectedCards = remainingValidCards.shuffled()
            print("🆓 [Association] Mode libre: \(selectedCards.count) cartes sélectionnées aléatoirement")
        } else {
            // Mode SM-2 : sélection intelligente
            selectedCards = SimpleSRSManager.shared.getSmartCards(
                deck: deck, 
                minCards: minCardsForBatch, 
                excludeCards: usedCards
            ).filter { card in
                allValidCards.contains(card)
            }
            print("🎯 [Association] Mode SM-2: \(selectedCards.count) cartes sélectionnées intelligemment")
        }
        
        print("🔍 [Association] Batch \(currentBatch)/\(totalBatches) - Cartes trouvées: \(selectedCards.count), Target: \(targetCardsForBatch)")
        
        // 4️⃣ Prendre jusqu'à 6 cartes (ou moins si c'est le dernier batch)
        let numberOfPairs = min(selectedCards.count, targetCardsForBatch)
        let cardsToUse = Array(selectedCards.prefix(numberOfPairs))
        
        // 5️⃣ Ajouter les cartes utilisées pour éviter les doublons
        usedCards += cardsToUse
        
        // 5️⃣ Générer les cartes d'association
        var cards: [AssociationCard] = []
        
        for flashcard in cardsToUse {
            let uniquePairId = UUID()
            let flashcardId = flashcard.id ?? UUID()
            
            cards.append(AssociationCard(
                id: UUID(),
                text: flashcard.question ?? "",
                matchId: uniquePairId,
                cardType: .question,
                originalFlashcardId: flashcardId,
                contentType: flashcard.questionContentType,
                imageFileName: flashcard.questionImageFileName,
                imageData: flashcard.questionImageData,
                audioFileName: flashcard.questionAudioFileName,
                audioDuration: flashcard.questionAudioDuration
            ))
            
            cards.append(AssociationCard(
                id: UUID(),
                text: flashcard.answer ?? "",
                matchId: uniquePairId,
                cardType: .answer,
                originalFlashcardId: flashcardId,
                contentType: flashcard.answerContentType,
                imageFileName: flashcard.answerImageFileName,
                imageData: flashcard.answerImageData,
                audioFileName: flashcard.answerAudioFileName,
                audioDuration: flashcard.answerAudioDuration
            ))
        }
        
        allCards = cards.shuffled()
        print("✅ \(numberOfPairs) paires générées (\(allCards.count) cartes total)")
    }
    
    private var progress: Double {
        guard totalPairs > 0 else { return 0 }
        return Double(correctMatches) / Double(totalPairs)
    }
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    
    // MARK: - Introduction View
    private var introductionView: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Bouton X en haut à droite
                HStack {
                    Spacer()
                    Button(action: {
                        HapticFeedbackManager.shared.impact(style: .soft)
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color(.systemGray6)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                // Titre du mode
                Text("Association")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.primary)
                
                // Icône du mode
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.purple)
                
                // Texte explicatif
                VStack(spacing: 16) {
                    Text("Associez les questions avec leurs réponses")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Touchez deux cartes pour les associer. Trouvez toutes les paires pour gagner !")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Bouton commencer
                Button(action: {
                    HapticFeedbackManager.shared.impact(style: .soft)
                    showIntroduction = false
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Commencer")
                            .font(.title3.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.purple)
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
    }
    
    var body: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()
            
            if showIntroduction {
                introductionView
            } else {
                VStack(spacing: 0) {
                    // ✅ HEADER TOUJOURS FIXÉ EN HAUT
                    if !showResult {
                        headerSection
                    }
                    
                    // ✅ CONTENU PRINCIPAL (pas de vue d'erreur)
                    if showResult {
                        associationCompletionView
                    } else {
                        associationContentView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startTime = Date()
            generateAssociationCards()
            // ✅ AJOUTER le tracking
            activityManager.startWeeklyTracking()
        }
        .onDisappear {
            activityManager.endWeeklyTracking()
            
            if let deckId = deck.id?.uuidString {
                let cache = SM2OptimizationCache.shared
                cache.invalidateDeckStats(forDeckId: deckId)
                cache.invalidateCardSelections(forDeckId: deckId)
            }
        }
        .alert("Recommencer l'association", isPresented: $showResetConfirmation) {
            Button("Annuler", role: .cancel) { }
            Button("Recommencer", role: .destructive) {
                resetAssociation()
            }
        } message: {
            Text("Voulez-vous recommencer l'association depuis le début ? Votre progression actuelle sera perdue.")
        }
    }
    
    // MARK: - Reset Functions
    private func resetAssociation() {
        // Réinitialiser tous les états
        correctMatches = 0
        totalCorrectMatches = 0
        showResult = false
        showCompletionElements = false
        showStatsElements = false
        showIntroduction = true
        showContinueOption = false
        currentBatch = 1
        usedCards = []
        
        // Nettoyer la progression sauvegardée
        SimpleSRSManager.shared.clearAssociationProgress(for: deck)
        
        // Régénérer les cartes
        generateAssociationCards()
        
        print("🔄 Association réinitialisée")
    }
    
    private var headerSection: some View {
        let isSmallScreen = UIScreen.main.bounds.height < 700
        
        return VStack(spacing: isSmallScreen ? 4 : 8) {
            HStack {
                Button(action: {
                    HapticFeedbackManager.shared.impact(style: .soft)
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color(.systemGray5)))
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(deck.name ?? String(localized: "association_game"))
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    HapticFeedbackManager.shared.impact(style: .soft)
                    showResetConfirmation = true
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color(.systemGray5)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, isSmallScreen ? 0 : 8)
            
            ProgressBar2(progress: progress)
                .padding(.horizontal, 20)
            
            ZStack {
                // ✅ Compteur centré
                Text("\(correctMatches)/\(totalPairs)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                
                // ✅ Indicateur de série positionné à droite
                if totalBatches > 1 {
                    HStack {
                        Spacer()
                        Text("Série \(currentBatch)/\(totalBatches)")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, isSmallScreen ? 8 : 20)
        .frame(height: isSmallScreen ? 70 : 100) // Hauteur réduite pour petits écrans
    }
    
    // MARK: - Game Logic (à ajouter à la fin de la struct)

    private func selectCard(_ card: AssociationCard) {
        guard !matchedPairs.contains(card.matchId) else { return }
        
        if selectedCards.contains(card.id) {
            selectedCards.remove(card.id)
            // Haptique supprimé : sera déclenché uniquement au résultat du match
        } else if selectedCards.count < 2 {
            selectedCards.insert(card.id)
            // Haptique supprimé : sera déclenché uniquement au résultat du match
            
            if selectedCards.count == 2 {
                checkMatch()
            }
        }
    }

    private func checkMatch() {
        attempts += 1
        totalAttempts += 1  // ✅ Tracker les tentatives totales
        
        let selectedCardsList = allCards.filter { selectedCards.contains($0.id) }
        guard selectedCardsList.count == 2 else { return }
        
        let card1 = selectedCardsList[0]
        let card2 = selectedCardsList[1]
        
        if card1.matchId == card2.matchId && card1.cardType != card2.cardType {
            HapticFeedbackManager.shared.impact(style: .soft)
            
            matchedPairs.insert(card1.matchId)
            correctMatches += 1
            totalCorrectMatches += 1  // ✅ Tracker les matches corrects totaux
            selectedCards.removeAll()
            
            // ✅ INTÉGRATION SM-2 vs MODE LIBRE pour Association (match correct)
            let flashcard1 = flashcards.first(where: { $0.id == card1.originalFlashcardId })
            let flashcard2 = flashcards.first(where: { $0.id == card2.originalFlashcardId })
            
            if !isFreeMode, let f1 = flashcard1, let f2 = flashcard2 {
                // Mode SM-2 : traiter le résultat (Quality 2 pour les 2 cartes)
                let operationId = UUID().uuidString
                SimpleSRSManager.shared.processAssociationResult(
                    card1: f1,
                    card2: f2,
                    quality: 2,
                    context: viewContext,
                    operationId: operationId
                )
                print("🎯 [Association] Match correct traité en mode SM-2: Quality 2 pour 2 cartes")
            } else {
                // Mode libre : pas de mise à jour SM-2
                print("🆓 [Association] Mode libre: pas de mise à jour SM-2")
                if let f1 = flashcard1 {
                    SimpleSRSManager.shared.markCardReviewedInFreeMode(
                        f1,
                        wasCorrect: true,
                        context: viewContext
                    )
                }
                if let f2 = flashcard2 {
                    SimpleSRSManager.shared.markCardReviewedInFreeMode(
                        f2,
                        wasCorrect: true,
                        context: viewContext
                    )
                }
            }
            
            if correctMatches == totalPairs {
                // ✅ Ne montrer l'écran de complétion que si c'est le dernier batch
                if canContinueToNextBatch {
                    // Passer automatiquement au batch suivant
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        continueToNextBatch()
                    }
                } else {
                    // Afficher l'écran de complétion final
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showResult = true
                    }
                }
            }
        } else {
            HapticFeedbackManager.shared.impact(style: .soft)
            
            wrongSelectionCards = selectedCards
            
            // ✅ INTÉGRATION SM-2 vs MODE LIBRE pour Association (match incorrect)
            // Pénaliser les 2 cartes concernées par l'erreur
            let flashcard1 = flashcards.first(where: { $0.id == card1.originalFlashcardId })
            let flashcard2 = flashcards.first(where: { $0.id == card2.originalFlashcardId })
            
            if !isFreeMode, let f1 = flashcard1, let f2 = flashcard2 {
                // Mode SM-2 : traiter le résultat (Quality 1 pour les 2 cartes)
                let operationId = UUID().uuidString
                SimpleSRSManager.shared.processAssociationResult(
                    card1: f1,
                    card2: f2,
                    quality: 1,
                    context: viewContext,
                    operationId: operationId
                )
                print("🎯 [Association] Match incorrect traité en mode SM-2: Quality 1 pour 2 cartes")
            } else {
                // Mode libre : pas de mise à jour SM-2
                print("🆓 [Association] Mode libre: pas de mise à jour SM-2")
                if let f1 = flashcard1 {
                    SimpleSRSManager.shared.markCardReviewedInFreeMode(
                        f1,
                        wasCorrect: false,
                        context: viewContext
                    )
                }
                if let f2 = flashcard2 {
                    SimpleSRSManager.shared.markCardReviewedInFreeMode(
                        f2,
                        wasCorrect: false,
                        context: viewContext
                    )
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    wrongSelectionCards.removeAll()
                    selectedCards.removeAll()
                }
            }
        }
    }

    private func restartAssociation() {
        // Reset complet de la session
        currentBatch = 1
        usedCards.removeAll()
        correctMatches = 0
        attempts = 0
        selectedCards.removeAll()
        matchedPairs.removeAll()
        wrongSelectionCards.removeAll()
        showResult = false
        showCompletionElements = false
        showStatsElements = false
        startTime = Date()
        // ✅ Réinitialiser aussi les statistiques totales
        totalCorrectMatches = 0
        totalAttempts = 0
        generateAssociationCards()
    }
    
    // ✅ NOUVELLES MÉTHODES : Gestion des sessions multiples
    private var canContinueToNextBatch: Bool {
        // Vérifier s'il reste des cartes non utilisées ET si on n'a pas atteint le dernier batch
        let allValidCards = flashcards.filter { card in
            guard let question = card.question, !question.isEmpty,
                  let answer = card.answer, !answer.isEmpty else {
                return false
            }
            return true
        }
        
        let remainingCards = allValidCards.filter { card in
            !usedCards.contains(card)
        }
        
        // On peut continuer si on n'est pas au dernier batch ET qu'il reste au moins 3 cartes
        return currentBatch < totalBatches && remainingCards.count >= 3
    }
    
    private func continueToNextBatch() {
        currentBatch += 1
        
        // Reset pour le nouveau batch
        correctMatches = 0
        attempts = 0
        selectedCards.removeAll()
        matchedPairs.removeAll()
        wrongSelectionCards.removeAll()
        showResult = false
        showCompletionElements = false
        showStatsElements = false
        startTime = Date()
        
        // Générer le nouveau batch
        generateAssociationCards()
    }

    
    // ✅ CONTENU PRINCIPAL CENTRÉ DANS L'ESPACE DISPONIBLE
    private var associationContentView: some View {
        let isSmallScreen = UIScreen.main.bounds.height < 700
        
        return GeometryReader { geometry in
            VStack {
                Spacer()
                    .frame(height: isSmallScreen ? 10 : 20)
                
                LazyVGrid(columns: columns, spacing: isSmallScreen ? 10 : 14) {
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
                .padding(.horizontal, isSmallScreen ? 16 : 20)
                
                Spacer()
                    .frame(height: isSmallScreen ? 10 : 20)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    // ✅ ÉCRAN DE COMPLÉTION (inchangé)
    private var associationCompletionView: some View {
        let isSmallScreen = UIScreen.main.bounds.height < 700
        
        return VStack(spacing: isSmallScreen ? 20 : 32) {
            Spacer()
                .frame(height: isSmallScreen ? 10 : 20)
            
            completionHeader
            completionStats
            
            Spacer()
                .frame(height: isSmallScreen ? 10 : 20)
            
            completionButtons
        }
        .padding(.horizontal, isSmallScreen ? 20 : 24)
        .onAppear {
            HapticFeedbackManager.shared.impact(style: .soft)
            
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
            
            Text(String(localized: "association_completed"))
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
                        Text("\(totalCorrectMatches)")
                            .font(.title.weight(.semibold))
                            .foregroundColor(.primary)
                        Text(String(localized: "stats_total"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
                    .opacity(0.3)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalAttempts)")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.primary)
                        Text(String(localized: "stats_attempts"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(totalCorrectMatches)")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.primary)
                        Text("Paires totales")
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
            // ✅ NOUVEAU : Bouton Continuer si plus de cartes disponibles
            if canContinueToNextBatch {
                Button(action: {
                    HapticFeedbackManager.shared.impact(style: .soft)
                    continueToNextBatch()
                }) {
                    HStack {
                        Text("Continuer")
                        Text("(\(currentBatch + 1)/\(totalBatches))")
                            .foregroundColor(.secondary)
                    }
                    .font(.headline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.blue)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .soft)
                restartAssociation()
            }) {
                Text(String(localized: "action_retry_association"))
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
                HapticFeedbackManager.shared.impact(style: .soft)
                activityManager.endWeeklyTracking()
                dismiss()
            }) {
                Text(String(localized: "action_finish"))
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
}



// ✅ MODÈLES DE DONNÉES RÉVISÉS
struct AssociationCard: Identifiable {
    let id: UUID
    let text: String
    let matchId: UUID
    let cardType: CardType
    let originalFlashcardId: UUID  // ✅ ID de la flashcard originale
    let contentType: FlashcardContentType
    let imageFileName: String?
    let imageData: Data?
    let audioFileName: String?
    let audioDuration: TimeInterval
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
                
                VStack(spacing: 4) {
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
                    
                    // ✅ TEXTE EN HAUT (si présent)
                    if !card.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(card.text)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(isMatched ? .green : (showWrongIndicator ? .red : .primary))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 4)
                    }
                    
                    // ✅ MÉDIA EN BAS
                    switch card.contentType {
                    case .text:
                        if card.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(card.text)
                                .font(.caption2.weight(.medium))
                                .foregroundColor(isMatched ? .green : (showWrongIndicator ? .red : .primary))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 4)
                        }
                        
                    case .image:
                        if let fileName = card.imageFileName,
                           let image = MediaStorageManager.shared.loadImage(fileName: fileName, data: card.imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 80, maxHeight: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .clipped()
                        }
                        
                    case .audio:
                        if let fileName = card.audioFileName {
                            Button(action: {
                                if AudioManager.shared.isPlaying && AudioManager.shared.playingFileName == fileName {
                                    AudioManager.shared.stopAudio()
                                } else {
                                    AudioManager.shared.playAudio(fileName: fileName)
                                }
                            }) {
                                Image(systemName: AudioManager.shared.isPlaying && AudioManager.shared.playingFileName == fileName ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
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
