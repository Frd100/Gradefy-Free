//
//  FlashcardRevisionSystem.swift
// PARALLAX
//
// Created by on 6/25/25.
//

import AVFoundation
import CoreData
import Foundation
import PhotosUI
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Gestionnaire d'état centralisé

@MainActor
class FlashcardStateManager: ObservableObject {
    @Published var isFlipping = false
    @Published var isUndoing = false
    @Published var isSwipeInProgress = false
    @Published var autoplayActive = false
    @Published var isAnimating = false

    @Published private(set) var operationLock = false // ✅ Changé : private(set) au lieu de private

    // ✅ AJOUT : Propriété publique pour vérifier le verrou
    var isOperationLocked: Bool {
        return operationLock
    }

    func lockOperation(_: String) -> Bool {
        guard !operationLock else {
            return false
        }
        operationLock = true
        return true
    }

    func unlockOperation(_: String) {
        operationLock = false
    }

    func canFlip() -> Bool {
        return !isFlipping && !isUndoing && !isSwipeInProgress && !operationLock && !isAnimating
    }

    func canUndo() -> Bool {
        return !isFlipping && !isUndoing && !isSwipeInProgress && !operationLock && !isAnimating
    }

    func canSwipe() -> Bool {
        return !isFlipping && !isUndoing && !operationLock && !isAnimating
    }

    func canTap() -> Bool {
        return !isAnimating && !isFlipping && !isUndoing && !isSwipeInProgress && !operationLock
    }
}

// MARK: - Autoplay Manager

@MainActor
class AutoplayManager: ObservableObject {
    @Published var isActive = false
    @Published var autoplayPhase: AutoplayPhase = .showingFront

    private var timer: Timer?
    private var currentIndex = 0

    enum AutoplayPhase {
        case showingFront
        case showingBack
        case transitioning
    }

    func toggle() {
        if isActive {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard !isActive else { return }
        isActive = true
        autoplayPhase = .showingFront // ✅ Commence par montrer la face avant
        scheduleTimer(after: 3.0) // ✅ Premier timer de 3s
        print("🎬 Autoplay started - showing FRONT for 3s")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
    }

    func scheduleTimer(after seconds: TimeInterval) {
        timer?.invalidate()
        print("🎬 Scheduling timer for \(seconds) seconds, phase: \(autoplayPhase)")

        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            print("🎬 Timer fired!")
            Task { @MainActor in
                self?.advancePhase()
            }
        }
    }

    func advancePhase() {
        print("🎬 Advancing phase from \(autoplayPhase)")

        switch autoplayPhase {
        case .showingFront:
            autoplayPhase = .showingBack
            scheduleTimer(after: 3.0)
            print("🎬 → Now showing BACK, next timer in 3s")

        case .showingBack:
            autoplayPhase = .transitioning
            scheduleTimer(after: 0.5)
            print("🎬 → Now transitioning, next timer in 0.5s")

        case .transitioning:
            autoplayPhase = .showingFront
            scheduleTimer(after: 3.0) // ✅ Au lieu de 0.5s
            print("🎬 → Back to showing FRONT, next timer in 1.5s")
        }
    }

    func currentSwipeDirection() -> SwipeDirection {
        return currentIndex % 2 == 0 ? .left : .right
    }

    func reset() {
        currentIndex = 0
        autoplayPhase = .showingFront
    }

    func recordSwipe() {
        currentIndex += 1
    }
}

// MARK: - Revision Activity Manager

@MainActor
class RevisionActivityManager: ObservableObject {
    static let shared = RevisionActivityManager()
    @Published var isActivityActive = false
    @Published var consecutiveWeeks = 0

    private init() {}

    private let sharedDefaults = UserDefaults(suiteName: "group.com.Coefficient.PARALLAX2")
    private let consecutiveWeeksKey = "consecutiveWeeks"
    private let lastActiveWeekKey = "lastActiveWeekIdentifier"

    func startWeeklyTracking() {
        // Marquer que cette semaine a une session
        markWeekAsActive()
        isActivityActive = true
    }

    func endWeeklyTracking() {
        // La semaine reste marquée comme active
        isActivityActive = false

        // Mettre à jour le widget
        let currentStreak = getConsecutiveWeeks()
        sharedDefaults?.set(currentStreak, forKey: consecutiveWeeksKey)
        sharedDefaults?.set(currentWeekIdentifier(), forKey: lastActiveWeekKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func markWeekAsActive() {
        let weekKey = getCurrentWeekKey()
        UserDefaults.standard.set(true, forKey: weekKey)
        sharedDefaults?.set(true, forKey: weekKey)
        sharedDefaults?.set(currentWeekIdentifier(), forKey: lastActiveWeekKey)

        // Recalculer les semaines consécutives
        Task { @MainActor in
            self.consecutiveWeeks = getConsecutiveWeeks()
            sharedDefaults?.set(self.consecutiveWeeks, forKey: consecutiveWeeksKey)
        }
    }

    private func getCurrentWeekKey() -> String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: Date())
        let week = calendar.component(.weekOfYear, from: Date())
        return "weekActive_\(year)_\(week)"
    }

    private func currentWeekIdentifier() -> String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: Date())
        let week = calendar.component(.weekOfYear, from: Date())
        return "\(year)-\(week)"
    }

    func getConsecutiveWeeks() -> Int {
        let calendar = Calendar.current
        var currentDate = Date()
        var consecutiveCount = 0

        // Vérifier les semaines en remontant dans le temps
        while true {
            let year = calendar.component(.yearForWeekOfYear, from: currentDate)
            let week = calendar.component(.weekOfYear, from: currentDate)
            let weekKey = "weekActive_\(year)_\(week)"

            if UserDefaults.standard.bool(forKey: weekKey) {
                consecutiveCount += 1
                // Passer à la semaine précédente
                currentDate = calendar.date(byAdding: .weekOfYear, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }

        // Mettre à jour la variable publiée
        Task { @MainActor in
            self.consecutiveWeeks = consecutiveCount
        }

        return consecutiveCount
    }
}

extension Color {
    static let flashcardBackground = Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF2 / 255)
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

struct UndoAction {
    let card: Flashcard
    let swipeDirection: SwipeDirection
    let cardRotation: Double
    let cardIndex: Int
    // ✅ ÉTAT SM-2 PRÉCÉDENT pour rollback
    let previousInterval: Double
    let previousEaseFactor: Double
    let previousNextReviewDate: Date?
    let previousReviewCount: Int32
    let previousCorrectCount: Int16
    let previousLastReviewDate: Date?
}

// MARK: - Enums

enum FlipDirection {
    case left, right

    var degrees: Double {
        switch self {
        case .right: return 180
        case .left: return -180
        }
    }
}

enum SwipeDirection {
    case left, right, none
}

// MARK: - FlashcardStackRevisionView

struct FlashcardStackRevisionView: View {
    // MARK: - Environment & ObservedObjects

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var activityManager = RevisionActivityManager.shared
    @StateObject private var audioService = AudioService.shared
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var autoplayManager = AutoplayManager()
    @StateObject private var stateManager = FlashcardStateManager()

    // MARK: - State Properties ✅ SYSTÈME DE FLIP UNIFIÉ

    @State private var cards: [Flashcard]
    @State private var isDragCancellingSimilarTaps = false
    @State private var lastTapTime: Date = .init()
    @State private var deck: FlashcardDeck
    @State private var showCompletionElements = false
    @State private var showSessionComplete = false
    @State private var dragOffset: CGSize = .zero
    @State private var isRemovingCard = false
    @State private var isNextCardActive = false
    @State private var showStatsElements = false
    @State private var bounceIcon = false
    @State private var swipeDirection: SwipeDirection = .none
    @State private var finalSwipeDirection: SwipeDirection = .none
    @State private var cardsKnown = 0
    @State private var cardsToReview = 0
    @State private var currentCardIndex = 0
    @State private var wasReinjected = false
    @State private var initialCardCount = 0
    @State private var dragVelocity: CGSize = .zero
    @State private var undoStack: [UndoAction] = []
    @State private var canUndo: Bool = false
    @State private var isUndoing = false
    @State private var isPreviousCardHidden = false
    @State private var activeCardIndex = 0
    @State private var cardRotations: [Double] = []
    @State private var showResetConfirmation = false
    @State private var showIntroduction = true // ✅ NOUVEAU : Écran d'introduction
    @State private var restoredFreeModeSession = false

    @AppStorage("isFreeMode") private var isFreeMode = false

    // ✅ ANIMATION CONSTANTS
    private let animationDuration: Double = 0.3

    // MARK: - Initializer

    init(deck: FlashcardDeck) {
        self.deck = deck

        let isFreeModeEnabled = UserDefaults.standard.bool(forKey: "isFreeMode")

        var initialCards: [Flashcard] = []
        var initialCount = 0
        var currentIndex = 0
        var knownCount = 0
        var toReviewCount = 0
        var undoItems: [UndoAction] = []
        var canUndoFlag = false
        var introductionVisible = true
        var restoredFlag = false

        if isFreeModeEnabled {
            let restoredCards = SimpleSRSManager.shared.loadFreeModeSession(for: deck)
            let progress = SimpleSRSManager.shared.loadFreeModeProgress(for: deck)

            if !restoredCards.isEmpty, let snapshot = progress {
                let flashcardsSet = deck.flashcards as? Set<Flashcard> ?? []
                let flashcardMap = Dictionary(uniqueKeysWithValues: flashcardsSet.compactMap { card -> (String, Flashcard)? in
                    guard let id = card.id?.uuidString else { return nil }
                    return (id, card)
                })

                initialCards = restoredCards
                let referenceInitial = max(snapshot.initialCount, initialCards.count)
                initialCount = max(referenceInitial, snapshot.currentIndex)
                currentIndex = min(snapshot.currentIndex, initialCount)
                knownCount = max(0, min(snapshot.cardsKnown, currentIndex))
                let remainingReviewed = max(0, currentIndex - knownCount)
                toReviewCount = max(0, min(snapshot.cardsToReview, remainingReviewed))

                undoItems = snapshot.undoRecords.compactMap { record in
                    guard let card = flashcardMap[record.cardId] else { return nil }
                    let direction: SwipeDirection
                    switch record.swipeDirection {
                    case "left": direction = .left
                    case "right": direction = .right
                    default: return nil
                    }
                    // ✅ NOUVELLE STRUCTURE : Utiliser les valeurs actuelles comme "précédentes"
                    return UndoAction(
                        card: card,
                        swipeDirection: direction,
                        cardRotation: 0.0,
                        cardIndex: 0,
                        previousInterval: card.interval,
                        previousEaseFactor: card.easeFactor,
                        previousNextReviewDate: card.nextReviewDate,
                        previousReviewCount: card.reviewCount,
                        previousCorrectCount: card.correctCount,
                        previousLastReviewDate: card.lastReviewDate
                    )
                }
                canUndoFlag = !undoItems.isEmpty

                if snapshot.currentIndex == 0, undoItems.isEmpty {
                    introductionVisible = true
                    restoredFlag = false
                } else {
                    introductionVisible = false
                    restoredFlag = true
                }

                print("🆓 [FREE_MODE] Session libre restaurée avec \(initialCards.count) cartes restantes (progression \(currentIndex)/\(initialCount))")
            } else {
                initialCards = SimpleSRSManager.shared.getAllCardsInOptimalOrder(deck: deck)
                initialCount = initialCards.count
                print("🆓 [FREE_MODE] Session libre initialisée avec \(initialCards.count) cartes")
            }
        } else {
            initialCards = SimpleSRSManager.shared.getSmartCards(deck: deck, minCards: 10)
            initialCount = initialCards.count
            print("🎯 [SM2] Session initialisée avec \(initialCards.count) cartes")
            print("🔍 [DEBUG] Session - IDs des cartes initiales: \(initialCards.map { $0.id?.uuidString.prefix(8) ?? "nil" })")
            print("🔍 [DEBUG] Session - initialCount: \(initialCount)")
        }

        _cards = State(initialValue: initialCards)
        _initialCardCount = State(initialValue: initialCount)
        _currentCardIndex = State(initialValue: currentIndex)
        _cardsKnown = State(initialValue: knownCount)
        _cardsToReview = State(initialValue: toReviewCount)
        _undoStack = State(initialValue: Array(undoItems.suffix(50)))
        _canUndo = State(initialValue: canUndoFlag)
        _cardRotations = State(initialValue: Array(repeating: 0.0, count: initialCards.count))
        _showIntroduction = State(initialValue: introductionVisible)
        _restoredFreeModeSession = State(initialValue: restoredFlag)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()

            if showIntroduction {
                introductionView
            } else if cards.isEmpty {
                sessionCompletedView
            } else {
                mainContentView
            }
        }
        .onAppear {
            initializeSession()
        }

        .onDisappear {
            cleanupSession()
        }
        .alert("Recommencer la session", isPresented: $showResetConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Recommencer", role: .destructive) {
                resetSession()
            }
        } message: {
            Text("Voulez-vous recommencer la session et parcourir toutes les cartes à nouveau ?")
        }
    }

    // MARK: - Computed Properties

    private var isFlipping: Bool {
        stateManager.isFlipping
    }

    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }

    private var totalCardsReviewed: Int {
        currentCardIndex
    }

    private var progressPercentage: Double {
        guard initialCardCount > 0 else { return 0 }
        return Double(currentCardIndex) / Double(initialCardCount)
    }

    private var backgroundColor: Color {
        switch colorScheme {
        case .dark: return .black
        default: return .white
        }
    }

    private var cardBackgroundColor: Color {
        switch colorScheme {
        case .dark: return Color(UIColor.secondarySystemBackground)
        default: return Color.white
        }
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
                Text("Flashcards")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.primary)

                // Icône du mode
                Image(systemName: "rectangle.on.rectangle.angled.fill")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.blue)

                // Texte explicatif
                VStack(spacing: 16) {
                    Text("Révisez vos cartes de manière interactive")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text("Swipez à droite si vous connaissez la réponse, à gauche si vous l'oubliez")
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
                            .fill(Color.blue)
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
    }

    // MARK: - Main Views

    private var mainContentView: some View {
        let isSmallScreen = UIScreen.main.bounds.height < 700

        return ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerSection
                cardStack
                    .padding(.top, isSmallScreen ? 20 : 40)
                    .zIndex(1)
                Spacer()
                    .frame(height: isSmallScreen ? 60 : 100)
            }

            VStack {
                HStack {
                    undoButton
                    Spacer()
                    autoplayButton
                }
                .padding(.horizontal, isSmallScreen ? 30 : 40)
                .padding(.bottom, isSmallScreen ? 20 : 30)
            }
            .zIndex(-1)
            .allowsHitTesting(!stateManager.isSwipeInProgress && !stateManager.isAnimating)
        }
        .onReceive(autoplayManager.$autoplayPhase) { phase in
            handleAutoplayPhase(phase)
        }
    }

    private var sessionCompletedView: some View {
        VStack(spacing: 32) {
            Spacer()
            completionHeader
            completionStats
            Spacer()
            completionButtons
        }
        .padding(.horizontal, 24)
        .onAppear {
            audioManager.stopAudio()
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

    // MARK: - UI Components

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
                    Text(deck.name ?? String(localized: "flashcard_revision"))
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

            ProgressBar2(progress: progressPercentage)
                .padding(.horizontal, 20)

            HStack {
                Spacer()
                Text("\(currentCardIndex)/\(initialCardCount)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, isSmallScreen ? 8 : 20)
        .frame(height: isSmallScreen ? 70 : 100) // Hauteur réduite pour petits écrans
    }

    private var cardStack: some View {
        ZStack {
            ForEach(Array(cards.prefix(3).enumerated()), id: \.element) { idx, card in
                cardView(for: card, at: idx)
            }
        }
        .frame(height: 500)
    }

    private var autoplayButton: some View {
        Button(action: {
            HapticFeedbackManager.shared.impact(style: .soft)
            autoplayManager.toggle()
        }) {
            Image(systemName: autoplayManager.isActive ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(isFreeMode ? .primary : .secondary)
        }
        .id(autoplayManager.isActive ? "pause" : "play") // ✅ Supprime les transitions
        .buttonStyle(.plain) // ✅ Supprime l'effet de pression
        .opacity(cards.isEmpty ? 0.3 : (isFreeMode ? 1.0 : 0.5))
        .disabled(cards.isEmpty || !isFreeMode)
    }

    // MARK: - Completion Views

    private var completionHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.primary)
                .opacity(showCompletionElements ? 1 : 0)
                .scaleEffect(showCompletionElements ? 1.0 : 0.9)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showCompletionElements)

            Text(String(localized: "session_completed"))
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
                        Text("\(totalCardsReviewed)")
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
                        Text("\(cardsKnown)")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.primary)
                        Text(String(localized: "stats_mastered"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(cardsToReview)")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.primary)
                        Text(String(localized: "stats_to_review"))
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
            // ✅ BOUTON RECOMMENCER SEULEMENT EN MODE LIBRE
            if isFreeMode {
                Button(action: {
                    HapticFeedbackManager.shared.impact(style: .soft)
                    restartFlashcardSession()
                }) {
                    Text(String(localized: "action_retry_flashcard"))
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
            }

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

    private var canShowUndoAsEnabled: Bool {
        return !undoStack.isEmpty && !stateManager.isUndoing
    }

    // Modifiez votre undoButton
    private var undoButton: some View {
        Button(action: {
            undoLastSwipe()
        }) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(canShowUndoAsEnabled ? .primary : .gray)
                .opacity(canShowUndoAsEnabled ? 1 : 0.4)
        }
        .disabled(!canShowUndoAsEnabled || stateManager.isOperationLocked)
    }

    // MARK: - Card View ✅ VERSION AVEC FLIP DIRECTIONNEL

    private func cardView(for card: Flashcard, at index: Int) -> some View {
        let cardColor = cardBackgroundColor

        return FastFlipCardView<AnyView, AnyView>(
            front: { AnyView(conditionalFrontContent(for: card, at: index)) },
            back: { AnyView(conditionalBackContent(for: card, at: index)) },
            cardRotation: index == 0 && !cardRotations.isEmpty ? cardRotations[0] : 0, // ✅ SEULEMENT la carte active flip
            backgroundColor: cardColor,
            animationDuration: animationDuration,
            swipeDirection: cardSwipeDirection(for: index),
            swipeProgress: cardSwipeProgress(for: index)
        )
        .frame(width: 350, height: 500)
        .offset(index == 0 ? dragOffset : .zero)
        .rotationEffect(.degrees(index == 0 ? Double(dragOffset.width / 20) : 0))
        .zIndex(index == 0 ? 999 : Double(cards.count - index)) // ✅ zIndex élevé pour carte active
        .opacity(shouldShowCard(at: index) ? 1 : 0)
        .allowsHitTesting(index == 0 && !stateManager.isAnimating)
        .gesture(
            index == 0 && !stateManager.isAnimating && !isUndoing ?
                createUnifiedGesture() : nil
        )
    }

    // MARK: - Card Helper Functions

    private func shouldShowCard(at index: Int) -> Bool {
        if index == 0 {
            return true
        }

        if isUndoing {
            return !isPreviousCardHidden
        }

        return index < 3
    }

    private func cardFrontContent(for card: Flashcard) -> some View {
        FlashcardContentView(
            contentType: card.questionContentType,
            text: card.question,
            imageData: card.questionImageData,
            imageFileName: card.questionImageFileName,
            audioFileName: card.questionAudioFileName,
            audioDuration: card.questionAudioDuration,
            autoplayManager: autoplayManager
        )
    }

    private func cardBackContent(for card: Flashcard) -> some View {
        FlashcardContentView(
            contentType: card.answerContentType,
            text: card.answer,
            imageData: card.answerImageData,
            imageFileName: card.answerImageFileName,
            audioFileName: card.answerAudioFileName,
            audioDuration: card.answerAudioDuration,
            autoplayManager: autoplayManager
        )
    }

    private func cardSwipeDirection(for index: Int) -> SwipeDirection {
        if index == 0 {
            return finalSwipeDirection != .none ? finalSwipeDirection : swipeDirection
        }
        return .none
    }

    private func cardSwipeProgress(for index: Int) -> CGFloat {
        if autoplayManager.isActive {
            return 0
        }
        return index == 0 ? min(abs(dragOffset.width) / 80, 1) : 0
    }

    private func conditionalFrontContent(for card: Flashcard, at index: Int) -> some View {
        Group {
            if index == 0 {
                cardFrontContent(for: card)
                    .transaction { $0.animation = nil }
            } else {
                Color.clear
                    .transaction { $0.animation = nil }
            }
        }
        .transaction { $0.animation = nil }
    }

    private func conditionalBackContent(for card: Flashcard, at index: Int) -> some View {
        Group {
            if index == 0 {
                cardBackContent(for: card)
                    .transaction { $0.animation = nil }
            } else {
                Color.clear
                    .transaction { $0.animation = nil }
            }
        }
        .transaction { $0.animation = nil }
    }

    private func handleCardTap(at direction: FlipDirection, stopAutoplay: Bool = true) {
        guard !stateManager.isAnimating else { return }
        guard dragOffset == .zero else { return }
        guard !cardRotations.isEmpty else { return }

        stateManager.isAnimating = true

        // Stop toutes les autres animations
        if stopAutoplay, autoplayManager.isActive {
            autoplayManager.stop()
            autoplayManager.reset()
        }
        if let manager = audioManager as AudioManager?, manager.isPlaying {
            manager.stopAudioSilently()
        }

        // Accumule 180° dans la direction choisie
        let rotationIncrement: Double = direction == .left ? -180 : 180

        withAnimation(.easeInOut(duration: animationDuration)) {
            cardRotations[0] += rotationIncrement
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.stateManager.isAnimating = false
        }

        HapticFeedbackManager.shared.impact(style: .soft)
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        if let manager = audioManager as AudioManager?, manager.isPlaying {
            manager.stopAudioSilently()
        }
        if autoplayManager.isActive {
            autoplayManager.stop()
            autoplayManager.reset()
        }

        let tx = value.translation.width
        let ty = value.translation.height
        let px = value.predictedEndTranslation.width

        let absX = abs(tx)
        let absPX = abs(px)

        let distanceThreshold: CGFloat = 120
        let predictedThreshold: CGFloat = 200

        // ✅ RETOUR AU SYSTÈME BINAIRE : Seulement horizontal
        let shouldDismiss: Bool
        let direction: SwipeDirection

        shouldDismiss = absX > distanceThreshold || absPX > predictedThreshold
        direction = tx > 0 ? .right : .left

        if shouldDismiss {
            finalSwipeDirection = direction

            // ✅ RETOUR AU SYSTÈME BINAIRE : Animation de sortie simple
            let exitX: CGFloat
            let exitY: CGFloat

            switch direction {
            case .right:
                exitX = 600
                exitY = ty * 0.3
            case .left:
                exitX = -600
                exitY = ty * 0.3
            default:
                exitX = 0
                exitY = 0
            }

            withAnimation(.easeOut(duration: 0.4)) {
                dragOffset = CGSize(width: exitX, height: exitY)
                isRemovingCard = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                nextCard()
            }
        } else {
            finalSwipeDirection = .none
            swipeDirection = .none
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                dragOffset = .zero
            }
        }
    }

    private func handleAutoplayPhase(_ phase: AutoplayManager.AutoplayPhase) {
        print("🎬 Phase reçue: \(phase)")

        guard autoplayManager.isActive, !cards.isEmpty else {
            print("🎬 ❌ Stopping autoplay: inactive or no cards")
            autoplayManager.stop()
            return
        }

        switch phase {
        case .showingFront:
            // ✅ NE RIEN FAIRE - juste laisser la face avant visible
            print("🎬 👁️ Showing FRONT for 3 seconds...")
            // Le timer va se déclencher automatiquement après 3s et passer à .showingBack

        case .showingBack:
            // ✅ MAINTENANT on peut flipper car les 3s de la face avant sont écoulées
            if !cardRotations.isEmpty, cardRotations[0].truncatingRemainder(dividingBy: 360) < 90 {
                print("🎬 🔄 Flipping to BACK (after 3s front)")
                handleCardTap(at: .right, stopAutoplay: false)
            }

        case .transitioning:
            print("🎬 ➡️ Performing auto swipe (after 3s back)")
            performAutoSwipe()
            // Le timer va se déclencher après 0.5s et revenir à .showingFront
        }
    }

    private func performAutoSwipe() {
        guard !cards.isEmpty else { return }

        let direction = autoplayManager.currentSwipeDirection()
        print("🎬 🚀 Auto swipe direction: \(direction)")

        finalSwipeDirection = direction

        let exitDistance: CGFloat = direction == .right ? 600 : -600

        withAnimation(.easeInOut(duration: 0.4)) { // Animation 1s
            dragOffset = CGSize(width: exitDistance, height: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.autoplayManager.recordSwipe()
            self.nextCard()
        }
    }

    private func undoLastSwipe() {
        guard !undoStack.isEmpty else { return }
        guard stateManager.canUndo() else { return }
        guard stateManager.lockOperation("undo") else { return }

        stateManager.isAnimating = false
        stateManager.isFlipping = false

        autoplayManager.stop()
        if let manager = audioManager as AudioManager?, manager.isPlaying {
            manager.stopAudioSilently()
        }

        stateManager.isUndoing = true

        let lastAction = undoStack.removeLast()

        // ✅ ROLLBACK selon le mode
        if !isFreeMode {
            // Mode répétition espacée : Rollback SM-2
            SimpleSRSManager.shared.rollbackSM2Data(
                card: lastAction.card,
                undoAction: lastAction,
                context: viewContext
            )
        } else {
            // Mode libre : Rollback des états temporaires
            if let cardId = lastAction.card.id?.uuidString {
                SimpleSRSManager.shared.rollbackFreeModeCard(cardId: cardId)
            }
        }

        cards.insert(lastAction.card, at: 0)

        // ✅ CHANGEMENT : Toujours revenir en face principale
        cardRotations.insert(0.0, at: 0)

        switch lastAction.swipeDirection {
        case .right: cardsKnown = max(0, cardsKnown - 1)
        case .left: cardsToReview = max(0, cardsToReview - 1)
        default: break
        }
        currentCardIndex = max(0, currentCardIndex - 1)

        let distance = UIScreen.main.bounds.width * 1.2
        dragOffset = CGSize(
            width: lastAction.swipeDirection == .right ? distance : -distance,
            height: 0
        )

        withAnimation(.spring(response: 0.15, dampingFraction: 1.0)) {
            dragOffset = .zero
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.synchronizeCardStates()
            self.stateManager.isUndoing = false
            self.stateManager.unlockOperation("undo")

            self.stateManager.isAnimating = false
            self.stateManager.isFlipping = false
        }

        HapticFeedbackManager.shared.impact(style: .soft)
    }

    private func synchronizeCardStates() {
        // ✅ RÉINITIALISATION COMPLÈTE si désynchronisé
        if cardRotations.count != cards.count {
            cardRotations = Array(repeating: 0.0, count: cards.count)

            // ✅ RESET des animations en cours
            stateManager.isAnimating = false
            stateManager.isFlipping = false
        }

        // ✅ ASSURER cohérence des indices
        activeCardIndex = 0

        // ✅ NE PAS forcer la rotation si on est en train de faire un undo
        if !cardRotations.isEmpty, !stateManager.isUndoing {
            cardRotations[0] = 0.0
        }
    }

    private func createUnifiedGesture() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !stateManager.isAnimating, !stateManager.isFlipping else { return }

                // ✅ ARRÊTER L'AUDIO PENDANT LE DRAG
                if let manager = audioManager as AudioManager?, manager.isPlaying {
                    manager.stopAudioSilently()
                }
                if autoplayManager.isActive {
                    autoplayManager.stop()
                    autoplayManager.reset()
                }

                // ✅ Mise à jour immédiate de dragOffset (zéro deadzone)
                dragOffset = value.translation

                // ✅ RETOUR AU SYSTÈME BINAIRE : Seulement gauche/droite
                let dx = value.translation.width
                swipeDirection = dx >= 0 ? .right : .left

                // Marquer comme swipe seulement après mouvement significatif
                let dragDistance = hypot(value.translation.width, value.translation.height)
                stateManager.isSwipeInProgress = dragDistance > 8
            }
            .onEnded { value in
                defer { stateManager.isSwipeInProgress = false }

                if stateManager.isAnimating {
                    dragOffset = .zero
                    return
                }

                let dragDistance = hypot(value.translation.width, value.translation.height)
                let startLocation = value.startLocation

                // ✅ Si mouvement minimal = c'est un TAP
                if dragDistance < 8 {
                    handleTapAtLocation(startLocation)
                    dragOffset = .zero
                    return
                }

                // ✅ Sinon = c'est un DRAG
                handleDragEnd(value)
            }
    }

    private func handleTapAtLocation(_ location: CGPoint) {
        // Dimensions de la carte (ajustez selon vos besoins)
        let cardWidth: CGFloat = 350
        let tapZoneWidth: CGFloat = 120

        let now = Date()
        guard now.timeIntervalSince(lastTapTime) > 0.3 else { return }
        lastTapTime = now

        // ✅ Déterminer si tap gauche ou droite
        if location.x < tapZoneWidth {
            handleCardTap(at: .left)
        } else if location.x > (cardWidth - tapZoneWidth) {
            handleCardTap(at: .right)
        }
        // Zone centrale = pas de flip
    }

    private func resetDragState() {
        dragOffset = .zero
        swipeDirection = .none
        finalSwipeDirection = .none
    }

    private func nextCard() {
        print("🔍 [DEBUG] nextCard() - cards.count: \(cards.count)")
        print("🔍 [DEBUG] nextCard() - currentCardIndex: \(currentCardIndex)")
        print("🔍 [DEBUG] nextCard() - cards IDs: \(cards.map { $0.id?.uuidString.prefix(8) ?? "nil" })")
        guard !cards.isEmpty else { return }

        // ✅ CAPTURER LA DIRECTION DU SWIPE AVANT TOUT
        let swipeWas = finalSwipeDirection

        isPreviousCardHidden = false

        if finalSwipeDirection != .none {
            let currentRotation = cardRotations.isEmpty ? 0.0 : cardRotations[0]
            let currentCard = cards[0]

            // ✅ CAPTURER L'ÉTAT SM-2 AVANT MODIFICATION
            let action = UndoAction(
                card: currentCard,
                swipeDirection: finalSwipeDirection,
                cardRotation: currentRotation,
                cardIndex: 0,
                // ✅ ÉTAT SM-2 PRÉCÉDENT
                previousInterval: currentCard.interval,
                previousEaseFactor: currentCard.easeFactor,
                previousNextReviewDate: currentCard.nextReviewDate,
                previousReviewCount: currentCard.reviewCount,
                previousCorrectCount: currentCard.correctCount,
                previousLastReviewDate: currentCard.lastReviewDate
            )

            undoStack.append(action)

            if undoStack.count > 50 {
                undoStack.removeFirst()
            }

            switch finalSwipeDirection {
            case .right:
                cardsKnown += 1
                print("🔍 [DEBUG] Carte correcte - cardsKnown: \(cardsKnown)")
            case .left:
                cardsToReview += 1
                print("🔍 [DEBUG] Carte incorrecte - cardsToReview: \(cardsToReview)")
            default: break
            }

            // ✅ HAPTIC UNIFIÉ : Feedback minimal
            HapticFeedbackManager.shared.impact(style: .soft)

            // ✅ GENERATION UNIQUE : operationId côté UI pour tous les modes
            let operationId = UUID().uuidString

            // ✅ NOUVEAU : Mise à jour immédiate du statut
            updateCardStatusImmediately(card: cards[0], isCorrect: finalSwipeDirection == .right)

            // ✅ SM-2 Integration avec LapseBuffer
            if !isFreeMode {
                // ✅ RETOUR AU SYSTÈME BINAIRE : Mapping simple
                let quality: Int
                switch finalSwipeDirection {
                case .right: quality = 2 // Bon
                case .left: quality = 1 // Faux
                default: quality = 2 // Par défaut bon
                }

                // ✅ RETOUR AU SYSTÈME BINAIRE : Réinjection pour faux
                let shouldReinject = quality == 1 && SimpleSRSManager.shared.shouldReinjectCard(
                    card: cards[0],
                    quality: quality
                )

                SimpleSRSManager.shared.processSwipeResult(
                    card: cards[0],
                    swipeDirection: finalSwipeDirection,
                    context: viewContext,
                    operationId: operationId
                )

                // ✅ LAPSEBUFFER : Réinjection immédiate si nécessaire
                if shouldReinject {
                    print("🔄 [LAPSEBUFFER] Carte incorrecte réinjectée immédiatement")
                    print("🔍 [DEBUG] LAPSEBUFFER - Avant réinjection: cards.count = \(cards.count)")
                    print("🔍 [DEBUG] LAPSEBUFFER - Carte réinjectée: \(cards[0].id?.uuidString.prefix(8) ?? "nil")")
                    // La carte sera réinjectée à la fin de la pile
                    cards.append(cards[0])
                    print("🔍 [DEBUG] LAPSEBUFFER - Après réinjection: cards.count = \(cards.count)")
                }

                // ✅ CAPTURER shouldReinject pour l'utiliser plus tard
                wasReinjected = shouldReinject
            } else {
                // ✅ MODE LIBRE : operationId généré mais ignoré (protection future)
                print("🆓 [FREE_MODE] Révision libre - pas de mise à jour SM-2 (opId: \(operationId.prefix(8)))")
                SimpleSRSManager.shared.markCardReviewedInFreeMode(
                    cards[0],
                    wasCorrect: finalSwipeDirection == .right,
                    context: viewContext
                )
                // ✅ MODE LIBRE : Pas de réinjection
                wasReinjected = false
            }
        }

        cards.removeFirst()
        if !cardRotations.isEmpty {
            cardRotations.removeFirst()
        }

        isRemovingCard = false

        // ✅ CORRECTION : Ne pas incrémenter si la carte a été réinjectée
        if !isFreeMode, swipeWas == .left {
            // Utiliser la variable capturée avant la réinjection
            if !wasReinjected {
                currentCardIndex += 1
                print("🔍 [DEBUG] currentCardIndex incrémenté: \(currentCardIndex)")
            } else {
                print("🔍 [DEBUG] currentCardIndex NON incrémenté (carte réinjectée)")
            }
        } else {
            currentCardIndex += 1
            print("🔍 [DEBUG] currentCardIndex incrémenté (mode libre ou carte correcte): \(currentCardIndex)")
        }

        // ✅ RÉINITIALISER L'ÉTAT DU DRAG APRÈS L'INCRÉMENT
        resetDragState()

        // ✅ RESET COMPLET des états d'animation
        stateManager.isAnimating = false
        stateManager.isFlipping = false

        synchronizeCardStates()

        if cards.isEmpty {
            // ✅ Délai pour laisser la barre de progression terminer son animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showSessionComplete = true
            }
        }
    }

    // ✅ NOUVELLE MÉTHODE : Mise à jour immédiate du statut
    private func updateCardStatusImmediately(card: Flashcard, isCorrect: Bool) {
        // ✅ LOGIQUE : Erreur = perte immédiate de la maîtrise
        if !isCorrect {
            // L'erreur va réduire l'intervalle, donc la carte ne sera plus maîtrisée
            // Le statut sera automatiquement mis à jour lors du prochain affichage
            print("👑 [STATUS] Carte perd sa maîtrise suite à une erreur")
        } else {
            // Vérifier si la bonne réponse permet d'atteindre la maîtrise
            let newInterval = card.interval * card.easeFactor
            if newInterval >= SRSConfiguration.masteryIntervalThreshold {
                print("👑 [STATUS] Carte devient maîtrisée suite à une bonne réponse")
            }
        }
    }

    // MARK: - Session Management

    private func initializeSession() {
        if !restoredFreeModeSession {
            initialCardCount = cards.count
            currentCardIndex = 0
            cardsKnown = 0
            cardsToReview = 0
            undoStack.removeAll()
            canUndo = false
        }

        cardRotations = Array(repeating: 0.0, count: cards.count)
        stateManager.isAnimating = false

        autoplayManager.stop()
        autoplayManager.reset()

        resetDragState()

        HapticFeedbackManager.shared.impact(style: .soft)
        activityManager.startWeeklyTracking()

        restoredFreeModeSession = false
    }

    private func cleanupSession() {
        activityManager.endWeeklyTracking()
        // Plus besoin de weeklyMinutes, le système de semaines se gère automatiquement
        WidgetCenter.shared.reloadAllTimelines()

        autoplayManager.stop()
        autoplayManager.reset()

        if isFreeMode {
            let remainingCards = cards
            let undoRecords = undoStack.compactMap { action -> SimpleSRSManager.FreeModeProgressSnapshot.UndoRecord? in
                guard let id = action.card.id?.uuidString,
                      let storedDirection = storedValue(for: action.swipeDirection)
                else {
                    return nil
                }
                return SimpleSRSManager.FreeModeProgressSnapshot.UndoRecord(
                    cardId: id,
                    swipeDirection: storedDirection
                )
            }

            if remainingCards.isEmpty, undoRecords.isEmpty, currentCardIndex == 0 {
                SimpleSRSManager.shared.clearFreeModeSession(for: deck)
                SimpleSRSManager.shared.clearFreeModeProgress(for: deck)
            } else {
                SimpleSRSManager.shared.saveFreeModeSession(for: deck, cards: remainingCards)
                let snapshot = SimpleSRSManager.FreeModeProgressSnapshot(
                    initialCount: max(initialCardCount, currentCardIndex + remainingCards.count),
                    currentIndex: currentCardIndex,
                    cardsKnown: cardsKnown,
                    cardsToReview: cardsToReview,
                    undoRecords: Array(undoRecords.suffix(50))
                )
                SimpleSRSManager.shared.saveFreeModeProgress(for: deck, snapshot: snapshot)
            }
        } else if let deckId = deck.id?.uuidString {
            let cache = SM2OptimizationCache.shared
            cache.invalidateDeckStats(forDeckId: deckId)
            cache.invalidateCardSelections(forDeckId: deckId)
        }
    }

    private func storedValue(for direction: SwipeDirection) -> String? {
        switch direction {
        case .left: return "left"
        case .right: return "right"
        default: return nil
        }
    }

    private func restartFlashcardSession() {
        undoStack.removeAll()
        canUndo = false
        isUndoing = false
        autoplayManager.stop()
        autoplayManager.reset()
        activeCardIndex = 0
        currentCardIndex = 0
        cardsKnown = 0
        cardsToReview = 0
        dragOffset = .zero
        resetDragState()
        isRemovingCard = false
        isNextCardActive = false
        finalSwipeDirection = .none
        showCompletionElements = false
        showStatsElements = false
        stateManager.isAnimating = false

        if isFreeMode {
            SimpleSRSManager.shared.clearFreeModeSession(for: deck)
            SimpleSRSManager.shared.clearFreeModeProgress(for: deck)
        }

        // ✅ UTILISER LA MÊME LOGIQUE QUE L'INITIALISATION NORMALE
        let flashcards: [Flashcard]
        if isFreeMode {
            flashcards = (deck.flashcards as? Set<Flashcard>)?.sorted {
                ($0.createdAt ?? Date()) < ($1.createdAt ?? Date())
            }.shuffled() ?? []
        } else {
            // ✅ MODE SM-2 : Utiliser getSmartCards comme l'initialisation normale
            flashcards = SimpleSRSManager.shared.getSmartCards(deck: deck, minCards: 10)
        }

        cards = flashcards
        initialCardCount = flashcards.count
        cardRotations = Array(repeating: 0.0, count: flashcards.count)
        restoredFreeModeSession = false
        showIntroduction = true

        activityManager.startWeeklyTracking()

        print("🔄 Session redémarrée (mode libre: \(isFreeMode ? "activé" : "désactivé"))")
    }

    // MARK: - Utility Functions

    // MARK: - Session Management

    private func resetSession() {
        // ✅ ROLLBACK SM-2 : Restaurer toutes les données SM-2 avant reset
        if !isFreeMode, !undoStack.isEmpty {
            print("🔄 [SM2] Rollback de session avant reset...")
            SimpleSRSManager.shared.rollbackSessionSM2Data(
                undoActions: undoStack,
                context: viewContext
            )
        }

        // Réinitialiser tous les états
        currentCardIndex = 0
        cardsKnown = 0
        cardsToReview = 0
        undoStack.removeAll()
        canUndo = false

        // Réinitialiser les états des cartes
        cardRotations = Array(repeating: 0.0, count: cards.count)

        // Réinitialiser les managers
        stateManager.unlockOperation("reset")
        autoplayManager.reset()

        if isFreeMode {
            SimpleSRSManager.shared.clearFreeModeSession(for: deck)
            SimpleSRSManager.shared.clearFreeModeProgress(for: deck)
            SimpleSRSManager.shared.clearFreeModeStates() // ✅ NETTOYER les états temporaires
        }

        // Le mode libre reste inchangé lors de la réinitialisation
        print("🔄 Session réinitialisée (mode libre: \(isFreeMode ? "activé" : "désactivé"))")
    }
}

// MARK: - Supporting Components

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

struct FastFlipCardView<Front: View, Back: View>: View {
    let front: () -> Front
    let back: () -> Back
    var cardRotation: Double = 0
    var backgroundColor: Color = .init(.systemBackground)
    var animationDuration: Double = 0.3
    var swipeDirection: SwipeDirection = .none
    var swipeProgress: CGFloat = 0

    private var isFlipped: Bool {
        let normalizedRotation = cardRotation.truncatingRemainder(dividingBy: 360)
        let absRotation = abs(normalizedRotation)
        return absRotation >= 90 && absRotation <= 270
    }

    private var isNearEdge: Bool {
        // Masque le contenu quand l'angle est proche de 90° ou 270° pour éviter une ligne visible
        var angle = cardRotation.truncatingRemainder(dividingBy: 360)
        if angle < 0 { angle += 360 }
        let epsilon = 1.0
        return abs(angle - 90) < epsilon || abs(angle - 270) < epsilon
    }

    var body: some View {
        ZStack {
            cardBackground
            cardBorder
            cardContent
        }
        .rotation3DEffect(
            .degrees(cardRotation),
            axis: (0, 1, 0),
            perspective: 0.6
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(backgroundColor)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 15)
            .strokeBorder(borderColor.opacity(Double(max(0, min(swipeProgress, 1)))), lineWidth: 3)
    }

    private var borderColor: Color {
        switch swipeDirection {
        case .right: return .green
        case .left: return .orange
        default: return .clear
        }
    }

    // ✅ SYSTÈME AMÉLIORÉ pour éviter les artefacts visuels
    private var cardContent: some View {
        ZStack {
            // Face avant
            front()
                .modifier(FlipOpacity(percentage: isFlipped ? 0 : 1))
                .allowsHitTesting(!isFlipped)
                .clipped()

            // Face arrière
            back()
                .modifier(FlipOpacity(percentage: isFlipped ? 1 : 0))
                .rotation3DEffect(.degrees(180), axis: (0, 1, 0))
                .allowsHitTesting(isFlipped)
                .clipped()
        }
        .padding()
        .clipped()
        .opacity(isNearEdge ? 0 : 1)
    }
}

// ✅ MODIFICATEUR AMÉLIORÉ pour éviter les artefacts visuels
private struct FlipOpacity: AnimatableModifier {
    var percentage: CGFloat = 0

    var animatableData: CGFloat {
        get { percentage }
        set { percentage = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(Double(percentage.rounded())) // ✅ Changement binaire instantané
            .allowsHitTesting(percentage > 0.5) // ✅ Masquer les interactions
    }
}
