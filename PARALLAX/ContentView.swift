import SwiftUI
import UIKit
import Foundation
import CoreData
import ActivityKit
import Combine
import Lottie


enum SortOrder {
    case ascending
    case descending
}

// MARK: - Adaptive Lottie Animation Component
struct AdaptiveLottieView: UIViewRepresentable {
    let animationName: String
    @Environment(\.colorScheme) private var colorScheme
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let animationView = LottieAnimationView(name: animationName)
        
        // Configuration de base
        animationView.loopMode = .playOnce
        animationView.contentMode = .scaleAspectFit
        
        // Adapter les couleurs selon le thème
        updateColors(animationView: animationView)
        
        // Layout
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
        
        animationView.play()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let animationView = uiView.subviews.first as? LottieAnimationView {
            updateColors(animationView: animationView)
        }
    }
    
    private func updateColors(animationView: LottieAnimationView) {
        // Couleur primaire selon le thème (pour les lignes/strokes)
        let primaryColor = colorScheme == .dark ?
            LottieColor(r: 1, g: 1, b: 1, a: 1) :    // Blanc en mode sombre
            LottieColor(r: 0, g: 0, b: 0, a: 1)      // Noir en mode clair
        
        let colorProvider = ColorValueProvider(primaryColor)
        
        // Cibler tous les strokes primaires
        let strokeKeyPaths = [
            "**.primary.Color",
            "**.Stroke *.Color",
            "**.Group *.**.Stroke *.Color"
        ]
        
        for keyPath in strokeKeyPaths {
            let animationKeypath = AnimationKeypath(keypath: keyPath)
            animationView.setValueProvider(colorProvider, keypath: animationKeypath)
        }
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
    @AppStorage("profilePhotoColorHex") private var profilePhotoColorHex: String = "CCCCCC"
    @AppStorage("profileGradientStartHex") private var profileGradientStartHex: String = "9BE8F6"
    @AppStorage("profileGradientEndHex") private var profileGradientEndHex: String = "5DD5F4"
    @AppStorage("darkModeEnabled") private var darkModeEnabled: Bool = false
    @AppStorage("showAppreciations") private var showAppreciations: Bool = true
    @AppStorage("selectedPeriod") private var onboardingPeriod: String = ""
    @AppStorage("onboardingPeriodProcessed") private var onboardingPeriodProcessed: Bool = false
    @AppStorage("activePeriodID") private var activePeriodIDString: String = ""
    
    // MARK: - State Variables
    @State private var selectedPeriod: Period? {
        didSet {
            if let period = selectedPeriod {
                activePeriodIDString = period.id?.uuidString ?? ""
            }
        }
    }
    
    @State private var refreshID = UUID()
    @State private var isViewActive = true
    @State private var selectedTab = 0
    @State private var showSplash = true
    @State private var selectedSubjectForNavigation: Subject?
    @State private var subjectToEdit: Subject?
    @State private var showingAddPeriodSheet = false
    @State private var showingAddSubjectSheet = false
    @State private var showNoPeriodAlert = false
    @State private var showDuplicateSubjectAlert = false
    @State private var duplicateSubjectName = ""
    @State private var showAddFlashcardSheet = false
    @State private var selectedDeckToEdit: FlashcardDeck?
    @State private var deckName: String = ""
    @State private var showPremiumView = false
    @State private var sortOption: SortOption = .alphabetical // Si pas déjà là
    @State private var sortOrder: SortOrder = .descending // ✅ AJOUTER ICI
    
    // Profile editing
    @State private var showingEditProfile = false
    @State private var tempUsername: String = ""
    @State private var tempSubtitle: String = ""
    @State private var selectedGradient: [Color] = [Color(hex: "9BE8F6"), Color(hex: "5DD5F4")]
    
    private let availableGradients: [[Color]] = [
        [Color(hex: "9BE8F6"), Color(hex: "5DD5F4")],
        [Color(hex: "B0F4B6"), Color(hex: "78E089")],
        [Color(hex: "FBB3C7"), Color(hex: "F68EB2")],
        [Color(hex: "DBC7F9"), Color(hex: "C6A8EF")],
        [Color(hex: "F8C79B"), Color(hex: "F5A26A")]
    ]
    
    // Cache et timers
    @State private var navigationUpdateTimer: Timer?
    @State private var cachedRelevantDecks: [FlashcardDeck] = []
    @State private var lastDecksUpdate = Date.distantPast
    
    // ✅ NOUVELLES VARIABLES pour TabBar Custom avec Animations
    @State private var symbolAnimations: [Bool] = [false, false, false, false]
    @State private var lastTapTime = Date.distantPast
    
    // MARK: - Computed Properties
    
    
    private var activePeriod: Period? {
        if let selected = selectedPeriod {
            return selected
        }
        
        if !activePeriodIDString.isEmpty,
           let uuid = UUID(uuidString: activePeriodIDString),
           let foundPeriod = periods.first(where: { $0.id == uuid }) {
            DispatchQueue.main.async {
                self.selectedPeriod = foundPeriod
            }
            return foundPeriod
        }
        
        if let firstPeriod = periods.first {
            DispatchQueue.main.async {
                self.selectedPeriod = firstPeriod
                self.activePeriodIDString = firstPeriod.id?.uuidString ?? ""
            }
            return firstPeriod
        }
        
        return nil
    }
    
    private var currentPeriodId: String {
        let periodName = activePeriod?.name ?? "all"
        let periodUUID = activePeriod?.id?.uuidString ?? "all"
        return "\(periodName)-\(periodUUID)-\(refreshID.uuidString)"
    }
    
    private var allSubjects: [Subject] {
        periods.flatMap { ($0.subjects as? Set<Subject>) ?? [] }
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
        MainContentView(
            hasCompletedOnboarding: hasCompletedOnboarding,
            showSplash: $showSplash,
            showingEditProfile: $showingEditProfile,
            tempUsername: $tempUsername,
            tempSubtitle: $tempSubtitle,
            selectedGradient: $selectedGradient,
            availableGradients: availableGradients,
            onCancel: handleEditProfileCancel,
            onApply: handleEditProfileApply,
            mainTabView: AnyView(customTabBarView) // ✅ CHANGÉ ici
        )
        .onAppear {
            isViewActive = true
            handleContentViewAppear()
        }
        .onDisappear {
            isViewActive = false
            cleanupTimers()
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
        .onChange(of: selectedTab) { _, newTab in
            guard isViewActive else { return }
            handleTabChange(newTab)
        }
        .onChange(of: selectedPeriod) { oldValue, newValue in
            guard isViewActive else { return }
            
            DispatchQueue.main.async {
                self.refreshID = UUID()
                self.debouncedNavigationUpdate()
            }
        }
        .onChange(of: sortOption) { _, _ in
            guard isViewActive else { return }
            debouncedNavigationUpdate()
        }
        .alert("Matière déjà existante", isPresented: $showDuplicateSubjectAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Une matière nommée '\(duplicateSubjectName)' existe déjà dans cette période. Veuillez choisir un nom différent.")
        }
    }
    
    // MARK: - ✅ NOUVELLE TabBar Custom avec Animations
    
    private var customTabBarView: some View {
        VStack(spacing: 0) {
            // Contenu principal avec switch selon l'onglet sélectionné
            Group {
                switch selectedTab {
                case 0:
                    homeTabContent
                case 1:
                    LazyView(subjectsTabContent)
                case 2:
                    LazyView(revisionTabContent)
                case 3:
                    profileTabContent
                default:
                    homeTabContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // ✅ TabBar Custom avec look natif
            nativeStyleTabBar
        }
    }
    
    private var nativeStyleTabBar: some View {
        HStack(spacing: 0) { // ✅ Pas d'espacement entre boutons
            ForEach([TabItem.home, TabItem.subjects, TabItem.revision, TabItem.settings], id: \.self) { tab in
                NativeTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab.rawValue,
                    animate: symbolAnimations[tab.rawValue]
                ) {
                    selectTab(tab.rawValue)
                }
            }
        }
        .frame(height: 49) // ✅ Hauteur fixe
        .clipped() // ✅ Empêche les débordements
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .frame(height: 0.33)
                .foregroundColor(Color(UIColor.separator))
        }
        .tint(.blue) // ✅ FORCE la couleur d'accent
    }
    
    private func selectTab(_ index: Int) {
        let localIsViewActive = isViewActive
        guard localIsViewActive else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastTapTime) > 0.3 else { return }
        lastTapTime = now
        
        if selectedTab == index { return }
        
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedTab = index
        }
        
        symbolAnimations[index].toggle()
    }
    
    // MARK: - ✅ Contenu des Onglets (inchangé)
    
    private var homeTabContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    HomeCardsView(
                        displayedSubjects: displayedSubjects,
                        allSubjects: allSubjects,
                        showPremiumView: $showPremiumView,
                        filteredEvaluations: filteredEvaluations,
                        nextEvaluation: nextEvaluation,
                        timeUntilNextEvaluation: timeUntilNextEvaluation,
                        hasNextEvaluation: hasNextEvaluation,
                        activePeriod: activePeriod,
                        periods: periods,
                        relevantDecks: relevantDecks,
                        relevantCardsToReview: relevantCardsToReview,
                        weeklyEvaluationAdditions: weeklyEvaluationAdditions,
                        currentPeriodId: currentPeriodId,
                        gradingSystem: gradingSystem,
                        selectedTab: $selectedTab,
                        selectedSubjectForNavigation: $selectedSubjectForNavigation
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(homeBackground) // ✅ NOUVEAU BACKGROUND
            .navigationTitle("Accueil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        periodSelectorMenu
                    } label: {
                        Text("Périodes")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showPremiumView) {
                PremiumView()
            }
            .sheet(isPresented: $showingAddPeriodSheet) {
                AddPeriodView { newPeriodName, startDate, endDate in
                    addNewPeriod(name: newPeriodName, startDate: startDate, endDate: endDate)
                }
            }
            .navigationDestination(for: Subject.self) { subject in
                SubjectDetailView(subjectObject: subject, showingProfileSheet: .constant(false))
            }
            .id(refreshID)
            .scrollDisabled(true)
        }
    }
    private var homeBackground: Color {
        colorScheme == .light ? Color(hex: "F2F2F6") : Color(.systemBackground)
    }
    
    private var subjectsTabContent: some View {
        NavigationStack {
            Group {
                if displayedSubjects.isEmpty {
                    subjectsEmptyState
                } else {
                    List {
                        ForEach(displayedSubjects, id: \.objectID) { subject in
                            NavigationLink(value: subject) {
                                SubjectRow(
                                    subject: subject,
                                    showAppreciations: showAppreciations,
                                    onEdit: { subjectToEdit = subject },
                                    onDelete: { deleteSubject(subject) }
                                )
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(adaptiveBackground)
                }
            }
            .navigationTitle("Matières")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        sortMenuContent
                    } label: {
                        Text("Trier")
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
            .alert("Aucune période", isPresented: $showNoPeriodAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Veuillez d'abord ajouter une période avant d'ajouter une matière.")
            }
            .navigationDestination(for: Subject.self) { subject in
                SubjectDetailView(subjectObject: subject, showingProfileSheet: .constant(false))
            }
            .id(isViewActive ? refreshID : UUID())
        }
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
                                            Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled.fill")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.accentColor)
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
                                    Label("Modifier", systemImage: "pencil")
                                }
                                .tint(.blue)
                                
                                Button(role: .destructive) {
                                    deleteDeck(deck)
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(adaptiveBackground)
                }
            }
            .navigationTitle("Révision")
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
        NavigationStack {
            ProfileView()
        }
    }
    
    // MARK: - Period Selector (inchangé)
    
    private var periodSelector: some View {
        Menu {
            periodSelectorMenu
        } label: {
            periodSelectorLabel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 15)
        .sheet(isPresented: $showingAddPeriodSheet) {
            AddPeriodView { newPeriodName, startDate, endDate in
                addNewPeriod(name: newPeriodName, startDate: startDate, endDate: endDate)
            }
        }
    }
    
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
            Button("Ajouter une période", systemImage: "plus") {
                showingAddPeriodSheet = true
            }
        }
    }
    
    private var periodSelectorLabel: some View {
        HStack(spacing: 4) {
            Text("Mes périodes")
                .font(.title3.weight(.semibold))
                .foregroundColor(.blue)
            Image(systemName: "chevron.up.chevron.down")
                .font(.headline)
                .foregroundColor(.blue)
        }
    }
    
    // MARK: - Empty States (inchangé)
    
    private var subjectsEmptyState: some View {
        VStack {
            Spacer()
            
            // ✅ ANIMATION ADAPTIVE au mode sombre
            AdaptiveLottieView(animationName: "subjectblue")
                .frame(width: 110, height: 110)
            
            // ✅ TEXTE parfaitement adaptatif
            VStack(spacing: 8) {
                Text("Vous n'avez aucune matière pour le moment")
                    .font(.headline.weight(.medium))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 16)
            
            Spacer()
            
            Button(action: handleAddSubjectTap) {
                Text("Nouvelle matière")
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
    }
    
    private var revisionEmptyState: some View {
        VStack {
            Spacer()
            
            // ✅ ANIMATION ADAPTIVE au mode sombre
            AdaptiveLottieView(animationName: "notesblue")
                .frame(width: 110, height: 110)
            
            // ✅ TEXTE parfaitement adaptatif
            VStack(spacing: 8) {
                Text("Vous n'avez aucune liste pour le moment")
                    .font(.headline.weight(.medium))
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
                Text("Nouvelle liste")
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
            Section("Trier par") {
                Button {
                    sortOption = .alphabetical
                    debouncedNavigationUpdate()
                } label: {
                    HStack {
                        Text("Par nom")
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
            Section("Ordre") {
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
    }
    
    private func ensureAtLeastOnePeriodExists() {
        if selectedPeriod == nil || !periods.contains(where: { $0.id == selectedPeriod?.id }) {
            if let firstPeriod = periods.first {
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
            return false
        }
        
        if hasRelevantChanges {
            DispatchQueue.main.async {
                self.refreshID = UUID()
            }
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
        
        let localIsViewActive = isViewActive
        
        navigationUpdateTimer?.invalidate()
        navigationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            guard localIsViewActive else { return }
            
            DispatchQueue.main.async {
                self.refreshID = UUID()
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
                selectedPeriod = periods.first
            }
        }
    }
    
    private func createOnboardingPeriodIfNeeded() {
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let processed = UserDefaults.standard.bool(forKey: "onboardingPeriodProcessed")
        let savedPeriod = UserDefaults.standard.string(forKey: "selectedPeriod") ?? ""
        
        guard hasCompleted && !processed && !savedPeriod.isEmpty else {
            if selectedPeriod == nil && !periods.isEmpty {
                selectedPeriod = periods.first
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
    
    private func deleteSubject(_ subject: Subject) {
        withAnimation {
            let request: NSFetchRequest<Evaluation> = Evaluation.fetchRequest()
            request.predicate = NSPredicate(format: "subject == %@", subject)
            
            do {
                let evaluations = try viewContext.fetch(request)
                evaluations.forEach(viewContext.delete)
                viewContext.delete(subject)
                try viewContext.save()
            } catch {
                print("Erreur lors de la suppression de la matière:", error)
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
        viewContext.performAndWait {
            do {
                let duplicateRequest: NSFetchRequest<Subject> = Subject.fetchRequest()
                duplicateRequest.predicate = NSPredicate(
                    format: "name ==[c] %@ AND period.name == %@",
                    subjectData.name.trimmingCharacters(in: .whitespaces),
                    subjectData.periodName
                )
                duplicateRequest.fetchLimit = 1
                
                let existingSubjects = try viewContext.fetch(duplicateRequest)
                
                if !existingSubjects.isEmpty {
                    DispatchQueue.main.async {
                        self.showDuplicateSubjectAlert = true
                        self.duplicateSubjectName = subjectData.name
                    }
                    return
                }
                
                let periodRequest: NSFetchRequest<Period> = Period.fetchRequest()
                periodRequest.predicate = NSPredicate(format: "name == %@", subjectData.periodName)
                periodRequest.fetchLimit = 1
                
                let foundPeriods = try viewContext.fetch(periodRequest)
                let targetPeriod = foundPeriods.first ?? activePeriod
                
                let newSubject = Subject(context: viewContext)
                newSubject.id = UUID()
                newSubject.name = subjectData.name.trimmingCharacters(in: .whitespaces)
                newSubject.code = subjectData.code
                newSubject.coefficient = subjectData.coefficient
                newSubject.grade = NO_GRADE
                newSubject.period = targetPeriod
                
                try viewContext.save()
                
            } catch {
                viewContext.rollback()
            }
        }
    }
}


// ✅ Ajoutez un enum pour l'ordre de tri


// Enum pour définir les onglets
enum TabItem: Int, CaseIterable {
    case home = 0
    case subjects = 1
    case revision = 2
    case settings = 3
    
    var icon: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .subjects: return "square.stack.fill"
        case .revision: return "rectangle.portrait.on.rectangle.portrait.angled.fill"
        case .settings: return "gear"
        }
    }
    
    var title: String {
        switch self {
        case .home: return "Accueil"
        case .subjects: return "Matières"
        case .revision: return "Révision"
        case .settings: return "Paramètres"
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
                .symbolEffect(.bounce.up, value: animate)
                .frame(height: 26)
            
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
        .offset(y: 3)
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
    let hasCompletedOnboarding: Bool
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
        if hasCompletedOnboarding {
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
        } else {
            AppleStyleOnboardingView()
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
        cancellable = Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
                .map { $0.height },
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        )
        .sink { [weak self] height in
            self?.currentHeight = height
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
        .onAppear {
            UserDefaults.standard.set("france", forKey: "GradingSystem")
            UserDefaults.standard.set("", forKey: "username")
            UserDefaults.standard.set("En révision", forKey: "profileSubtitle")
            UserDefaults.standard.set(false, forKey: "darkModeEnabled")
            UserDefaults.standard.set(true, forKey: "showAppreciations")
        }
}
