import SwiftUI
import UIKit
import Foundation
import CoreData
import Combine
import Lottie
import WidgetKit
import StoreKit

extension NSNotification.Name {
    static let saveActivePeriod = NSNotification.Name("saveActivePeriod")
}

enum SortOrder {
    case ascending
    case descending
}

enum DeckSortOption {
    case alphabetical
    case cardCount
}



// MARK: - Adaptive Lottie Animation Component
struct AdaptiveLottieView: UIViewRepresentable {
    // MARK: - Properties
    let animationName: String
    let isAnimated: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Initialization
    init(animationName: String, isAnimated: Bool = true) {
        self.animationName = animationName
        self.isAnimated = isAnimated
    }
    
    // MARK: - UIViewRepresentable
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        let animationView = LottieAnimationView(name: animationName)
        
        // Configuration de base
        animationView.loopMode = .playOnce
        animationView.contentMode = .scaleAspectFit
        
        // Adapter les couleurs selon le thème
        updateColors(animationView: animationView)
        
        // Layout setup
        setupLayout(containerView: containerView, animationView: animationView)
        
        // Gestion de l'animation
        if isAnimated {
            animationView.play()
        } else {
            // Afficher la première frame sans animation
            animationView.currentFrame = 0
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let animationView = uiView.subviews.first as? LottieAnimationView else {
            return
        }
        
        // Mettre à jour les couleurs si le thème a changé
        updateColors(animationView: animationView)
    }
    
    // MARK: - Private Methods
    private func setupLayout(containerView: UIView, animationView: LottieAnimationView) {
        animationView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            animationView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
        ])
    }
    
    private func updateColors(animationView: LottieAnimationView) {
        // Exception : laisser les couleurs originales pour confetti ET palette
        guard animationName != "confetti" && animationName != "palette" else { return }
        
        // Votre logique existante pour les autres animations
        let primaryColor = colorScheme == .dark ?
            LottieColor(r: 0.6, g: 0.6, b: 0.6, a: 1) :    // Gris en mode sombre
            LottieColor(r: 0, g: 0, b: 0, a: 1)           // Noir en mode clair
        
        let colorProvider = ColorValueProvider(primaryColor)
        
        let strokeKeyPaths = [
            "**.primary.Color",
            "**.Stroke *.Color",
            "**.Group *.**.Stroke *.Color"
        ]
        
        strokeKeyPaths.forEach { keyPath in
            let animationKeypath = AnimationKeypath(keypath: keyPath)
            animationView.setValueProvider(colorProvider, keypath: animationKeypath)
        }
    }
}

extension ShareableDeck: Identifiable {
    public var id: String {
        return metadata.id
    }
}

@MainActor
struct ContentView: View {
    @FetchRequest(
        entity: FlashcardDeck.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FlashcardDeck.name, ascending: true)]
    ) private var allDecks: FetchedResults<FlashcardDeck>
    
    @FetchRequest(sortDescriptors: [SortDescriptor(\Period.startDate)])
    private var periods: FetchedResults<Period>
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - AppStorage Variables
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("username") private var username: String = ""
    @AppStorage("profileSubtitle") private var profileSubtitle: String = ""
    @AppStorage("profileGradientStartHex") private var profileGradientStartHex: String = "90A4AE"
    @AppStorage("profileGradientEndHex") private var profileGradientEndHex: String = "253137"
    @AppStorage("darkModeEnabled") private var darkModeEnabled: Bool = false
    @AppStorage("selectedPeriod") private var onboardingPeriod: String = ""
    @AppStorage("onboardingPeriodProcessed") private var onboardingPeriodProcessed: Bool = false
    @AppStorage("activePeriodID") var activePeriodIDString: String = "" {
        didSet {
            print("🔄 [PERIOD_PERSISTENCE] activePeriodIDString changé: '\(oldValue)' → '\(activePeriodIDString)'")
            
            // S'assurer que le cache ne va pas interférer
            if !activePeriodIDString.isEmpty {
                // Nettoyer tout cache qui pourrait interférer
                GradefyCacheManager.shared.invalidateObject(key: "active_period")
                GradefyCacheManager.shared.invalidateObject(key: "selected_period")
                print("🧹 [PERIOD_PERSISTENCE] Cache period invalidé pour éviter conflits")
            }
        }
    }

    @State private var selectedPeriod: Period? {
        didSet {
            print("🎯 [PERIOD_PERSISTENCE] selectedPeriod changé: \(oldValue?.name ?? "nil") → \(selectedPeriod?.name ?? "nil")")
            
            if let period = selectedPeriod {
                let periodID = period.id?.uuidString ?? ""
                print("💾 [PERIOD_PERSISTENCE] Sauvegarde période: \(period.name ?? "") - \(periodID)")
                
                // SAUVEGARDE MULTIPLE pour éviter les conflits
                // 1. @AppStorage (principal)
                activePeriodIDString = periodID
                
                // 2. UserDefaults direct (backup)
                UserDefaults.standard.set(periodID, forKey: "activePeriodID_backup")
                
                // 3. Dans votre cache système (integration avec votre architecture)
                GradefyCacheManager.shared.cacheObject(periodID as NSString, forKey: "active_period_id")
                
                // 4. Synchronisation forcée
                UserDefaults.standard.synchronize()
                
                print("✅ [PERIOD_PERSISTENCE] Triple sauvegarde terminée")
            }
        }
    }

    @State private var selectedDetent: PresentationDetent = .fraction(0.60)
    @Environment(\.scenePhase) private var scenePhase
    @State private var showImportLimitPopover = false
    @State private var showFlashcardGlobalFreePopover = false
    @State private var showFlashcardGlobalPremiumPopover = false
    @State private var showFlashcardLimitPopover = false
    @State private var showPremiumFlashcardLimitPopover = false
    @State private var deckSortOption: DeckSortOption = .alphabetical
    @State private var deckSortOrder: SortOrder = .ascending
    @State private var showDeleteAlert = false
    @State private var deckToDelete: FlashcardDeck?
    @State private var showFileImporter = false
    @State private var showImportDeckView = false
    @State private var pendingImportDeck: ShareableDeck?
    @State private var shouldShowOnboarding = false
    @State private var refreshID = UUID()
    @State private var isViewActive = true
    @State private var showSplash = true
    @State private var selectedSubjectForNavigation: Subject?
    @State private var subjectToEdit: Subject?
    @State private var showingAddPeriodSheet = false
    @State private var showingAddSubjectSheet = false
    @State private var showNoPeriodAlert = false
    @State private var showDuplicateSubjectAlert = false
    @State private var duplicateSubjectName = ""
    @State private var showAddFlashcardSheet = false
    @State private var navigationPath = NavigationPath()
    @State private var selectedDeckToEdit: FlashcardDeck?
    @State private var deckName: String = ""
    @State private var showPremiumView = false
    @State private var sortOption: SortOption = .alphabetical
    @State private var sortOrder: SortOrder = .descending
    @State private var lastWidgetSync: Date = Date.distantPast
    @State private var showingEditProfile = false
    @State private var tempUsername: String = ""
    @State private var tempSubtitle: String = ""
    @State private var selectedGradient: [Color] = [Color(hex: "9BE8F6"), Color(hex: "5DD5F4")]
    @State private var showDeleteSubjectAlert = false
    @State private var subjectToDelete: Subject?

    private let availableGradients: [[Color]] = [
        [Color(hex: "9BE8F6"), Color(hex: "5DD5F4")],
        [Color(hex: "B0F4B6"), Color(hex: "78E089")],
        [Color(hex: "FBB3C7"), Color(hex: "F68EB2")],
        [Color(hex: "DBC7F9"), Color(hex: "C6A8EF")],
        [Color(hex: "F8C79B"), Color(hex: "F5A26A")]
    ]
    @State private var premiumManager = PremiumManager.shared
    @State private var showDeckLimitPopover = false
    @State private var navigationUpdateTimer: Timer?
    @State private var cachedRelevantDecks: [FlashcardDeck] = []
    @State private var lastDecksUpdate = Date.distantPast
    @State private var isRestoringPeriod = false

    // ✅ NOUVELLES VARIABLES pour TabBar Custom avec Animations
    @State private var selectedTab = 0
    @State private var symbolAnimations: [Bool] = [false, false, false]
    @State private var lastTapTime = Date.distantPast
    
    private var activePeriod: Period? {
        if let selected = selectedPeriod {
            return selected
        }
        
        if !activePeriodIDString.isEmpty,
           let uuid = UUID(uuidString: activePeriodIDString),
           let foundPeriod = periods.first(where: { $0.id == uuid }) {
            return foundPeriod
        }
        
        // NOUVEAU : Seulement si on n'est pas en train de restaurer
        if !isRestoringPeriod {
            return periods.first
        }
        
        return nil
    }

    // Déplacer la logique de mise à jour dans une fonction séparée
    private func updateActivePeriod() {
        if selectedPeriod == nil {
            if !activePeriodIDString.isEmpty,
               let uuid = UUID(uuidString: activePeriodIDString),
               let foundPeriod = periods.first(where: { $0.id == uuid }) {
                selectedPeriod = foundPeriod
            } else if let firstPeriod = periods.first {
                selectedPeriod = firstPeriod
                activePeriodIDString = firstPeriod.id?.uuidString ?? ""
            }
        }
    }
    
    private func restoreActivePeriodWithCache() {
        print("🔄 [PERIOD_PERSISTENCE] === RESTAURATION INTELLIGENTE DÉBUT ===")
        
        // ATTENDRE que PersistenceController soit prêt
        guard PersistenceController.shared.isReady else {
            print("⏳ [PERIOD_PERSISTENCE] PersistenceController pas prêt, retry dans 0.5s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.restoreActivePeriodWithCache()
            }
            return
        }
        
        print("✅ [PERIOD_PERSISTENCE] PersistenceController prêt, début restauration")
        print("📊 [PERIOD_PERSISTENCE] Périodes disponibles: \(periods.count)")
        
        // Ne pas restaurer si une période est déjà sélectionnée
        if selectedPeriod != nil {
            print("✅ [PERIOD_PERSISTENCE] Période déjà sélectionnée: \(selectedPeriod?.name ?? "")")
            return
        }
        
        // Méthode 1: @AppStorage
        if !activePeriodIDString.isEmpty,
           let uuid = UUID(uuidString: activePeriodIDString),
           let foundPeriod = periods.first(where: { $0.id == uuid }) {
            print("✅ [PERIOD_PERSISTENCE] SUCCÈS @AppStorage: \(foundPeriod.name ?? "")")
            selectedPeriod = foundPeriod
            return
        }
        
        // Méthode 2: UserDefaults backup
        if let backupID = UserDefaults.standard.string(forKey: "activePeriodID_backup"),
           !backupID.isEmpty,
           let uuid = UUID(uuidString: backupID),
           let foundPeriod = periods.first(where: { $0.id == uuid }) {
            print("✅ [PERIOD_PERSISTENCE] SUCCÈS Backup: \(foundPeriod.name ?? "")")
            activePeriodIDString = backupID // Resynchroniser @AppStorage
            selectedPeriod = foundPeriod
            return
        }
        
        // Méthode 3: Votre cache système
        if let cachedID = GradefyCacheManager.shared.getCachedObject(forKey: "active_period_id") as? String,
           !cachedID.isEmpty,
           let uuid = UUID(uuidString: cachedID),
           let foundPeriod = periods.first(where: { $0.id == uuid }) {
            print("✅ [PERIOD_PERSISTENCE] SUCCÈS Cache: \(foundPeriod.name ?? "")")
            activePeriodIDString = cachedID // Resynchroniser @AppStorage
            selectedPeriod = foundPeriod
            return
        }
        
        // Fallback: première période
        if let firstPeriod = periods.first {
            print("⚠️ [PERIOD_PERSISTENCE] FALLBACK première période: \(firstPeriod.name ?? "")")
            selectedPeriod = firstPeriod
        }
        
        print("✅ [PERIOD_PERSISTENCE] === RESTAURATION INTELLIGENTE TERMINÉE ===")
    }
    
    // MARK: - Subject Delete Functions
    private func requestDeleteSubject(_ subject: Subject) {
        subjectToDelete = subject
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showDeleteSubjectAlert = true
        }
    }

    private func confirmDeleteSubject(_ subject: Subject) {
        showDeleteSubjectAlert = false
        subjectToDelete = nil
        
        Task {
            do {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        viewContext.delete(subject)
                    }
                }
                
                try await Task.sleep(nanoseconds: 200_000_000)
                try viewContext.save()
                
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .success)
                }
                
            } catch {
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .error)
                }
            }
        }
    }

    
    private func requestDeleteDeck(_ deck: FlashcardDeck) {
        deckToDelete = deck
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showDeleteAlert = true
        }
    }


    private func confirmDeleteDeck(_ deck: FlashcardDeck) {
        showDeleteAlert = false
        deckToDelete = nil
        
        Task {
            do {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        viewContext.delete(deck)
                    }
                }
                
                try await Task.sleep(nanoseconds: 200_000_000)
                try viewContext.save()
                
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .success)
                }
                
            } catch {
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .error)
                }
            }
        }
    }


    
    private var simpleDeckButton: some View {
        Button {
            let canCreate = premiumManager.canCreateDeck(currentDeckCount: allDecks.count)
            if canCreate {
                showAddFlashcardSheet = true
            } else {
                showDeckLimitPopover = true
            }
        } label: {
            Image(systemName: "plus")
                .foregroundStyle(.blue)
        }
    }

    private var decksList: some View {
        List {
            ForEach(sortedDecks, id: \.objectID) { deck in
                NavigationLink(value: deck) {
                    HStack(spacing: 15) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(deck.name ?? "Nom inconnu")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        if let count = (deck.flashcards as? Set<Flashcard>)?.count {
                            HStack(spacing: 4) {
                                Text("\(count)")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.primary)
                            }
                            .padding(.trailing, 2)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        selectedDeckToEdit = deck
                    } label: {
                        Label(String(localized: "action_modify"), systemImage: "pencil")
                    }
                    .tint(.blue)
                    
                    Button(role: .none) {
                        print("🟠 [DEBUG] TAP sur bouton trash pour : \(deck.name ?? "sans nom")")
                        print("🟠 [DEBUG] withAnimation(.none) appliqué")
                        withAnimation(.none) {
                            requestDeleteDeck(deck)
                        }
                        print("🟠 [DEBUG] Après withAnimation(.none)")
                    } label: {
                        Label(String(localized: "action_delete"), systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .tint(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(adaptiveBackground)
        .scrollIndicators(.hidden)
        .scrollDisabled(false)
    }
    
    private var deckSortMenuContent: some View {
        Group {
            Section(String(localized: "sort_section_by")) {
                Button {
                    deckSortOption = .alphabetical
                    HapticFeedbackManager.shared.selection()
                } label: {
                    HStack {
                        Text(String(localized: "sort_by_name"))
                        Spacer()
                        if deckSortOption == .alphabetical {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Button {
                    deckSortOption = .cardCount
                    HapticFeedbackManager.shared.selection()
                } label: {
                    HStack {
                        Text(String(localized: "sort_by_size"))
                        Spacer()
                        if deckSortOption == .cardCount {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Section(String(localized: "sort_section_order")) {
                Button {
                    deckSortOrder = .ascending
                    HapticFeedbackManager.shared.selection()
                } label: {
                    HStack {
                        Text(String(localized: "sort_ascending"))
                        Spacer()
                        if deckSortOrder == .ascending {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Button {
                    deckSortOrder = .descending
                    HapticFeedbackManager.shared.selection()
                } label: {
                    HStack {
                        Text(String(localized: "sort_descending"))
                        Spacer()
                        if deckSortOrder == .descending {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }

    
    private var sortedDecks: [FlashcardDeck] {
        switch (deckSortOption, deckSortOrder) {
        case (.alphabetical, .ascending):
            return allDecks.sorted { ($0.name ?? "") < ($1.name ?? "") }
            
        case (.alphabetical, .descending):
            return allDecks.sorted { ($0.name ?? "") > ($1.name ?? "") }
            
        case (.cardCount, .ascending):
            return allDecks.sorted { deck1, deck2 in
                let count1 = (deck1.flashcards as? Set<Flashcard>)?.count ?? 0
                let count2 = (deck2.flashcards as? Set<Flashcard>)?.count ?? 0
                return count1 < count2
            }
            
        case (.cardCount, .descending):
            return allDecks.sorted { deck1, deck2 in
                let count1 = (deck1.flashcards as? Set<Flashcard>)?.count ?? 0
                let count2 = (deck2.flashcards as? Set<Flashcard>)?.count ?? 0
                return count1 > count2
            }
        }
    }
    
    private var addDeckSheet: some View {
        AddDeckSheet(
            deckName: $deckName,
            onSave: handleDeckSaveSimplified
        )
        .presentationDetents([.height(150)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(16)
    }

    private func editDeckSheet(_ deck: FlashcardDeck) -> some View {
        EditDeckView(deck: deck)
            .presentationDetents([.height(150)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(16)
    }

    
    private var revisionTabContentSimplified: some View {
        NavigationStack {
            revisionMainContent
        }
        .sheet(isPresented: $showAddFlashcardSheet) {
            addDeckSheet
        }
        .sheet(item: $selectedDeckToEdit) { deck in
            editDeckSheet(deck)
        }
        .confirmationDialog(
            String(localized: "delete_list_title"),
            isPresented: $showDeleteAlert,
            titleVisibility: .visible
        ) {
            Button(String(localized: "delete_permanently"), role: .destructive) {
                print("🟡 [DEBUG] Confirmation SUPPRIMER tapée")
                if let deck = deckToDelete {
                    print("🟡 [DEBUG] Deck à supprimer : \(deck.name ?? "sans nom")")
                    confirmDeleteDeck(deck)
                } else {
                    print("🔴 [DEBUG] ERREUR : deckToDelete est nil !")
                }
            }

            Button(String(localized: "action_cancel"), role: .cancel) {
                print("🟡 [DEBUG] Confirmation ANNULER tapée")
                deckToDelete = nil
                print("🟡 [DEBUG] deckToDelete remis à nil")
            }
        } message: {
            Text(
                String(localized: "delete_list_message")
                    .replacingOccurrences(of: "%@", with: deckToDelete?.name ?? String(localized: "this_deck"))
            )
        }
        .sheet(item: $pendingImportDeck) { shareableDeck in
            ImportDeckView(
                shareableDeck: shareableDeck,
                onImport: { deck, importAll in
                    importDeck(deck, importAll: importAll)
                },
                onCancel: {
                    pendingImportDeck = nil
                }
            )
            .presentationDetents([.fraction(0.60)], selection: $selectedDetent)
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(25)
            .presentationCompactAdaptation(.sheet)
            .presentationBackground(.regularMaterial)
            .onAppear {
                selectedDetent = .fraction(0.60)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && pendingImportDeck != nil {
                selectedDetent = .fraction(0.60)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.init(filenameExtension: "gradefy") ?? .data, .json],
            onCompletion: handleFileImport
        )
        .onAppear {
            showDeckLimitPopover = false
            showImportLimitPopover = false
            showFlashcardGlobalFreePopover = false
            showFlashcardGlobalPremiumPopover = false
        }
        .onDisappear {
            showDeckLimitPopover = false
            showImportLimitPopover = false
            showFlashcardGlobalFreePopover = false
            showFlashcardGlobalPremiumPopover = false
        }
    }
    
    private var revisionMainContent: some View {
        Group {
            if sortedDecks.isEmpty {
                revisionEmptyState
            } else {
                revisionDeckList
            }
        }
        .navigationTitle(String(localized: "tab_revision"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(for: FlashcardDeck.self) { deck in
            DeckDetailView(deck: deck)
                .onAppear {
                    showDeckLimitPopover = false
                    showImportLimitPopover = false
                    showFlashcardGlobalFreePopover = false
                    showFlashcardGlobalPremiumPopover = false
                    print("🔧 [FIX] État popover nettoyé à la navigation")
                }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    deckSortMenuContent
                } label: {
                    Text(String(localized: "action_sort"))
                        .foregroundStyle(.blue)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    handleImportButtonTap()
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(hasReachedImportLimit ? .gray : .blue)
                }
                .popover(isPresented: $showImportLimitPopover, arrowEdge: .bottom) {
                    importLimitPopoverContent
                        .presentationCompactAdaptation(.popover)
                }
                .popover(isPresented: $showFlashcardGlobalFreePopover, arrowEdge: .bottom) {
                    flashcardGlobalFreePopoverContent
                        .presentationCompactAdaptation(.popover)
                }
                .popover(isPresented: $showFlashcardGlobalPremiumPopover, arrowEdge: .bottom) {
                    flashcardGlobalPremiumPopoverContent
                        .presentationCompactAdaptation(.popover)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    let canCreate = premiumManager.canCreateDeck(currentDeckCount: allDecks.count)
                    print("🔍 [DEBUG] Bouton plus tappé - canCreate: \(canCreate), allDecks.count: \(allDecks.count)")
                    if canCreate {
                        print("🔍 [DEBUG] Ouverture de la sheet addDeckSheet")
                        showAddFlashcardSheet = true
                    } else {
                        print("🔍 [DEBUG] Affichage de la popover limite")
                        print("🔍 [DEBUG] showDeckLimitPopover avant: \(showDeckLimitPopover)")
                        showDeckLimitPopover = true
                        print("🔍 [DEBUG] showDeckLimitPopover après: \(showDeckLimitPopover)")
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(hasReachedDeckLimit ? .gray : .blue)
                }
                .popover(isPresented: $showDeckLimitPopover, arrowEdge: .bottom) {
                    deckLimitPopoverContent
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
    }
    
    private var revisionDeckList: some View {
        List {
            Section {
                GlobalLimitsDashboardView()
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            
            Section {
                HStack {
                    Menu { deckSortMenuContent } label: {
                        Text(String(localized: "action_sort"))
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .listSectionSpacing(0)
            
            Section {
                ForEach(sortedDecks, id: \.objectID) { deck in
                    revisionDeckRow(deck: deck)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(adaptiveBackground)
        .scrollIndicators(.hidden)
        .contentMargins(.top, 25)
        .contentMargins(.bottom, 80)
        .scrollDisabled(false)
    }
    
    private func revisionDeckRow(deck: FlashcardDeck) -> some View {
        NavigationLink(value: deck) {
            HStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(deck.name ?? "Nom inconnu")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                Spacer()
                if let count = (deck.flashcards as? Set<Flashcard>)?.count {
                    HStack(spacing: 4) {
                        Text("\(count)")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.trailing, 2)
                }
            }
            .padding(.vertical, 8)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                selectedDeckToEdit = deck
            } label: {
                Label(String(localized: "action_modify"), systemImage: "pencil")
            }
            .tint(.blue)
            
            Button(role: .none) {
                print("🟠 [DEBUG] TAP sur bouton trash pour : \(deck.name ?? "sans nom")")
                print("🟠 [DEBUG] withAnimation(.none) appliqué")
                withAnimation(.none) {
                    requestDeleteDeck(deck)
                }
                print("🟠 [DEBUG] Après withAnimation(.none)")
            } label: {
                Label(String(localized: "action_delete"), systemImage: "trash")
                    .foregroundColor(.red)
            }
            .tint(.red)
        }
    }
    
    private var hasReachedDeckLimit: Bool {
        !premiumManager.canCreateDeck(currentDeckCount: allDecks.count)
    }
    
    private var hasReachedImportLimit: Bool {
        hasReachedDeckLimit || allFlashcards.count >= (premiumManager.isPremium ? 2000 : 300)
    }
    
    private var allFlashcards: [Flashcard] {
        allDecks.flatMap { deck in
            (deck.flashcards as? Set<Flashcard>) ?? []
        }
    }
    
    private func handleImportButtonTap() {
        let canCreateDeck = premiumManager.canCreateDeck(currentDeckCount: allDecks.count)
        let currentFlashcardCount = allFlashcards.count
        let maxGlobalFlashcards = premiumManager.isPremium ? 2000 : 300
        let hasReachedGlobalLimit = currentFlashcardCount >= maxGlobalFlashcards
        
        if !canCreateDeck {
            showImportLimitPopover = true
        } else if hasReachedGlobalLimit {
            if premiumManager.isPremium {
                showFlashcardGlobalPremiumPopover = true
            } else {
                showFlashcardGlobalFreePopover = true
            }
        } else {
            showFileImporter = true
        }
    }
    
    private func importDeck(_ shareableDeck: ShareableDeck, importAll: Bool) {
        Task {
            do {
                let _ = try await DeckSharingManager.shared.importDeckDirect(
                    shareableDeck: shareableDeck,
                    context: viewContext,
                    limitToFreeQuota: !importAll
                )
                
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .success)
                    pendingImportDeck = nil
                    print("✅ Deck importé avec succès depuis la sheet de prévisualisation")
                }
                
            } catch {
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .error)
                    pendingImportDeck = nil
                    print("❌ Erreur import deck : \(error)")
                }
            }
        }
    }

    private var deckLimitPopoverContent: some View {
        (Text(String(localized: "premium_add_unlimited")) +
         Text(" Gradefy Pro").foregroundColor(.blue) +
         Text("."))
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .frame(maxWidth: 300)
            .onTapGesture {
                showPremiumView = true
                showDeckLimitPopover = false
            }
    }


    
    private var currentPeriodId: String {
        let periodName = activePeriod?.name ?? "all"
        let periodUUID = activePeriod?.id?.uuidString ?? "all"
        return "\(periodName)-\(periodUUID)-\(refreshID.uuidString)"
    }
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("📥 Fichier sélectionné : \(url.lastPathComponent)")
            
            // Vérifier l'accès sécurisé au fichier
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Impossible d'accéder au fichier sélectionné")
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            do {
                // Parser le fichier avec DeckSharingManager
                let shareableDeck = try DeckSharingManager.shared.parseSharedFile(url: url)
                
                // ✅ NOUVEAU : Stocker le deck et afficher la sheet de prévisualisation
                DispatchQueue.main.async {
                    self.pendingImportDeck = shareableDeck
                }
                
            } catch {
                print("❌ Erreur parsing fichier : \(error)")
                HapticFeedbackManager.shared.notification(type: .error)
            }
            
        case .failure(let error):
            print("❌ Erreur sélection fichier : \(error)")
            HapticFeedbackManager.shared.notification(type: .error)
        }
    }


    
    private var allSubjects: [Subject] {
        periods.flatMap { ($0.subjects as? Set<Subject>) ?? [] }
    }

    private func handleWidgetURL(_ url: URL) {
        switch url.absoluteString {
        case "parallax://revision":
            selectedTab = 1 // revision est maintenant à l'index 1
        case "parallax://dashboard":
            selectedTab = 0 // rediriger vers subjects au lieu de home
        default:
            break
        }
    }
    private var allEvaluations: [Evaluation] {
        allSubjects.flatMap { ($0.evaluations as? Set<Evaluation>) ?? [] }
    }
    
    private var displayedSubjects: [Subject] {
        let allSubjectsArray = Array(allSubjects)
        
        // ✅ FILTRAGE par période seulement
        let filteredByPeriod = allSubjectsArray.filter { subject in
            guard let period = activePeriod else { return true }
            if period.name == "Année" { return true }
            return subject.period == period
        }
        
        // ✅ APPLIQUER le tri avec sortOrder
        switch (sortOption, sortOrder) {
        case (.alphabetical, .ascending):
            return filteredByPeriod.sorted { ($0.name ?? "") < ($1.name ?? "") }
            
        case (.alphabetical, .descending):
            return filteredByPeriod.sorted { ($0.name ?? "") > ($1.name ?? "") }
            
        case (.grade, .ascending):
            return filteredByPeriod.sorted { subject1, subject2 in
                if subject1.grade == NO_GRADE && subject2.grade == NO_GRADE {
                    return false
                }
                if subject1.grade == NO_GRADE {
                    return false
                }
                if subject2.grade == NO_GRADE {
                    return true
                }
                return subject1.grade < subject2.grade
            }
            
        case (.grade, .descending):
            return filteredByPeriod.sorted { subject1, subject2 in
                if subject1.grade == NO_GRADE && subject2.grade == NO_GRADE {
                    return false
                }
                if subject1.grade == NO_GRADE {
                    return false
                }
                if subject2.grade == NO_GRADE {
                    return true
                }
                return subject1.grade > subject2.grade
            }
        }
    }
    
    private var filteredEvaluations: [Evaluation] {
        allEvaluations.filter { eval in
            guard let subj = eval.subject else { return false }
            guard let period = activePeriod else { return true }
            if period.name == "Année" { return true }
            return subj.period == period
        }
    }
    
    private var nextEvaluation: Evaluation? {
        let now = Date()
        let futureEvals = filteredEvaluations.filter { eval in
            guard let evaluationDate = eval.date else { return false }
            return evaluationDate > now
        }
        
        return futureEvals.min { first, second in
            guard let date1 = first.date, let date2 = second.date else { return false }
            return date1 < date2
        }
    }
    
    private var timeUntilNextEvaluation: String {
        guard let evaluation = nextEvaluation,
              let date = evaluation.date else { return "" }
        
        let now = Date()
        guard date > now else { return "" }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        
        return formatter.string(from: now, to: date) ?? ""
    }
    
    private var hasNextEvaluation: Bool {
        nextEvaluation != nil
    }
    
    private var relevantDecks: [FlashcardDeck] {
        let now = Date()
        if now.timeIntervalSince(lastDecksUpdate) > 2.0 {
            updateRelevantDecks()
        }
        return cachedRelevantDecks
    }
    
    private var relevantCardsToReview: Int {
        return relevantDecks.reduce(0) { count, deck in
            let cards = (deck.flashcards as? Set<Flashcard>) ?? []
            return count + cards.filter { card in
                guard let lastReview = card.lastReviewDate else { return true }
                let daysSinceReview = Calendar.current.dateComponents([.day], from: lastReview, to: Date()).day ?? 0
                return daysSinceReview >= 3
            }.count
        }
    }
    
    private var weeklyEvaluationAdditions: Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return filteredEvaluations.filter { eval in
            (eval.date ?? Date.distantPast) >= oneWeekAgo
        }.count
    }
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    // MARK: - Body
    
    var body: some View {
        buildMainView()
    }

    private func buildMainView() -> some View {
        let mainContentView = MainContentView(
            hasCompletedOnboarding: $hasCompletedOnboarding,
            showSplash: $showSplash,
            showingEditProfile: $showingEditProfile,
            tempUsername: $tempUsername,
            tempSubtitle: $tempSubtitle,
            selectedGradient: $selectedGradient,
            availableGradients: availableGradients,
            onCancel: handleEditProfileCancel,
            onApply: handleEditProfileApply,
            mainTabView: AnyView(customTabBarView)
        )
        
        return mainContentView
            .onReceive(NotificationCenter.default.publisher(for: .activePeriodChanged)) { notification in
                handleActivePeriodChanged(notification)
            }
            .onAppear {
                handleViewAppear()
            }
            .onOpenURL { url in
                handleWidgetURL(url)
            }
            .onDisappear {
                isViewActive = false
                cleanupTimers()
            }
            .onChange(of: showDeckLimitPopover) { oldValue, newValue in
                // ✅ GARDE : Protection contre l'affichage dans d'autres onglets
                if newValue && selectedTab != 1 {  // Revision tab = 1, pas 2
                    showDeckLimitPopover = false
                }
            }
            .onChange(of: showImportLimitPopover) { oldValue, newValue in
                // ✅ GARDE : Protection contre l'affichage dans d'autres onglets
                if newValue && selectedTab != 1 {  // Revision tab = 1, pas 2
                    showImportLimitPopover = false
                }
            }
            .onChange(of: showFlashcardGlobalFreePopover) { oldValue, newValue in
                // ✅ GARDE : Protection contre l'affichage dans d'autres onglets
                if newValue && selectedTab != 1 {  // Revision tab = 1, pas 2
                    showFlashcardGlobalFreePopover = false
                }
            }
            .onChange(of: showFlashcardGlobalPremiumPopover) { oldValue, newValue in
                // ✅ GARDE : Protection contre l'affichage dans d'autres onglets
                if newValue && selectedTab != 1 {  // Revision tab = 1, pas 2
                    showFlashcardGlobalPremiumPopover = false
                }
            }
            .onChange(of: hasCompletedOnboarding) { _, newValue in
                guard isViewActive else { return }
                handleOnboardingChange(newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { notification in
                guard isViewActive else { return }
                handleContextSave(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .systemChanged)) { _ in
                guard isViewActive else { return }
                handleSystemChange()
            }
            .onDisappear {
                NotificationCenter.default.post(name: .forceClosePopovers, object: nil)
            }
            .onChange(of: selectedTab) { _, newTab in
                guard isViewActive else { return }
                handleTabChange(newTab)
                
                // ✅ Déplacer l'arrêt audio en dehors de l'animation pour éviter le scintillement
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    AudioManager.shared.stopAudio()
                }
            }
            .onChange(of: selectedPeriod) { oldValue, newValue in
                handleSelectedPeriodChange(oldValue: oldValue, newValue: newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetToOnboarding)) { _ in
                shouldShowOnboarding = true
                hasCompletedOnboarding = false
            }
            .onChange(of: sortOption) { _, _ in
                guard isViewActive else { return }
                debouncedNavigationUpdate()
            }
            .alert("alert_error", isPresented: $showDuplicateSubjectAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(String(localized: "error_subject_duplicate").replacingOccurrences(of: "%@", with: duplicateSubjectName))
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveActivePeriod)) { _ in
                if let currentPeriod = selectedPeriod {
                    let periodID = currentPeriod.id?.uuidString ?? ""
                    UserDefaults.standard.set(periodID, forKey: "activePeriodID_backup")
                    UserDefaults.standard.synchronize()
                    print("💾 [PERIOD_PERSISTENCE] Période sauvegardée à la fermeture: \(currentPeriod.name ?? "")")
                }
            }
            .onReceive(PersistenceController.shared.$isReady) { isReady in
                print("🔔 [PERIOD_PERSISTENCE] PersistenceController.isReady: \(isReady)")
                
                if isReady && selectedPeriod == nil {
                    print("🚀 [PERIOD_PERSISTENCE] PersistenceController prêt - tentative restauration immédiate")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.restoreActivePeriodWithCache()
                    }
                }
            }

    }

    
    // MARK: - ✅ NOUVELLE TabBar Custom avec Animations
    
    private var customTabBarView: some View {
        ZStack {
            // ✅ Contenu principal qui occupe tout l'écran
            Group {
                switch selectedTab {
                case 0:
                    LazyView(subjectsTabContent)
                case 1:
                    LazyView(revisionTabContentSimplified)
                case 2:
                    LazyView(profileTabContent)
                default:
                    LazyView(subjectsTabContent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 83)
            }
            
            VStack {
                Spacer()
                nativeStyleTabBar
                    .background(colorScheme == .dark ? Color(.systemGray6) : Color(.white))
                    .ignoresSafeArea(.all)
            }
            .ignoresSafeArea(.keyboard)
        }
        .sheet(isPresented: $showPremiumView) {
            PremiumView(highlightedFeature: .unlimitedDecks)
        }
    }

    private var nativeStyleTabBar: some View {
        HStack(spacing: 0) {
            ForEach([TabItem.subjects, TabItem.revision, TabItem.settings], id: \.self) { tab in
                NativeTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab.rawValue,
                    animate: symbolAnimations[tab.rawValue]
                ) {
                    selectTab(tab.rawValue)
                }
            }
        }
        .frame(height: 49)
        .clipped()
        .overlay(alignment: .top) {
            Rectangle()
                .frame(height: 0.33)
                .foregroundColor(Color(UIColor.separator))
        }
        .ignoresSafeArea(.keyboard, edges: .all) // ✅ CRUCIAL
        .ignoresSafeArea(.container, edges: .bottom) // ✅ CRUCIAL
        .tint(.blue)
    }

    
    private func selectTab(_ index: Int) {
        guard isViewActive else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastTapTime) > 0.03 else { return }
        lastTapTime = now
        
        if selectedTab == index { return }
        
        // ✅ Suppression de l'animation pour un changement instantané
        selectedTab = index
        
        symbolAnimations[index].toggle()
    }

    private var homeBackground: Color {
        colorScheme == .light ? Color(hex: "F2F2F6") : Color(.systemBackground)
    }
    
    private var importLimitPopoverContent: some View {
        (Text(String(localized: "premium_deck_limit_reached")) +
         Text(" Gradefy Pro").foregroundColor(.blue) +
         Text("."))
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .frame(maxWidth: 300)
            .onTapGesture {
                showPremiumView = true
                showImportLimitPopover = false
            }
    }
    
    private var flashcardGlobalFreePopoverContent: some View {
        (Text(String(localized: "premium_flashcard_limit_reached")) +
         Text(" Gradefy Pro").foregroundColor(.blue) +
         Text("."))
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .frame(maxWidth: 300)
            .onTapGesture {
                showPremiumView = true
                showFlashcardGlobalFreePopover = false
            }
    }
    
    private var flashcardGlobalPremiumPopoverContent: some View {
        Text(String(localized: "premium_flashcard_limit_premium"))
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .frame(maxWidth: 300)
    }
    
    private var subjectsTabContent: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if displayedSubjects.isEmpty {
                    subjectsEmptyState
                } else {
                    List {
                        // Section dashboard alignée comme les rows
                        Section {
                            MiniDashboardView(subjects: displayedSubjects)
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        
                        // Section bouton Sort
                        Section {
                            HStack {
                                Menu { sortMenuContent } label: {
                                    Text(String(localized: "action_sort"))
                                        .foregroundStyle(.blue)
                                }
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .listSectionSpacing(0)

                        // Section subjects
                        Section {
                            ForEach(displayedSubjects, id: \.objectID) { subject in
                                NavigationLink(value: subject) {
                                    SubjectRow(
                                        subject: subject,
                                        onEdit: { subjectToEdit = subject },
                                        onDelete: { requestDeleteSubject(subject) }
                                    )
                                }
                                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                                .listRowBackground(rowBackground)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(adaptiveBackground)
                    .scrollIndicators(.hidden)
                    .contentMargins(.top, 25)   // remonte légèrement le contenu
                    .contentMargins(.bottom, 80) // coussin bas pour voir la dernière carte entière
                    .scrollDisabled(false)
                }
            }
            .navigationTitle(String(localized: "tab_subjects"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu { periodSelectorMenu } label: {
                        HStack(spacing: 4) {
                            Text(selectedPeriod?.name ?? "Période")
                                .font(.subheadline.weight(.medium))
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.blue)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: handleAddSubjectTap) {
                        Image(systemName: "plus")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddSubjectSheet) {
                if let selectedPeriod = activePeriod {
                    AddSubjectView(selectedPeriod: selectedPeriod.name ?? "—", onAdd: addNewSubject)
                }
            }
            .sheet(item: $subjectToEdit) { subject in
                EditSubjectView(subject: subject)
            }
            .sheet(isPresented: $showingAddPeriodSheet) {
                AddPeriodSheet { name, startDate, endDate in
                    addNewPeriod(name: name, startDate: startDate, endDate: endDate)
                }
            }
            .confirmationDialog(
                String(localized: "delete_subject_title"),
                isPresented: $showDeleteSubjectAlert,
                titleVisibility: .visible
            ) {
                Button(String(localized: "delete_permanently"), role: .destructive) {
                    if let subject = subjectToDelete {
                        confirmDeleteSubject(subject)
                    }
                }
                Button(String(localized: "action_cancel"), role: .cancel) {
                    subjectToDelete = nil
                }
            } message: {
                Text(
                    String(localized: "delete_subject_message")
                        .replacingOccurrences(of: "%@", with: subjectToDelete?.name ?? String(localized: "this_subject"))
                )
            }
            .alert(String(localized: "no_period_title"), isPresented: $showNoPeriodAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(String(localized: "error_add_period_first"))
            }
            .navigationDestination(for: Subject.self) { subject in
                SubjectDetailView(subjectObject: subject, showingProfileSheet: .constant(false))
            }
            .onChange(of: selectedSubjectForNavigation) { _, newSubject in
                if let subject = newSubject {
                    navigationPath.append(subject)
                    selectedSubjectForNavigation = nil
                }
            }
        }
    }
    
    private var rowBackground: Color {
        colorScheme == .light ? Color.white : Color(.secondarySystemBackground)
    }
    
    private var revisionTabContent: some View {
        NavigationStack {
            Group {
                if allDecks.isEmpty {
                    revisionEmptyState
                } else {
                    List {
                        ForEach(allDecks, id: \.id) { deck in
                            NavigationLink(value: deck) {
                                HStack(spacing: 15) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(deck.name ?? "Nom inconnu")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }
                                    Spacer()
                                    if let count = (deck.flashcards as? Set<Flashcard>)?.count {
                                        HStack(spacing: 4) {
                                            Text("\(count)")
                                                .font(.title3.weight(.semibold))
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.trailing, 2)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    selectedDeckToEdit = deck
                                } label: {
                                    Label(String(localized: "action_modify"), systemImage: "pencil")
                                }
                                .tint(.blue)
                                
                                // ✅ SOLUTION : role: .none au lieu de .destructive
                                Button(role: .none) { // ← CHANGEMENT ICI
                                    print("🟠 [DEBUG] TAP sur bouton trash pour : \(deck.name ?? "sans nom")")
                                    print("🟠 [DEBUG] withAnimation(.none) appliqué")
                                    withAnimation(.none) {
                                        requestDeleteDeck(deck)
                                    }
                                    print("🟠 [DEBUG] Après withAnimation(.none)")
                                } label: {
                                    Label(String(localized: "action_delete"), systemImage: "trash")
                                        .foregroundColor(.red) // ✅ Couleur rouge manuelle
                                }
                                .tint(.red)
                            }

                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(adaptiveBackground)
                    .scrollIndicators(.hidden)
                    .scrollDisabled(false)
                }
            }
            .navigationTitle(String(localized: "tab_revision"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: FlashcardDeck.self) { deck in
                DeckDetailView(deck: deck)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddFlashcardSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddFlashcardSheet) {
            AddDeckSheet(
                deckName: $deckName,
                onSave: handleDeckSaveSimplified
            )
            .presentationDetents([.height(150)])  // ✅ Hauteur fixe adaptée au contenu
            .presentationDragIndicator(.hidden)   // ✅ Indicateur de glissement
            .presentationCornerRadius(16)          // ✅ Coins arrondis
        }
        .sheet(item: $selectedDeckToEdit) { deck in
            EditDeckView(deck: deck)
                .presentationDetents([.height(150)])  // ✅ Hauteur fixe adaptée au contenu
                .presentationDragIndicator(.hidden)   // ✅ Indicateur de glissement
                .presentationCornerRadius(16)         // ✅ Coins arrondis
        }
    }
    
    private var profileTabContent: some View {
            ProfileView()
    }
    
    // MARK: - Period Selector (inchangé)
    

    
    private var periodSelectorMenu: some View {
        Group {
            ForEach(periods, id: \.id) { period in
                Button {
                    selectedPeriod = period
                    activePeriodIDString = period.id?.uuidString ?? ""
                    debouncedNavigationUpdate()
                } label: {
                    if selectedPeriod?.id == period.id {
                        Label(period.name ?? "", systemImage: "checkmark")
                    } else {
                        Text(period.name ?? "")
                    }
                }
            }
            Divider()
            Button {
                showingAddPeriodSheet = true
            } label: {
                Label(String(localized: "add_period"), systemImage: "plus")
            }
        }
    }
    
    private var subjectsEmptyState: some View {
        VStack {
            Spacer()
            AdaptiveLottieView(animationName: "subjectblue")
                .frame(width: 110, height: 110)
            
            VStack(spacing: 8) {
                Text(String(localized: "empty_subjects_message"))
                    .font(.headline.weight(.medium))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 16)
            
            Spacer()
            
            Button(action: handleAddSubjectTap) {
                Text(String(localized: "action_add_subject"))
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
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    private var revisionEmptyState: some View {
        VStack {
            Spacer()
            
            // ✅ ANIMATION ADAPTIVE au mode sombre
            AdaptiveLottieView(animationName: "notesblue")
                .frame(width: 110, height: 110)
            
            // ✅ TEXTE parfaitement adaptatif
            VStack(spacing: 8) {
                Text(String(localized: "empty_list_title"))                    .font(.headline.weight(.medium))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 16)
            
            Spacer()
            
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .medium)
                showAddFlashcardSheet = true
            }) {
                Text(String(localized: "empty_list_button_add"))                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 45)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    // MARK: - Helper Functions (inchangé)
    
    private func toolbarButtonView(systemImage: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(UIColor.secondarySystemFill))
                .frame(width: 30, height: 30)
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
    }
    
    private var sortedSubjects: [Subject] {
        switch (sortOption, sortOrder) {
        case (.alphabetical, .ascending):
            return allSubjects.sorted { ($0.name ?? "") < ($1.name ?? "") }
            
        case (.alphabetical, .descending):
            return allSubjects.sorted { ($0.name ?? "") > ($1.name ?? "") }
            
        case (.grade, .ascending):
            return allSubjects.sorted { subject1, subject2 in
                // ✅ Gestion NO_GRADE comme dans l'exemple Python
                if subject1.grade == NO_GRADE && subject2.grade == NO_GRADE {
                    return false
                }
                if subject1.grade == NO_GRADE {
                    return false // NO_GRADE à la fin
                }
                if subject2.grade == NO_GRADE {
                    return true // NO_GRADE à la fin
                }
                return subject1.grade < subject2.grade
            }
            
        case (.grade, .descending):
            return allSubjects.sorted { subject1, subject2 in
                // ✅ Gestion NO_GRADE pour tri descendant
                if subject1.grade == NO_GRADE && subject2.grade == NO_GRADE {
                    return false
                }
                if subject1.grade == NO_GRADE {
                    return false // NO_GRADE à la fin
                }
                if subject2.grade == NO_GRADE {
                    return true // NO_GRADE à la fin
                }
                return subject1.grade > subject2.grade
            }
        }
    }
    
    
    private var sortMenuContent: some View {
        Group {
            // ✅ Section pour le critère de tri
            Section(String(localized: "sort_by")) {
                Button {
                    sortOption = .alphabetical
                    debouncedNavigationUpdate()
                } label: {
                    HStack {
                        Text(String(localized: "sort_by_name"))
                        Spacer()
                        if sortOption == .alphabetical {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Button {
                    sortOption = .grade
                    debouncedNavigationUpdate()
                } label: {
                    HStack {
                        Text("Par note")
                        Spacer()
                        if sortOption == .grade {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // ✅ Section pour l'ordre de tri
            Section(String(localized: "sort_section_order")) {
                Button {
                    sortOrder = .ascending
                    debouncedNavigationUpdate()
                } label: {
                    HStack {
                        Text("Ascendant")
                        Spacer()
                        if sortOrder == .ascending {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Button {
                    sortOrder = .descending
                    debouncedNavigationUpdate()
                } label: {
                    HStack {
                        Text("Descendant")
                        Spacer()
                        if sortOrder == .descending {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
    
    private func updateRelevantDecks() {
        let subjectNames = displayedSubjects.map { $0.name?.lowercased() ?? "" }
        
        let filteredDecks = allDecks.filter { deck in
            guard let deckName = deck.name?.lowercased() else { return false }
            return subjectNames.contains { subjectName in
                deckName.contains(subjectName) || subjectName.contains(deckName)
            }
        }
        
        Task { @MainActor in
            self.cachedRelevantDecks = filteredDecks
            self.lastDecksUpdate = Date()
        }
    }
    
    private func handleContentViewAppear() {
        ensureAtLeastOnePeriodExists()
        checkAndCreateOnboardingPeriod()
        
        // Initialisation locale uniquement
        Task {
            await initializeLocalConfiguration()
        }
        
        // ✅ Widget sync simplifié pour le nouveau système
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func initializeLocalConfiguration() async {
        print("🔄 Initialisation de la configuration locale...")
        
        let persistenceController = PersistenceController.shared
        let configManager = ConfigurationManager(context: persistenceController.container.viewContext)
        
        configManager.initializeUserDefaultsIfNeeded()
        print("✅ Configuration locale restaurée avec succès")
    }
    
    private func ensureAtLeastOnePeriodExists() {
        if selectedPeriod == nil || !periods.contains(where: { $0.id == selectedPeriod?.id }) {
            // PRIORITÉ : Restauration depuis activePeriodIDString
            if !activePeriodIDString.isEmpty,
               let uuid = UUID(uuidString: activePeriodIDString),
               let foundPeriod = periods.first(where: { $0.id == uuid }) {
                print("🔄 [ENSURE_PERIOD] Restauration: \(foundPeriod.name ?? "")")
                selectedPeriod = foundPeriod
                activePeriodIDString = foundPeriod.id?.uuidString ?? ""
            } else if let firstPeriod = periods.first {
                print("⚠️ [ENSURE_PERIOD] Fallback première période")
                selectedPeriod = firstPeriod
                activePeriodIDString = firstPeriod.id?.uuidString ?? ""
            }
        }
    }
    
    private func handleOnboardingChange(_ newValue: Bool) {
        if newValue == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkAndCreateOnboardingPeriod()
            }
        }
    }
    
    private func handleContextSave(_ notification: Notification) {
        guard isViewActive else { return }
        
        guard let userInfo = notification.userInfo else { return }
        
        let changedObjects = [
            NSInsertedObjectsKey,
            NSUpdatedObjectsKey,
            NSDeletedObjectsKey
        ].compactMap { key in
            userInfo[key] as? Set<NSManagedObject>
        }.flatMap { $0 }
        
        let hasRelevantChanges = changedObjects.contains { object in
            if object is Evaluation {
                return true
            }
            if let subject = object as? Subject {
                return subject.period == activePeriod
            }
            // ✅ NOUVEAU : Détecter les changements de flashcards et médias
            if object is Flashcard {
                return true
            }
            if object is FlashcardDeck {
                return true
            }
            return false
        }
        
        if hasRelevantChanges {
            DispatchQueue.main.async {
                self.refreshID = UUID()
                
                // ✅ SYNCHRONISATION WIDGET SIMPLIFIÉE
                WidgetCenter.shared.reloadAllTimelines()
                
                // ✅ NOUVEAU : Forcer la mise à jour des indicateurs de limite
                self.forceUpdateLimitIndicators()
            }
        }
    }
    
    // ✅ NOUVELLE FONCTION : Forcer la mise à jour des indicateurs
    private func forceUpdateLimitIndicators() {
        // Forcer la mise à jour des @State qui dépendent des limites
        DispatchQueue.main.async {
            // Rafraîchir les propriétés calculées
            let _ = self.hasReachedDeckLimit
            let _ = self.hasReachedImportLimit
            let _ = self.allFlashcards.count
            
            // Notifier les vues enfants si nécessaire
            NotificationCenter.default.post(name: .dataDidChange, object: nil)
        }
    }
    
    private func handleSystemChange() {
        guard isViewActive else { return }
        
        let periodToMaintain = activePeriod
        
        refreshID = UUID()
        selectedSubjectForNavigation = nil
        selectedTab = 0
        
        DispatchQueue.main.async {
            if let savedPeriod = periodToMaintain,
               self.periods.contains(where: { $0.id == savedPeriod.id }) {
                self.selectedPeriod = savedPeriod
            } else if !self.periods.isEmpty {
                self.selectedPeriod = self.periods.first
            } else {
                self.selectedPeriod = nil
            }
        }
    }
    
    private func handleEditProfileCancel() {
        showingEditProfile = false
    }
    
    private func handleEditProfileApply() {
        username = tempUsername
        profileSubtitle = tempSubtitle
        
        if selectedGradient.count >= 2 {
            profileGradientStartHex = selectedGradient[0].toHex()
            profileGradientEndHex = selectedGradient[1].toHex()
        }
        
        showingEditProfile = false
    }
    
    func handleTabChange(_ newTab: Int) {
        guard isViewActive else { return }
        selectedTab = newTab
    }
    
    private func cleanupTimers() {
        navigationUpdateTimer?.invalidate()
        navigationUpdateTimer = nil
    }
    
    private func debouncedNavigationUpdate() {
        guard isViewActive else { return }
        
        navigationUpdateTimer?.invalidate()
        navigationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            DispatchQueue.main.async {
                if self.isViewActive {
                    self.refreshID = UUID()
                }
            }
        }
    }
    
    private func checkAndCreateOnboardingPeriod() {
        let savedPeriod = UserDefaults.standard.string(forKey: "selectedPeriod") ?? ""
        let processed = UserDefaults.standard.bool(forKey: "onboardingPeriodProcessed")
        
        if hasCompletedOnboarding && !savedPeriod.isEmpty && !processed {
            createOnboardingPeriodIfNeeded()
        } else {
            if selectedPeriod == nil && !periods.isEmpty {
                // PRIORITÉ : Restauration depuis activePeriodIDString
                if !activePeriodIDString.isEmpty,
                   let uuid = UUID(uuidString: activePeriodIDString),
                   let foundPeriod = periods.first(where: { $0.id == uuid }) {
                    print("🔄 [ONBOARDING] Restauration: \(foundPeriod.name ?? "")")
                    selectedPeriod = foundPeriod
                } else {
                    print("⚠️ [ONBOARDING] Fallback première période")
                    selectedPeriod = periods.first
                }
            }
        }
    }
    
    private func createOnboardingPeriodIfNeeded() {
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let processed = UserDefaults.standard.bool(forKey: "onboardingPeriodProcessed")
        let savedPeriod = UserDefaults.standard.string(forKey: "selectedPeriod") ?? ""
        
        guard hasCompleted && !processed && !savedPeriod.isEmpty else {
            if selectedPeriod == nil && !periods.isEmpty {
                // PRIORITÉ : Restauration depuis activePeriodIDString
                if !activePeriodIDString.isEmpty,
                   let uuid = UUID(uuidString: activePeriodIDString),
                   let foundPeriod = periods.first(where: { $0.id == uuid }) {
                    print("🔄 [CREATE_ONBOARDING] Restauration: \(foundPeriod.name ?? "")")
                    selectedPeriod = foundPeriod
                } else {
                    print("⚠️ [CREATE_ONBOARDING] Fallback première période")
                    selectedPeriod = periods.first
                }
            }
            return
        }
        
        let request: NSFetchRequest<Period> = Period.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", savedPeriod)
        
        do {
            let foundPeriods = try viewContext.fetch(request)
            
            if let foundPeriod = foundPeriods.first {
                selectedPeriod = foundPeriod
                activePeriodIDString = foundPeriod.id?.uuidString ?? ""
            } else {
                if let firstPeriod = periods.first {
                    selectedPeriod = firstPeriod
                    activePeriodIDString = firstPeriod.id?.uuidString ?? ""
                }
            }
            
            UserDefaults.standard.set(true, forKey: "onboardingPeriodProcessed")
            UserDefaults.standard.removeObject(forKey: "selectedPeriod")
            UserDefaults.standard.synchronize()
            
        } catch {
            if let firstPeriod = periods.first {
                selectedPeriod = firstPeriod
                activePeriodIDString = firstPeriod.id?.uuidString ?? ""
            }
            
            UserDefaults.standard.set(true, forKey: "onboardingPeriodProcessed")
            UserDefaults.standard.removeObject(forKey: "selectedPeriod")
            UserDefaults.standard.synchronize()
        }
    }
    
    private var adaptiveBackground: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color(.systemGray6)
    }
    
    
    private func addNewPeriod(name: String, startDate: Date, endDate: Date) {
        viewContext.performAndWait {
            do {
                let newPeriod = Period(context: viewContext)
                newPeriod.id = UUID()
                newPeriod.name = name
                newPeriod.startDate = startDate
                newPeriod.endDate = endDate
                
                try viewContext.save()
                
                DispatchQueue.main.async {
                    selectedPeriod = newPeriod
                    activePeriodIDString = newPeriod.id?.uuidString ?? ""
                    debouncedNavigationUpdate()
                }
            } catch {
                viewContext.rollback()
            }
        }
    }
    
    private func handleDeckSaveSimplified(name: String) {
        viewContext.performAndWait {
            do {
                let newDeck = FlashcardDeck(context: viewContext)
                newDeck.id = UUID()
                newDeck.createdAt = Date()
                newDeck.name = name
                
                try viewContext.save()
            } catch {
                viewContext.rollback()
            }
        }
        showAddFlashcardSheet = false
        deckName = ""
    }
    
    private func deleteDeck(_ deck: FlashcardDeck) {
        viewContext.performAndWait {
            do {
                viewContext.delete(deck)
                try viewContext.save()
            } catch {
                viewContext.rollback()
            }
        }
    }
    
    private func handleAddSubjectTap() {
        if periods.isEmpty {
            showNoPeriodAlert = true
        } else {
            showingAddSubjectSheet = true
        }
    }
    
    private func addNewSubject(_ subjectData: SubjectData) {
        print("🔹 === DÉBUT addNewSubject ===")
        print("🔹 Données reçues: nom='\(subjectData.name)', période='\(subjectData.periodName)'")
        print("🔹 Avant fermeture sheet: showingAddSubjectSheet = \(showingAddSubjectSheet)")
        print("🔹 État isViewActive: \(isViewActive)")
        print("🔹 refreshID actuel: \(refreshID)")
        
        viewContext.performAndWait {
            do {
                // ✅ ÉTAPE 1: Vérification des doublons
                print("🔸 Vérification des doublons...")
                let duplicateRequest: NSFetchRequest<Subject> = Subject.fetchRequest()
                duplicateRequest.predicate = NSPredicate(
                    format: "name ==[c] %@ AND period.name == %@",
                    subjectData.name.trimmingCharacters(in: .whitespaces),
                    subjectData.periodName
                )
                duplicateRequest.fetchLimit = 1
                
                let existingSubjects = try viewContext.fetch(duplicateRequest)
                print("🔸 Doublons trouvés: \(existingSubjects.count)")
                
                if !existingSubjects.isEmpty {
                    print("⚠️ Doublon détecté pour '\(subjectData.name)', abandon de la création")
                    print("⚠️ Fermeture de la sheet pour doublon...")
                    DispatchQueue.main.async {
                        print("⚠️ Fermeture sheet (doublon) - showingAddSubjectSheet: \(self.showingAddSubjectSheet) → false")
                        self.showDuplicateSubjectAlert = true
                        self.duplicateSubjectName = subjectData.name
                        self.showingAddSubjectSheet = false
                    }
                    return
                }
                
                // ✅ ÉTAPE 2: Récupération de la période dans le bon contexte
                print("🔸 Recherche de la période '\(subjectData.periodName)'...")
                let periodRequest: NSFetchRequest<Period> = Period.fetchRequest()
                periodRequest.predicate = NSPredicate(format: "name == %@", subjectData.periodName)
                periodRequest.fetchLimit = 1
                
                let foundPeriods = try viewContext.fetch(periodRequest)
                print("🔸 Périodes trouvées: \(foundPeriods.count)")
                
                // ✅ CORRECTION CRITIQUE: Validation du contexte
                var targetPeriod: Period?
                
                if let period = foundPeriods.first {
                    // Vérifier que la période est dans le bon contexte
                    if period.managedObjectContext == viewContext {
                        targetPeriod = period
                        print("✅ Période trouvée dans le bon contexte: '\(period.name ?? "")'")
                    } else {
                        print("⚠️ Période trouvée mais dans un mauvais contexte, récupération par ID...")
                        // Récupérer la période par ID dans le bon contexte
                        if let periodId = period.id {
                            let idRequest: NSFetchRequest<Period> = Period.fetchRequest()
                            idRequest.predicate = NSPredicate(format: "id == %@", periodId as CVarArg)
                            idRequest.fetchLimit = 1
                            targetPeriod = try viewContext.fetch(idRequest).first
                            print("✅ Période récupérée par ID dans le bon contexte")
                        }
                    }
                }
                
                // ✅ FALLBACK: Utiliser activePeriod si nécessaire
                if targetPeriod == nil {
                    print("⚠️ Aucune période trouvée, utilisation de activePeriod...")
                    
                    // Vérifier le contexte de activePeriod
                    if let activePeriod = activePeriod {
                        if activePeriod.managedObjectContext == viewContext {
                            targetPeriod = activePeriod
                            print("✅ activePeriod utilisée: '\(activePeriod.name ?? "")'")
                        } else {
                            print("⚠️ activePeriod dans mauvais contexte, récupération par ID...")
                            if let activePeriodId = activePeriod.id {
                                let idRequest: NSFetchRequest<Period> = Period.fetchRequest()
                                idRequest.predicate = NSPredicate(format: "id == %@", activePeriodId as CVarArg)
                                idRequest.fetchLimit = 1
                                targetPeriod = try viewContext.fetch(idRequest).first
                                print("✅ activePeriod récupérée par ID dans le bon contexte")
                            }
                        }
                    } else {
                        print("❌ Aucune période active disponible")
                    }
                }
                
                // ✅ VALIDATION FINALE
                guard let finalPeriod = targetPeriod else {
                    print("❌ Impossible de trouver une période valide")
                    print("❌ Fermeture de la sheet pour erreur de période...")
                    DispatchQueue.main.async {
                        print("❌ Fermeture sheet (erreur période) - showingAddSubjectSheet: \(self.showingAddSubjectSheet) → false")
                        self.showingAddSubjectSheet = false
                    }
                    throw NSError(domain: "SubjectCreation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Aucune période valide trouvée"])
                }
                
                // ✅ ÉTAPE 3: Création de la matière
                print("🔸 Création de la nouvelle matière...")
                let newSubject = Subject(context: viewContext)
                newSubject.id = UUID()
                newSubject.name = subjectData.name.trimmingCharacters(in: .whitespaces)
                newSubject.code = subjectData.code
                newSubject.coefficient = subjectData.coefficient
                newSubject.creditHours = subjectData.creditHours
                newSubject.grade = NO_GRADE
                newSubject.createdAt = Date()
                newSubject.lastModified = Date()
                
                print("🔸 Attribution de la période...")
                newSubject.period = finalPeriod
                print("✅ Relation établie: '\(newSubject.name ?? "")' → '\(finalPeriod.name ?? "")'")
                
                // ✅ ÉTAPE 4: Sauvegarde
                print("🔸 Sauvegarde en cours...")
                try viewContext.save()
                print("✅ Matière créée et sauvegardée avec succès: '\(newSubject.name ?? "")'")
                
            } catch {
                print("❌ Erreur lors de la création de la matière: \(error.localizedDescription)")
                print("❌ Détails de l'erreur: \(error)")
                viewContext.rollback()
                print("🔄 Rollback effectué")
                
                // ✅ FERMETURE en cas d'erreur
                DispatchQueue.main.async {
                    print("❌ Fermeture sheet (catch) - showingAddSubjectSheet: \(self.showingAddSubjectSheet) → false")
                    self.showingAddSubjectSheet = false
                }
                return
            }
        }
        
        // ✅ FERMETURE DE LA SHEET EN CAS DE SUCCÈS (CORRECTION PRINCIPALE)
        DispatchQueue.main.async {
            print("🔹 === FERMETURE EFFECTIVE DE LA SHEET ===")
            print("🔹 Thread: main")
            print("🔹 Avant modification: showingAddSubjectSheet = \(self.showingAddSubjectSheet)")
            self.showingAddSubjectSheet = false
            print("🔹 Après modification: showingAddSubjectSheet = \(self.showingAddSubjectSheet)")
            print("🔹 === FERMETURE TERMINÉE ===")
        }
        
        print("🔹 === FIN addNewSubject ===")
        print("🔹 Fonction terminée, fermeture sheet programmée")
    }
}


// Enum pour définir les onglets
enum TabItem: Int, CaseIterable {
    case subjects = 0
    case revision = 1
    case settings = 2
    
    var icon: String {
        switch self {
        case .subjects: return "square.stack.3d.up.fill"
        case .revision: return "rectangle.portrait.on.rectangle.portrait.angled.fill"
        case .settings: return "gear"
        }
    }
    
    var title: String {
        switch self {
        case .subjects: return String(localized: "tab_subjects")
        case .revision: return String(localized: "tab_revision")
        case .settings: return String(localized: "tab_settings")
        }
    }
    
    var accessibilityLabel: String {
        return "Onglet \(title)"
    }
}


struct NativeTabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let animate: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: tab.icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(isSelected ? Color.blue : (colorScheme == .dark ? Color.gray.opacity(0.8) : Color.gray))
                .symbolEffect(.bounce.up.byLayer, options: .speed(1), value: animate)                .frame(height: 24)
                .scaleEffect(x: 1, y: tab.icon == "rectangle.portrait.on.rectangle.portrait.angled.fill" ? 0.94 : 1)
            Spacer()
                .frame(height: 4)
            
            Text(tab.title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? Color.blue : (colorScheme == .dark ? Color.gray.opacity(0.8) : Color.gray))
                .lineLimit(1)
                .frame(height: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: 49)
        .offset(y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}


// MARK: - LazyView Helper (inchangé)

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

// MARK: - Main Content View (inchangé)

struct MainContentView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Binding var showSplash: Bool
    @Binding var showingEditProfile: Bool
    let tempUsername: Binding<String>
    let tempSubtitle: Binding<String>
    let selectedGradient: Binding<[Color]>
    let availableGradients: [[Color]]
    let onCancel: () -> Void
    let onApply: () -> Void
    let mainTabView: AnyView
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSplash = false
                    }
                }
            } else {
                mainTabView
            }
        }
    }
}


// MARK: - Splash Screen (inchangé)

struct SplashScreenView: View {
    let onCompletion: () -> Void
    private let letters = Array("Gradefy")
    @State private var letterVisible: [Bool]
    @State private var dragOffset: CGSize = .zero
    
    init(onCompletion: @escaping () -> Void) {
        self.onCompletion = onCompletion
        self._letterVisible = State(initialValue: Array(repeating: false, count: letters.count))
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            HStack(spacing: 0) {
                ForEach(letters.indices, id: \.self) { index in
                    letterView(at: index)
                }
            }
            .rotation3DEffect(.degrees(Double(dragOffset.height / 5)), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
            .rotation3DEffect(.degrees(Double(-dragOffset.width / 5)), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
            .gesture(dragGesture)
            .onAppear(perform: startAnimation)
        }
    }
    
    private func letterView(at index: Int) -> some View {
        Text(String(letters[index]))
            .foregroundColor(Color.blue)
            .font(.system(size: 60, weight: .bold))
            .scaleEffect(letterVisible[index] ? 1.0 : 0.5)
            .opacity(letterVisible[index] ? 1 : 0)
            .animation(.interpolatingSpring(stiffness: 250, damping: 15), value: letterVisible[index])
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { _ in dragOffset = .zero }
    }
    
    private func startAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            for index in letters.indices {
                letterVisible[index] = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            onCompletion()
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}

// MARK: - Extensions et helpers (inchangé)

final class KeyboardResponder: ObservableObject {
    @Published var currentHeight: CGFloat = 0
    private var cancellable: AnyCancellable?

    init() {
        // ✅ SOLUTION PARFAITE : Gestion robuste du clavier avec délai
        cancellable = Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
                .map { $0.height }
                .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main), // Délai pour éviter les conflits
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
                .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main) // Délai pour éviter les conflits
        )
        .sink { [weak self] height in
            // ✅ SOLUTION : Mise à jour avec animation fluide
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.currentHeight = height
            }
        }
    }

    deinit { cancellable?.cancel() }
}

func formatTime(seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
        return String(format: "%02d:%02d", minutes, secs)
    }
}

struct NoPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

// MARK: - Tag List View (inchangé)

struct TagListView: View {
    let tags: [String]
    
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                TagView(text: tag)
            }
        }
    }
}

private struct TagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.1))
            )
            .foregroundStyle(.tint)
            .overlay(
                Capsule()
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
            )
    }
}

// MARK: - Flow Layout for Tags (inchangé)

struct FlowLayout: Layout {
    let spacing: CGFloat

    struct Cache {
        let rows: [[(LayoutSubview, CGSize)]]
        let height: CGFloat
    }

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func makeCache(subviews: Subviews) -> Cache {
        arrangeViews(proposal: .unspecified, subviews: subviews)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: cache.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        var y = bounds.minY
        for row in cache.rows {
            var x = bounds.minX
            for (subview, size) in row {
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.first?.1.height ?? 0
            y += spacing
        }
    }

    private func arrangeViews(proposal: ProposedViewSize, subviews: Subviews) -> Cache {
        let maxWidth = proposal.width ?? 300
        var rows: [[(LayoutSubview, CGSize)]] = []
        var currentRow: [(LayoutSubview, CGSize)] = []
        var currentRowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentRowWidth + size.width > maxWidth && !currentRow.isEmpty {
                rows.append(currentRow)
                totalHeight += currentRow.first?.1.height ?? 0
                if !rows.isEmpty { totalHeight += spacing }
                currentRow = [(subview, size)]
                currentRowWidth = size.width
            } else {
                currentRow.append((subview, size))
                currentRowWidth += size.width
                if currentRow.count > 1 { currentRowWidth += spacing }
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
            totalHeight += currentRow.first?.1.height ?? 0
        }

        return Cache(rows: rows, height: totalHeight)
    }
}

struct BouncedScrollView<Content: View>: UIViewRepresentable {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.bounces = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = true

        let hosting = UIHostingController(rootView: content())
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
    }
}

// MARK: - Méthodes privées pour les gestionnaires
extension ContentView {
    
    private func handleActivePeriodChanged(_ notification: Notification) {
        print("📢 Notification reçue dans ContentView")
        print("📋 UserInfo: \(notification.userInfo ?? [:])")
        
        if let newPeriodID = notification.userInfo?["newPeriodID"] as? String {
            print("🔄 Mise à jour vers période ID: \(newPeriodID)")
            activePeriodIDString = newPeriodID
            
            // Forcer la mise à jour de selectedPeriod
            if let uuid = UUID(uuidString: newPeriodID),
               let newPeriod = periods.first(where: { $0.id == uuid }) {
                selectedPeriod = newPeriod
                print("✅ selectedPeriod mis à jour: \(newPeriod.name ?? "")")
            } else {
                print("❌ Période non trouvée dans la liste pour ID: \(newPeriodID)")
                debugPrintAvailablePeriods()
            }
        } else {
            print("⚠️ Pas de newPeriodID dans la notification")
        }
        
        // Rafraîchir l'interface
        refreshID = UUID()
        print("🔄 Interface rafraîchie (refreshID mis à jour)")
    }
    
    private func handleViewAppear() {
        isViewActive = true
        handleContentViewAppear()
        
        // RESTAURATION DE PÉRIODE - TIMING ADAPTÉ à votre architecture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("⏰ [PERIOD_PERSISTENCE] Première tentative restauration (0.1s)")
            self.restoreActivePeriodWithCache()
        }
        
        // Retry si nécessaire quand Core Data est stabilisé
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("⏰ [PERIOD_PERSISTENCE] Seconde tentative restauration (2.0s)")
            if self.selectedPeriod == nil {
                self.restoreActivePeriodWithCache()
            }
        }
        
        // ✅ SYNCHRONISATION WIDGET - Version simplifiée
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func handleSelectedPeriodChange(oldValue: Period?, newValue: Period?) {
        guard isViewActive else { return }
        
        // ✅ Optimiser les refreshID pour éviter les re-renders inutiles
        debouncedNavigationUpdate()
    }
    
    private func debugPrintAvailablePeriods() {
        print("📋 Périodes disponibles:")
        for period in periods {
            print("   - \(period.name ?? "") (ID: \(period.id?.uuidString ?? ""))")
        }
    }
}


private extension View {
    func opacityButtonEffect() -> some View {
        self.modifier(OpacityButtonEffect())
    }
}

private struct OpacityButtonEffect: ViewModifier {
    @State private var isPressed = false
    func body(content: Content) -> some View {
        content
            .opacity(isPressed ? 1 : 1)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.13), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed { isPressed = true }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}





