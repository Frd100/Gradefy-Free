//
//  DeckManagement.swift
//  PARALLAX
//
//  Created by  on 7/21/25.
//

import SwiftUI
import UIKit
import Foundation
import CoreData
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import Lottie


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
    @State private var premiumManager = PremiumManager.shared
    
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
                Text(String(localized: "navigation_by_subjects")).tag(NavigationMode.subjects)
                Text(String(localized: "navigation_all_decks")).tag(NavigationMode.decks)
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
                                subjectName: subject.name ?? String(localized: "form_subject"),
                                cardsCount: flashcardCount(for: subject)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
            }
            Text(String(localized: "deck_choose_subject"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }

    private var deckBasedNavigation: some View {
        NavigationStack {
            VStack {
                HStack {
                    Text("")
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
                    .background(Color.clear)
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
            Text(String(localized: "empty_no_deck"))
                .font(.title)
                .bold()
            Text(String(localized: "deck_create_first"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .medium)
                createStandaloneDeck()
            }) {
                Label(String(localized: "action_create_deck"), systemImage: "plus")
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
            Text(String(localized: "empty_no_subject"))
                .font(.title)
                .bold()
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .medium)
                showingAddSubject = true
            }) {
                Label(String(localized: "action_add_subject"), systemImage: "plus")
                    .font(.headline)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 28)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    
    private func flashcardCount(for subject: Subject) -> Int {
        // Les flashcards ne sont plus liées aux subjects
        return 0
    }
    
    private func createStandaloneDeck() {
        let newDeck = FlashcardDeck(context: viewContext)
        newDeck.id = UUID()
        newDeck.createdAt = Date()
        newDeck.name = String(localized: "deck_new_default")
        
        do {
            try viewContext.save()
            DeckSharingManager.shared.notifyDeckModification(deck: newDeck)
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
                // ✅ AJOUTEZ CES LIGNES - Invalider le cache AVANT suppression
                let decksToDelete = offsets.map { allDecks[$0] }
                decksToDelete.forEach { deck in
                    DeckSharingManager.shared.invalidateDeckCache(for: deck)
                }
                decksToDelete.forEach(viewContext.delete)
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
        let count = (deck.flashcards as? Set<Flashcard>)?.count ?? 0
        print("🔍 [DEBUG] flashcardCount: \(count)")
        return count
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(deck.name ?? String(localized: "deck_unnamed"))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(String(localized: "deck_cards_count", comment: "Cards count").replacingOccurrences(of: "%lld", with: "\(flashcardCount)"))
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


struct FlashcardRow: View {
    let flashcard: Flashcard
    @ObservedObject var audioManager: AudioManager
    
    @State private var showingDetailView = false
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // Question en haut (couleur normale)
                faceCell(type: flashcard.questionContentType,
                         text: flashcard.question,
                         imageFileName: flashcard.questionImageFileName,
                         audioFileName: flashcard.questionAudioFileName,
                         isAnswer: false) // ✅ Question = couleur primary
                
                // Réponse en bas (couleur secondary)
                faceCell(type: flashcard.answerContentType,
                         text: flashcard.answer,
                         imageFileName: flashcard.answerImageFileName,
                         audioFileName: flashcard.answerAudioFileName,
                         isAnswer: true) // ✅ Réponse = couleur secondary
            }
            
            Spacer()
            
            // ✅ Icône de statut + chevron côte à côte
            HStack(spacing: 8) {
                FlashcardStatusView(card: flashcard)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedbackManager.shared.impact(style: .light)
            showingDetailView = true
        }
        // ✅ SOLUTION : Sheet avec item binding - SUPPRIMÉE
        .sheet(isPresented: $showingDetailView) {
            FlashcardDetailView(flashcard: flashcard)
        }
    }

    @ViewBuilder
    private func faceCell(type: FlashcardContentType, text: String?, imageFileName: String?, audioFileName: String?, isAnswer: Bool = false) -> some View {
        switch type {
        case .text:
            Text(text ?? "Aucun contenu")
                .font(.body)
                .foregroundColor(isAnswer ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                
        case .image:
            if let imageFileName = imageFileName {
                let imageData = (imageFileName == flashcard.questionImageFileName)
                                ? flashcard.questionImageData
                                : flashcard.answerImageData
                
                HStack(spacing: 8) {
                    if let loadedImage = MediaStorageManager.shared.loadImage(fileName: imageFileName, data: imageData) {
                        Image(uiImage: loadedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .clipped()

                    } else {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Texte à côté de l'image
                    if let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(truncateText(text, maxLength: 30))
                            .font(.caption)
                            .foregroundColor(isAnswer ? .secondary : .primary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .frame(width: 60, height: 60)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
        case .audio:
            if let audioFileName = audioFileName {
                HStack(spacing: 8) {
                    Button(action: {
                        playAudio(fileName: audioFileName)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: audioManager.isPlaying && audioManager.playingFileName == audioFileName ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                                .transaction { transaction in
                                    transaction.animation = nil
                                }
                            
                            AudioSpectrumView(isPlaying: audioManager.isPlaying && audioManager.playingFileName == audioFileName)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Texte à côté de l'audio
                    if let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(truncateText(text, maxLength: 30))
                            .font(.caption)
                            .foregroundColor(isAnswer ? .secondary : .primary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Image(systemName: "waveform")
                    .foregroundColor(.gray)
                    .font(.title2)
            }
        }
    }
    
    // ✅ FONCTION HELPER : Tronquer le texte avec "..."
    private func truncateText(_ text: String, maxLength: Int) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.count <= maxLength {
            return trimmedText
        } else {
            let index = trimmedText.index(trimmedText.startIndex, offsetBy: maxLength - 3)
            return String(trimmedText[..<index]) + "..."
        }
    }
    


    private func playAudio(fileName: String) {
        print("🔍 AVANT CLICK - isPlaying: \(audioManager.isPlaying), fileName: \(audioManager.playingFileName ?? "nil")")
        
        HapticFeedbackManager.shared.impact(style: .light)
        audioManager.togglePlayback(fileName: fileName)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("🔍 APRÈS CLICK - isPlaying: \(self.audioManager.isPlaying), fileName: \(self.audioManager.playingFileName ?? "nil")")
        }
    }
}






@MainActor
@Observable
class AudioVisualizer {
    private(set) var isAnimating = false
    private var lastKnownPlayingState = false
    private var animationTask: Task<Void, Never>? = nil
    var currentHeights: [CGFloat] = Array(repeating: 3.6, count: 7)
    private var barCount = 7
    
    func startAnimation() {
        guard !isAnimating else { return }
        
        print("🎬 AudioVisualizer: Démarrage animation")
        isAnimating = true
        lastKnownPlayingState = true
        currentHeights = generateRandomHeights()
        
        animationTask = Task { [weak self] in
            guard let self = self else { return }
            
            // ✅ SOLUTION : Capturer les valeurs avant le while
            while !Task.isCancelled {
                // ✅ Capturer les états dans MainActor.run
                let shouldContinue = await MainActor.run {
                    return self.isAnimating && self.lastKnownPlayingState
                }
                
                // ✅ Condition simple sans await
                guard shouldContinue else { break }
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.currentHeights = self.generateRandomHeights()
                    }
                }
                
                try? await Task.sleep(for: .milliseconds(300))
            }
            
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.currentHeights = Array(repeating: 3.6, count: 7)
                    }
                }
            }
        }
    }
    
    func stopAnimation() {
        print("🛑 AudioVisualizer: Arrêt animation")
        lastKnownPlayingState = false
        isAnimating = false
        
        animationTask?.cancel()
        animationTask = nil
        
        withAnimation(.easeOut(duration: 0.3)) {
            currentHeights = Array(repeating: 3.6, count: 7)
        }
    }
    
    private func generateRandomHeights() -> [CGFloat] {
        return (0..<barCount).map { _ in
            CGFloat.random(in: 2.4...12.0)
        }
    }
    
    deinit {
        print("🧹 AudioVisualizer: Nettoyage deinit")
        NotificationCenter.default.removeObserver(self)
    }
}


struct AudioSpectrumView: View {
    let isPlaying: Bool
    @State private var barHeights: [CGFloat] = Array(repeating: 3.6, count: 7)
    @State private var animationTask: Task<Void, Never>? = nil
    @State private var isActuallyAnimating = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.blue)
                    .frame(width: 2, height: barHeights[index])
                    .animation(
                        .easeInOut(duration: 0.5 + Double(index) * 0.1),
                        value: barHeights[index]
                    )
            }
        }
        .frame(width: 20, height: 12)
        .onChange(of: isPlaying) { _, newValue in
            if newValue && !isActuallyAnimating {
                startAnimation()
            } else if !newValue && isActuallyAnimating {
                stopAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        guard !isActuallyAnimating else { return }
        isActuallyAnimating = true
        
        animationTask = Task { @MainActor in
            while !Task.isCancelled && isActuallyAnimating && isPlaying {
                withAnimation(.easeInOut(duration: 0.2)) {
                    barHeights = generateRandomHeights()
                }
                try? await Task.sleep(for: .milliseconds(300))
            }
            
            withAnimation(.easeOut(duration: 0.3)) {
                barHeights = Array(repeating: 3.6, count: 7)
            }
        }
    }
    
    private func stopAnimation() {
        isActuallyAnimating = false
        animationTask?.cancel()
        animationTask = nil
        
        withAnimation(.easeOut(duration: 0.3)) {
            barHeights = Array(repeating: 3.6, count: 7)
        }
    }
    
    private func generateRandomHeights() -> [CGFloat] {
        return (0..<7).map { _ in
            CGFloat.random(in: 2.4...12.0)
        }
    }
}


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
                Text(String(localized: "deck_cards_simple", comment: "Simple card count").replacingOccurrences(of: "%lld", with: "\(cardsCount)"))
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


struct RevisionDeckView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var premiumManager = PremiumManager.shared
    @State private var showingAddDeck = false
    @State private var deckName: String = ""
    @State private var selectedDeckToEdit: FlashcardDeck?
    @State private var allDecks: [FlashcardDeck] = []
    @State private var showEditDeckSheet = false
    @State private var refreshTrigger = UUID() // ✅ NOUVEAU : Trigger pour forcer les mises à jour
    var subject: Subject
    var onBack: () -> Void
    
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    private func flashcardCount(for deck: FlashcardDeck) -> Int {
        (deck.flashcards as? Set<Flashcard>)?.count ?? 0
    }
    
    var body: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()
            
            VStack {
                // Header avec bouton retour
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
                
                // ✅ SUPPRIMÉ : deckLimitIndicator (plus de limite de decks)
                
                // ✅ CORRECTION : Bouton pour créer un deck (pas une flashcard)
                Button(action: {
                    HapticFeedbackManager.shared.impact(style: .medium)
                    showingAddDeck = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.headline)
                        
                        Text("Créer un deck")  // ✅ Texte corrigé
                            .font(.headline)
                    }
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
                                // ✅ AJOUTEZ CETTE LIGNE
                                DeckSharingManager.shared.notifyDeckModification(deck: newDeck)
                                HapticFeedbackManager.shared.notification(type: .success)
                                print("Deck créé avec succès")
                                loadDecks()
                                // ✅ NOUVEAU : Forcer la mise à jour des indicateurs
                                refreshTrigger = UUID()
                            } catch {
                                HapticFeedbackManager.shared.notification(type: .error)
                                print("Erreur lors de la création du deck :", error)
                                viewContext.rollback()
                            }
                            deckName = ""
                        }
                    )
                }
                
                // Liste des decks
                List {
                    decksListContent
                }
                .scrollContentBackground(.hidden)
                .background(adaptiveBackground)
                .scrollIndicators(.hidden)
                .id(refreshTrigger) // ✅ NOUVEAU : Forcer le refresh de la liste
            }
        }
        .onAppear {
            loadDecks()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataDidChange)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                loadDecks()
                refreshTrigger = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { notification in
            // ✅ NOUVEAU : Réagir aux changements Core Data
            if let userInfo = notification.userInfo {
                let changedObjects = [
                    NSInsertedObjectsKey,
                    NSUpdatedObjectsKey,
                    NSDeletedObjectsKey
                ].compactMap { key in
                    userInfo[key] as? Set<NSManagedObject>
                }.flatMap { $0 }
                
                let hasRelevantChanges = changedObjects.contains { object in
                    if object is Flashcard {
                        return true
                    }
                    if object is FlashcardDeck {
                        return true // ✅ CORRIGÉ : Tous les decks sont pertinents maintenant
                    }
                    return false
                }
                
                if hasRelevantChanges {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        loadDecks()
                        refreshTrigger = UUID()
                    }
                }
            }
        }
        .sheet(isPresented: $showEditDeckSheet) {
            if let deckToEdit = selectedDeckToEdit {
                EditDeckView(deck: deckToEdit)
            }
        }
    }
    
    // MARK: - Private Functions
    private func loadDecks() {
        let request = NSFetchRequest<FlashcardDeck>(entityName: "FlashcardDeck")
        // ✅ CORRIGÉ : Plus de filtre par subject, charger tous les decks
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlashcardDeck.name, ascending: true)]
        allDecks = (try? viewContext.fetch(request)) ?? []
        
        print("📊 Decks chargés: \(allDecks.count)")
    }
    
    private func deleteDeck(_ deck: FlashcardDeck) {
        HapticFeedbackManager.shared.impact(style: .heavy)
        
        viewContext.performAndWait {
            do {
                // ✅ AJOUTEZ CETTE LIGNE AVANT la suppression
                DeckSharingManager.shared.invalidateDeckCache(for: deck)
                viewContext.delete(deck)
                try viewContext.save()
                loadDecks()
                HapticFeedbackManager.shared.notification(type: .success)
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
                        
                        // ✅ CORRIGÉ : Suppression de la référence à subject
                        Text("\(flashcardCount(for: deck)) cartes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    // ✅ AJOUT : Indicateur de limite par deck
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.accentColor)
                            Text("\(flashcardCount(for: deck))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.accentColor)
                        }
                        
                        // ✅ NOUVELLE LOGIQUE : Limitation par deck
                        if !premiumManager.isPremium {
                            let count = flashcardCount(for: deck)
                            if count >= 45 {
                                Text(count >= 50 ? "LIMITE ATTEINTE" : "Bientôt limité")
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(count >= 50 ? .red : .orange)
                            }
                        }
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
                    Label(String(localized: "action_delete"), systemImage: "trash")
                }
                .tint(.red)
                
                Button {
                    HapticFeedbackManager.shared.impact(style: .light)
                    selectedDeckToEdit = deck
                    showEditDeckSheet = true
                } label: {
                    Label(String(localized: "action_modify"), systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
        .onDelete { indexSet in
            for index in indexSet {
                deleteDeck(allDecks[index])
            }
        }
    }
}

// MARK: - EditDeckView
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
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color(.secondarySystemBackground)))
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.top, 18)
                    
                    // ✅ Titre qui remonte SEUL avec offset
                    Text(String(localized: "deck_edit_name"))
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
                    // ✅ AJOUTEZ CETTE LIGNE
                    DeckSharingManager.shared.notifyDeckModification(deck: deck)
                    HapticFeedbackManager.shared.notification(type: .success)
                    dismiss()
                } catch {
                    HapticFeedbackManager.shared.notification(type: .error)
                    print("Erreur modification deck: \(error)")
                    viewContext.rollback()
                }
            }
        }
    }

// MARK: - AddDeckSheet
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
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color(.secondarySystemBackground)))
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.top, 18)
                    
                    // ✅ Titre qui remonte SEUL avec offset
                    Text(String(localized: "deck_enter_name"))
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

// MARK: - EditFlashcardView
struct EditFlashcardView: View {
        @ObservedObject var flashcard: Flashcard
        @Environment(\.managedObjectContext) private var viewContext
        @Environment(\.dismiss) private var dismiss
        @Environment(\.colorScheme) private var colorScheme
        
        // MARK: - États pour le contenu
        @State private var questionText = ""
        @State private var answerText = ""
        
        // MARK: - États médias Question
        @State private var questionImageData: Data?
        @State private var questionImageFileName: String?
        @State private var questionAudioFileName: String?
        @State private var questionAudioDuration: TimeInterval?
        
        // MARK: - États médias Answer
        @State private var answerImageData: Data?
        @State private var answerImageFileName: String?
        @State private var answerAudioFileName: String?
        @State private var answerAudioDuration: TimeInterval?
        
        // MARK: - États UI pour les présentations
        @State private var showingQuestionImagePicker = false
        @State private var showingAnswerImagePicker = false
        @State private var showingQuestionAudioMenu = false
        @State private var showingAnswerAudioMenu = false
        @State private var showingAudioFilePicker = false
        @State private var isQuestionAudioImport = false
        @State private var showQuestionAudioMenu: Bool = false
        @State private var showAnswerAudioMenu: Bool = false
        @State private var questionAudioImportContext: AudioImportContext = .question
        
        @State private var selectedQuestionImage: PhotosPickerItem?
        @State private var selectedAnswerImage: PhotosPickerItem?
        
        @ObservedObject private var audioManager = AudioManager.shared
        @State private var currentRecordingContext: RecordingContext?
        @State private var isProcessingAudio = false
        
        // ✅ NOUVEAU : États pour l'alerte audio
        @State private var showAudioDurationAlert = false
        @State private var audioDurationAlertMessage = ""
        
        private enum RecordingContext {
            case question
            case answer
        }
        
        private enum AudioImportContext {
            case question
            case answer
        }
        
        // MARK: - Computed properties pour interface conditionnelle
        private var hasQuestionMedia: Bool {
            questionImageFileName != nil || questionAudioFileName != nil
        }
        
        private var hasAnswerMedia: Bool {
            answerImageFileName != nil || answerAudioFileName != nil
        }
        
        // ✅ BACKGROUND ADAPTATIF : F6F7FB seulement en mode clair
        private var adaptiveBackground: Color {
            colorScheme == .light ? Color.appBackground : Color(.systemBackground)
        }
        
        init(flashcard: Flashcard) {
            self.flashcard = flashcard
            
            // ✅ CORRECTION : Toujours charger le texte, peu importe le type de contenu
            _questionText = State(initialValue: flashcard.question ?? "")
            _answerText = State(initialValue: flashcard.answer ?? "")
            
            // Initialiser les médias selon le type existant
            switch flashcard.questionContentType {
            case .text:
                // Texte déjà chargé
                break
            case .image:
                _questionImageData = State(initialValue: flashcard.questionImageData)
                _questionImageFileName = State(initialValue: flashcard.questionImageFileName)
            case .audio:
                _questionAudioFileName = State(initialValue: flashcard.questionAudioFileName)
                _questionAudioDuration = State(initialValue: flashcard.questionAudioDuration)
            }
            
            switch flashcard.answerContentType {
            case .text:
                // Texte déjà chargé
                break
            case .image:
                _answerImageData = State(initialValue: flashcard.answerImageData)
                _answerImageFileName = State(initialValue: flashcard.answerImageFileName)
            case .audio:
                _answerAudioFileName = State(initialValue: flashcard.answerAudioFileName)
                _answerAudioDuration = State(initialValue: flashcard.answerAudioDuration)
            }
        }
        
        // MARK: - Body principal
        var body: some View {
            NavigationStack {
                mainForm
                    .navigationTitle("Modifier la carte")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        toolbarContent
                    }
                    .onDisappear {
                        handleViewDisappear()
                    }
            }
            .photosPicker(
                isPresented: $showingQuestionImagePicker,
                selection: $selectedQuestionImage,
                matching: .images
            )
            .photosPicker(
                isPresented: $showingAnswerImagePicker,
                selection: $selectedAnswerImage,
                matching: .images
            )
            .confirmationDialog("Options audio", isPresented: $showQuestionAudioMenu) {
                Button("Enregistrer un audio") {
                    startInstantRecording(forQuestion: true)
                }
                Button("Importer un fichier") {
                    questionAudioImportContext = .question
                    showingAudioFilePicker = true
                }
                Button("Annuler", role: .cancel) { }
            }
            .confirmationDialog("Options audio", isPresented: $showAnswerAudioMenu) {
                Button("Enregistrer un audio") {
                    startInstantRecording(forQuestion: false)
                }
                Button("Importer un fichier") {
                    questionAudioImportContext = .answer
                    showingAudioFilePicker = true
                }
                Button("Annuler", role: .cancel) { }
            }
            .fileImporter(
                isPresented: $showingAudioFilePicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                handleAudioFileImport(result: result)
            }
            .onChange(of: selectedQuestionImage) { _, newValue in
                Task {
                    await handleQuestionImageSelection(newValue)
                }
            }
            .onChange(of: selectedAnswerImage) { _, newValue in
                Task {
                    await handleAnswerImageSelection(newValue)
                }
            }
            // ✅ NOUVEAU : Alerte SwiftUI pour la durée audio
            .alert("Durée audio limitée", isPresented: $showAudioDurationAlert) {
                Button("OK") { }
            } message: {
                Text(audioDurationAlertMessage)
            }
        }
        
        // MARK: - Sauvegarde optimisée
        private func saveChanges() {
            HapticFeedbackManager.shared.impact(style: .medium)
            
            // ✅ OPTIMISATION : Utiliser perform au lieu de performAndWait pour éviter le blocage
            viewContext.perform {
                do {
                    // Question - Sauvegarder le texte et déterminer le type principal
                    flashcard.question = questionText
                    if let questionAudioFileName = questionAudioFileName {
                        flashcard.questionContentType = .audio
                        flashcard.questionAudioFileName = questionAudioFileName
                        flashcard.questionAudioDuration = questionAudioDuration ?? 0
                    } else if let questionImageFileName = questionImageFileName {
                        flashcard.questionContentType = .image
                        flashcard.questionImageData = questionImageData
                        flashcard.questionImageFileName = questionImageFileName
                    } else {
                        flashcard.questionContentType = .text
                    }
                    
                    // Answer - Sauvegarder le texte et déterminer le type principal
                    flashcard.answer = answerText
                    if let answerAudioFileName = answerAudioFileName {
                        flashcard.answerContentType = .audio
                        flashcard.answerAudioFileName = answerAudioFileName
                        flashcard.answerAudioDuration = answerAudioDuration ?? 0
                    } else if let answerImageFileName = answerImageFileName {
                        flashcard.answerContentType = .image
                        flashcard.answerImageData = answerImageData
                        flashcard.answerImageFileName = answerImageFileName
                    } else {
                        flashcard.answerContentType = .text
                    }
                    
                    try viewContext.save()
                    
                    // ✅ AJOUT : Invalider le cache SM-2 pour forcer le rechargement
                    SM2OptimizationCache.shared.clearAllSM2Caches()
                    
                    // ✅ OPTIMISATION : Supprimer les rafraîchissements coûteux
                    // viewContext.refresh(flashcard, mergeChanges: true)
                    // if let deck = flashcard.deck {
                    //     viewContext.refresh(deck, mergeChanges: true)
                    // }
                    
                    // ✅ OPTIMISATION : Notification asynchrone
                    DispatchQueue.main.async {
                        if let deck = flashcard.deck {
                            DeckSharingManager.shared.notifyFlashcardModification(deck: deck)
                        }
                        HapticFeedbackManager.shared.notification(type: .success)
                        dismiss()
                    }
                } catch {
                    DispatchQueue.main.async {
                        HapticFeedbackManager.shared.notification(type: .error)
                        print("Erreur modification flashcard: \(error)")
                        viewContext.rollback()
                    }
                }
            }
        }
        
        // MARK: - Form principal séparé
        @ViewBuilder
        private var mainForm: some View {
            Form {
                questionSection
                answerSection
            }
        }
        
        @ViewBuilder
        private var questionSection: some View {
            Section("QUESTION") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        // TextField toujours visible
                        TextField("Question (optionnel)", text: $questionText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(1...3)
                        
                        Spacer()
                        
                        // Boutons d'action
                        questionActionButtons
                    }
                    
                    // Indicateurs médias
                    questionMediaIndicators
                }
            }
        }
        
        @ViewBuilder
        private var answerSection: some View {
            Section("RÉPONSE") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        // TextField toujours visible
                        TextField("Réponse (optionnel)", text: $answerText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(1...3)
                        
                        Spacer()
                        
                        // Boutons d'action
                        answerActionButtons
                    }
                    // Indicateurs médias
                    answerMediaIndicators
                }
            }
        }
        
        // MARK: - Toolbar séparé
        @ToolbarContentBuilder
        private var toolbarContent: some ToolbarContent {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") {
                    handleCancel()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sauvegarder") {
                    saveChanges()
                }
                .disabled(!canSave || audioManager.isRecording)
            }
        }
        
        // MARK: - Computed Properties
        private var canSave: Bool {
            let hasQuestionContent = !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            questionImageFileName != nil ||
            questionAudioFileName != nil
            
            let hasAnswerContent = !answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            answerImageFileName != nil ||
            answerAudioFileName != nil
            
            return hasQuestionContent && hasAnswerContent
        }
        
        // MARK: - Boutons d'action Question
        @ViewBuilder
        private var questionActionButtons: some View {
            HStack(spacing: 12) {
                Button(action: {
                    showingQuestionImagePicker = true
                }) {
                    Image(systemName: questionImageFileName != nil ? "photo.badge.checkmark" : "photo.badge.plus")
                        .foregroundColor(questionImageFileName != nil ? .green : .blue)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    let isCurrentlyRecording = audioManager.isRecording &&
                    currentRecordingContext == .question
                    
                    if isCurrentlyRecording {
                        finishInstantRecording()
                    } else {
                        handleAudioButtonTap(forQuestion: true)
                    }
                }) {
                    audioButtonIcon(forQuestion: true)
                }
                .buttonStyle(.plain)
                .disabled(isProcessingAudio)
            }
        }
        
        // MARK: - Boutons d'action Answer
        @ViewBuilder
        private var answerActionButtons: some View {
            HStack(spacing: 12) {
                Button(action: {
                    showingAnswerImagePicker = true
                }) {
                    Image(systemName: answerImageFileName != nil ? "photo.badge.checkmark" : "photo.badge.plus")
                        .foregroundColor(answerImageFileName != nil ? .green : .blue)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    let isCurrentlyRecording = audioManager.isRecording &&
                    currentRecordingContext == .answer
                    
                    if isCurrentlyRecording {
                        finishInstantRecording()
                    } else {
                        handleAudioButtonTap(forQuestion: false)
                    }
                }) {
                    audioButtonIcon(forQuestion: false)
                }
                .buttonStyle(.plain)
                .disabled(isProcessingAudio)
            }
        }
        
        @ViewBuilder
        private func audioButtonIcon(forQuestion: Bool) -> some View {
            let isCurrentlyRecording = audioManager.isRecording &&
            currentRecordingContext == (forQuestion ? .question : .answer)
            let hasAudio = forQuestion ? questionAudioFileName != nil : answerAudioFileName != nil
            
            if isCurrentlyRecording {
                ZStack {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.red)
                        .opacity(0.25)
                        .font(.title2)
                    
                    Image(systemName: "circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 8))
                }
                .scaleEffect(1.1)
                .animation(.easeInOut(duration: 0.2), value: isCurrentlyRecording)
                
            } else if hasAudio {
                Image(systemName: "waveform.badge.checkmark")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        
        // MARK: - Indicateurs médias séparés
        @ViewBuilder
        private var questionMediaIndicators: some View {
            mediaIndicatorsView(
                imageFileName: questionImageFileName,
                imageData: questionImageData,
                audioFileName: questionAudioFileName,
                audioDuration: questionAudioDuration,
                onRemoveImage: {
                    removeQuestionImage()
                },
                onRemoveAudio: {
                    if audioManager.isPlaying && audioManager.playingFileName == questionAudioFileName {
                        audioManager.stopAudioSilently()
                    }
                    removeQuestionAudio()
                }
            )
        }
        
        @ViewBuilder
        private var answerMediaIndicators: some View {
            mediaIndicatorsView(
                imageFileName: answerImageFileName,
                imageData: answerImageData,
                audioFileName: answerAudioFileName,
                audioDuration: answerAudioDuration,
                onRemoveImage: {
                    removeAnswerImage()
                },
                onRemoveAudio: {
                    if audioManager.isPlaying && audioManager.playingFileName == answerAudioFileName {
                        audioManager.stopAudio()
                    }
                    removeAnswerAudio()
                }
            )
        }
        
        // MARK: - Indicateurs Médias
        @ViewBuilder
        private func mediaIndicatorsView(
            imageFileName: String?,
            imageData: Data?,
            audioFileName: String?,
            audioDuration: TimeInterval?,
            onRemoveImage: @escaping () -> Void,
            onRemoveAudio: @escaping () -> Void
        ) -> some View {
            if imageFileName != nil || audioFileName != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let imageFileName = imageFileName {
                        HStack(spacing: 8) {
                            imagePreview(imageFileName: imageFileName, imageData: imageData)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Image ajoutée")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Button(action: onRemoveImage) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    if let audioFileName = audioFileName {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Audio ajouté")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                if let duration = audioDuration {
                                    Text("Durée: \(formatDuration(duration))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                if audioManager.isPlaying && audioManager.playingFileName == audioFileName {
                                    audioManager.stopAudio()
                                } else {
                                    audioManager.playAudio(fileName: audioFileName)
                                }
                            }) {
                                Image(systemName: audioManager.isPlaying && audioManager.playingFileName == audioFileName ? "pause.circle" : "play.circle")
                                    .foregroundColor(.blue)
                                    .contentTransition(.identity)
                                    .transaction { $0.animation = nil }
                                    .animation(nil, value: audioManager.isPlaying)
                            }
                            .buttonStyle(.plain)
                            .transaction { $0.animation = nil }
                            
                            Button(action: onRemoveAudio) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        
        @ViewBuilder
        private func imagePreview(imageFileName: String?, imageData: Data?) -> some View {
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if let imageFileName = imageFileName {
                if let imageURL = MediaStorageManager.shared.getImageURL(fileName: imageFileName),
                   let uiImage = UIImage(contentsOfFile: imageURL.path) {
                    
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    errorPlaceholder("Image non trouvée")
                }
            } else {
                Image(systemName: "photo")
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        
        @ViewBuilder
        private func errorPlaceholder(_ message: String) -> some View {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 40, height: 40)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        
        // MARK: - Actions
        private func handleCancel() {
            if audioManager.isRecording {
                audioManager.forceStopRecording()
            }
            if audioManager.isPlaying {
                audioManager.stopAudio()
            }
            dismiss()
        }
        
        private func handleViewDisappear() {
            if audioManager.isPlaying {
                audioManager.stopAudioSilently()
            }
            
            if audioManager.isRecording {
                audioManager.forceCleanState()
            }
        }
        
        private func handleAudioButtonTap(forQuestion: Bool) {
            if forQuestion {
                showQuestionAudioMenu = true
            } else {
                showAnswerAudioMenu = true
            }
        }
        
        // MARK: - Gestion Images
        private func handleQuestionImageSelection(_ newValue: PhotosPickerItem?) async {
            guard let selectedQuestionImage = newValue else { return }
            
            do {
                if let data = try await selectedQuestionImage.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    
                    let compressedImage = compressImageForPreview(image)
                    
                    if let result = MediaStorageManager.shared.storeImage(compressedImage) {
                        await MainActor.run {
                            // Supprimer l'audio existant
                            if let existingAudioFileName = self.questionAudioFileName {
                                MediaStorageManager.shared.deleteAudio(fileName: existingAudioFileName)
                                self.questionAudioFileName = nil
                                self.questionAudioDuration = nil
                            }
                            
                            self.questionImageData = data
                            self.questionImageFileName = result.fileName
                            self.selectedQuestionImage = nil
                        }
                    }
                }
            } catch {
                print("❌ Error loading question image: \(error)")
            }
        }
        
        private func handleAnswerImageSelection(_ newValue: PhotosPickerItem?) async {
            guard let selectedAnswerImage = newValue else { return }
            
            do {
                if let data = try await selectedAnswerImage.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let result = MediaStorageManager.shared.storeImage(image) {
                    
                    await MainActor.run {
                        // Supprimer l'audio existant avant d'ajouter l'image
                        if let existingAudioFileName = self.answerAudioFileName {
                            MediaStorageManager.shared.deleteAudio(fileName: existingAudioFileName)
                            self.answerAudioFileName = nil
                            self.answerAudioDuration = nil
                        }
                        
                        self.answerImageData = result.shouldStoreInFileManager ? nil : result.data
                        self.answerImageFileName = result.fileName
                        self.selectedAnswerImage = nil
                    }
                }
            } catch {
                print("❌ Error loading answer image: \(error)")
                await MainActor.run {
                    self.selectedAnswerImage = nil
                }
            }
        }
        
        private func compressImageForPreview(_ image: UIImage) -> UIImage {
            let maxSize: CGFloat = 1024
            let size = image.size
            let ratio = min(maxSize / size.width, maxSize / size.height)
            
            if ratio >= 1 { return image }
            
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let compressedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return compressedImage ?? image
        }
        
        // MARK: - Suppression Médias
        private func removeQuestionImage() {
            if let fileName = questionImageFileName {
                MediaStorageManager.shared.deleteImage(fileName: fileName, hasFileManagerData: questionImageData == nil)
            }
            questionImageData = nil
            questionImageFileName = nil
        }
        
        private func removeAnswerImage() {
            if let fileName = answerImageFileName {
                MediaStorageManager.shared.deleteImage(fileName: fileName, hasFileManagerData: answerImageData == nil)
            }
            answerImageData = nil
            answerImageFileName = nil
        }
        
        private func removeQuestionAudio() {
            if let fileName = questionAudioFileName {
                MediaStorageManager.shared.deleteAudio(fileName: fileName)
            }
            questionAudioFileName = nil
            questionAudioDuration = nil
        }
        
        private func removeAnswerAudio() {
            if let fileName = answerAudioFileName {
                MediaStorageManager.shared.deleteAudio(fileName: fileName)
            }
            answerAudioFileName = nil
            answerAudioDuration = nil
        }
        
        // MARK: - Audio Recording
        private func startInstantRecording(forQuestion: Bool) {
            guard !audioManager.isRecording && !isProcessingAudio else { return }
            
            currentRecordingContext = forQuestion ? .question : .answer
            audioManager.startRecordingInstantly()
            
            Task.detached(priority: .background) {
                await MainActor.run {
                    self.isProcessingAudio = true
                    
                    if forQuestion {
                        if let fileName = self.questionAudioFileName {
                            MediaStorageManager.shared.deleteAudio(fileName: fileName)
                            self.questionAudioFileName = nil
                            self.questionAudioDuration = 0
                        }
                        if let existingImageFileName = self.questionImageFileName {
                            MediaStorageManager.shared.deleteImage(fileName: existingImageFileName, hasFileManagerData: self.questionImageData == nil)
                            self.questionImageData = nil
                            self.questionImageFileName = nil
                        }
                    } else {
                        if let fileName = self.answerAudioFileName {
                            MediaStorageManager.shared.deleteAudio(fileName: fileName)
                            self.answerAudioFileName = nil
                            self.answerAudioDuration = 0
                        }
                        if let existingImageFileName = self.answerImageFileName {
                            MediaStorageManager.shared.deleteImage(fileName: existingImageFileName, hasFileManagerData: self.answerImageData == nil)
                            self.answerImageData = nil
                            self.answerImageFileName = nil
                        }
                    }
                    
                    self.isProcessingAudio = false
                }
            }
            
            HapticFeedbackManager.shared.impact(style: .medium)
        }
        
        private func finishInstantRecording() {
            guard audioManager.isRecording else { return }
            
            finishRecording()
            HapticFeedbackManager.shared.impact(style: .light)
        }
        
        private func finishRecording() {
            guard audioManager.isRecording && !isProcessingAudio else { return }
            
            isProcessingAudio = true
            
            Task { @MainActor in
                if let finalFileName = await audioManager.toggleRecording() {
                    let duration = audioManager.recordingDuration > 0 ? audioManager.recordingDuration : 1.0
                    
                    if self.currentRecordingContext == .question {
                        self.questionAudioFileName = finalFileName
                        self.questionAudioDuration = duration
                    } else {
                        self.answerAudioFileName = finalFileName
                        self.answerAudioDuration = duration
                    }
                    
                    self.currentRecordingContext = nil
                    self.isProcessingAudio = false
                } else {
                    audioManager.forceCleanState()
                    self.isProcessingAudio = false
                    self.cancelRecording()
                }
            }
        }
        
        private func cancelRecording() {
            audioManager.forceStopRecording()
            
            Task { @MainActor in
                if let context = currentRecordingContext {
                    let fileName = context == .question ? questionAudioFileName : answerAudioFileName
                    if let fileName = fileName {
                        MediaStorageManager.shared.deleteAudio(fileName: fileName)
                    }
                    
                    if context == .question {
                        self.questionAudioFileName = nil
                        self.questionAudioDuration = nil
                    } else {
                        self.answerAudioFileName = nil
                        self.answerAudioDuration = nil
                    }
                }
                
                self.currentRecordingContext = nil
                self.isProcessingAudio = false
            }
        }
        
        // MARK: - Import Audio
        private func handleAudioFileImport(result: Result<[URL], Error>) {
            switch result {
            case .success(let urls):
                guard let sourceURL = urls.first else { return }
                
                Task {
                    let shouldStopAccessing = sourceURL.startAccessingSecurityScopedResource()
                    defer {
                        if shouldStopAccessing {
                            sourceURL.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    do {
                        let audioData = try Data(contentsOf: sourceURL)
                        let newFileName = "\(UUID().uuidString).\(sourceURL.pathExtension)"
                        let destinationURL = MediaStorageManager.shared.getAudioURL(fileName: newFileName)
                        
                        try audioData.write(to: destinationURL, options: .atomic)
                        
                        let asset = AVAsset(url: destinationURL)
                        let duration = try await asset.load(.duration)
                        let seconds = CMTimeGetSeconds(duration)
                        
                        // ✅ NOUVEAU : Vérification de la durée audio avec alerte SwiftUI
                        let premiumManager = PremiumManager.shared
                        if !premiumManager.isValidAudioDuration(seconds) {
                            await MainActor.run {
                                // Supprimer le fichier temporaire
                                try? FileManager.default.removeItem(at: destinationURL)
                                
                                // Afficher l'alerte SwiftUI
                                HapticFeedbackManager.shared.notification(type: .warning)
                                audioDurationAlertMessage = "Les fichiers audio sont limités à 30 secondes maximum."
                                showAudioDurationAlert = true
                            }
                            return
                        }
                        
                        await MainActor.run {
                            if questionAudioImportContext == .question {
                                if let existingImageFileName = self.questionImageFileName {
                                    MediaStorageManager.shared.deleteImage(fileName: existingImageFileName, hasFileManagerData: self.questionImageData == nil)
                                    self.questionImageData = nil
                                    self.questionImageFileName = nil
                                }
                                self.questionAudioFileName = newFileName
                                self.questionAudioDuration = seconds
                            } else {
                                if let existingImageFileName = self.answerImageFileName {
                                    MediaStorageManager.shared.deleteImage(fileName: existingImageFileName, hasFileManagerData: self.answerImageData == nil)
                                    self.answerImageData = nil
                                    self.answerImageFileName = nil
                                }
                                self.answerAudioFileName = newFileName
                                self.answerAudioDuration = seconds
                                    }
    }

    } catch {
                        print("❌ Audio import error: \(error)")
                    }
                }
                
            case .failure(let error):
                print("❌ File selection error: \(error)")
            }
        }
        
        // MARK: - Utilitaires
        private func formatDuration(_ duration: TimeInterval) -> String {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

// MARK: - Extensions
private extension View {
    func safeAreaInsets() -> some View {
        self
            .safeAreaInset(edge: .top) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 25)
            }
            .safeAreaInset(edge: .bottom) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 60)
            }
    }
}

// MARK: - ActiveSheet Enum
enum ActiveSheet: Identifiable, Equatable {
    case addFlashcard
    case modeSelection
    case premium
    case editFlashcard(Flashcard)
    
    var id: String {
        switch self {
        case .addFlashcard: return "add"
        case .modeSelection: return "mode"
        case .premium: return "premium"
        case .editFlashcard(let card): return "edit_\(card.id?.uuidString ?? "")"
        }
    }
    
    // ✅ IMPLÉMENTATION DE EQUATABLE
    static func == (lhs: ActiveSheet, rhs: ActiveSheet) -> Bool {
        switch (lhs, rhs) {
        case (.addFlashcard, .addFlashcard):
            return true
        case (.modeSelection, .modeSelection):
            return true
        case (.premium, .premium):
            return true
        case (.editFlashcard(let lhsCard), .editFlashcard(let rhsCard)):
            return lhsCard.id == rhsCard.id // Comparaison par ID
        default:
            return false
        }
    }
}

// ✅ NOUVEAU : Enum pour les options de filtrage des flashcards
enum FlashcardFilterOption: String, CaseIterable {
    case all = "all"
    case new = "new"
    case needsReview = "needs_review"
    case overdue = "overdue"
    case acquired = "acquired"
    case mastered = "mastered"
    case toStudy = "to_study"  // ✅ NOUVEAU : Pour mode libre
    case textOnly = "text_only"
    case withMedia = "with_media"
    case withAudio = "with_audio"
    case withImages = "with_images"
    
    var displayName: String {
        switch self {
        case .all: return "Toutes"
        case .new: return "Nouvelles"
        case .needsReview: return "À réviser"
        case .overdue: return "En retard"
        case .acquired: return "Acquises"
        case .mastered: return "Maîtrisées"
        case .toStudy: return "À étudier"  // ✅ NOUVEAU : Pour mode libre
        case .textOnly: return "Texte uniquement"
        case .withMedia: return "Médias"
        case .withAudio: return "Audio"
        case .withImages: return "Images"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "rectangle.stack"
        case .new: return "sparkles"
        case .needsReview: return "clock"
        case .overdue: return "exclamationmark.triangle"
        case .acquired: return "star"
        case .mastered: return "crown"
        case .toStudy: return "clock"  // ✅ NOUVEAU : Même icône que "À réviser"
        case .textOnly: return "textformat"
        case .withMedia: return "photo.on.rectangle.angled"
        case .withAudio: return "speaker.wave.2"
        case .withImages: return "photo"
        }
    }
}

// ✅ NOUVEAU : Enum pour les options de tri des flashcards
enum FlashcardSortOption: String, CaseIterable {
    case creationDate = "creation_date"
    case lastReview = "last_review"
    case difficulty = "difficulty"
    case alphabetical = "alphabetical"
    
    var displayName: String {
        switch self {
        case .creationDate: return "Date de création"
        case .lastReview: return "Dernière révision"
        case .difficulty: return "Difficulté"
        case .alphabetical: return "Alphabétique"
        }
    }
    
    var icon: String {
        switch self {
        case .creationDate: return "calendar"
        case .lastReview: return "clock"
        case .difficulty: return "chart.bar"
        case .alphabetical: return "textformat"
        }
    }
}

// MARK: - DeckDetailView
struct DeckDetailView: View {
    @ObservedObject var deck: FlashcardDeck
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    // ✅ CRITICAL : Force refresh du dashboard après les sessions
    @State private var dashboardRefreshTrigger = UUID()
    @State private var listRefreshTrigger = UUID()  // ✅ AJOUT : Trigger pour la liste
    
    // ✅ AJOUT : Timer pour rafraîchir le dashboard automatiquement
    @State private var dashboardRefreshTimer: Timer?
    
    // ✅ OPTIMISATION : Debouncing pour éviter les rafraîchissements multiples
    @State private var refreshWorkItem: DispatchWorkItem?
    
    // ✅ NOUVEAU : Écoute des notifications de mise à jour
    @State private var statsUpdateObserver: NSObjectProtocol?
    @FetchRequest var flashcards: FetchedResults<Flashcard>
    @ObservedObject private var audioManager = AudioManager.shared
    
    // ✅ SYSTÈME UNIFIÉ ACTIVESHEET
    @State private var activeSheet: ActiveSheet?
    
    // ✅ FULLSCREEN COVERS (séparés des sheets)
    @State private var showRevisionSession = false
    @State private var showQuizSession = false
    @State private var showAssociationSession = false
    
    // ✅ NOUVEAU : Indicateur de mode
    @State private var showModeExplanationSheet = false
    
    // ✅ NOUVEAU : Sheet pour la génération IA
    @State private var showAIGenerationSheet = false
    
    // ✅ AUTRES VARIABLES
    @State private var premiumManager = PremiumManager.shared
    @State private var isViewActive = true
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @StateObject private var sharingManager = DeckSharingManager.shared
    @State private var searchText = ""
    @State private var showMediaWarningPopover = false
    @State private var showFlashcardLimitToast = false
    @State private var debouncedSearchText = ""
    @State private var searchWorkItem: DispatchWorkItem?
    
    // ✅ VARIABLES DE PROTECTION CONTRE LE DOUBLE TAP
    @State private var isAddButtonProcessing = false
    @State private var isStartButtonProcessing = false
    
    // ✅ NOUVEAU : Variables pour le filtrage des flashcards
    @State private var flashcardFilterOption: FlashcardFilterOption = .all
    @State private var flashcardSortOption: FlashcardSortOption = .creationDate
    @State private var flashcardSortOrder: SortOrder = .ascending
    
    // ✅ MODE LIBRE : Synchronisé avec les sessions
    @AppStorage("isFreeMode") private var isFreeMode = false
    
    // ✅ NOUVEAU : Indicateur de mode
    private var modeIndicatorView: some View {
        Button {
            showModeExplanationSheet = true
        } label: {
            HStack(spacing: 4) {
                Text(isFreeMode ? "Mode Libre" : "Mode répétition espacée")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    private var hasReachedFlashcardLimit: Bool {
        !premiumManager.canCreateFlashcard(currentDeckCount: flashcards.count, context: viewContext)
    }
    
    private var flashcardLimitInfo: (canCreate: Bool, isGlobalLimit: Bool, remaining: Int, max: Int) {
        let globalInfo = premiumManager.getTotalFlashcardInfo(context: viewContext)
        let deckInfo = premiumManager.getDeckFlashcardInfo(currentDeckCount: flashcards.count)
        
        // Vérifier d'abord la limite globale
        if !premiumManager.canCreateFlashcardGlobal(context: viewContext) {
            return (canCreate: false, isGlobalLimit: true, remaining: globalInfo.remaining, max: globalInfo.max)
        }
        
        // Puis la limite par deck
        if !premiumManager.canCreateFlashcardInDeck(currentDeckCount: flashcards.count) {
            return (canCreate: false, isGlobalLimit: false, remaining: deckInfo.remaining, max: deckInfo.max)
        }
        
        return (canCreate: true, isGlobalLimit: false, remaining: deckInfo.remaining, max: deckInfo.max)
    }
    
    private var shouldShowLimitWarning: Bool {
        let info = flashcardLimitInfo
        return info.remaining <= 5  // Afficher si ≤ 5 cartes restantes (dès la 195ème)
    }
    
    private func getLimitMessage() -> String {
        let info = flashcardLimitInfo
        
        if info.isGlobalLimit {
            return "Limite globale atteinte ! Passez à "
        } else if info.remaining <= 5 && info.remaining > 0 {
            return "Attention : Plus que \(info.remaining) cartes restantes !"
        } else {
            return "Deck complet !"
        }
    }
    
    private var getLimitMessageWithColoredPro: some View {
        let baseMessage = getLimitMessage()
        
        if baseMessage.contains("Passez à") {
            return AnyView(
                Text(baseMessage + "Gradefy Pro")
                    .foregroundColor(.white)
                    .overlay(
                        Text("Gradefy Pro")
                            .foregroundColor(.blue)
                            .offset(x: baseMessage.size(withAttributes: [.font: UIFont.systemFont(ofSize: 16)]).width)
                    )
            )
        } else {
            return AnyView(
                Text(baseMessage)
                    .foregroundColor(.white)
            )
        }
    }
    
    private var isToastClickable: Bool {
        let info = flashcardLimitInfo
        // Cliquable seulement si c'est une limite premium (globale uniquement)
        return info.isGlobalLimit
    }
    
    private var hasMediaContent: Bool {
        flashcards.contains { flashcard in
            flashcard.questionContentType != .text || flashcard.answerContentType != .text
        }
    }
    
    init(deck: FlashcardDeck) {
        self.deck = deck
        self._flashcards = FetchRequest(
            entity: Flashcard.entity(),
            sortDescriptors: [
                NSSortDescriptor(keyPath: \Flashcard.createdAt, ascending: true)
            ],
            predicate: NSPredicate(format: "deck == %@", deck)
        )
    }
    
    private var hasFlashcards: Bool {
        !flashcards.isEmpty
    }
    
    // 🔍 AMÉLIORÉ : Filtrage natif avec support médias
    private var filteredFlashcards: [Flashcard] {
        var cards = Array(flashcards)
        
        // ✅ ÉTAPE 1 : Filtrage par type de contenu
        switch flashcardFilterOption {
        case .all:
            break // Pas de filtrage
        case .textOnly:
            cards = cards.filter { flashcard in
                flashcard.questionContentType == .text && flashcard.answerContentType == .text
            }
        case .withMedia:
            cards = cards.filter { flashcard in
                flashcard.questionContentType != .text || flashcard.answerContentType != .text
            }
        case .mastered:
            cards = cards.filter { flashcard in
                // ✅ Cartes maîtrisées : intervalle >= 21 jours (selon SRSConfiguration)
                flashcard.interval >= SRSConfiguration.masteryIntervalThreshold
            }
        case .acquired:
            cards = cards.filter { flashcard in
                // ✅ Cartes acquises : intervalle >= 7 jours mais < 21 jours
                flashcard.interval >= SRSConfiguration.acquiredIntervalThreshold && 
                flashcard.interval < SRSConfiguration.masteryIntervalThreshold
            }
        case .needsReview:
            cards = cards.filter { flashcard in
                // Cartes à réviser : statut "À réviser" selon SM-2
                if let nextReview = flashcard.nextReviewDate {
                    return nextReview <= Date() // Due aujourd'hui ou en retard
                }
                return false
            }
        case .new:
            cards = cards.filter { flashcard in
                // Nouvelles cartes : reviewCount == 0
                flashcard.reviewCount == 0
            }
        case .overdue:
            cards = cards.filter { flashcard in
                // Cartes en retard : statut "En retard" selon SM-2
                if let nextReview = flashcard.nextReviewDate {
                    return nextReview < Date() // Strictement en retard
                }
                return false
            }
        case .withAudio:
            cards = cards.filter { flashcard in
                // Cartes avec audio
                flashcard.questionAudioFileName != nil || flashcard.answerAudioFileName != nil
            }
        case .withImages:
            cards = cards.filter { flashcard in
                // Cartes avec images
                flashcard.questionImageFileName != nil || flashcard.answerImageFileName != nil
            }
        case .toStudy:
            cards = cards.filter { flashcard in
                // ✅ MODE LIBRE : Cartes à étudier (pas maîtrisées)
                let status = SimpleSRSManager.shared.getFreeModeStatus(for: flashcard)
                return status == .toStudy
            }
        }
        
        // ✅ ÉTAPE 2 : Filtrage par recherche textuelle
        if !debouncedSearchText.isEmpty {
            let searchTerms = debouncedSearchText.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            if !searchTerms.isEmpty {
                cards = cards.filter { flashcard in
                    // ✅ Recherche dans le contenu textuel
                    let questionText = flashcard.question?.lowercased() ?? ""
                    let answerText = flashcard.answer?.lowercased() ?? ""
                    
                    // ✅ Recherche dans les noms de fichiers médias
                    let questionMediaName = flashcard.questionImageFileName?.lowercased() ??
                    flashcard.questionAudioFileName?.lowercased() ?? ""
                    let answerMediaName = flashcard.answerImageFileName?.lowercased() ??
                    flashcard.answerAudioFileName?.lowercased() ?? ""
                    
                    let allContent = "\(questionText) \(answerText) \(questionMediaName) \(answerMediaName)"
                    
                    // ✅ Tous les termes doivent être trouvés (recherche AND)
                    return searchTerms.allSatisfy { term in
                        allContent.contains(term)
                    }
                }
            }
        }
        
        // ✅ ÉTAPE 3 : Tri des cartes
        cards.sort { first, second in
            let comparison: Bool
            
            switch flashcardSortOption {
            case .creationDate:
                let date1 = first.createdAt ?? Date.distantPast
                let date2 = second.createdAt ?? Date.distantPast
                comparison = date1 < date2
                
            case .lastReview:
                // ✅ Les cartes jamais révisées apparaissent en dernier
                if first.lastReviewDate == nil && second.lastReviewDate != nil {
                    comparison = false // first (jamais révisée) après second
                } else if first.lastReviewDate != nil && second.lastReviewDate == nil {
                    comparison = true // first (révisée) avant second (jamais révisée)
                } else {
                    // Les deux ont une date de révision ou aucune n'en a
                    let date1 = first.lastReviewDate ?? Date.distantPast
                    let date2 = second.lastReviewDate ?? Date.distantPast
                    comparison = date1 < date2
                }
                
            case .difficulty:
                // ✅ Les cartes jamais révisées sont considérées comme les plus difficiles
                if first.lastReviewDate == nil && second.lastReviewDate != nil {
                    comparison = false // first (jamais révisée) après second (plus difficile)
                } else if first.lastReviewDate != nil && second.lastReviewDate == nil {
                    comparison = true // first (révisée) avant second (jamais révisée)
                } else {
                    // Les deux ont été révisées ou aucune n'a été révisée
                    let ease1 = first.easeFactor
                    let ease2 = second.easeFactor
                    comparison = ease1 < ease2 // Plus difficile (easeFactor plus bas) en premier
                }
                
            case .alphabetical:
                let text1 = first.question ?? ""
                let text2 = second.question ?? ""
                comparison = text1 < text2
            }
            
            return flashcardSortOrder == .ascending ? comparison : !comparison
        }
        
        return cards
    }
    
    // ✅ AMÉLIORÉ : Prompt de recherche dynamique
    private var searchPrompt: String {
        if debouncedSearchText.isEmpty {
            // ✅ Calculer le nombre de cartes après filtrage sans récursion
            let filteredCount = getFilteredCountWithoutSearch()
            return "Rechercher dans \(filteredCount) carte\(filteredCount > 1 ? "s" : "")"
        } else {
            let count = filteredFlashcards.count
            return "\(count) résultat\(count > 1 ? "s" : "") trouvé\(count > 1 ? "s" : "")"
        }
    }
    
    // ✅ Fonction helper pour éviter la récursion
    private func getFilteredCountWithoutSearch() -> Int {
        var cards = Array(flashcards)
        
        // Appliquer seulement le filtrage par type (pas la recherche)
        switch flashcardFilterOption {
        case .all:
            break
        case .textOnly:
            cards = cards.filter { flashcard in
                flashcard.questionContentType == .text && flashcard.answerContentType == .text
            }
        case .withMedia:
            cards = cards.filter { flashcard in
                flashcard.questionContentType != .text || flashcard.answerContentType != .text
            }
        case .mastered:
            cards = cards.filter { flashcard in
                // ✅ Cartes maîtrisées : intervalle >= 21 jours (selon SRSConfiguration)
                flashcard.interval >= SRSConfiguration.masteryIntervalThreshold
            }
        case .acquired:
            cards = cards.filter { flashcard in
                // ✅ Cartes acquises : intervalle >= 7 jours mais < 21 jours
                flashcard.interval >= SRSConfiguration.acquiredIntervalThreshold && 
                flashcard.interval < SRSConfiguration.masteryIntervalThreshold
            }
        case .needsReview:
            cards = cards.filter { flashcard in
                flashcard.easeFactor < 2.0 || flashcard.lastReviewDate == nil
            }
        case .new:
            cards = cards.filter { flashcard in
                flashcard.reviewCount == 0
            }
        case .overdue:
            cards = cards.filter { flashcard in
                if let nextReview = flashcard.nextReviewDate {
                    return nextReview < Date() // Strictement en retard
                }
                return false
            }
        case .withAudio:
            cards = cards.filter { flashcard in
                flashcard.questionAudioFileName != nil || flashcard.answerAudioFileName != nil
            }
        case .withImages:
            cards = cards.filter { flashcard in
                flashcard.questionImageFileName != nil || flashcard.answerImageFileName != nil
            }
        case .toStudy:
            cards = cards.filter { flashcard in
                // ✅ MODE LIBRE : Cartes à étudier (pas maîtrisées)
                let status = SimpleSRSManager.shared.getFreeModeStatus(for: flashcard)
                return status == .toStudy
            }
        }
        
        return cards.count
    }
    
    var body: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                contentSection
            }
            
            // ✅ Toast overlay
            VStack {
                Spacer()
                if showFlashcardLimitToast {
                    flashcardLimitToast
                        .padding(.bottom, 100)
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showFlashcardLimitToast)
        }
        .navigationTitle(deck.name ?? "Deck")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            colorScheme == .dark ? Color(.systemBackground) : Color.white,
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                toolbarContent
            }
        }
        .onDisappear {
            if let url = shareURL {
                try? FileManager.default.removeItem(at: url)
                shareURL = nil
            }
        }
        .onAppear {
            isViewActive = true
            // ✅ RESET : Effacer la recherche en arrivant sur la vue
            searchText = ""
            debouncedSearchText = ""
            
            // ✅ CRITICAL : Démarrer le timer de rafraîchissement automatique
            startDashboardRefreshTimer()
            
            // ✅ NOUVEAU : Écouter les mises à jour de stats en temps réel
            statsUpdateObserver = NotificationCenter.default.addObserver(
                forName: .deckStatsUpdated,
                object: deck,
                queue: .main
            ) { _ in
                refreshDashboardImmediately()
            }
        }
        .onDisappear {
            isViewActive = false
            
            // ✅ NOUVEAU : Nettoyer l'observateur de notifications
            if let observer = statsUpdateObserver {
                NotificationCenter.default.removeObserver(observer)
                statsUpdateObserver = nil
            }
            audioManager.stopAudio()
            
            // ✅ CRITICAL : Arrêter le timer quand la vue disparaît
            stopDashboardRefreshTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FlashcardModified"))) { notification in
            // ✅ SOLUTION : Rafraîchir la liste quand une flashcard est modifiée
            if let modifiedDeck = notification.object as? FlashcardDeck, modifiedDeck == deck {
                DispatchQueue.main.async {
                    listRefreshTrigger = UUID()
                    viewContext.refreshAllObjects()
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            searchWorkItem?.cancel()
            let workItem = DispatchWorkItem {
                debouncedSearchText = newValue
            }
            searchWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)  // ✅ Plus réactif
        }
        .onChange(of: activeSheet) { _, newSheet in
            if newSheet != nil {
                audioManager.stopAudio()
            }
        }
        .fullScreenCover(isPresented: $showRevisionSession) {
            FlashcardStackRevisionView(deck: deck)
                .onAppear {
                    AudioManager.shared.stopAudio()
                }
                .onDisappear {
                    // ✅ CRITICAL : Refresh dashboard immédiat après session flashcards
                    refreshDashboardImmediately()
                }
        }
        .onChange(of: showRevisionSession) { isPresented in
            if !isPresented {
                // ✅ NOUVEAU : Refresh immédiat quand la session se ferme
                refreshDashboardImmediately()
            }
        }
        .fullScreenCover(isPresented: $showQuizSession) {
            QuizView(deck: deck)
                .onAppear {
                    AudioManager.shared.stopAudio()
                }
                .onDisappear {
                    // ✅ CRITICAL : Refresh dashboard immédiat après session quiz
                    refreshDashboardImmediately()
                }
        }
        .onChange(of: showQuizSession) { isPresented in
            if !isPresented {
                // ✅ NOUVEAU : Refresh immédiat quand la session se ferme
                refreshDashboardImmediately()
            }
        }
        .fullScreenCover(isPresented: $showAssociationSession) {
            AssociationView(deck: deck)
                .onAppear {
                    AudioManager.shared.stopAudio()
                }
                .onDisappear {
                    // ✅ CRITICAL : Refresh dashboard immédiat après session association
                    refreshDashboardImmediately()
                }
        }
        .onChange(of: showAssociationSession) { isPresented in
            if !isPresented {
                // ✅ NOUVEAU : Refresh immédiat quand la session se ferme
                refreshDashboardImmediately()
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addFlashcard:
                AddFlashcardView(deck: deck)
                    .environment(\.managedObjectContext, viewContext)
                    .onDisappear {
                        // ✅ CRITICAL : Refresh dashboard après ajout de carte (délai réduit)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            refreshDashboardImmediately()
                        }
                        
                        // ✅ Afficher le toast d'avertissement si on approche de la limite
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if shouldShowLimitWarning && !showFlashcardLimitToast {
                                showFlashcardLimitToast = true
                                
                                // Auto-hide après 4 secondes pour l'avertissement
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                    showFlashcardLimitToast = false
                                }
                            }
                        }
                    }
            case .modeSelection:
                RevisionModeSelectionView(
                    deck: deck,
                    showRevisionSession: $showRevisionSession,
                    showQuizSession: $showQuizSession,
                    showAssociationSession: $showAssociationSession
                )
            case .premium:
                PremiumView(highlightedFeature: .unlimitedFlashcardsPerDeck)
            case .editFlashcard(let flashcard):
                EditFlashcardView(flashcard: flashcard)
                    .onDisappear {
                        // ✅ CRITICAL : Refresh dashboard après modification
                        refreshDashboardWithDebouncing()
                    }
            }
        }
        .sheet(isPresented: $showModeExplanationSheet) {
            ModeExplanationView()
                .presentationDetents([.fraction(0.50)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(25)
        }
        .sheet(isPresented: $showAIGenerationSheet) {
            AIGenerationView(deck: deck)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(25)
        }
    }
    
    // ✅ EXTRACTION : Contenu toolbar
    private var toolbarContent: some View {
        HStack(spacing: 16) {
            // ✅ NOUVEAU : Bouton Settings pour les statuts avec deck
            FlashcardSettingsButton(deck: deck)
            
            // ✅ NOUVEAU : Bouton génération IA
            Button {
                HapticFeedbackManager.shared.impact(style: .light)
                showAIGenerationSheet = true
            } label: {
                Image(systemName: "sparkles.square.filled.on.square")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ModelManager.shared.isModelDownloaded(.smolLM3) ? .blue : .gray)
                    .frame(width: 20, height: 20)
            }
            .disabled(!ModelManager.shared.isModelDownloaded(.smolLM3))
            
            shareButton
            
#if DEBUG
            debugButton
#endif
        }
    }
    
    // ✅ EXTRACTION : Bouton partage
    private var shareButton: some View {
        Button {
            guard isViewActive else { return }
            
            if hasMediaContent {
                showMediaWarningPopover = true
            } else if !flashcards.isEmpty {
                shareDeck()
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(hasMediaContent || flashcards.isEmpty ? .gray : .blue)
                .frame(width: 20, height: 20)
        }
        .popover(isPresented: $showMediaWarningPopover) {
            mediaWarningPopoverContent
                .presentationCompactAdaptation(.popover)
        }
    }
    
    // ✅ EXTRACTION : Bouton debug (moins visible)
    private var debugButton: some View {
        Button {
            addDebugFlashcards()
        } label: {
            Image(systemName: "hammer.fill")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(.gray.opacity(0.5))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var mediaWarningPopoverContent: some View {
        Text(String(localized: "share_media_limitation"))
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: 300)
            .onTapGesture {
                showMediaWarningPopover = false
            }
    }
    
    // ✅ NOUVEAU : Vue Lottie blanche pour le toast
    struct WhiteLottieView: UIViewRepresentable {
        let animationName: String
        
        func makeUIView(context: Context) -> UIView {
            let containerView = UIView()
            let animationView = LottieAnimationView(name: animationName)
            
            animationView.loopMode = .playOnce
            animationView.contentMode = .scaleAspectFit
            
            // Force la couleur blanche
            let whiteColor = LottieColor(r: 1, g: 1, b: 1, a: 1)
            let colorProvider = ColorValueProvider(whiteColor)
            
            let strokeKeyPaths = [
                "**.primary.Color",
                "**.Stroke *.Color",
                "**.Group *.**.Stroke *.Color"
            ]
            
            strokeKeyPaths.forEach { keyPath in
                let animationKeypath = AnimationKeypath(keypath: keyPath)
                animationView.setValueProvider(colorProvider, keypath: animationKeypath)
            }
            
            animationView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(animationView)
            
            NSLayoutConstraint.activate([
                animationView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                animationView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                animationView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
                animationView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
            ])
            
            animationView.play()
            return containerView
        }
        
        func updateUIView(_ uiView: UIView, context: Context) {
            // Pas de mise à jour nécessaire
        }
    }
    
    // ✅ NOUVEAU : Toast limite flashcards
    private var flashcardLimitToast: some View {
        HStack(spacing: 8) {
            WhiteLottieView(animationName: "information")
                .frame(width: 30, height: 30)
            
            getLimitMessageWithColoredPro
                .font(.system(size: 16))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onTapGesture {
            if isToastClickable && !showFlashcardLimitToast {
                activeSheet = .premium
                showFlashcardLimitToast = false
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.3))
                )
        )

        .environment(\.colorScheme, .dark)

    }
    
    // MARK: - Views
    

    

    

    
    // ✅ NOUVELLE MÉTHODE : Préchargement des médias
    private func preloadMediaForCards(_ cards: [Flashcard]) {
        Task {
            for card in cards {
                // Précharger les images
                if card.questionContentType == .image, let fileName = card.questionImageFileName {
                    await preloadImage(fileName: fileName, data: card.questionImageData)
                }
                
                if card.answerContentType == .image, let fileName = card.answerImageFileName {
                    await preloadImage(fileName: fileName, data: card.answerImageData)
                }
                
                // Précharger les audios
                if card.questionContentType == .audio, let fileName = card.questionAudioFileName {
                    await preloadAudio(fileName: fileName)
                }
                
                if card.answerContentType == .audio, let fileName = card.answerAudioFileName {
                    await preloadAudio(fileName: fileName)
                }
            }
        }
    }
    
    private func preloadImage(fileName: String, data: Data?) async {
        if let data = data, let image = UIImage(data: data) {
            await MainActor.run {
                MediaCacheManager.shared.storeImage(image, forKey: fileName)
            }
        }
    }
    
    private func preloadAudio(fileName: String) async {
        let audioURL = MediaStorageManager.shared.getAudioURL(fileName: fileName)
        if let audioData = try? Data(contentsOf: audioURL) {
            await MainActor.run {
                MediaCacheManager.shared.storeAudio(audioData, forKey: fileName)
            }
        }
    }
    
    // ✅ EXTRACTION : Message d'avertissement
    private func limitWarningView(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.orange)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }
    
    private var contentSection: some View {
        Group {
            if flashcards.isEmpty || (filteredFlashcards.isEmpty && debouncedSearchText.isEmpty) {
                emptyStateView
            } else {
                flashcardsListView
            }
        }
    }
    
    private var flashcardsListView: some View {
        List {
            // ✅ SOLUTION : Masquer le dashboard quand recherche active sans résultats
            if !debouncedSearchText.isEmpty && filteredFlashcards.isEmpty {
                // Dashboard masqué pendant recherche sans résultats
            } else {
                Section {
                    dashboardSection
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            
            // ✅ NOUVEAU : Section boutons Filtre et Tri avec indicateur de mode
            if debouncedSearchText.isEmpty {
                Section {
                    HStack {
                        Menu {
                            flashcardSortMenuContent
                        } label: {
                            Text("Trier")
                                .foregroundStyle(.blue)
                        }
                        
                        Spacer()
                        
                        // Indicateur de mode centré
                        modeIndicatorView
                        
                        Spacer()
                        
                        Menu {
                            flashcardFilterMenuContent
                        } label: {
                            Text("Filtrer")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 24, leading: 16, bottom: 20, trailing: 16))
                .listSectionSpacing(0)
            }
            
            flashcardsSection
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),  // ✅ Toujours visible
            prompt: searchPrompt
        )
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(adaptiveBackground)
        .scrollIndicators(.hidden)
        .contentMargins(.top, 5)   // remonte légèrement le contenu
        .safeAreaInset(edge: .top) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 25)
        }
        .safeAreaInset(edge: .bottom) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 60)
        }
    }
    
    private var flashcardsSection: some View {
        Section {
            if filteredFlashcards.isEmpty {
                if !debouncedSearchText.isEmpty {
                    // ✅ Message dans la liste pour garder la recherche active
                    noSearchResultsRow
                } else {
                    // ✅ Empty state pour filtrage sans résultats
                    noFilterResultsRow
                }
            } else {
                ForEach(Array(filteredFlashcards.enumerated()), id: \.element.id) { index, flashcard in
                    FlashcardRow(flashcard: flashcard, audioManager: AudioManager.shared)
                        .listRowBackground(rowBackground)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(
                            index == filteredFlashcards.count - 1 ? .hidden : .visible,
                            edges: .bottom
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            swipeActionsForFlashcard(flashcard)
                        }
                        .onAppear {
                            // Précharger les médias des 5 prochaines cartes
                            if index < filteredFlashcards.count - 1 {
                                let nextCards = Array(filteredFlashcards.suffix(from: index + 1).prefix(5))
                                preloadMediaForCards(nextCards)
                            }
                        }
                }
            }
        }
        .id(listRefreshTrigger)  // ✅ SOLUTION : Force le refresh de la section
    }
    
    private var rowBackground: Color {
        colorScheme == .light ? Color.white : Color(.secondarySystemBackground)
    }
    
    @ViewBuilder
    private func swipeActionsForFlashcard(_ flashcard: Flashcard) -> some View {
        Button {
            HapticFeedbackManager.shared.impact(style: .light)
            activeSheet = .editFlashcard(flashcard)
        } label: {
            Label("Modifier", systemImage: "pencil")
        }
        .tint(.blue)
        
        Button(role: .destructive) {
            HapticFeedbackManager.shared.impact(style: .medium)
            if let index = filteredFlashcards.firstIndex(of: flashcard) {
                deleteFlashcardFiltered(at: IndexSet([index]))
            }
        } label: {
            Label("Supprimer", systemImage: "trash")
        }
        .tint(.red)
    }
    
    private var dashboardSection: some View {
        VStack(spacing: 8) {
            // ✅ NOUVEAU : Métriques SRS discrètes
            srsMetricsSection
            
            HStack(spacing: 16) {
                addButton
                startButton
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 280) // ✅ Agrandi pour les métriques
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // ✅ NOUVEAU : Section métriques SRS inspirées Anki/Quizlet/Memrise
    private var srsMetricsSection: some View {
        // ✅ OPTIMISATION : Calcul optimisé avec cache intelligent
        let stats = SimpleSRSManager.shared.getDeckStats(deck: deck)
        let freeModeCount = SimpleSRSManager.shared.countFreeModeCards(deck: deck)
        let freeMasteredCount = SimpleSRSManager.shared.countFreeModeMastered(deck: deck)
        let totalFreeModeCards = (deck.flashcards as? Set<Flashcard>)?.count ?? 0
        print("🔍 [DEBUG] totalFreeModeCards: \(totalFreeModeCards)")

        let readyDisplayCount = isFreeMode ? totalFreeModeCards : stats.readyCount
        let masteredDisplayCount = isFreeMode ? freeMasteredCount : stats.masteredCards
        
        print("🔍 [DEBUG] Dashboard - isFreeMode: \(isFreeMode)")
        print("🔍 [DEBUG] Dashboard - readyDisplayCount: \(readyDisplayCount)")
        print("🔍 [DEBUG] Dashboard - stats.readyCount: \(stats.readyCount)")
        print("🔍 [DEBUG] Dashboard - freeModeCount: \(freeModeCount)")
        print("🔍 [DEBUG] Dashboard - freeMasteredCount: \(freeMasteredCount)")

        let freeToStudyStatus = SimpleSRSManager.FreeModeStatus.toStudy
        let freeMasteredStatus = SimpleSRSManager.FreeModeStatus.mastered

        let readyLabel = isFreeMode ? freeToStudyStatus.caption : "à étudier"
        let readyIconName = isFreeMode ? freeToStudyStatus.icon : "clock"
        let readyIconColor: Color = isFreeMode ? freeToStudyStatus.color : .orange
        let masteredIconName = isFreeMode ? freeMasteredStatus.icon : "checkmark.circle"
        let masteredIconColor: Color = isFreeMode ? freeMasteredStatus.color : .purple
        let masteredLabel = isFreeMode ? freeMasteredStatus.caption : "maîtrisé"

        let primaryCount = readyDisplayCount  // ✅ CORRECTION : Toujours utiliser readyDisplayCount
        let primaryLabel = "Cartes disponibles"  // ✅ UNIFIÉ : Même texte pour les deux modes
        
        return VStack(spacing: 12) {
            // ✅ PANEL D'ÉTAT : Gestion des cas spéciaux
            if stats.totalCards == 0 {
                // Deck vide - pas de dashboard affiché
                EmptyView()
            } else {
                // ✅ Métrique Principale : Cartes à réviser (PRIORITÉ ABSOLUE)
                VStack(spacing: 3) {
                    // ✅ Message d'état simple
                    if !isFreeMode && stats.readyCount == 0 {
                        Text("Aucune carte à réviser. Passez au mode libre.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(primaryCount)")
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                    Text(primaryLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // ✅ Indicateur de progression discrète supprimé
                }
            
            // ✅ Métriques Secondaires : 3 métriques clés
            HStack(spacing: 32) {
                // Statut : cartes à étudier / disponibles
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        Image(systemName: readyIconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(readyIconColor)
                        Text("\(readyDisplayCount)")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                    }
                    Text(readyLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                }

                // Statut : maîtrisé (toujours affiché)
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        Image(systemName: masteredIconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(masteredIconColor)
                        Text("\(masteredDisplayCount)")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                    }
                    Text(masteredLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                }

                if !isFreeMode {
                    // Statut : Cartes en retard (SM-2 uniquement)
                    VStack(spacing: 3) {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                            Text("\(stats.overdue)")
                                .font(.system(size: 18, weight: .semibold, design: .default))
                                .foregroundColor(.primary)
                        }
                        Text("en retard")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            }
        }
        .padding(.horizontal, 20)
        .id(dashboardRefreshTrigger)  // ✅ Force refresh avec le trigger
    }
    

    
    // ✅ NOUVEAU : Panel deck vide (supprimé car non utilisé)
    
    // ✅ EXTRACTION : Bouton ajouter
    private var addButton: some View {
        Button(action: addFlashcardAction) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                Text("Ajouter")
                    .font(.body.weight(.medium))
            }
            .foregroundColor(hasReachedFlashcardLimit ? .orange : .blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(hasReachedFlashcardLimit ? .orange.opacity(0.20) : .blue.opacity(0.20))
            )
        }
        .contentShape(Rectangle())
        .buttonStyle(PlainButtonStyle())
        .disabled(isAddButtonProcessing)
    }
    
    // ✅ EXTRACTION : Bouton commencer
    private var startButton: some View {
        let hasSmartCards = !SimpleSRSManager.shared.getSmartCards(deck: deck, minCards: 1).isEmpty
        let hasFreeCards = SimpleSRSManager.shared.countFreeModeCards(deck: deck) > 0
        let isButtonEnabled = !flashcards.isEmpty && !isStartButtonProcessing && (hasSmartCards || (isFreeMode && hasFreeCards))
        
        return Button(action: startStudyAction) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .medium))
                Text("Commencer")
                    .font(.body.weight(.medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isButtonEnabled ? .blue : .gray)
            )
        }
        .contentShape(Rectangle())
        .buttonStyle(PlainButtonStyle())
        .disabled(!isButtonEnabled)
    }
    
    // ✅ ACTIONS SÉPARÉES AVEC PROTECTION
    private func addFlashcardAction() {
        guard !isAddButtonProcessing && isViewActive && !showFlashcardLimitToast else { return }
        isAddButtonProcessing = true
        
        HapticFeedbackManager.shared.impact(style: .light)
        
        if !hasReachedFlashcardLimit {
            activeSheet = .addFlashcard
        } else {
            // ✅ Protection : Annuler tout timer existant avant d'afficher le toast
            showFlashcardLimitToast = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showFlashcardLimitToast = true
                
                // Auto-hide après 3 secondes
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showFlashcardLimitToast = false
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAddButtonProcessing = false
        }
    }
    
    private func startStudyAction() {
        let hasSmartCards = !SimpleSRSManager.shared.getSmartCards(deck: deck, minCards: 1).isEmpty
        let hasFreeCards = SimpleSRSManager.shared.countFreeModeCards(deck: deck) > 0
        guard !isStartButtonProcessing && isViewActive && hasFlashcards && (hasSmartCards || (isFreeMode && hasFreeCards)) else { return }
        isStartButtonProcessing = true
        
        HapticFeedbackManager.shared.impact(style: .medium)
        
        // ✅ OPTIONNEL : Filtrer les cartes prêtes pour SM-2
        // Les cartes sont automatiquement filtrées dans FlashcardStackRevisionView
        
        activeSheet = .modeSelection
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isStartButtonProcessing = false
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            AdaptiveLottieView(animationName: "poeme")
                .frame(width: 110, height: 110)
            VStack(spacing: 8) {
                Text(String(localized: "empty_flashcard_title"))
                    .font(.headline.weight(.medium))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 16)
            Spacer()
            
            Button(action: {
                if premiumManager.canCreateFlashcard(currentDeckCount: flashcards.count, context: viewContext) {
                    HapticFeedbackManager.shared.impact(style: .medium)
                    activeSheet = .addFlashcard
                } else {
                    HapticFeedbackManager.shared.notification(type: .warning)
                    activeSheet = .premium
                }
            }) {
                HStack {
                    if hasReachedFlashcardLimit {
                        Image(systemName: "lock.fill")
                    }
                    Text(hasReachedFlashcardLimit ? "Limite atteinte" : String(localized: "action_new_card"))
                }
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(hasReachedFlashcardLimit ? Color.gray : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 45)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            colorScheme == .dark
            ? Color(.systemBackground)
            : Color.white
        )
    }
    
    // ✅ NOUVEAU : Row aucun résultat avec animation Lottie (garde la recherche active)
    private var noSearchResultsRow: some View {
        VStack(spacing: 16) {
            // ✅ Animation Lottie loupe comme dans les autres empty states
            AdaptiveLottieView(animationName: "loop")
                .frame(width: 80, height: 80)
            
            VStack(spacing: 6) {
                Text("Aucun résultat pour \"\(debouncedSearchText)\"")
                    .font(.headline.weight(.medium))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Text("Essayez un autre terme de recherche")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
    }
    
    // ✅ NOUVEAU : Empty state pour filtrage sans résultats (message simple)
    private var noFilterResultsRow: some View {
        VStack(spacing: 8) {
            Text(getFilterEmptyStateMessage())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
    }
    
    // ✅ Fonction helper pour générer le message selon le filtre actif
    private func getFilterEmptyStateMessage() -> String {
        return "Aucune carte trouvée"
    }
    

    
    // MARK: - Fonctions
    
    private func shareDeck() {
        Task {
            do {
                let exportData = try await sharingManager.exportDeck(deck: deck, context: viewContext)
                let fileURL = try sharingManager.createTemporaryFile(
                    data: exportData,
                    fileName: deck.name ?? "Deck"
                )
                
                await MainActor.run {
                    presentShareSheet(fileURL: fileURL)
                }
            } catch {
                print("❌ DIAGNOSTIC - Erreur : \(error)")
            }
        }
    }
    
    private func presentShareSheet(fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        
        let activityController = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityController, animated: true)
        }
    }
    
    private func deleteFlashcardFiltered(at offsets: IndexSet) {
        HapticFeedbackManager.shared.impact(style: .medium)
        let cardsToDelete = offsets.map { filteredFlashcards[$0] }
        for card in cardsToDelete {
            viewContext.delete(card)
        }
        
        do {
            try viewContext.save()
            
            // ✅ OPTIMISATION : Invalider seulement le cache du deck actuel
            SM2OptimizationCache.shared.clearDeckCache(deck: deck)
            
            // ✅ CRITICAL : Refresh dashboard après suppression
            refreshDashboardWithDebouncing()
            
            if let deck = cardsToDelete.first?.deck {
                DeckSharingManager.shared.notifyFlashcardModification(deck: deck)
            }
            HapticFeedbackManager.shared.notification(type: .success)
        } catch {
            HapticFeedbackManager.shared.notification(type: .error)
            viewContext.rollback()
        }
    }
    
    private func addDebugFlashcards() {
        // ✅ Création de 1000 cartes avec 200 médias pour tester l'import/export
        let totalCards = 1000
        let mediaCards = 200
        let textCards = totalCards - mediaCards
        
        print("🚀 [DEBUG] Création de \(totalCards) cartes (\(textCards) texte, \(mediaCards) médias)")
        
        // ✅ Créer d'abord les cartes texte
        for i in 1...textCards {
            let newFlashcard = Flashcard(context: viewContext)
            newFlashcard.id = UUID()
            newFlashcard.question = "Question texte \(i) - Test import/export"
            newFlashcard.answer = "Réponse texte \(i) - Carte de test pour performance"
            newFlashcard.createdAt = Date().addingTimeInterval(Double(i * 60))
            newFlashcard.deck = deck
            
            // Configuration SRS aléatoire
            newFlashcard.interval = Double.random(in: 1...30)
            newFlashcard.reviewCount = Int32.random(in: 0...10)
            newFlashcard.correctCount = Int16.random(in: 0...8)
            newFlashcard.easeFactor = Double.random(in: 1.3...3.0)
            
            // Date de prochaine révision
            let daysOffset = Int.random(in: -10...20)
            let nextReviewDate = Calendar.current.date(byAdding: .day, value: daysOffset, to: Date())
            newFlashcard.nextReviewDate = nextReviewDate
            
            // Date de dernière révision (pour les cartes déjà étudiées)
            if newFlashcard.reviewCount > 0 {
                let lastReviewOffset = Int.random(in: -30...0)
                let lastReviewDate = Calendar.current.date(byAdding: .day, value: lastReviewOffset, to: Date())
                newFlashcard.lastReviewDate = lastReviewDate
            }
            
            // Contenu texte
            newFlashcard.questionContentType = .text
            newFlashcard.answerContentType = .text
            
            if i % 100 == 0 {
                print("📝 [DEBUG] Cartes texte créées: \(i)/\(textCards)")
            }
        }
        
        // ✅ Créer les cartes avec médias (combinaisons mixtes)
        for i in 1...mediaCards {
            let newFlashcard = Flashcard(context: viewContext)
            newFlashcard.id = UUID()
            newFlashcard.question = "Question média \(i) - Test performance"
            newFlashcard.answer = "Réponse média \(i) - Carte avec contenu multimédia"
            newFlashcard.createdAt = Date().addingTimeInterval(Double((textCards + i) * 60))
            newFlashcard.deck = deck
            
            // Configuration SRS aléatoire
            newFlashcard.interval = Double.random(in: 1...30)
            newFlashcard.reviewCount = Int32.random(in: 0...10)
            newFlashcard.correctCount = Int16.random(in: 0...8)
            newFlashcard.easeFactor = Double.random(in: 1.3...3.0)
            
            // Date de prochaine révision
            let daysOffset = Int.random(in: -10...20)
            let nextReviewDate = Calendar.current.date(byAdding: .day, value: daysOffset, to: Date())
            newFlashcard.nextReviewDate = nextReviewDate
            
            // Date de dernière révision (pour les cartes déjà étudiées)
            if newFlashcard.reviewCount > 0 {
                let lastReviewOffset = Int.random(in: -30...0)
                let lastReviewDate = Calendar.current.date(byAdding: .day, value: lastReviewOffset, to: Date())
                newFlashcard.lastReviewDate = lastReviewDate
            }
            
            // ✅ COMBINAISONS MIXTES : 6 types différents
            let mediaType = i % 6
            
            switch mediaType {
            case 0: // Question image + Réponse texte
                newFlashcard.questionContentType = .image
                newFlashcard.answerContentType = .text
                let imageData = createFakeImageData()
                newFlashcard.questionImageData = imageData
                newFlashcard.questionImageFileName = "debug_q_image_\(i).jpg"
                
            case 1: // Question texte + Réponse audio
                newFlashcard.questionContentType = .text
                newFlashcard.answerContentType = .audio
                let audioFileName = "debug_a_audio_\(i).m4a"
                createFakeAudioFile(fileName: audioFileName, duration: 25.0)
                newFlashcard.answerAudioFileName = audioFileName
                
            case 2: // Question audio + Réponse texte
                newFlashcard.questionContentType = .audio
                newFlashcard.answerContentType = .text
                let audioFileName = "debug_q_audio_\(i).m4a"
                createFakeAudioFile(fileName: audioFileName, duration: 25.0)
                newFlashcard.questionAudioFileName = audioFileName
                
            case 3: // Question texte + Réponse image
                newFlashcard.questionContentType = .text
                newFlashcard.answerContentType = .image
                let imageData = createFakeImageData()
                newFlashcard.answerImageData = imageData
                newFlashcard.answerImageFileName = "debug_a_image_\(i).jpg"
                
            case 4: // Question image + Réponse audio
                newFlashcard.questionContentType = .image
                newFlashcard.answerContentType = .audio
                let imageData = createFakeImageData()
                newFlashcard.questionImageData = imageData
                newFlashcard.questionImageFileName = "debug_q_image_\(i).jpg"
                let audioFileName = "debug_a_audio_\(i).m4a"
                createFakeAudioFile(fileName: audioFileName, duration: 25.0)
                newFlashcard.answerAudioFileName = audioFileName
                
            case 5: // Question audio + Réponse image
                newFlashcard.questionContentType = .audio
                newFlashcard.answerContentType = .image
                let audioFileName = "debug_q_audio_\(i).m4a"
                createFakeAudioFile(fileName: audioFileName, duration: 25.0)
                newFlashcard.questionAudioFileName = audioFileName
                let imageData = createFakeImageData()
                newFlashcard.answerImageData = imageData
                newFlashcard.answerImageFileName = "debug_a_image_\(i).jpg"
                
            default:
                break
            }
            
            if i % 50 == 0 {
                print("🎵 [DEBUG] Cartes médias créées: \(i)/\(mediaCards)")
            }
        }
        
        do {
            try viewContext.save()
            
            // ✅ OPTIMISATION : Invalider seulement le cache du deck actuel
            SM2OptimizationCache.shared.clearDeckCache(deck: deck)
            
            print("✅ [DEBUG] \(totalCards) flashcards créées avec succès")
            print("📊 Répartition : \(textCards) texte, \(mediaCards) médias mixtes")
            print("🎵 Types de médias : Question image+texte, Question texte+audio, Question audio+texte, Question texte+image, Question image+audio, Question audio+image")
            print("🎯 Prêt pour tester l'import/export avec de gros volumes de données")
            HapticFeedbackManager.shared.notification(type: .success)
        } catch {
            print("❌ Erreur lors de la création des flashcards: \(error.localizedDescription)")
            HapticFeedbackManager.shared.notification(type: .error)
        }
    }
    
    // ✅ Fonction helper pour créer des données d'image factices
    private func createFakeImageData() -> Data {
        // Créer une image simple 1x1 pixel pour simuler des données d'image
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image?.jpegData(compressionQuality: 0.8) ?? Data()
    }
    
    // ✅ Fonction helper pour créer des fichiers audio factices
    private func createFakeAudioFile(fileName: String, duration: Double) {
        // Créer un fichier audio factice de 25 secondes
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        // Créer des données audio factices (silence de 25 secondes)
        let sampleRate: Double = 44100
        let samples = Int(sampleRate * duration)
        let audioData = Data(count: samples * 2) // 16-bit audio
        
        do {
            try audioData.write(to: audioURL)
            print("🎵 [DEBUG] Fichier audio créé: \(fileName) (\(duration)s)")
        } catch {
            print("❌ [DEBUG] Erreur création audio \(fileName): \(error)")
        }
    }
    
    // ✅ CRITICAL : Timer intelligent pour rafraîchir le dashboard
    private func startDashboardRefreshTimer() {
        // Arrêter le timer existant s'il y en a un
        stopDashboardRefreshTimer()
        
        // ✅ OPTIMISATION : Timer adaptatif selon la taille du deck
        let deckSize = flashcards.count
        let refreshInterval: TimeInterval
        
        switch deckSize {
        case 0...10:
            refreshInterval = 5.0  // 5s pour petits decks
        case 11...50:
            refreshInterval = 3.0  // 3s pour decks moyens
        case 51...200:
            refreshInterval = 2.0  // 2s pour gros decks
        default:
            refreshInterval = 1.5  // 1.5s pour très gros decks
        }
        
        // Créer un timer avec debouncing pour éviter les rafraîchissements multiples
        dashboardRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                // ✅ OPTIMISATION : Vérifier si le dashboard a vraiment besoin d'être rafraîchi
                if shouldRefreshDashboard() {
                    refreshDashboardWithDebouncing()
                }
            }
        }
        
        print("⏰ [DASHBOARD] Timer démarré: \(refreshInterval)s (deck: \(deckSize) cartes)")
    }
    
    // ✅ OPTIMISATION : Vérifier si le dashboard a besoin d'être rafraîchi
    private func shouldRefreshDashboard() -> Bool {
        // Ne pas rafraîchir si l'app est en arrière-plan
        guard UIApplication.shared.applicationState == .active else {
            return false
        }
        
        // Ne pas rafraîchir si aucune session de révision n'est active
        guard !showRevisionSession && !showQuizSession && !showAssociationSession else {
            return false
        }
        
        return true
    }
    
    // ✅ OPTIMISATION : Rafraîchir le dashboard avec debouncing
    private func refreshDashboardWithDebouncing() {
        // Annuler le refresh précédent s'il y en a un
        refreshWorkItem?.cancel()
        
        // Créer un nouveau work item avec un délai de 0.5s
        let workItem = DispatchWorkItem {
            DispatchQueue.main.async {
                dashboardRefreshTrigger = UUID()
            }
        }
        
        refreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    // ✅ NOUVELLE MÉTHODE : Rafraîchissement immédiat sans délai
    private func refreshDashboardImmediately() {
        // Annuler tous les refresh en attente
        refreshWorkItem?.cancel()
        
        // ✅ OPTIMISATION : Invalider le cache AVANT le refresh
        SM2OptimizationCache.shared.clearDeckCache(deck: deck)
        
        // ✅ CRITICAL : Refresh SYNCHRONE sur le thread principal
        dashboardRefreshTrigger = UUID()
        
        // ✅ BONUS : Forcer un refresh de l'interface
        DispatchQueue.main.async {
            // Double refresh pour garantir la mise à jour
            self.dashboardRefreshTrigger = UUID()
        }
    }
    
    private func stopDashboardRefreshTimer() {
        dashboardRefreshTimer?.invalidate()
        dashboardRefreshTimer = nil
        
        // ✅ OPTIMISATION : Annuler aussi le work item en cours
        refreshWorkItem?.cancel()
        refreshWorkItem = nil
    }
    
    // ✅ NOUVEAU : Contenu du menu de filtrage des flashcards avec sections
    private var flashcardFilterMenuContent: some View {
        Group {
            Section("Par statut") {
                if isFreeMode {
                    // ✅ MODE LIBRE : Statuts adaptés
                    ForEach([FlashcardFilterOption.all, .new, .toStudy, .mastered], id: \.self) { option in
                        Button {
                            flashcardFilterOption = option
                            HapticFeedbackManager.shared.selection()
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text(option.displayName)
                                Spacer()
                                if flashcardFilterOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } else {
                    // ✅ MODE SM-2 : Statuts complets
                    ForEach([FlashcardFilterOption.all, .new, .needsReview, .overdue, .mastered], id: \.self) { option in
                        Button {
                            flashcardFilterOption = option
                            HapticFeedbackManager.shared.selection()
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text(option.displayName)
                                Spacer()
                                if flashcardFilterOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            
            Section("Autres filtres") {
                ForEach([FlashcardFilterOption.textOnly, .withMedia, .withAudio, .withImages], id: \.self) { option in
                    Button {
                        flashcardFilterOption = option
                        HapticFeedbackManager.shared.selection()
                    } label: {
                        HStack {
                            Image(systemName: option.icon)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text(option.displayName)
                            Spacer()
                            if flashcardFilterOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ✅ NOUVEAU : Contenu du menu de tri des flashcards
    private var flashcardSortMenuContent: some View {
        Group {
            Section("Trier par") {
                if isFreeMode {
                    // ✅ MODE LIBRE : Seulement date de création et alphabétique
                    ForEach([FlashcardSortOption.creationDate, .alphabetical], id: \.self) { option in
                        Button {
                            flashcardSortOption = option
                            HapticFeedbackManager.shared.selection()
                        } label: {
                            HStack {
                                Text(option.displayName)
                                Spacer()
                                if flashcardSortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } else {
                    // ✅ MODE SM-2 : Tout sauf difficulté et dernière révision
                    ForEach([FlashcardSortOption.creationDate, .alphabetical], id: \.self) { option in
                        Button {
                            flashcardSortOption = option
                            HapticFeedbackManager.shared.selection()
                        } label: {
                            HStack {
                                Text(option.displayName)
                                Spacer()
                                if flashcardSortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            
            Section("Ordre") {
                Button {
                    flashcardSortOrder = .ascending
                    HapticFeedbackManager.shared.selection()
                } label: {
                    HStack {
                        Text("Ascendant")
                        Spacer()
                        if flashcardSortOrder == .ascending {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Button {
                    flashcardSortOrder = .descending
                    HapticFeedbackManager.shared.selection()
                } label: {
                    HStack {
                        Text("Descendant")
                        Spacer()
                        if flashcardSortOrder == .descending {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
    

}

    // MARK: - ModeExplanationView
    struct ModeExplanationView: View {
        @Environment(\.dismiss) private var dismiss
        @AppStorage("isFreeMode") private var isFreeMode = false
        
        var body: some View {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    // ✅ Bouton X en haut à droite
                    HStack {
                        Spacer()
                        Button {
                            HapticFeedbackManager.shared.impact(style: .light)
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color(.secondarySystemBackground)))
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.top, 18)
                    
                    // ✅ Contenu principal
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: isFreeMode ? "leaf" : "arrow.up.circle.badge.clock")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            Text(isFreeMode ? "Mode Libre" : "Mode répétition espacée")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(isFreeMode ?
                                "Dans ce mode, vos cartes ne sont pas mises à jour selon un algorithme de répétition espacée. Vous pouvez réviser librement sans impact sur les intervalles de révision." :
                                "Ce mode utilise l'algorithme de répétition espacée pour optimiser vos intervalles de révision. Chaque réponse influence les futures dates de révision de vos cartes."
                            )
                            .font(.body)
                            .foregroundColor(.secondary)
                            
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
        }
    }
