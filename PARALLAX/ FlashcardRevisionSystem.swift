//
// FlashcardRevisionSystem.swift
// PARALLAX
//
// Created by Farid on 6/25/25.
//

import SwiftUI
import UIKit
import Foundation
import CoreData
import ActivityKit

// MARK: - Revision Activity Manager

@MainActor
class RevisionActivityManager: ObservableObject {
    @Published var isActivityActive = false
    
    private var currentRevisionActivity: Activity<RevisionAttributes>?
    private var currentAIActivity: Activity<RevisionAttributes>?
    
    func startFlashcardActivity(subjectName: String, deckName: String, totalCards: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }
        
        let attributes = RevisionAttributes(
            sessionID: UUID(),
            subjectName: subjectName,
            deckName: deckName
        )
        
        let contentState = RevisionAttributes.ContentState(
            startDate: Date(),
            cardsCompleted: 0,
            totalCards: totalCards,
            currentCardQuestion: "Démarrage de la session...",
            cardsKnown: 0,
            cardsToReview: 0,
            isActive: true,
            lastUpdate: Date()
        )
        
        do {
            currentRevisionActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )
            
            // Feedback haptique pour le démarrage de session
            HapticFeedbackManager.shared.notification(type: .success)
            print("✅ Live Activity révision démarrée")
        } catch {
            HapticFeedbackManager.shared.notification(type: .error)
            print("❌ Erreur Live Activity révision: \(error)")
        }
    }
    
    func updateFlashcardActivity(cardsCompleted: Int, currentCard: String, cardsKnown: Int, cardsToReview: Int, isActive: Bool) {
        guard let activity = currentRevisionActivity else {
            print("No active Live Activity to update")
            return
        }
        
        let contentState = RevisionAttributes.ContentState(
            startDate: activity.content.state.startDate,
            cardsCompleted: cardsCompleted,
            totalCards: activity.content.state.totalCards,
            currentCardQuestion: currentCard,
            cardsKnown: cardsKnown,
            cardsToReview: cardsToReview,
            isActive: isActive,
            lastUpdate: Date()
        )
        
        Task {
            await activity.update(.init(state: contentState, staleDate: nil))
        }
    }
    
    func endRevisionActivity() {
        guard let activity = currentRevisionActivity else {
            print("No active Live Activity to end")
            return
        }
        
        Task {
            let finalContentState = RevisionAttributes.ContentState(
                startDate: activity.content.state.startDate,
                cardsCompleted: activity.content.state.cardsCompleted,
                totalCards: activity.content.state.totalCards,
                currentCardQuestion: "Session terminée",
                cardsKnown: activity.content.state.cardsKnown,
                cardsToReview: activity.content.state.cardsToReview,
                isActive: false,
                lastUpdate: Date()
            )
            
            await activity.end(
                .init(state: finalContentState, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(3))
            )
            
            currentRevisionActivity = nil
        }
        
        // Feedback haptique pour la fin de session
        HapticFeedbackManager.shared.notification(type: .success)
        print("Live Activity ended")
    }
}

// MARK: - Swipe Direction

enum SwipeDirection {
    case none, left, right
}

extension Color {
    static let flashcardBackground = Color(red: 0xF2/255, green: 0xF2/255, blue: 0xF2/255)
}

// MARK: - Progress Bar Component

struct ProgressBar2: View {
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

struct FlashcardStackRevisionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var cards: [Flashcard]
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var isRemovingCard = false
    @State private var isNextCardActive = false
    @State private var deck: FlashcardDeck
    @State private var showCompletionElements = false
    @State private var showStatsElements = false
    @State private var bounceIcon = false
    @State private var swipeDirection: SwipeDirection = .none
    @State private var finalSwipeDirection: SwipeDirection = .none
    @State private var sessionStartTime = Date()
    @State private var cardsKnown = 0
    @State private var cardsToReview = 0
    @State private var currentCardIndex = 0
    @State private var initialCardCount = 0
    @StateObject private var activityManager = RevisionActivityManager()
    
    // ✅ BACKGROUND ADAPTATIF : F6F7FB seulement en mode clair
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    private var totalCardsReviewed: Int {
        currentCardIndex
    }
    
    private var sessionDuration: Int {
        Int(Date().timeIntervalSince(sessionStartTime))
    }
    
    private var progressPercentage: Double {
        guard initialCardCount > 0 else { return 0 }
        return Double(currentCardIndex) / Double(initialCardCount)
    }
    
    private func formatSessionTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%dm %02ds", minutes, secs)
    }
    
    private var backgroundColor: Color {
        switch colorScheme {
        case .dark:
            return .black
        default:
            return .white
        }
    }
    
    init(deck: FlashcardDeck) {
        self.deck = deck
        let flashcards = (deck.flashcards as? Set<Flashcard>)?.sorted {
            ($0.createdAt ?? Date()) < ($1.createdAt ?? Date())
        } ?? []
        _cards = State(initialValue: flashcards)
        _initialCardCount = State(initialValue: flashcards.count)
    }
    
    var body: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()  // ✅ Background adaptatif
            
            if cards.isEmpty {
                sessionCompletedView
            } else {
                mainContentView
            }
        }
        .onAppear {
            sessionStartTime = Date()
            initialCardCount = cards.count
            currentCardIndex = 0
            
            // Feedback haptique léger pour l'ouverture
            HapticFeedbackManager.shared.impact(style: .light)
            
            print("🎯 Starting flashcard session with \(initialCardCount) cards")
            activityManager.startFlashcardActivity(
                subjectName: deck.subject?.name ?? "Révision",
                deckName: deck.name ?? "Deck",
                totalCards: initialCardCount
            )
        }
        .onDisappear {
            print("👋 Session ending - Final stats: Known: \(cardsKnown), Review: \(cardsToReview)")
            activityManager.endRevisionActivity()
        }
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        VStack {
            topBar
            cardStack
                .padding(.top, 80)
            Spacer()
        }
    }
    
    // MARK: - Top Bar (même structure que QuizView)

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack {
                Text(deck.name ?? "Révision")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    HapticFeedbackManager.shared.selection()
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
                ProgressBar2(progress: progressPercentage)
                    .frame(width: UIScreen.main.bounds.width * 0.45)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            HStack {
                Text("\(currentCardIndex)/\(initialCardCount)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 30)
    }
    
    private var topBarHeader: some View {
        HStack {
            Spacer()
            Button(action: {
                HapticFeedbackManager.shared.selection()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color(.systemGray5)))
            }
        }
        .padding(.horizontal, 22)
    }
    
    private var topBarProgress: some View {
        VStack(spacing: 8) {
            if let name = deck.name {
                HStack {
                    Text(name)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 4)
            }
            
            HStack {
                ProgressBar2(progress: progressPercentage)
                    .frame(width: 180)
                Spacer()
            }
            .padding(.horizontal, 22)
            
            HStack {
                Text("\(currentCardIndex)/\(initialCardCount)")
                    .font(.body)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 22)
        }
    }
    
    // MARK: - Session Completed View ✅ REFAITE POUR ÊTRE MINIMALISTE
    
    private var sessionCompletedView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // ✅ SECTION TITRE MINIMALISTE
            completionHeader
            
            // ✅ STATISTIQUES ÉPURÉES
            completionStats
            
            Spacer()
            
            // ✅ BOUTON FERMETURE SIMPLE
            completionCloseButton
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
            Text("Session terminée")
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
                        Text("\(totalCardsReviewed)")
                            .font(.title.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("cartes révisées")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatSessionTime(seconds: sessionDuration))
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
                        Text("\(cardsKnown)")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.primary)
                        Text("maîtrisées")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(cardsToReview)")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.primary)
                        Text("à revoir")
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
    
    private var completionCloseButton: some View {
        Button(action: {
            HapticFeedbackManager.shared.impact(style: .light)
            dismiss()
        }) {
            Text("Terminer")
                .font(.headline.weight(.medium))
                .foregroundColor(colorScheme == .light ? .white : .primary) // ✅ Blanc sur fond noir en mode clair
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(colorScheme == .light ? .black : Color(.tertiarySystemGroupedBackground)) // ✅ Fond noir en mode clair
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .opacity(showCompletionElements ? 1 : 0)
        .scaleEffect(showCompletionElements ? 1 : 0.95)
        .animation(.easeOut(duration: 0.6).delay(0.8), value: showCompletionElements)
        .padding(.bottom, 24)
    }
    
    // MARK: - Card Stack
    
    private var cardStack: some View {
        ZStack {
            ForEach(Array(cards.prefix(3).enumerated()), id: \.element) { idx, card in
                cardView(for: card, at: idx)
            }
        }
        .frame(height: 500)
    }
    
    private func cardView(for card: Flashcard, at index: Int) -> some View {
        let cardColor = cardBackgroundColor
        
        return CardFlipView(
            front: { cardFrontContent(for: card) },
            back: { cardBackContent(for: card) },
            isFlipped: cardBinding(for: index),
            backgroundColor: cardColor,
            swipeDirection: cardSwipeDirection(for: index),
            swipeProgress: cardSwipeProgress(for: index)
        )
        .frame(width: 370, height: 400)
        .offset(y: CGFloat(index) * 25)
        .scaleEffect(1 - CGFloat(index) * 0.05)
        .offset(index == 0 ? dragOffset : .zero)
        .rotationEffect(.degrees(index == 0 ? Double(dragOffset.width / 16) : 0))
        .zIndex(Double(cards.count - index))
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: dragOffset)
        .allowsHitTesting(index == 0)
        .gesture(index == 0 ? swipeGesture : nil)
        .onTapGesture {
            if index == 0 {
                // Feedback haptique subtil pour le flip
                HapticFeedbackManager.shared.selection()
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    isFlipped.toggle()
                }
            }
        }
        .animation(.easeInOut(duration: 0.13), value: isNextCardActive)
    }
    
    // MARK: - Card Helpers
    
    private var cardBackgroundColor: Color {
        switch colorScheme {
        case .dark:
            return Color(UIColor.secondarySystemBackground)
        default:
            return Color.white
        }
    }
    
    private func cardFrontContent(for card: Flashcard) -> some View {
        Text(card.question ?? "—")
            .font(.title2.weight(.medium))
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .padding()
    }
    
    private func cardBackContent(for card: Flashcard) -> some View {
        Text(card.answer ?? "—")
            .font(.title2.weight(.medium))
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .padding()
    }
    
    private func cardBinding(for index: Int) -> Binding<Bool> {
        Binding(
            get: { index == 0 ? isFlipped : false },
            set: { _ in }
        )
    }
    
    private func cardSwipeDirection(for index: Int) -> SwipeDirection {
        if index == 0 {
            return finalSwipeDirection != .none ? finalSwipeDirection : swipeDirection
        }
        return .none
    }
    
    private func cardSwipeProgress(for index: Int) -> CGFloat {
        return index == 0 ? min(abs(dragOffset.width) / 80, 1) : 0
    }
    
    // MARK: - Swipe Gesture
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = CGSize(width: value.translation.width, height: 0)
                let threshold: CGFloat = 80
                
                swipeDirection = value.translation.width > 0 ? .right : .left
                isNextCardActive = abs(value.translation.width) > threshold
                
                // Feedback haptique léger lors du seuil
                if abs(value.translation.width) > threshold && !isNextCardActive {
                    HapticFeedbackManager.shared.impact(style: .light)
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 80
                
                if abs(value.translation.width) > threshold {
                    finalSwipeDirection = value.translation.width > 0 ? .right : .left
                    
                    // Feedback haptique selon le résultat
                    if finalSwipeDirection == .right {
                        HapticFeedbackManager.shared.notification(type: .success)
                    } else {
                        HapticFeedbackManager.shared.impact(style: .medium)
                    }
                    
                    withAnimation(.spring()) {
                        dragOffset = CGSize(width: value.translation.width > 0 ? 700 : -700, height: 0)
                        isRemovingCard = true
                    }
                    
                    withAnimation {
                        bounceIcon.toggle()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        nextCard()
                        isNextCardActive = false
                        bounceIcon = false
                    }
                } else {
                    swipeDirection = .none
                    finalSwipeDirection = .none
                    withAnimation(.spring()) { dragOffset = .zero }
                    isNextCardActive = false
                }
            }
    }
    
    // MARK: - Next Card Logic
    
    private func nextCard() {
        guard !cards.isEmpty else { return }
        
        let currentCard = cards.first?.question ?? ""
        print("🔄 Processing card \(currentCardIndex + 1)/\(initialCardCount)")
        print("📋 Current card: \(String(currentCard.prefix(30)))...")
        
        let swipeDirection: SwipeDirection = finalSwipeDirection
        
        switch swipeDirection {
        case .right:
            cardsKnown += 1
            print("✅ Card marked as KNOWN - Total known: \(cardsKnown)")
        case .left:
            cardsToReview += 1
            print("🔄 Card marked as TO REVIEW - Total to review: \(cardsToReview)")
        case .none:
            print("⚠️ No swipe direction detected")
        }
        
        currentCardIndex += 1
        let nextCard = cards.count > 1 ? cards[1].question ?? "" : "Session terminée"
        let isStillActive = currentCardIndex < initialCardCount
        
        // Feedback haptique pour les jalons (tous les 5 cartes)
        if currentCardIndex % 5 == 0 && isStillActive {
            HapticFeedbackManager.shared.notification(type: .success)
        }
        
        print("🎯 Updating Live Activity - Progress: \(currentCardIndex)/\(initialCardCount)")
        activityManager.updateFlashcardActivity(
            cardsCompleted: currentCardIndex,
            currentCard: nextCard,
            cardsKnown: cardsKnown,
            cardsToReview: cardsToReview,
            isActive: isStillActive
        )
        
        isFlipped = false
        dragOffset = .zero
        isRemovingCard = false
        finalSwipeDirection = .none
        cards.removeFirst()
        
        if cards.isEmpty {
            print("🏁 All cards completed! Ending session...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                activityManager.endRevisionActivity()
            }
        }
    }
}


// MARK: - Stat Item Component

struct StatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
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

// MARK: - Card Flip View

struct CardFlipView<Front: View, Back: View>: View {
    let front: () -> Front
    let back: () -> Back
    var isFlipped: Binding<Bool>
    var backgroundColor: Color = Color(.systemBackground)
    var swipeDirection: SwipeDirection = .none
    var swipeProgress: CGFloat = 0
    
    var body: some View {
        ZStack {
            cardBackground
            cardBorder
            cardContent
        }
        .rotation3DEffect(
            .degrees(isFlipped.wrappedValue ? 180 : 0),
            axis: (0, 1, 0)
        )
        .animation(.easeInOut(duration: 0.25), value: isFlipped.wrappedValue)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 25)
            .fill(backgroundColor)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    private var cardBorder: some View {
        Group {
            if swipeProgress > 0 {
                RoundedRectangle(cornerRadius: 25)
                    .strokeBorder(
                        borderColor,
                        lineWidth: 6
                    )
                    .opacity(Double(swipeProgress))
                    .animation(.easeInOut(duration: 0.09), value: swipeProgress)
            }
        }
    }
    
    private var borderColor: Color {
        switch swipeDirection {
        case .left:
            return Color(UIColor.systemOrange)
        default:
            return Color.green
        }
    }
    
    private var cardContent: some View {
        ZStack {
            front()
                .modifier(FlipOpacity(percentage: isFlipped.wrappedValue ? 0 : 1))
            
            back()
                .modifier(FlipOpacity(percentage: isFlipped.wrappedValue ? 1 : 0))
                .rotation3DEffect(.degrees(180), axis: (0, 1, 0))
        }
        .padding()
    }
}

// MARK: - Flip Opacity Modifier

private struct FlipOpacity: AnimatableModifier {
    var percentage: CGFloat = 0
    
    var animatableData: CGFloat {
        get { percentage }
        set { percentage = newValue }
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(Double(percentage.rounded()))
    }
}

// MARK: - Minimal Revision View

struct MinimalRevisionView: View {
    @ObservedObject var deck: FlashcardDeck
    @StateObject private var activityManager = RevisionActivityManager()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var bounceIcon = false
    @State private var currentIndex = 0
    @State private var cardsKnown = 0
    @State private var cardsToReview = 0
    
    // ✅ BACKGROUND ADAPTATIF : F6F7FB seulement en mode clair
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    private var flashcards: [Flashcard] {
        (deck.flashcards as? Set<Flashcard>)?.sorted {
            $0.createdAt ?? Date() < $1.createdAt ?? Date()
        } ?? []
    }
    
    private var currentFlashcard: Flashcard? {
        guard currentIndex < flashcards.count else { return nil }
        return flashcards[currentIndex]
    }
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                topNavigation
                
                if let card = currentFlashcard {
                    SwipeableFlashcardMinimal(
                        question: card.question ?? "",
                        answer: card.answer ?? "",
                        onSwipe: { direction in
                            handleSwipe(direction)
                        }
                    )
                    .frame(width: min(geo.size.width * 0.9, 420), height: min(geo.size.height * 0.95, 660))
                } else {
                    emptyStateView
                }
                
                Spacer()
            }
        }
        .background(adaptiveBackground.ignoresSafeArea())  // ✅ Background adaptatif
        .onAppear {
            HapticFeedbackManager.shared.impact(style: .light)
        }
    }
    
    private var topNavigation: some View {
        HStack {
            Button(action: {
                HapticFeedbackManager.shared.selection()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
            
            Spacer()
            Text("\(currentIndex + 1)/\(flashcards.count)")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
            Spacer().frame(width: 40)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    private var emptyStateView: some View {
        Text("Aucune carte à réviser.")
            .font(.title2.weight(.medium))
            .foregroundColor(.secondary)
    }
    
    private func handleSwipe(_ direction: CardSwipeDirection) {
        withAnimation {
            bounceIcon = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation {
                bounceIcon = false
            }
        }
        
        switch direction {
        case .up:
            HapticFeedbackManager.shared.notification(type: .success)
            markCardAsKnown()
        case .down:
            HapticFeedbackManager.shared.impact(style: .medium)
            markCardAsUnknown()
        case .left:
            HapticFeedbackManager.shared.impact(style: .medium)
            markCardAsUnknown()
        case .right:
            HapticFeedbackManager.shared.selection()
            if currentIndex > 0 { currentIndex -= 1 }
        }
    }
    
    private func markCardAsKnown() {
        cardsKnown += 1
        nextCard()
    }
    
    private func markCardAsUnknown() {
        cardsToReview += 1
        nextCard()
    }
    
    private func nextCard() {
        if currentIndex < flashcards.count - 1 {
            currentIndex += 1
        } else {
            HapticFeedbackManager.shared.notification(type: .success)
            dismiss()
        }
    }
}

// MARK: - Card Swipe Direction

enum CardSwipeDirection {
    case left, right, up, down
}

// MARK: - Swipeable Flashcard Minimal

struct SwipeableFlashcardMinimal: View {
    let question: String
    let answer: String
    let onSwipe: (CardSwipeDirection) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @GestureState private var isPressing = false
    @State private var cachedBackgroundColor: Color = Color(.systemBackground)
    
    // ✅ BACKGROUND ADAPTATIF pour les cartes
    private var defaultCardBackground: Color {
        colorScheme == .light ? Color.white : Color(.secondarySystemBackground)
    }
    
    private var shouldUpdateBackground: Bool {
        let newColor = computeBackgroundColor()
        return newColor != cachedBackgroundColor
    }
    
    private func computeBackgroundColor() -> Color {
        if dragOffset.height < -40 { return Color.green.opacity(0.18) }
        if dragOffset.height > 40 { return Color.orange.opacity(0.18) }
        if dragOffset.width > 40 { return Color.accentColor.opacity(0.13) }
        if dragOffset.width < -40 { return Color.blue.opacity(0.13) }
        return defaultCardBackground
    }
    
    private func updateBackgroundColor() {
        let newColor = computeBackgroundColor()
        if newColor != cachedBackgroundColor {
            cachedBackgroundColor = newColor
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(cachedBackgroundColor)
                .animation(.easeInOut(duration: 0.18), value: cachedBackgroundColor)
            
            cardContentView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(swipeGesture)
        .offset(dragOffset)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: dragOffset)
        .onTapGesture {
            HapticFeedbackManager.shared.selection()
            withAnimation(.easeInOut(duration: 0.4)) {
                isFlipped.toggle()
            }
        }
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .accessibilityLabel(isFlipped ? answer : question)
        .contextMenu {
            Button("Copier question", action: {
                UIPasteboard.general.string = question
                HapticFeedbackManager.shared.selection()
            })
            Button("Copier réponse", action: {
                UIPasteboard.general.string = answer
                HapticFeedbackManager.shared.selection()
            })
        }
        .onAppear {
            cachedBackgroundColor = defaultCardBackground
        }
    }
    
    private var cardContentView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(isFlipped ? answer : question)
                .font(isFlipped ? .title2.weight(.medium) : .largeTitle.weight(.bold))
                .foregroundColor(isFlipped ? .accentColor : .primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .scaleEffect(isPressing ? 0.98 : 1)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isPressing)
            Spacer()
        }
    }
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($isPressing) { _, state, _ in state = true }
            .onChanged { value in
                dragOffset = value.translation
                updateBackgroundColor()
                
                // Feedback haptique au seuil
                let thresh: CGFloat = 80
                if abs(value.translation.width) > thresh || abs(value.translation.height) > thresh {
                    HapticFeedbackManager.shared.impact(style: .light)
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let thresh: CGFloat = 80
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    if dy < -thresh {
                        onSwipe(.up)
                    } else if dy > thresh {
                        onSwipe(.down)
                    } else if dx < -thresh {
                        onSwipe(.left)
                    } else if dx > thresh {
                        onSwipe(.right)
                    }
                    
                    dragOffset = .zero
                    cachedBackgroundColor = defaultCardBackground
                }
            }
    }
}
