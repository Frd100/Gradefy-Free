//
//  FlashcardViews.swift
//  PARALLAX
//
//  Created by Farid on 6/25/25.
//

import SwiftUI
import UIKit
import Foundation
import CoreData
import ActivityKit

// MARK: - Progress Bar Component

struct ProgressBar: View {
    let progress: Double
    let height: CGFloat = 10
    
    private var progressWidth: CGFloat {
        return min(CGFloat(progress), 1.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: height)
                    .cornerRadius(height / 2)
                
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: progressWidth * geometry.size.width, height: height)
                    .cornerRadius(height / 2)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Stat Column Component

struct StatColumn: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                Capsule()
                    .fill(Color.accentColor)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
    }
}

// MARK: - Revision Flashcard View

struct RevisionFlashcardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @FetchRequest(
        entity: Subject.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Subject.name, ascending: true)]
    ) var subjects: FetchedResults<Subject>
    
    @FetchRequest(
        entity: FlashcardDeck.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FlashcardDeck.name, ascending: true)]
    ) var allDecks: FetchedResults<FlashcardDeck>
    
    @State private var selectedSubject: Subject? = nil
    @State private var showingAddSubject: Bool = false
    @State private var selectedNavigationMode: NavigationMode = .subjects
    
    // ✅ BACKGROUND ADAPTATIF : F6F7FB seulement en mode clair
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    enum NavigationMode {
        case subjects
        case decks
    }
    
    var body: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()  // ✅ Background adaptatif
            
            VStack {
                navigationModeSelector
                
                if selectedNavigationMode == .subjects {
                    subjectBasedNavigation
                } else {
                    deckBasedNavigation
                }
            }
        }
        .sheet(isPresented: $showingAddSubject) {
            AddSubjectView(selectedPeriod: "—", onAdd: { _ in })
        }
    }
    
    private var navigationModeSelector: some View {
        HStack {
            Spacer()
            Picker("Mode", selection: $selectedNavigationMode) {
                Text("Par matières").tag(NavigationMode.subjects)
                Text("Tous les decks").tag(NavigationMode.decks)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .onChange(of: selectedNavigationMode) { _, _ in
                HapticFeedbackManager.shared.selection()
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var subjectBasedNavigation: some View {
        Group {
            if subjects.isEmpty {
                emptySubjectsView
            } else if selectedSubject == nil {
                subjectSelectionView
            } else {
                RevisionDeckView(subject: selectedSubject!, onBack: {
                    HapticFeedbackManager.shared.impact(style: .light)
                    selectedSubject = nil
                })
            }
        }
    }
    
    private var deckBasedNavigation: some View {
        NavigationStack {
            VStack {
                HStack {
                    Text("Tous les decks")
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        HapticFeedbackManager.shared.impact(style: .medium)
                        createStandaloneDeck()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                
                if allDecks.isEmpty {
                    emptyDecksView
                } else {
                    List {
                        ForEach(allDecks, id: \.id) { deck in
                            NavigationLink(value: deck) {
                                DeckRowView(deck: deck)
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticFeedbackManager.shared.impact(style: .light)
                            })
                        }
                        .onDelete(perform: deleteDecks)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)  // ✅ Background transparent pour List
                }
            }
            .navigationDestination(for: FlashcardDeck.self) { deck in
                DeckDetailView(deck: deck)
            }
        }
    }
    
    private var emptyDecksView: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            Text("Aucun deck")
                .font(.title)
                .bold()
            Text("Créez votre premier deck de flashcards")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .medium)
                createStandaloneDeck()
            }) {
                Label("Créer un deck", systemImage: "plus")
                    .font(.headline)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 28)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptySubjectsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            Text("Aucune matière")
                .font(.title)
                .bold()
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .medium)
                showingAddSubject = true
            }) {
                Label("Ajouter une matière", systemImage: "plus")
                    .font(.headline)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 28)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var subjectSelectionView: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    HapticFeedbackManager.shared.impact(style: .light)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(UIColor.secondarySystemFill))
                            .frame(width: 32, height: 32)
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.trailing, 20)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(subjects, id: \.id) { subject in
                        Button {
                            HapticFeedbackManager.shared.impact(style: .medium)
                            selectedSubject = subject
                        } label: {
                            DeckStackView(
                                subjectName: subject.name ?? "Matière",
                                cardsCount: (subject.flashcards as? Set<Flashcard>)?.count ?? 0
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
            }
            Text("Choisissez une matière à réviser")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }
    
    private func createStandaloneDeck() {
        let newDeck = FlashcardDeck(context: viewContext)
        newDeck.id = UUID()
        newDeck.createdAt = Date()
        newDeck.name = "Nouveau deck"
        newDeck.subject = nil
        
        do {
            try viewContext.save()
            HapticFeedbackManager.shared.notification(type: .success)
            print("Deck standalone créé avec succès")
        } catch {
            HapticFeedbackManager.shared.notification(type: .error)
            print("Erreur création deck standalone: \(error)")
            viewContext.rollback()
        }
    }
    
    private func deleteDecks(offsets: IndexSet) {
        HapticFeedbackManager.shared.impact(style: .heavy)
        
        viewContext.performAndWait {
            do {
                offsets.map { allDecks[$0] }.forEach(viewContext.delete)
                try viewContext.save()
                HapticFeedbackManager.shared.notification(type: .success)
            } catch {
                HapticFeedbackManager.shared.notification(type: .error)
                print("Erreur suppression decks: \(error)")
                viewContext.rollback()
            }
        }
    }
}

// MARK: - Deck Row View

struct DeckRowView: View {
    let deck: FlashcardDeck
    
    private var flashcardCount: Int {
        (deck.flashcards as? Set<Flashcard>)?.count ?? 0
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(deck.name ?? "Deck sans nom")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("Cartes: \(flashcardCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(flashcardCount)")
                .font(.title3.weight(.medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

// MARK: - Deck Stack View

struct DeckStackView: View {
    var subjectName: String
    var cardsCount: Int
    var deck: FlashcardDeck? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subjectName)
                .font(.headline)
                .foregroundColor(.primary)
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack.fill")
                    .foregroundColor(.accentColor)
                Text("\(cardsCount) cartes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(UIColor.secondarySystemFill))
        )
    }
}

// MARK: - Revision Deck View

struct RevisionDeckView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAddFlashcardSheet = false
    @State private var showingAddDeck = false
    @State private var deckName: String = ""
    @State private var selectedDeckToEdit: FlashcardDeck?
    @State private var allDecks: [FlashcardDeck] = []
    @State private var showEditDeckSheet = false
    var subject: Subject
    var onBack: () -> Void
    
    // ✅ BACKGROUND ADAPTATIF : F6F7FB seulement en mode clair
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    private func flashcardCount(for deck: FlashcardDeck) -> Int {
        (deck.flashcards as? Set<Flashcard>)?.count ?? 0
    }
    
    var body: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()  // ✅ Background adaptatif
            
            VStack {
                HStack {
                    Button(action: { onBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .padding(8)
                    }
                    Spacer()
                    Text(subject.name ?? "")
                        .font(.headline)
                    Spacer()
                    Spacer().frame(width: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Button(action: {
                    HapticFeedbackManager.shared.impact(style: .medium)
                    showingAddDeck = true
                }) {
                    Label("Ajouter une flashcard", systemImage: "plus")
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 28)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundColor(.white)
                }
                .sheet(isPresented: $showingAddDeck) {
                    AddDeckSheet(
                        deckName: $deckName,
                        onSave: { name in
                            let newDeck = FlashcardDeck(context: viewContext)
                            newDeck.id = UUID()
                            newDeck.createdAt = Date()
                            newDeck.name = name
                            
                            do {
                                try viewContext.save()
                                HapticFeedbackManager.shared.notification(type: .success)
                                print("Liste créée avec succès")
                            } catch {
                                HapticFeedbackManager.shared.notification(type: .error)
                                print("Erreur lors de la création de la liste :", error)
                                viewContext.rollback()
                            }
                            deckName = ""
                        }
                    )
                }
                
                List {
                    decksListContent
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)  // ✅ Background transparent pour List
                .navigationDestination(for: FlashcardDeck.self) { deck in
                    DeckDetailView(deck: deck)
                }
                Spacer()
                Text("Révision des flashcards pour la matière « \(subject.name ?? "") »")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .onAppear {
            let request = NSFetchRequest<FlashcardDeck>(entityName: "FlashcardDeck")
            request.predicate = NSPredicate(format: "subject == %@", self.subject)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \FlashcardDeck.name, ascending: true)]
            self.allDecks = (try? viewContext.fetch(request)) ?? []
        }
    }
    
    private func loadDecks() {
        let request = NSFetchRequest<FlashcardDeck>(entityName: "FlashcardDeck")
        request.predicate = NSPredicate(format: "subject == %@", subject)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlashcardDeck.name, ascending: true)]
        allDecks = (try? viewContext.fetch(request)) ?? []
    }
    
    private func deleteDeck(_ deck: FlashcardDeck) {
        HapticFeedbackManager.shared.impact(style: .heavy)
        
        viewContext.performAndWait {
            do {
                viewContext.delete(deck)
                try viewContext.save()
                loadDecks()
                HapticFeedbackManager.shared.notification(type: .success)
                print("Deck supprimé avec succès")
            } catch {
                HapticFeedbackManager.shared.notification(type: .error)
                print("Erreur lors de la suppression du deck :", error)
                viewContext.rollback()
            }
        }
    }

    private var decksListContent: some View {
        ForEach(allDecks, id: \.id) { deck in
            NavigationLink(value: deck) {
                HStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(deck.name ?? "Nom inconnu")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Matière : \(deck.subject?.name ?? "Inconnue")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.accentColor)
                        Text("\(flashcardCount(for: deck))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.trailing, 2)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .simultaneousGesture(TapGesture().onEnded {
                HapticFeedbackManager.shared.impact(style: .light)
            })
            .listRowBackground(
                Color(UIColor { trait in
                    trait.userInterfaceStyle == .dark
                    ? .secondarySystemBackground
                    : .systemBackground
                })
            )
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    deleteDeck(deck)
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
                .tint(.red)
                
                Button {
                    HapticFeedbackManager.shared.impact(style: .light)
                    selectedDeckToEdit = deck
                } label: {
                    Label("Modifier", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
    }
}

// MARK: - Quiz Question Model

struct QuizQuestion {
    let id = UUID()
    let question: String
    let correctAnswer: String
    let allAnswers: [String]
    let correctIndex: Int
}

// MARK: - Quiz View

struct QuizView: View {
    @ObservedObject var deck: FlashcardDeck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var quizQuestions: [QuizQuestion] = []
    @State private var currentQuestionIndex = 0
    @State private var score = 0
    @State private var selectedAnswerIndex: Int? = nil
    @State private var showResult = false
    @State private var isAnswerSelected = false
    @State private var showCompletionAlert = false
    @State private var startTime = Date()
    @State private var showCompletionElements = false
    @State private var showStatsElements = false
    
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
    
    private var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    private var formattedDuration: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    var body: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()  // ✅ Background adaptatif
            
            VStack(spacing: 0) {
                if !showResult {
                    headerSection
                }
                
                if showResult {
                    quizCompletionView
                } else {
                    questionContentView
                }
                
                Spacer()
            }
        }
        .onAppear {
            startTime = Date()
            generateQuizQuestions()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(deck.name ?? "Quiz")
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
                ProgressBar(progress: progress)
                    .frame(width: UIScreen.main.bounds.width * 0.5)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            HStack {
                Text("\(currentQuestionIndex)/\(quizQuestions.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 30)
    }
    
    private var questionContentView: some View {
        VStack(spacing: 180) {
            if let question = currentQuestion {
                VStack(spacing: 16) {
                    Text(question.question)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .id(question.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                
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
                .id("answers-\(question.id)")
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
        }
    }

    private func answerButton(text: String, index: Int, isCorrect: Bool) -> some View {
        Text(text)
            .font(.body.weight(.medium))
            .foregroundColor(buttonTextColor(index: index, isCorrect: isCorrect))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(buttonBackgroundColor(index: index, isCorrect: isCorrect))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(buttonBorderColor(index: index, isCorrect: isCorrect), lineWidth: 2)
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
        guard isAnswerSelected else { return Color(.systemBackground) }
        
        if isCorrect {
            return .green.opacity(0.2)
        } else if index == selectedAnswerIndex {
            return .red.opacity(0.2)
        } else {
            return Color(.systemBackground)
        }
    }

    private func buttonBorderColor(index: Int, isCorrect: Bool) -> Color {
        guard isAnswerSelected else { return Color(.systemGray4) }
        
        if isCorrect {
            return .green
        } else if index == selectedAnswerIndex {
            return .red
        } else {
            return Color(.systemGray4)
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
            // ✅ ICÔNE SIMPLE SANS COULEUR VIVE
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.primary)
                .opacity(showCompletionElements ? 1 : 0)
                .scaleEffect(showCompletionElements ? 1.0 : 0.9)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showCompletionElements)
            
            // ✅ TITRE SOBRE
            Text("Quiz terminé")
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
                        Text("\(score)")
                            .font(.title.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("correctes")
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
                        Text("incorrectes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(quizQuestions.count)")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.primary)
                        Text("total")
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
                HapticFeedbackManager.shared.impact(style: .light)
                restartQuiz()
            }) {
                Text("Refaire le quiz")
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
    
    private func selectAnswer(index: Int) {
        selectedAnswerIndex = index
        isAnswerSelected = true
        
        let isCorrect = currentQuestion?.correctIndex == index
        
        // Feedback haptique immédiat selon la réponse
        if isCorrect {
            HapticFeedbackManager.shared.notification(type: .success)
            score += 1
        } else {
            HapticFeedbackManager.shared.notification(type: .error)
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
                HapticFeedbackManager.shared.notification(type: .success)
                showResult = true
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
        startTime = Date()
        generateQuizQuestions()
    }
    
    private func generateQuizQuestions() {
        let validFlashcards = flashcards.filter { card in
            guard let question = card.question, !question.isEmpty,
                  let answer = card.answer, !answer.isEmpty else {
                return false
            }
            return true
        }
        
        guard validFlashcards.count >= 4 else {
            quizQuestions = []
            return
        }
        
        var questions: [QuizQuestion] = []
        
        for flashcard in validFlashcards {
            guard let question = flashcard.question,
                  let correctAnswer = flashcard.answer else { continue }
            
            let otherFlashcards = validFlashcards.filter { $0.id != flashcard.id }
            let wrongAnswers = Array(otherFlashcards.compactMap { $0.answer }.prefix(3))
            
            guard wrongAnswers.count >= 3 else { continue }
            
            var allAnswers = wrongAnswers
            allAnswers.append(correctAnswer)
            allAnswers.shuffle()
            
            let correctIndex = allAnswers.firstIndex(of: correctAnswer) ?? 0
            
            let quizQuestion = QuizQuestion(
                question: question,
                correctAnswer: correctAnswer,
                allAnswers: allAnswers,
                correctIndex: correctIndex
            )
            
            questions.append(quizQuestion)
        }
        
        quizQuestions = questions.shuffled()
    }
}


// MARK: - Revision Mode Selection View

struct RevisionModeSelectionView: View {
    let deck: FlashcardDeck
    @Binding var showRevisionSession: Bool
    @Binding var showQuizSession: Bool
    @Binding var showAssociationSession: Bool // ✅ RETOUR À showAssociationSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private var flashcardCount: Int {
        (deck.flashcards as? Set<Flashcard>)?.count ?? 0
    }
    
    private var canStartQuiz: Bool {
        flashcardCount >= 4
    }
    
    private var canStartAssociation: Bool {
        flashcardCount >= 3
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Choisissez votre mode de révision")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 40)
            
            VStack(spacing: 16) {
                // ✅ FLASHCARDS BUTTON
                RevisionModeButton(
                    icon: "rectangle.on.rectangle.angled.fill",
                    title: "Flashcards",
                    description: "Révisez avec des cartes",
                    color: .blue,
                    isEnabled: true,
                    showChevron: true
                ) {
                    HapticFeedbackManager.shared.impact(style: .light)
                    dismiss()
                    showRevisionSession = true
                }
                
                // ✅ QUIZ BUTTON
                RevisionModeButton(
                    icon: "questionmark.app.fill",
                    title: "Quiz",
                    description: canStartQuiz ? "Testez vos connaissances" : "Minimum 4 flashcards requis",
                    color: canStartQuiz ? .orange : .gray,
                    isEnabled: canStartQuiz,
                    showChevron: canStartQuiz,
                    rightContent: {
                        if !canStartQuiz {
                            Text("\(flashcardCount)/4")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.orange.opacity(0.2)))
                        }
                    }
                ) {
                    if canStartQuiz {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                        showQuizSession = true
                    } else {
                        HapticFeedbackManager.shared.notification(type: .warning)
                    }
                }
                
                // ✅ BOUTON ASSOCIATION SIMPLIFIÉ
                RevisionModeButton(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Associer",
                    description: canStartAssociation ? "Associez questions et réponses" : "Minimum 3 flashcards requis",
                    color: canStartAssociation ? .purple : .gray,
                    isEnabled: canStartAssociation,
                    showChevron: canStartAssociation,
                    rightContent: {
                        if !canStartAssociation {
                            Text("\(flashcardCount)/3")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.purple.opacity(0.2)))
                        }
                    }
                ) {
                    if canStartAssociation {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                        showAssociationSession = true // ✅ DIRECT, plus de délai
                    } else {
                        HapticFeedbackManager.shared.notification(type: .warning)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .presentationDetents([.height(350)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(25)
        .presentationCompactAdaptation(.none)
    }
}

// ✅ COMPOSANT RÉUTILISABLE POUR LES BOUTONS
struct RevisionModeButton<RightContent: View>: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let isEnabled: Bool
    let showChevron: Bool
    let rightContent: () -> RightContent
    let action: () -> Void
    
    init(
        icon: String,
        title: String,
        description: String,
        color: Color,
        isEnabled: Bool,
        showChevron: Bool,
        @ViewBuilder rightContent: @escaping () -> RightContent = { EmptyView() },
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.color = color
        self.isEnabled = isEnabled
        self.showChevron = showChevron
        self.rightContent = rightContent
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isEnabled ? .primary : .secondary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Group {
                    if showChevron {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        rightContent()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(borderColor, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 30))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.7)
    }
    
    private var backgroundColor: Color {
        Color(.secondarySystemGroupedBackground)
    }
    
    private var borderColor: Color {
        Color(.separator).opacity(0.3)
    }
}

struct DeckDetailView: View {
    @ObservedObject var deck: FlashcardDeck
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAddFlashcard = false
    @State private var showRevisionSession = false
    @State private var showQuizSession = false
    @State private var showModeSelection = false
    @State private var showEmptyDeckAlert = false
    @State private var flashcardToEdit: Flashcard?
    @State private var showAssociationSession = false

    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }

    var flashcards: [Flashcard] {
        (deck.flashcards as? Set<Flashcard>)?.sorted {
            $0.createdAt ?? Date() < $1.createdAt ?? Date()
        } ?? []
    }

    private var hasFlashcards: Bool {
        !flashcards.isEmpty
    }

    var body: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ✅ SUPPRESSION de headerSection
                contentSection
            }
        }
        // ✅ NAVIGATION INLINE avec titre du deck
        .navigationTitle(deck.name ?? "Deck")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        // ✅ BOUTONS NATIFS dans la toolbar
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    // Bouton Play natif
                    Button {
                        if hasFlashcards {
                            HapticFeedbackManager.shared.impact(style: .medium)
                            showModeSelection = true
                        } else {
                            HapticFeedbackManager.shared.notification(type: .warning)
                            showEmptyDeckAlert = true
                        }
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .disabled(!hasFlashcards)
                    
                    // Bouton Plus natif
                    Button {
                        HapticFeedbackManager.shared.impact(style: .medium)
                        showAddFlashcard = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .foregroundColor(.blue) // ✅ Style natif bleu Apple
            }
        }
        // Reste du code inchangé...
        .fullScreenCover(isPresented: $showRevisionSession) {
            FlashcardStackRevisionView(deck: deck)
        }
        .fullScreenCover(isPresented: $showQuizSession) {
            QuizView(deck: deck)
        }
        .fullScreenCover(isPresented: $showAssociationSession) {
            AssociationView(deck: deck)
        }
        .sheet(isPresented: $showAddFlashcard) {
            AddFlashcardView(deck: deck)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $flashcardToEdit) { flashcard in
            EditFlashcardView(flashcard: flashcard)
        }
        .sheet(isPresented: $showModeSelection) {
            RevisionModeSelectionView(
                deck: deck,
                showRevisionSession: $showRevisionSession,
                showQuizSession: $showQuizSession,
                showAssociationSession: $showAssociationSession
            )
        }
        .alert("Deck vide", isPresented: $showEmptyDeckAlert) {
            Button("Ajouter des cartes") {
                HapticFeedbackManager.shared.impact(style: .medium)
                showAddFlashcard = true
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Ajoutez au moins une flashcard avant de commencer la révision.")
        }
    }

    // ✅ SUPPRESSION COMPLÈTE de headerSection
    // private var headerSection: some View { ... } // À SUPPRIMER

    private var contentSection: some View {
        Group {
            if flashcards.isEmpty {
                emptyStateView
            } else {
                flashcardsListView
            }
        }
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            
            // ✅ ANIMATION ADAPTIVE "poeme" - même taille que revisionEmptyState
            AdaptiveLottieView(animationName: "poeme")
                .frame(width: 110, height: 110)
            
            // ✅ TEXTE parfaitement adaptatif - même structure
            VStack(spacing: 8) {
                Text("Vous n'avez aucune flashcard pour le moment")
                    .font(.headline.weight(.medium))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 16)
            
            Spacer()
            
            // ✅ BOUTON - même style et structure
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .medium)
                showAddFlashcard = true
            }) {
                Text("Nouvelle flashcard")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 45)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            colorScheme == .dark
            ? Color(.systemBackground)
            : Color.white
        )
    }


    private var flashcardsListView: some View {
        List {
            ForEach(flashcards, id: \.id) { card in
                FlashcardRowView(
                    flashcard: card,
                    onEdit: {
                        HapticFeedbackManager.shared.impact(style: .light)
                        flashcardToEdit = card
                    }
                )
            }
            .onDelete(perform: deleteFlashcard)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .scrollBounceBehavior(.basedOnSize) // ✅ Désactive complètement le bounce
    }

    func deleteFlashcard(at offsets: IndexSet) {
        HapticFeedbackManager.shared.impact(style: .medium)
        
        let toDelete = offsets.map { flashcards[$0] }
        for card in toDelete {
            viewContext.delete(card)
        }
        
        do {
            try viewContext.save()
            HapticFeedbackManager.shared.notification(type: .success)
        } catch {
            HapticFeedbackManager.shared.notification(type: .error)
            viewContext.rollback()
        }
    }
}



// MARK: - Flashcard Row View

struct FlashcardRowView: View {
    let flashcard: Flashcard
    let onEdit: (() -> Void)?
    @Environment(\.managedObjectContext) private var viewContext
    
    init(flashcard: Flashcard, onEdit: (() -> Void)? = nil) {
        self.flashcard = flashcard
        self.onEdit = onEdit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(flashcard.question ?? "Question vide")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let answer = flashcard.answer, !answer.isEmpty {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteFlashcard()
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
            .tint(.red)
            
            if let onEdit = onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Modifier", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Question: \(flashcard.question ?? ""). Réponse: \(flashcard.answer ?? "")")
    }
    
    private func deleteFlashcard() {
        HapticFeedbackManager.shared.impact(style: .heavy)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            viewContext.performAndWait {
                do {
                    viewContext.delete(flashcard)
                    try viewContext.save()
                    HapticFeedbackManager.shared.notification(type: .success)
                    print("Flashcard supprimée avec succès")
                } catch {
                    HapticFeedbackManager.shared.notification(type: .error)
                    print("Erreur suppression flashcard: \(error)")
                    viewContext.rollback()
                }
            }
        }
    }
}

// MARK: - Edit Deck View

struct EditDeckView: View {
    @ObservedObject var deck: FlashcardDeck
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // ✅ State local pour le texte en cours d'édition
    @State private var localDeckName: String = ""
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                // ✅ Bouton X qui ne bouge PAS
                HStack {
                    Spacer()
                    Button {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.top, 18)
                
                // ✅ Titre qui remonte SEUL avec offset
                Text("Modifier le nom de la liste")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .offset(y: -5)
                
                VStack(spacing: 4) {
                    InstantFocusTextFieldforedit(
                        text: $localDeckName, // ✅ Utilise le state local
                        placeholder: "",
                        onReturn: {
                            if !localDeckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                saveChanges()
                            }
                        }
                    )
                    .frame(width: 280, height: 35)
                    .clipped()
                    
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 280, height: 1)
                }
                .padding(.top, 10)
                
                Spacer()
            }
        }
        .onAppear {
            // ✅ Charge le nom existant du deck
            localDeckName = deck.name ?? ""
        }
    }
    
    private func saveChanges() {
        HapticFeedbackManager.shared.impact(style: .medium)
        
        viewContext.performAndWait {
            do {
                deck.name = localDeckName.trimmingCharacters(in: .whitespacesAndNewlines)
                try viewContext.save()
                HapticFeedbackManager.shared.notification(type: .success)
                dismiss()
                print("Deck modifié avec succès")
            } catch {
                HapticFeedbackManager.shared.notification(type: .error)
                print("Erreur modification deck: \(error)")
                viewContext.rollback()
            }
        }
    }
}

struct InstantFocusTextFieldforedit: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onReturn: () -> Void
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = ""
        textField.delegate = context.coordinator
        
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = UIFont.systemFont(ofSize: 18)
        textField.textAlignment = .center
        textField.returnKeyType = .done
        
        textField.adjustsFontSizeToFitWidth = false
        textField.clipsToBounds = true
        textField.contentHorizontalAlignment = .center
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: InstantFocusTextFieldforedit  // ✅ CORRIGÉ ICI
        
        init(_ parent: InstantFocusTextFieldforedit) {  // ✅ ET ICI
            self.parent = parent
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let newText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? string
            parent.text = newText
            return true
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onReturn()
            return true
        }
    }
}


// MARK: - Add Flashcard View

struct AddFlashcardView: View {
    @ObservedObject var deck: FlashcardDeck
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var question = ""
    @State private var answer = ""
    
    // ✅ BACKGROUND ADAPTATIF : F6F7FB seulement en mode clair
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                adaptiveBackground.ignoresSafeArea()  // ✅ Background adaptatif
                
                Form {
                    Section("Sujet") {
                        TextField("Requis", text: $question, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    Section("Réponse") {
                        TextField("Requis", text: $answer, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Ajouter une carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        saveFlashcard()
                    }
                    .disabled(question.isEmpty || answer.isEmpty)
                }
            }
        }
    }
    
    private func saveFlashcard() {
        HapticFeedbackManager.shared.impact(style: .medium)
        
        viewContext.performAndWait {
            do {
                let newFlashcard = Flashcard(context: viewContext)
                newFlashcard.id = UUID()
                newFlashcard.question = question
                newFlashcard.answer = answer
                newFlashcard.createdAt = Date()
                newFlashcard.deck = deck
                newFlashcard.subject = deck.subject
                
                try viewContext.save()
                HapticFeedbackManager.shared.notification(type: .success)
                dismiss()
                print("Flashcard ajoutée avec succès")
            } catch {
                HapticFeedbackManager.shared.notification(type: .error)
                print("Erreur ajout flashcard: \(error)")
                viewContext.rollback()
            }
        }
    }
}

struct AddDeckSheet: View {
    @Binding var deckName: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    // ✅ State local pour le texte en cours d'édition
    @State private var localDeckName: String = ""
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                // ✅ Bouton X qui ne bouge PAS
                HStack {
                    Spacer()
                    Button {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.top, 18)
                
                // ✅ Titre qui remonte SEUL avec offset
                Text("Saisir le nom de la liste")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .offset(y: -5)
                
                VStack(spacing: 4) {
                    InstantFocusTextField(
                        text: $localDeckName, // ✅ Utilise le state local
                        placeholder: "",
                        onReturn: {
                            if !localDeckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                HapticFeedbackManager.shared.impact(style: .medium)
                                onSave(localDeckName.trimmingCharacters(in: .whitespacesAndNewlines)) // ✅ Passe la valeur locale nettoyée
                                dismiss()
                            }
                        }
                    )
                    .frame(width: 280, height: 35)
                    .clipped()
                    
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 280, height: 1)
                }
                .padding(.top, 10)
                
                Spacer()
            }
        }
        .onAppear {
            // ✅ Démarre toujours avec un champ vide
            localDeckName = ""
        }
    }
}

struct InstantFocusTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onReturn: () -> Void
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = ""
        textField.delegate = context.coordinator
        
        // ✅ Configuration pour texte plus grand
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = UIFont.systemFont(ofSize: 18)
        textField.textAlignment = .center
        textField.returnKeyType = .done
        
        // ✅ Propriétés pour contrôler la taille et le défilement
        textField.adjustsFontSizeToFitWidth = false
        textField.clipsToBounds = true
        textField.contentHorizontalAlignment = .center
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        // ✅ Focus instantané
        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: InstantFocusTextField
        
        init(_ parent: InstantFocusTextField) {
            self.parent = parent
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let newText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? string
            parent.text = newText
            return true
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onReturn()
            return true
        }
    }
}



// MARK: - Subject Picker Sheet

struct SubjectPickerSheet: View {
    let subjects: [Subject]
    @Binding var selectedSubject: Subject?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // ✅ BACKGROUND ADAPTATIF : F6F7FB seulement en mode clair
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                adaptiveBackground.ignoresSafeArea()  // ✅ Background adaptatif
                
                List {
                    Button(action: {
                        HapticFeedbackManager.shared.selection()
                        selectedSubject = nil
                        dismiss()
                    }) {
                        HStack {
                            Text("Aucune matière")
                            Spacer()
                            if selectedSubject == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    ForEach(subjects, id: \.id) { subject in
                        Button(action: {
                            HapticFeedbackManager.shared.selection()
                            selectedSubject = subject
                            dismiss()
                        }) {
                            HStack {
                                Text(subject.name ?? "Matière")
                                Spacer()
                                if selectedSubject == subject {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Choisir une matière")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Flashcard View

struct EditFlashcardView: View {
    @ObservedObject var flashcard: Flashcard
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var question: String
    @State private var answer: String
    
    // ✅ BACKGROUND ADAPTATIF : F6F7FB seulement en mode clair
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    init(flashcard: Flashcard) {
        self.flashcard = flashcard
        _question = State(initialValue: flashcard.question ?? "")
        _answer = State(initialValue: flashcard.answer ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                adaptiveBackground.ignoresSafeArea()  // ✅ Background adaptatif
                
                Form {
                    Section("Question") {
                        TextField("Question", text: $question, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    Section("Réponse") {
                        TextField("Réponse", text: $answer, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Modifier flashcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        saveChanges()
                    }
                    .disabled(question.isEmpty || answer.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        HapticFeedbackManager.shared.impact(style: .medium)
        
        viewContext.performAndWait {
            do {
                flashcard.question = question
                flashcard.answer = answer
                try viewContext.save()
                HapticFeedbackManager.shared.notification(type: .success)
                dismiss()
                print("Flashcard modifiée avec succès")
            } catch {
                HapticFeedbackManager.shared.notification(type: .error)
                print("Erreur modification flashcard: \(error)")
                viewContext.rollback()
            }
        }
    }
}

// MARK: - Extensions

extension FlashcardDeck {
    var flashcardCount: Int {
        (flashcards as? Set<Flashcard>)?.count ?? 0
    }
    
    var hasFlashcards: Bool {
        flashcardCount > 0
    }
}

extension Subject {
    var flashcardCount: Int {
        (flashcards as? Set<Flashcard>)?.count ?? 0
    }
    
    var deckCount: Int {
        (decks as? Set<FlashcardDeck>)?.count ?? 0
    }
}
