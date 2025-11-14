//
//  QuizQuestion.swift
//  PARALLAX
//
//  Created by  on 7/21/25.
//
import SwiftUI
import UIKit
import Foundation
import CoreData


struct QuizQuestion {
    let id = UUID()
    let question: String
    let correctAnswer: String
    let allAnswers: [String]
    let correctIndex: Int
    let originalFlashcard: Flashcard? // ✅ Ajouté pour accéder aux médias
}

// MARK: - Quiz View

struct QuizView: View {
    @ObservedObject var deck: FlashcardDeck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var activityManager = RevisionActivityManager.shared
    @AppStorage("isFreeMode") private var isFreeMode = false
    @State private var quizQuestions: [QuizQuestion] = []
    @State private var currentQuestionIndex = 0
    @State private var score = 0
    @State private var selectedAnswerIndex: Int? = nil
    @State private var showResult = false
    @State private var isAnswerSelected = false
    @State private var showCompletionAlert = false
    @State private var showCompletionElements = false
    @State private var showStatsElements = false
    @State private var showIntroduction = true // ✅ NOUVEAU : Écran d'introduction
    @State private var showSettings = false // ✅ NOUVEAU : Paramètres
    @State private var showResetConfirmation = false // ✅ NOUVEAU : Confirmation reset
    
    // ✅ BACKGROUND ADAPTATIF : F6F7FB seulement en mode clair
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    var flashcards: [Flashcard] {
        (deck.flashcards as? Set<Flashcard>)?.compactMap { $0 } ?? []
    }
    
    private var flashcardCount: Int {
        (deck.flashcards as? Set<Flashcard>)?.count ?? 0
    }
    
    private var progress: Double {
        guard !quizQuestions.isEmpty else { return 0 }
        return Double(currentQuestionIndex) / Double(quizQuestions.count)
    }
    
    private var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < quizQuestions.count else { return nil }
        return quizQuestions[currentQuestionIndex]
    }
    
    var body: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()  // ✅ Background adaptatif
            
            if showIntroduction {
                introductionView
            } else {
                VStack(spacing: 0) {
                    if !showResult {
                        headerSection
                    }
                    
                    if showResult {
                        quizCompletionView
                    } else {
                        VStack(spacing: 0) {
                            questionContentView
                            
                            // ✅ SPACER LIMITÉ POUR RÉDUIRE L'ESPACE ENTRE QUESTION ET RÉPONSES
                            Spacer()
                                .frame(height: 20)
                            
                            // ✅ TEXTE "CHOISISSEZ LA BONNE RÉPONSE" AU-DESSUS DES RÉPONSES
                            chooseAnswerText
                            
                            // ✅ RÉPONSES EN BAS - REMONTÉES
                            if let question = currentQuestion {
                                VStack(spacing: 16) {
                                    ForEach(0..<question.allAnswers.count, id: \.self) { index in
                                        answerButton(
                                            text: question.allAnswers[index],
                                            index: index,
                                            isCorrect: index == question.correctIndex
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                // ✅ SUPPRIMÉ LE PADDING BOTTOM POUR PERMETTRE L'EXTENSION
                                .id("answers-\(question.id)")
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing),
                                    removal: .move(edge: .leading)
                                ))
                            }
                            // ✅ SUPPRIMÉ LE SPACER POUR ÉLIMINER L'ESPACE EN DESSOUS DES RÉPONSES
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onAppear {
            generateQuizQuestions()
            activityManager.startWeeklyTracking()
        }
        .onDisappear {  // ✅ AJOUTER si pas déjà présent
            activityManager.endWeeklyTracking()
            
        if let deckId = deck.id?.uuidString {
            let cache = SM2OptimizationCache.shared
            cache.invalidateDeckStats(forDeckId: deckId)
            cache.invalidateCardSelections(forDeckId: deckId)
        }
        }
        .alert("Recommencer le quiz", isPresented: $showResetConfirmation) {
            Button("Annuler", role: .cancel) { }
            Button("Recommencer", role: .destructive) {
                resetQuiz()
            }
        } message: {
            Text("Voulez-vous recommencer le quiz depuis le début ? Votre progression actuelle sera perdue.")
        }
    }
    
    // MARK: - Reset Functions
    private func resetQuiz() {
        // Réinitialiser tous les états
        currentQuestionIndex = 0
        score = 0
        isAnswerSelected = false
        showResult = false
        showCompletionAlert = false
        showCompletionElements = false
        showStatsElements = false
        showIntroduction = true
        
        // Nettoyer la progression sauvegardée
        SimpleSRSManager.shared.clearQuizProgress(for: deck)
        
        // Régénérer les questions
        generateQuizQuestions()
        
        print("🔄 Quiz réinitialisé")
    }
    
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
                Text("Quiz")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.primary)
                
                // Icône du mode
                Image(systemName: "questionmark.app.fill")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.orange)
                
                // Texte explicatif
                VStack(spacing: 16) {
                    Text("Testez vos connaissances de manière ludique")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Sélectionnez la bonne réponse parmi les options proposées")
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
                            .fill(Color.orange)
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
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
                    Text(deck.name ?? String(localized: "quiz_game"))
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
            
            HStack {
                Spacer()
                Text("\(currentQuestionIndex)/\(quizQuestions.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, isSmallScreen ? 8 : 20)
        .frame(height: isSmallScreen ? 70 : 100) // Hauteur réduite pour petits écrans
    }

    
    private var questionContentView: some View {
        let isSmallScreen = UIScreen.main.bounds.height < 700
        
        if let question = currentQuestion {
            return AnyView(
                Group {
                    // ✅ GESTION MÉDIA : Utiliser FlashcardContentView si média, sinon Text
                    if let flashcard = question.originalFlashcard, 
                       (flashcard.questionImageFileName != nil || flashcard.questionAudioFileName != nil) {
                        // ✅ Question avec média - Version Quiz optimisée
                        quizMediaContentView(for: flashcard)
                    } else {
                        // ✅ Question texte uniquement
                        Text(question.question)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)  // ✅ LIMITE À 3 LIGNES
                            .truncationMode(.tail)  // ✅ POINTS DE SUSPENSION
                            .fixedSize(horizontal: false, vertical: true)  // ✅ FORCER LE RETOUR À LA LIGNE
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 0)  // ✅ SUPPRIMÉ LE PADDING VERTICAL
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: isSmallScreen ? 150 : 200) // ✅ ZONE DÉDIÉE ADAPTATIVE POUR LA QUESTION
                .padding(.bottom, 0)  // ✅ SUPPRIMÉ LE PADDING BOTTOM
                .id(question.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            )
        } else {
            return AnyView(EmptyView())
        }
    }
    
    // ✅ VERSION QUIZ OPTIMISÉE : Gestion des médias avec taille limitée
    @ViewBuilder
    private func quizMediaContentView(for flashcard: Flashcard) -> some View {
        let isSmallScreen = UIScreen.main.bounds.height < 700
        
        switch flashcard.questionContentType {
        case .text:
            Text(flashcard.question ?? "—")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 0)  // ✅ SUPPRIMÉ LE PADDING VERTICAL
                
        case .image:
            if let fileName = flashcard.questionImageFileName,
               let image = MediaStorageManager.shared.loadImage(fileName: fileName, data: flashcard.questionImageData) {
                VStack(spacing: 0) {
                    // ✅ Image avec taille strictement limitée pour Quiz
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                                                            .frame(maxWidth: .infinity, maxHeight: isSmallScreen ? 120 : 180) // ✅ IMAGES ADAPTATIVES SELON LA TAILLE D'ÉCRAN
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .clipped()
                        .background(Color.clear)
                        .compositingGroup()
                    
                    // ✅ Texte de la question en dessous si présent et non vide
                    if let questionText = flashcard.question, 
                       !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(questionText)
                            .font(.body.weight(.medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 0)  // ✅ SUPPRIMÉ LE PADDING VERTICAL
                .padding(.top, 0)  // ✅ PADDING TOP REMIS À ZÉRO
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Image introuvable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120) // ✅ Hauteur fixe même pour l'erreur
                .padding()
            }
            
        case .audio:
            if let fileName = flashcard.questionAudioFileName {
                VStack(spacing: 0) {
                    // ✅ Bouton audio plus compact pour Quiz
                    Button(action: {
                        if AudioManager.shared.isPlaying && AudioManager.shared.playingFileName == fileName {
                            AudioManager.shared.stopAudio()
                        } else {
                            AudioManager.shared.playAudio(fileName: fileName)
                        }
                    }) {
                        Image(systemName: AudioManager.shared.isPlaying && AudioManager.shared.playingFileName == fileName ? "pause.fill" : "play.fill")
                            .font(.system(size: 30)) // ✅ Taille réduite
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60) // ✅ Taille réduite
                            .background(
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(Color.blue)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // ✅ Texte de la question en dessous si présent et non vide
                    if let questionText = flashcard.question, 
                       !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(questionText)
                            .font(.body.weight(.medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                    }
                }
                .frame(height: 120) // ✅ Hauteur fixe pour audio
                .padding(.top, 0)  // ✅ PADDING TOP REMIS À ZÉRO
                // ✅ SUPPRIMÉ LE PADDING GÉNÉRAL QUI POUSSAIT LE CONTENU
            }
        }
    }
    
    // ✅ PHRASE "CHOISISSEZ LA BONNE RÉPONSE" HORS TRANSITION
    private var chooseAnswerText: some View {
        Text("Choisissez la bonne réponse")
            .font(.headline.weight(.medium))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)  // ✅ ALIGNEMENT À GAUCHE
            .padding(.horizontal, 20)
            .padding(.top, 40)  // ✅ AUGMENTÉ ESPACEMENT EN HAUT
            .padding(.bottom, 16)  // ✅ AUGMENTÉ ESPACEMENT EN BAS
    }

    private func answerButton(text: String, index: Int, isCorrect: Bool) -> some View {
        Text(text)
            .font(.body.weight(.medium))
            .foregroundColor(buttonTextColor(index: index, isCorrect: isCorrect))
            .multilineTextAlignment(.leading)    // ✅ AJOUT : Alignement pour multi-lignes
            .lineLimit(2)                        // ✅ MODIFICATION : Limite à 2 lignes comme demandé
            .truncationMode(.tail)               // ✅ AJOUT : Points de suspension
            .frame(maxWidth: .infinity, alignment: .leading)  // ✅ MODIFICATION : Alignement explicite
            .padding(.vertical, 16)
            .padding(.horizontal, 12)            // ✅ AJOUT : Padding horizontal pour éviter le collage
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(buttonBackgroundColor(index: index, isCorrect: isCorrect))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(buttonBorderColor(index: index, isCorrect: isCorrect), lineWidth: 1.5)
                    )
            )
            .onTapGesture {
                if !isAnswerSelected {
                    selectAnswer(index: index)
                }
            }
            .transaction { $0.animation = nil }
    }
    
    private func buttonBackgroundColor(index: Int, isCorrect: Bool) -> Color {
        guard isAnswerSelected else {
            // Blanc en clair, gris doux en sombre
            return colorScheme == .light ? Color.white : Color(.systemGray6)
        }

        if isCorrect {
            return .green.opacity(0.2)
        } else if index == selectedAnswerIndex {
            return .red.opacity(0.2)
        } else {
            return colorScheme == .light ? Color.white : Color(.systemGray6)
        }
    }
    
    private func buttonBorderColor(index: Int, isCorrect: Bool) -> Color {
        guard isAnswerSelected else { return Color(.systemGray3) }
        
        if isCorrect {
            return .green
        } else if index == selectedAnswerIndex {
            return .red
        } else {
            return Color(.systemGray3)
        }
    }

    private func buttonTextColor(index: Int, isCorrect: Bool) -> Color {
        guard isAnswerSelected else { return .primary }
        
        if isCorrect {
            return .green
        } else if index == selectedAnswerIndex {
            return .red
        } else {
            return .primary
        }
    }
    
    // ✅ VUE DE COMPLÉTION MINIMALISTE (MÊME STYLE QUE LES FLASHCARDS)
    private var quizCompletionView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // ✅ SECTION TITRE MINIMALISTE
            completionHeader
            
            // ✅ STATISTIQUES ÉPURÉES
            completionStats
            
            Spacer()
            
            // ✅ BOUTONS FERMETURE SIMPLES
            completionButtons
        }
        .padding(.horizontal, 24)
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
            // ✅ ICÔNE SIMPLE SANS COULEUR VIVE
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.primary)
                .opacity(showCompletionElements ? 1 : 0)
                .scaleEffect(showCompletionElements ? 1.0 : 0.9)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showCompletionElements)
            
            // ✅ TITRE SOBRE
            Text(String(localized: "quiz_completed"))
                .font(.title.weight(.medium))
                .foregroundColor(.primary)
                .opacity(showCompletionElements ? 1 : 0)
                .offset(y: showCompletionElements ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: showCompletionElements)
        }
    }
    
    private var completionStats: some View {
        VStack(spacing: 20) {
            // ✅ CARTE PRINCIPALE AVEC RÉSUMÉ
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(quizQuestions.count)")
                            .font(.title.weight(.semibold))
                            .foregroundColor(.primary)
                        Text(String(localized: "stats_total_lowercase"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                // ✅ SÉPARATEUR SUBTIL
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
                    .opacity(0.3)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(quizQuestions.count - score)")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.primary)
                        Text(String(localized: "stats_incorrect"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(score)")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.primary)
                        Text(String(localized: "stats_correct"))
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
            // ✅ BOUTON REFAIRE (SECONDAIRE)
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .soft)
                restartQuiz()
            }) {
                Text(String(localized: "action_retry_quiz"))
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
            
            // ✅ BOUTON TERMINER (PRINCIPAL)
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .soft)
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
    
    private func selectAnswer(index: Int) {
        selectedAnswerIndex = index
        isAnswerSelected = true
        
        let isCorrect = currentQuestion?.correctIndex == index
        
        // Feedback haptique minimal
        HapticFeedbackManager.shared.impact(style: .soft)
        
        if isCorrect {
            score += 1
        }
        
        // ✅ INTÉGRATION SM-2 vs MODE LIBRE pour Quiz
        if let currentQ = currentQuestion {
            let questionFlashcard = flashcards.first { $0.question == currentQ.question }
            if let card = questionFlashcard {
                if !isFreeMode {
                    // Mode SM-2 : traiter le résultat
                    let quality = isCorrect ? 2 : 1
                    let operationId = UUID().uuidString
                    SimpleSRSManager.shared.processQuizResult(
                        card: card,
                        quality: quality,
                        context: viewContext,
                        operationId: operationId
                    )
                    print("🎯 [QUIZ] Résultat traité en mode SM-2: quality \(quality)")
                } else {
                    // Mode libre : pas de mise à jour SM-2
                    print("🆓 [QUIZ] Mode libre: pas de mise à jour SM-2")
                    SimpleSRSManager.shared.markCardReviewedInFreeMode(
                        card,
                        wasCorrect: isCorrect,
                        context: viewContext
                    )
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            nextQuestion()
        }
    }
    
    private func nextQuestion() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentQuestionIndex < quizQuestions.count - 1 {
                currentQuestionIndex += 1
                selectedAnswerIndex = nil
                isAnswerSelected = false
            } else {
                HapticFeedbackManager.shared.impact(style: .soft)
                // ✅ Délai pour laisser la barre de progression terminer son animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showResult = true
                }
            }
        }
    }
    
    private func restartQuiz() {
        currentQuestionIndex = 0
        score = 0
        selectedAnswerIndex = nil
        isAnswerSelected = false
        showResult = false
        showCompletionElements = false
        showStatsElements = false
        generateQuizQuestions()
    }
    
    private func generateQuizQuestions() {
        // ✅ NOUVELLE LOGIQUE SM-2 : Sélection intelligente pour les questions
        // ✅ RÈGLE QUIZ : Question peut contenir média, réponse doit être texte uniquement
        let allValidCards = flashcards.filter { card in
            guard let question = card.question, !question.isEmpty,
                  let answer = card.answer, !answer.isEmpty else {
                return false
            }
            
            // ✅ FILTRE MÉDIA : Exclure les cartes avec média dans la réponse
            // Question peut contenir image/audio, mais réponse doit être texte uniquement
            let hasMediaInAnswer = card.answerImageFileName != nil || card.answerAudioFileName != nil
            if hasMediaInAnswer {
                print("🚫 [QUIZ] Carte exclue - média dans la réponse: \(card.question ?? "")")
                return false
            }
            
            // ✅ RÈGLE QUIZ : Seules les cartes avec média dans la question OU texte uniquement sont autorisées
            let hasMediaInQuestion = card.questionImageFileName != nil || card.questionAudioFileName != nil
            let isTextOnly = card.questionContentType == .text && card.answerContentType == .text
            
            // ✅ Autoriser : cartes texte uniquement OU cartes avec média dans la question (mais pas dans la réponse)
            let isValidForQuiz = isTextOnly || hasMediaInQuestion
            
            if !isValidForQuiz {
                print("🚫 [QUIZ] Carte exclue - ne respecte pas la règle Quiz: \(card.question ?? "")")
                return false
            }
            
            return true
        }
        
        // ✅ INTÉGRATION SM-2 vs MODE LIBRE
        let selectedCards: [Flashcard]
        if isFreeMode {
            // Mode libre : toutes les cartes en ordre aléatoire
            selectedCards = SimpleSRSManager.shared.getAllCardsInOptimalOrder(deck: deck)
                .filter { card in
                    allValidCards.contains(card)
                }
            print("🆓 [QUIZ] Mode libre: \(selectedCards.count) cartes sélectionnées aléatoirement")
        } else {
            // Mode SM-2 : sélection intelligente
            selectedCards = SimpleSRSManager.shared.getSmartCards(deck: deck, minCards: 10)
                .filter { card in
                    allValidCards.contains(card)
                }
            print("🎯 [QUIZ] Mode SM-2: \(selectedCards.count) cartes sélectionnées intelligemment")
        }
        
        // ✅ INFO : Statistiques sur les cartes exclues
        let totalCards = flashcards.count
        let excludedCards = totalCards - allValidCards.count
        if excludedCards > 0 {
            print("📊 [QUIZ] \(excludedCards)/\(totalCards) cartes exclues (média dans la réponse)")
        }
        
        // Compléter avec d'autres cartes valides si nécessaire
        let validFlashcards = selectedCards.count >= 4 ? selectedCards : allValidCards.shuffled()
        
        guard validFlashcards.count >= 4 else {
            quizQuestions = []
            print("⚠️ [QUIZ] Minimum 4 flashcards requises pour générer un quiz")
            return
        }
        
        var questions: [QuizQuestion] = []
        
        // ✅ CRÉATION DES QUESTIONS AVEC TOUJOURS 4 OPTIONS
        for flashcard in validFlashcards {
            guard let correctAnswer = flashcard.answer,
                  let questionText = flashcard.question else {
                continue
            }
            
            // Collecte TOUTES les réponses des autres flashcards
            let otherFlashcards = validFlashcards.filter { $0 != flashcard }
            let availableWrongAnswers = otherFlashcards.compactMap { $0.answer }
                .filter { !$0.isEmpty }
            
            // ✅ S'ASSURER D'AVOIR EXACTEMENT 3 DISTRACTEURS (même si répétés)
            var wrongAnswers: [String] = []
            
            // Prendre les 3 premiers distracteurs disponibles
            for answer in availableWrongAnswers.shuffled() {
                wrongAnswers.append(answer)
                if wrongAnswers.count >= 3 { break }
            }
            
            // ✅ Si pas assez de distracteurs, répéter les existants
            while wrongAnswers.count < 3 && !availableWrongAnswers.isEmpty {
                let randomAnswer = availableWrongAnswers.randomElement()!
                wrongAnswers.append(randomAnswer)
            }
            
            // ✅ Assemblage : Toujours 4 options exactement
            var allAnswers = wrongAnswers
            allAnswers.append(correctAnswer)
            allAnswers.shuffle() // 🎲 Randomisation des réponses
            
            // ✅ Vérification qu'on a bien 4 options
            guard allAnswers.count == 4 else {
                print("❌ [QUIZ] Erreur: \(allAnswers.count) options au lieu de 4")
                continue
            }
            
            // ✅ Trouver l'index de la bonne réponse après mélange
            guard let correctIndex = allAnswers.firstIndex(of: correctAnswer) else {
                print("❌ [QUIZ] Erreur: impossible de trouver l'index de la bonne réponse")
                continue
            }
            
            // ✅ Création de la question
            let quizQuestion = QuizQuestion(
                question: questionText,
                correctAnswer: correctAnswer,
                allAnswers: allAnswers,
                correctIndex: correctIndex,
                originalFlashcard: flashcard // ✅ Ajouté pour accéder aux médias
            )
            
            questions.append(quizQuestion)
            print("✅ [QUIZ] Question ajoutée: '\(questionText)' avec 4 options")
        }
        
        // ✅ Mélange final des questions générées
        quizQuestions = questions.shuffled() // 🎲 Randomisation de l'ordre des questions
        
        print("🎯 [QUIZ] \(quizQuestions.count) questions générées avec toujours 4 options chacune")
        
        // 🐛 DEBUG : Affichage pour vérification
        #if DEBUG
        if let firstQuestion = quizQuestions.first {
            print("🎲 [DEBUG] Première question: '\(firstQuestion.question)'")
            print("🎲 [DEBUG] 4 options: \(firstQuestion.allAnswers)")
            print("🎲 [DEBUG] Bonne réponse: \(firstQuestion.correctAnswer)")
        }
        #endif
    }
}
