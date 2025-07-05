//
// HomeViewComponents.swift
// PARALLAX
//
// Created by Farid on 6/29/25.
//

import SwiftUI
import Foundation
import CoreData



// MARK: - Activity Ring avec animation au lancement de l'app uniquement
struct ActivityRingView: View {
    let value: Double
    @Environment(\.colorScheme) private var colorScheme
    @State private var displayValue: Double = 0.0
    @State private var animationProgress: Double = 0.0
    
    private var safeFraction: Double {
        min(max(displayValue, 0), 1)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 30)
                .foregroundColor(Color(hex: "5AC8FA").opacity(0.2))
            
            Circle()
                .trim(from: 0, to: safeFraction * animationProgress)
                .stroke(Color(hex: "5AC8FA"), style: StrokeStyle(lineWidth: 30, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.2), value: animationProgress)
            
            Circle()
                .frame(width: 30, height: 30)
                .foregroundColor(Color(hex: "5AC8FA"))
                .offset(y: -65)
                
            Image(systemName: "arrow.right")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
                .offset(y: -65)
        }
        .onAppear {
            displayValue = value
            
            // Utiliser la même logique que les barres
            if AppLaunchTracker.shared.shouldPlayRingAnimation {
                AppLaunchTracker.shared.markRingAnimationPlayed()
                triggerFirstAnimation()
            } else {
                animationProgress = 1.0
            }
        }
        .onChange(of: value) { _, newValue in
            displayValue = newValue
        }
    }
    
    private func triggerFirstAnimation() {
        animationProgress = 0.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 1.5)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Revision Data Manager avec SmartAverageCache
@MainActor
final class HomeRevisionManager: ObservableObject {
    @Published var revisionData = RevisionCardData()
    
    private let smartCache = SmartAverageCache()
    
    struct RevisionCardData: Codable, Equatable {
        let totalDecks: Int
        let cardsToReview: Int
        let lastActivityDate: Date
        
        init(totalDecks: Int = 0, cardsToReview: Int = 0, lastActivityDate: Date = Date.distantPast) {
            self.totalDecks = totalDecks
            self.cardsToReview = cardsToReview
            self.lastActivityDate = lastActivityDate
        }
        
        var lastActivityText: String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: lastActivityDate, relativeTo: Date())
        }
        
        var statusText: String {
            if cardsToReview > 0 {
                return "Cartes disponibles"
            } else if totalDecks > 0 {
                return "Dernière activité: \(lastActivityText)"
            } else {
                return "Aucune flashcard"
            }
        }
        
        var statusColor: Color {
            cardsToReview > 0 ? .blue : .secondary
        }
    }
    
    func updateData(decks: [FlashcardDeck]) {
        let cacheKey = "home_revision_\(decks.count)_\(Date().timeIntervalSince1970 / 120)"
        let dependencies = Set(decks.compactMap { $0.objectID.uriRepresentation().absoluteString })
        
        let cardsToReview: Int
        if let cachedValue = smartCache.getCachedAverage(forKey: cacheKey) {
            cardsToReview = Int(cachedValue)
        } else {
            cardsToReview = calculateCardsToReview(decks)
            smartCache.cacheAverage(Double(cardsToReview), forKey: cacheKey, dependencies: dependencies)
        }
        
        let lastActivity = getLastRevisionDate()
        
        let newData = RevisionCardData(
            totalDecks: decks.count,
            cardsToReview: cardsToReview,
            lastActivityDate: lastActivity
        )
        
        self.revisionData = newData
    }
    
    private func calculateCardsToReview(_ decks: [FlashcardDeck]) -> Int {
        return decks
            .flatMap { deck in
                (deck.flashcards as? Set<Flashcard>) ?? []
            }
            .filter { flashcard in
                needsReview(flashcard)
            }
            .count
    }
    
    private func needsReview(_ card: Flashcard) -> Bool {
        guard let lastDate = card.createdAt else { return true }
        
        let daysSince = Calendar.current.dateComponents([.day],
            from: lastDate, to: Date()).day ?? 0
            
        return daysSince >= 1
    }
    
    private func getLastRevisionDate() -> Date {
        return UserDefaults.standard.object(forKey: "lastRevisionDate") as? Date ?? Date.distantPast
    }
}

struct StatsCardView: View {
    let headerTitle: String
    let subjects: [Subject]
    let periodId: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentDisplayValue = "--"
    @State private var currentFraction: Double = 0.0
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    private let smartCache = SmartAverageCache()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 20) {
                ActivityRingView(value: currentFraction)
                    .frame(width: 130, height: 130)
                    .padding(.leading, 20)
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                
                Spacer()

                // Titre et valeur de la moyenne
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Moyenne")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.cyan)
                    
                    Text(currentDisplayValue)
                        .font(.title.weight(.semibold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 5)
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 20)
            
            Spacer()
        }
        .frame(height: 210)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(cardBackground)
        )
        .onAppear {
            updateDisplayData()
        }
        .onChange(of: subjects.count) { _, _ in
            updateDisplayData()
        }
        .onChange(of: subjects.map { $0.grade }) { _, _ in
            updateDisplayData()
        }
    }
    
    // MARK: - Computed Properties
    
    private var cardBackground: Color {
        colorScheme == .light ? Color.white : Color(.secondarySystemBackground)
    }
    
    private var validSubjects: [Subject] {
        subjects.filter { subject in
            subject.grade != NO_GRADE && gradingSystem.validate(subject.grade)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateDisplayData() {
        guard !validSubjects.isEmpty else {
            currentDisplayValue = "--"
            currentFraction = 0.0
            return
        }
        
        let cacheKey = "home_stats_\(periodId)_\(gradingSystem.id)_\(validSubjects.hashValue)"
        let dependencies = Set(validSubjects.compactMap {
            $0.objectID.uriRepresentation().absoluteString
        })
        
        let average: Double
        if let cachedAverage = smartCache.getCachedAverage(forKey: cacheKey) {
            average = cachedAverage
        } else {
            average = calculateAverage()
            
            if average != NO_GRADE && gradingSystem.validate(average) {
                smartCache.cacheAverage(average, forKey: cacheKey, dependencies: dependencies)
            }
        }
        
        guard average != NO_GRADE && gradingSystem.validate(average) else {
            currentDisplayValue = "--"
            currentFraction = 0.0
            return
        }
        
        currentDisplayValue = gradingSystem.format(average)
        currentFraction = calculateFraction(for: average)
    }
    
    private func calculateAverage() -> Double {
        let dummyEvals = validSubjects.map {
            DummyEvaluation(grade: $0.grade, coefficient: $0.coefficient)
        }
        return gradingSystem.weightedAverage(dummyEvals)
    }
    
    private func calculateFraction(for average: Double) -> Double {
        let maxGrade = getMaxGrade(for: gradingSystem)
        
        // Normalisation pour le ring (0.0 à 1.0)
        let fraction = average / maxGrade
        
        // Adaptation pour le système allemand (1 = meilleur, 6 = pire)
        if gradingSystem.id == "germany" {
            return (maxGrade - average) / (maxGrade - 1.0)
        }
        
        return min(max(fraction, 0.0), 1.0)
    }
    
    private func getMaxGrade(for system: GradingSystemPlugin) -> Double {
        switch system.id {
        case "french": return 20.0
        case "usa": return 4.0
        case "germany": return 6.0
        case "uk": return 100.0
        default: return 20.0
        }
    }
}



// MARK: - Subject Insights Manager avec SmartAverageCache
struct SubjectInsightsManager {
    private let smartCache = SmartAverageCache()
    
    struct InsightData {
        let bestSubject: SubjectSnapshot?
        let worstSubject: SubjectSnapshot?
        let subjectsWithGrades: Int
        
        struct SubjectSnapshot {
            let name: String
            let grade: Double
        }
    }
    
    func getInsights(for subjects: [Subject], using gradingSystem: GradingSystemPlugin) -> InsightData {
        let cacheKey = "subject_insights_\(subjects.hashValue)_\(gradingSystem.id)"
        let dependencies = Set(subjects.compactMap {
            $0.objectID.uriRepresentation().absoluteString
        })
        
        if let cachedBest = smartCache.getCachedAverage(forKey: "\(cacheKey)_best"),
           let cachedWorst = smartCache.getCachedAverage(forKey: "\(cacheKey)_worst"),
           let cachedCount = smartCache.getCachedAverage(forKey: "\(cacheKey)_count") {
            
            var bestSubject: InsightData.SubjectSnapshot?
            var worstSubject: InsightData.SubjectSnapshot?
            
            if cachedBest != -1 {
                bestSubject = InsightData.SubjectSnapshot(name: "Meilleure matière", grade: cachedBest)
            }
            
            if cachedWorst != -1 && Int(cachedCount) > 1 {
                worstSubject = InsightData.SubjectSnapshot(name: "Matière à améliorer", grade: cachedWorst)
            }
            
            return InsightData(
                bestSubject: bestSubject,
                worstSubject: worstSubject,
                subjectsWithGrades: Int(cachedCount)
            )
        }
        
        let insights = calculateInsights(for: subjects, using: gradingSystem)
        
        smartCache.cacheAverage(insights.bestSubject?.grade ?? -1, forKey: "\(cacheKey)_best", dependencies: dependencies)
        smartCache.cacheAverage(insights.worstSubject?.grade ?? -1, forKey: "\(cacheKey)_worst", dependencies: dependencies)
        smartCache.cacheAverage(Double(insights.subjectsWithGrades), forKey: "\(cacheKey)_count", dependencies: dependencies)
        
        return insights
    }
    
    private func calculateInsights(for subjects: [Subject], using gradingSystem: GradingSystemPlugin) -> InsightData {
        let subjectsWithGrades = subjects.filter {
            $0.grade != NO_GRADE && gradingSystem.validate($0.grade)
        }
        
        let bestSubject: Subject?
        let worstSubject: Subject?
        
        if gradingSystem.id == "germany" {
            // En Allemagne : 1.0 = meilleur, 6.0 = pire
            bestSubject = subjectsWithGrades.min(by: { $0.grade < $1.grade })
            worstSubject = subjectsWithGrades.max(by: { $0.grade < $1.grade })
        } else {
            // Autres systèmes : plus haut = meilleur
            bestSubject = subjectsWithGrades.max(by: { $0.grade < $1.grade })
            worstSubject = subjectsWithGrades.min(by: { $0.grade < $1.grade })
        }
        
        return InsightData(
            bestSubject: bestSubject.map {
                InsightData.SubjectSnapshot(name: $0.name ?? "", grade: $0.grade)
            },
            worstSubject: worstSubject.map {
                InsightData.SubjectSnapshot(name: $0.name ?? "", grade: $0.grade)
            },
            subjectsWithGrades: subjectsWithGrades.count
        )
    }
}

// MARK: - Cartes longues (full width)
struct FullWidthCard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: 135)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(cardBackground)
            )
    }
    
    private var cardBackground: Color {
        colorScheme == .light ? Color.white : Color(.secondarySystemBackground)
    }
}

// MARK: - Carte compacte (100px de hauteur)
struct CompactCard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(cardBackground)
            )
    }
    
    private var cardBackground: Color {
        colorScheme == .light ? Color.white : Color(.secondarySystemBackground)
    }
}

// MARK: - Vue principale des cartes (refactorisée)
struct HomeCardsView: View {
    let displayedSubjects: [Subject]
    let allSubjects: [Subject]
    let showPremiumView: Binding<Bool>
    let filteredEvaluations: [Evaluation]
    let nextEvaluation: Evaluation?
    let timeUntilNextEvaluation: String
    let hasNextEvaluation: Bool
    let activePeriod: Period?
    let periods: FetchedResults<Period>
    let relevantDecks: [FlashcardDeck]
    let relevantCardsToReview: Int
    let weeklyEvaluationAdditions: Int
    let currentPeriodId: String
    let gradingSystem: GradingSystemPlugin
    let selectedTab: Binding<Int>
    let selectedSubjectForNavigation: Binding<Subject?>
    
    @StateObject private var revisionManager = HomeRevisionManager()
    @State private var subjectInsights: SubjectInsightsManager.InsightData?
    
    private let insightsManager = SubjectInsightsManager()
    private let smartCache = SmartAverageCache()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsCard
                subjectsCard
                evaluationCard
                revisionsCard
            }
            .padding(.horizontal, 0)
            .padding(.top, 5)
        }
        .scrollDisabled(true)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 20)
        }
        .onAppear {
            revisionManager.updateData(decks: relevantDecks)
            updateSubjectInsights()
        }
        .onChange(of: relevantDecks.count) { _, _ in
            revisionManager.updateData(decks: relevantDecks)
        }
        .onChange(of: displayedSubjects.count) { _, _ in
            updateSubjectInsights()
        }
        .onChange(of: displayedSubjects.map { $0.grade }) { _, _ in
            updateSubjectInsights()
            invalidateCache()
        }
    }
    
    // MARK: - Computed Properties pour les cartes
    
    private var statsCard: some View {
        StatsCardView(
            headerTitle: gradingSystem.averageLabel,
            subjects: displayedSubjects,
            periodId: currentPeriodId
        )
    }
    
    private func getMaxGrade(for system: GradingSystemPlugin) -> Double {
        switch system.id {
        case "french":
            return 20.0
        case "usa":
            return 4.0
        case "germany":
            return 6.0
        case "uk":
            return 100.0
        default:
            return 20.0
        }
    }
    
    private var subjectsCard: some View {
        SubjectsGraphCard(
            displayedSubjects: displayedSubjects,
            subjectInsights: subjectInsights,
            gradingSystem: gradingSystem,
            selectedTab: selectedTab
        )
    }
    
    private var evaluationCard: some View {
        EvaluationCard(
            hasNextEvaluation: hasNextEvaluation,
            nextEvaluation: nextEvaluation,
            timeUntilNextEvaluation: timeUntilNextEvaluation,
            selectedSubjectForNavigation: selectedSubjectForNavigation
        )
    }
    
    private var revisionsCard: some View {
        RevisionsCard(
            revisionData: revisionManager.revisionData,
            selectedTab: selectedTab
        )
    }
    
    // MARK: - Helper Methods
    
    private func updateSubjectInsights() {
        subjectInsights = insightsManager.getInsights(for: displayedSubjects, using: gradingSystem)
    }
    
    private func invalidateCache() {
        for subject in displayedSubjects {
            let objectIDString = subject.objectID.uriRepresentation().absoluteString
            smartCache.invalidateIfNeeded(changedObjectID: objectIDString)
        }
    }
    
    func colorForGrade(_ grade: Double, maxGrade: Double) -> Color {
        let percentage = grade / maxGrade
        switch percentage {
        case 0.8...:
            return Color.green
        case 0.6..<0.8:
            return Color.blue
        case 0.4..<0.6:
            return Color.orange
        default:
            return Color.red
        }
    }
}

// MARK: - Carte matières avec graphique des 5 dernières notes
struct SubjectsGraphCard: View {
    let displayedSubjects: [Subject]
    let subjectInsights: SubjectInsightsManager.InsightData?
    let gradingSystem: GradingSystemPlugin
    let selectedTab: Binding<Int>
    
    @State private var fillProgress: [Double] = Array(repeating: 0.0, count: 5)
    @State private var hasAnimated = false
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        FullWidthCard {
            HStack(spacing: 20) {
                // Graphique à barres à gauche
                miniBarChart
                
                Spacer()
                
                // Valeur principale à droite
                VStack(alignment: .trailing, spacing: 4) {
                    Text(displayLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.trailing)
                    
                    Text(displayValue)
                        .font(.title.weight(.semibold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 25)
            .frame(maxHeight: .infinity) // Centrage vertical
        }
        .onAppear {
            // ✅ CORRECT - Utiliser les nouvelles propriétés
            if AppLaunchTracker.shared.shouldPlayBarAnimation {
                AppLaunchTracker.shared.markBarAnimationPlayed()
                triggerFillAnimation()
            } else {
                fillProgress = Array(repeating: 1.0, count: 5)
            }
        }
        .onTapGesture {
            HapticFeedbackManager.shared.impact(style: .light)
            selectedTab.wrappedValue = 1
        }
    }
    
    // MARK: - Private Methods
    
    // Déclencher l'animation de remplissage
    private func triggerFillAnimation() {
        for index in 0..<min(lastFiveGrades.count, 5) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    fillProgress[index] = 1.0
                }
            }
        }
    }
    
    // Mini graphique à barres des 5 dernières notes
    private var miniBarChart: some View {
        HStack(alignment: .bottom, spacing: 15) {
            ForEach(0..<5, id: \.self) { index in
                ZStack(alignment: .bottom) {
                    // Barre de fond (toujours visible)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 18, height: 70)
                    
                    // Barre remplie (animation progressive comme un verre d'eau)
                    if index < lastFiveGrades.count {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.blue)
                            .frame(width: 18, height: barHeight(for: lastFiveGrades[index]) * fillProgress[index])
                    }
                }
            }
        }
        .frame(height: 70) // Hauteur fixe pour le graphique
    }
    
    // Calcul de la hauteur des barres
    private func barHeight(for grade: Double) -> CGFloat {
        let maxGrade = getMaxGrade(for: gradingSystem)
        
        let normalizedHeight: CGFloat
        if gradingSystem.id == "germany" {
            // Pour l'Allemagne : inverser la logique (1.0 = meilleur = grande barre)
            normalizedHeight = CGFloat((maxGrade - grade) / (maxGrade - 1.0)) * 70
        } else {
            // Pour les autres systèmes : logique normale
            normalizedHeight = CGFloat(grade / maxGrade) * 70
        }
        
        return max(normalizedHeight, 4)
    }
    
    // ✅ CORRECTION : Les 5 dernières notes par DATE, pas par valeur
    // ✅ CORRECTION : Les 5 dernières notes par DATE, pas par valeur
    private var lastFiveGrades: [Double] {
        let request: NSFetchRequest<Subject> = Subject.fetchRequest()
        
        // ✅ Filtre pour la période active (ajustez le nom de la relation)
        if let activePeriod = getActivePeriod() {
            request.predicate = NSPredicate(format: "period == %@ AND grade > 0", activePeriod)
        } else {
            request.predicate = NSPredicate(format: "grade > 0")
        }
        
        // ✅ TRI FORCÉ par createdAt
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        
        request.fetchLimit = 5
        
        do {
            let recentSubjects = try viewContext.fetch(request)
            return recentSubjects
                .filter { gradingSystem.validate($0.grade) }
                .map { $0.grade }
        } catch {
            return []
        }
    }

    private func getActivePeriod() -> Period? {
        // Votre logique pour récupérer la période active
        // Par exemple depuis UserDefaults ou une autre source
        return nil
    }

    
    // ✅ CORRECTION : Meilleure note parmi les 5 dernières
    private var displayValue: String {
        guard !lastFiveGrades.isEmpty else { return "--" }
        
        // Meilleure note parmi les 5 dernières (pas forcément la première)
        let bestOfLastFive = lastFiveGrades.max() ?? 0
        return gradingSystem.format(bestOfLastFive)
    }
    
    // ✅ CORRECTION : Label plus précis
    private var displayLabel: String {
        guard !lastFiveGrades.isEmpty else { return "Aucune note" }
        
        return "Meilleure note"
    }
    
    private func getMaxGrade(for system: GradingSystemPlugin) -> Double {
        switch system.id {
        case "french": return 20.0
        case "usa": return 4.0
        case "germany": return 6.0
        case "uk": return 100.0
        default: return 20.0
        }
    }
}



// MARK: - App Launch Tracker unifié
class AppLaunchTracker: ObservableObject {
    static let shared = AppLaunchTracker()
    
    @Published var shouldPlayBarAnimation = true
    @Published var shouldPlayRingAnimation = true
    
    private var hasPlayedBarsThisSession = false
    private var hasPlayedRingThisSession = false
    
    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        if !hasPlayedBarsThisSession {
            shouldPlayBarAnimation = true
        }
        if !hasPlayedRingThisSession {
            shouldPlayRingAnimation = true
        }
    }
    
    @objc private func appDidEnterBackground() {
        hasPlayedBarsThisSession = false
        hasPlayedRingThisSession = false
        shouldPlayBarAnimation = false
        shouldPlayRingAnimation = false
    }
    
    func markBarAnimationPlayed() {
        shouldPlayBarAnimation = false
        hasPlayedBarsThisSession = true
    }
    
    func markRingAnimationPlayed() {
        shouldPlayRingAnimation = false
        hasPlayedRingThisSession = true
    }
}


// MARK: - Sous-vue pour la carte évaluation
struct EvaluationCard: View {
    let hasNextEvaluation: Bool
    let nextEvaluation: Evaluation?
    let timeUntilNextEvaluation: String
    let selectedSubjectForNavigation: Binding<Subject?>
    
    var body: some View {
        CompactCard {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(evaluationTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(evaluationTime)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 32))
                    .foregroundColor(.indigo)
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 8)
        }
        .onTapGesture {
            if let evaluation = nextEvaluation, let subject = evaluation.subject {
                HapticFeedbackManager.shared.impact(style: .light)
                selectedSubjectForNavigation.wrappedValue = subject
            }
        }
    }
    
    private var evaluationTitle: String {
        if hasNextEvaluation && !(nextEvaluation?.title?.isEmpty ?? true) {
            return nextEvaluation?.title ?? "Titre de l'évaluation"
        } else {
            return "Aucune évaluation"
        }
    }
    
    private var evaluationTime: String {
        if hasNextEvaluation && !timeUntilNextEvaluation.isEmpty {
            return timeUntilNextEvaluation
        } else {
            return "durée en jour et heures"
        }
    }
}

// MARK: - Sous-vue pour la carte révisions
struct RevisionsCard: View {
    let revisionData: HomeRevisionManager.RevisionCardData
    let selectedTab: Binding<Int>
    
    var body: some View {
        FullWidthCard {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(revisionData.cardsToReview)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }
                    
                    Text(revisionData.statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Spacer()
            }
        }
        .onTapGesture {
            HapticFeedbackManager.shared.impact(style: .light)
            selectedTab.wrappedValue = 2
        }
    }
}

// MARK: - Cartes conservées pour compatibilité
struct BaseSmallCard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(width: 170, height: 170)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
    }
    
    private var cardBackground: Color {
        colorScheme == .light ? Color.white : Color(.secondarySystemBackground)
    }
}

struct ListesCardView: View {
    let deckCount: Int
    let cardsToReview: Int
    let periodId: String
    
    var body: some View {
        BaseSmallCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Listes")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                
                Divider()
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                
                HStack {
                    Text("\(deckCount)")
                        .font(.title.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                
                Spacer()
                
                Text(cardsToReview > 0 ? "\(cardsToReview) à réviser" : "Aucune révision")
                    .font(.caption.weight(.medium))
                    .foregroundColor(cardsToReview > 0 ? .orange : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }
}

struct SubjectsStatusCardView: View {
    let totalSubjects: Int
    let subjectsWithoutGrades: Int
    let periodId: String
    
    var body: some View {
        BaseSmallCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Matières")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                
                Divider()
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                
                HStack {
                    Text("\(totalSubjects)")
                        .font(.title.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "book.pages")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                
                Spacer()
                
                Text(subjectsWithoutGrades > 0 ? "\(subjectsWithoutGrades) sans note" :
                     totalSubjects > 0 ? "Toutes notées" : "Aucune matière")
                    .font(.caption.weight(.medium))
                    .foregroundColor(subjectsWithoutGrades > 0 ? .orange :
                                   totalSubjects > 0 ? .green : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }
}

struct DeadlineCardView: View {
    let timeUntilNextEvaluation: String
    let hasNextEvaluation: Bool
    let nextEvaluationTitle: String
    let periodId: String
    
    var body: some View {
        BaseSmallCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Évaluation")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                
                Divider()
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                
                HStack {
                    Text(hasNextEvaluation && !timeUntilNextEvaluation.isEmpty ? timeUntilNextEvaluation : "--")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 30))
                        .foregroundColor(.orange)
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                
                Spacer()
                
                Text(hasNextEvaluation && !nextEvaluationTitle.isEmpty ? nextEvaluationTitle : "Aucune évaluation")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }
}

struct PeriodsCardView: View {
    let currentPeriod: Period?
    let totalPeriods: Int
    let periodId: String
    
    var body: some View {
        BaseSmallCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Périodes")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                
                Divider()
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                
                HStack {
                    Text("\(totalPeriods)")
                        .font(.title.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 30))
                        .foregroundColor(.green)
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                
                Spacer()
                
                Text(currentPeriod?.name ?? "Aucune active")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }
}

struct PremiumCardView: View {
    let periodId: String
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            BaseSmallCard {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Gradefy PRO")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.top, 16)
                        .padding(.horizontal, 16)
                    
                    Divider()
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                    
                    HStack {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    Text("Débloquez toutes les fonctionnalités")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SystemCardView: View {
    let periodId: String
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    var body: some View {
        BaseSmallCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Notation")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                
                Divider()
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                
                HStack {
                    Text(systemFlag)
                        .font(.system(size: 32))
                    
                    Spacer()
                    
                    Image(systemName: "gear")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                
                Spacer()
                
                Text(gradingSystem.systemName)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }
    
    private var systemFlag: String {
        switch gradingSystem.id {
        case "french": return "🇫🇷"
        case "usa": return "🇺🇸"
        case "germany": return "🇩🇪"
        case "uk": return "🇬🇧"
        default: return "⚙️"
        }
    }
}

struct EmptyStateCardView: View {
    let title: String
    let message: String
    let icon: String
    let color: Color
    
    var body: some View {
        BaseSmallCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                
                Divider()
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(color.opacity(0.6))
                    
                    Text(message)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}
