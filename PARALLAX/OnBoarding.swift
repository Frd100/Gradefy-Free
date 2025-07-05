//
//  OnBoarding.swift
//  PARALLAX
//
//  Created by Farid on 6/27/25.
//

import SwiftUI
import CoreData
import Combine
import UIKit

// MARK: - Models

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome = 0
    case system = 1
    case profile = 2
    case period = 3
    case completion = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: return "Bienvenue dans Gradefy"
        case .system: return "Système de Notation"
        case .profile: return "Votre Profil"
        case .period: return "Période Académique"
        case .completion: return "Configuration Terminée"
        }
    }

    var icon: String {
        switch self {
        case .welcome: return "graduationcap.fill"
        case .system: return "gear"
        case .profile: return "person.circle"
        case .period: return "calendar.badge.plus"
        case .completion: return "checkmark.seal.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .welcome: return .blue
        case .system: return .green
        case .profile: return .orange
        case .period: return .cyan
        case .completion: return .green
        }
    }

    var showIcon: Bool {
        switch self {
        case .welcome, .system, .profile: return false
        case .period, .completion: return true
        }
    }
}

struct FeatureItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct UserProfileData {
    var username: String = ""
    var userStatus: String = ""
    var selectedGradient: [Color] = [Color.blue, Color.purple]
    var selectedSystem: String = "france"
    var periodName: String = ""
    var periodStartDate: Date = Date()
    var periodEndDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()

    var isValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isPeriodValid: Bool {
        !periodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - ViewModel

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var userProfile = UserProfileData()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAnimating = false
    @Published var contentScale: CGFloat = 1.0
    @Published var contentOpacity: Double = 1.0
    @Published var buttonScale: CGFloat = 1.0
        

    private let persistentContainer: NSPersistentContainer
    private var backgroundContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.persistentContainer = PersistenceController.shared.container
        self.backgroundContext = persistentContainer.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        setupValidation()
    }

    private func setupValidation() {
        $userProfile
            .map(\.periodEndDate)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.validateDates()
            }
            .store(in: &cancellables)
    }

    private func validateDates() {
        if userProfile.periodEndDate <= userProfile.periodStartDate {
            userProfile.periodEndDate = Calendar.current.date(byAdding: .month, value: 1, to: userProfile.periodStartDate) ?? Date()
        }
    }

    var canProceed: Bool {
        switch currentStep {
        case .welcome, .system, .completion:
            return true
        case .profile:
            return userProfile.isValid
        case .period:
            return userProfile.isPeriodValid
        }
    }

    var buttonTitle: String {
        switch currentStep {
        case .welcome: return "Commencer"
        case .completion: return "Utiliser Gradefy"
        case .period: return "Créer la Période"
        default: return "Continuer"
        }
    }

    func next() {
        guard canProceed && !isAnimating else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        isAnimating = true

        switch currentStep {
        case .period:
            // ✅ PAS D'ANIMATION pour createPeriod - transition directe
            Task {
                await createPeriod()
                // Animation seulement APRÈS succès
                if errorMessage == nil {
                    await moveToNextWithoutAnimation()
                } else {
                    await MainActor.run {
                        isAnimating = false
                    }
                }
            }
        case .completion:
            finish()
            isAnimating = false
        default:
            // ✅ ANIMATION seulement pour les transitions normales
            // BOUNCE EFFECT DU BOUTON
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                buttonScale = 0.92
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    self.buttonScale = 1.0
                }
            }
            
            moveToNext()
        }
    }
    
    private func moveToNextWithoutAnimation() async {
        await MainActor.run {
            self.currentStep = OnboardingStep(rawValue: self.currentStep.rawValue + 1) ?? .completion
            self.isAnimating = false
        }
    }
    
    func back() {
        guard currentStep.rawValue > 0 && !isAnimating else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        isAnimating = true
        currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .welcome
        isAnimating = false
    }

    private func moveToNext() {
        // ✅ ANIMATION DE SORTIE (bounce out)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            contentScale = 0.95
            contentOpacity = 0.7
        }
        
        // ✅ DÉLAI PUIS CHANGEMENT DE VUE
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.currentStep = OnboardingStep(rawValue: self.currentStep.rawValue + 1) ?? .completion
            
            // ✅ ANIMATION D'ENTRÉE (bounce in)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.contentScale = 1.0
                self.contentOpacity = 1.0
            }
            
            self.isAnimating = false
        }
    }

    private func createPeriod() async {
        print("🔍 ===== DEBUT createPeriod() =====")
        print("🔍 Nom de période: '\(userProfile.periodName)'")
        print("🔍 Nom après trim: '\(userProfile.periodName.trimmingCharacters(in: .whitespacesAndNewlines))'")
        print("🔍 Date début: \(userProfile.periodStartDate)")
        print("🔍 Date fin: \(userProfile.periodEndDate)")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            var createdPeriodID: UUID?
            
            try await MainActor.run {
                print("🔍 Début sauvegarde Core Data...")
                backgroundContext.parent?.refreshAllObjects()
                
                let trimmedName = self.userProfile.periodName.trimmingCharacters(in: .whitespacesAndNewlines)
                let request: NSFetchRequest<Period> = Period.fetchRequest()
                request.predicate = NSPredicate(format: "name == %@", trimmedName)
                
                let mainContext = backgroundContext.parent ?? backgroundContext
                let existingPeriods = try mainContext.fetch(request)
                
                print("🔍 Vérification existence - Périodes trouvées: \(existingPeriods.count)")
                
                if !existingPeriods.isEmpty {
                    print("❌ Période existe déjà!")
                    throw NSError(domain: "OnboardingError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Une période avec ce nom existe déjà"])
                }

                let period = Period(context: mainContext)
                period.id = UUID()
                period.name = trimmedName
                period.startDate = self.userProfile.periodStartDate
                period.endDate = self.userProfile.periodEndDate
                
                createdPeriodID = period.id
                print("🔍 Période créée en mémoire - ID: \(period.id?.uuidString ?? "nil")")
                print("🔍 Période créée en mémoire - Nom: '\(period.name ?? "nil")'")
                
                if mainContext.hasChanges {
                    try mainContext.save()
                    print("✅ Context sauvegardé avec succès!")
                } else {
                    print("⚠️ Aucun changement à sauvegarder")
                }
                
                // Vérification que la période a bien été sauvegardée
                let verificationRequest: NSFetchRequest<Period> = Period.fetchRequest()
                let allPeriods = try mainContext.fetch(verificationRequest)
                print("🔍 Vérification - Total périodes après sauvegarde: \(allPeriods.count)")
                for p in allPeriods {
                    print("   - Période: '\(p.name ?? "nil")' - ID: \(p.id?.uuidString ?? "nil")")
                }
            }
            
            // Sauvegarde des préférences
            if let periodID = createdPeriodID {
                print("🔍 ===== DEBUT SAUVEGARDE PREFERENCES =====")
                
                savePreferences()
                
                let trimmedName = userProfile.periodName.trimmingCharacters(in: .whitespacesAndNewlines)
                print("🔍 Définition UserDefaults pour période: '\(trimmedName)'")
                
                // Vérification AVANT définition
                print("🔍 UserDefaults AVANT modification:")
                print("   - selectedPeriod: '\(UserDefaults.standard.string(forKey: "selectedPeriod") ?? "nil")'")
                print("   - onboardingPeriodProcessed: \(UserDefaults.standard.bool(forKey: "onboardingPeriodProcessed"))")
                print("   - hasCompletedOnboarding: \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")
                
                UserDefaults.standard.set(trimmedName, forKey: "selectedPeriod")
                UserDefaults.standard.set(false, forKey: "onboardingPeriodProcessed")
                UserDefaults.standard.synchronize()
                
                // Vérification APRÈS définition
                print("🔍 UserDefaults APRÈS modification:")
                print("   - selectedPeriod: '\(UserDefaults.standard.string(forKey: "selectedPeriod") ?? "nil")'")
                print("   - onboardingPeriodProcessed: \(UserDefaults.standard.bool(forKey: "onboardingPeriodProcessed"))")
                print("   - hasCompletedOnboarding: \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")
                
                print("✅ Période définie pour ContentView: '\(trimmedName)'")
                print("🔍 ===== FIN SAUVEGARDE PREFERENCES =====")
            } else {
                print("❌ createdPeriodID est nil!")
            }
                        
            await MainActor.run {
                isLoading = false
                print("✅ isLoading = false")
            }
            
        } catch {
            print("❌ ERREUR dans createPeriod(): \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
        
        print("🔍 ===== FIN createPeriod() =====")
    }

    private func savePreferences() {
        print("🔍 --- DEBUT savePreferences() ---")
        
        // Sauvegarde du profil utilisateur
        print("🔍 Sauvegarde username: '\(userProfile.username)'")
        UserDefaults.standard.set(userProfile.username, forKey: "username")
        
        print("🔍 Sauvegarde userStatus: '\(userProfile.userStatus)'")
        UserDefaults.standard.set(userProfile.userStatus, forKey: "profileSubtitle")
        
        print("🔍 Sauvegarde selectedSystem: '\(userProfile.selectedSystem)'")
        UserDefaults.standard.set(userProfile.selectedSystem, forKey: "GradingSystem")

        // Sauvegarde des couleurs du profil
        if userProfile.selectedGradient.count >= 2 {
            let startHex = userProfile.selectedGradient[0].toHex()
            let endHex = userProfile.selectedGradient[1].toHex()
            
            print("🔍 Sauvegarde couleurs: start=\(startHex), end=\(endHex)")
            UserDefaults.standard.set(startHex, forKey: "profileGradientStartHex")
            UserDefaults.standard.set(endHex, forKey: "profileGradientEndHex")
        } else {
            print("⚠️ selectedGradient n'a pas assez de couleurs: \(userProfile.selectedGradient.count)")
        }
        
        // Marquer l'onboarding comme terminé
        print("🔍 Marquage onboarding terminé")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        UserDefaults.standard.synchronize()
        print("✅ UserDefaults synchronisés")
        print("🔍 --- FIN savePreferences() ---")
    }



    // ✅ Modification de savePreferences pour inclure la période active
    private func savePreferences(activePeriodID: UUID?) {
        // Sauvegarde du profil utilisateur
        UserDefaults.standard.set(userProfile.username, forKey: "username")
        UserDefaults.standard.set(userProfile.userStatus, forKey: "profileSubtitle")
        UserDefaults.standard.set(userProfile.selectedSystem, forKey: "GradingSystem")

        // Sauvegarde des couleurs du profil
        if userProfile.selectedGradient.count >= 2 {
            UserDefaults.standard.set(userProfile.selectedGradient[0].toHex(), forKey: "profileGradientStartHex")
            UserDefaults.standard.set(userProfile.selectedGradient[1].toHex(), forKey: "profileGradientEndHex")
        }
        
        // ✅ NOUVEAU : Sauvegarde de la période active
        if let periodID = activePeriodID {
            UserDefaults.standard.set(periodID.uuidString, forKey: "selectedPeriodID")
            print("✅ Période active définie : \(periodID.uuidString)")
        }
        
        // ✅ Marquer l'onboarding comme terminé ET la période comme traitée
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(true, forKey: "onboardingPeriodProcessed")
        
        UserDefaults.standard.synchronize()
        print("✅ Toutes les préférences utilisateur sauvegardées")
    }

    
    private func mergeToMainContext() async {
        let viewContext = persistentContainer.viewContext
        
        await viewContext.perform {
            do {
                if viewContext.hasChanges {
                    try viewContext.save()
                }
            } catch {
                print("❌ Erreur merge vers main context: \(error)")
            }
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func clearError() {
        errorMessage = nil
    }

    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Main View

struct AppleStyleOnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView
                
                VStack(spacing: 0) {
                    Spacer(minLength: geometry.safeAreaInsets.top + 30)

                    contentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Spacer(minLength: 40)

                    actionButtons(geometry)  // ✅ Fonction maintenant définie
                }
            }
        }
        .onTapGesture {
            isTextFieldFocused = false
            viewModel.dismissKeyboard()
        }
        .alert("Erreur", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)  // ✅ Syntaxe corrigée
    }
    
    private func actionButtons(_ geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            // Bouton principal avec animation de rebond
            primaryButton
                .scaleEffect(viewModel.buttonScale)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.buttonScale)
            
            // Bouton retour
            backButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 16))
    }
    
    private var backgroundView: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            GeometricPattern(colorScheme: colorScheme)
                .opacity(0.1)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var contentView: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeView()
            case .system:
                SystemView(selectedSystem: $viewModel.userProfile.selectedSystem)
            case .profile:
                OnboardingProfileView(
                    userProfile: $viewModel.userProfile,
                    dismissKeyboard: viewModel.dismissKeyboard,
                    isTextFieldFocused: $isTextFieldFocused
                )
            case .period:
                PeriodView(
                    userProfile: $viewModel.userProfile,
                    dismissKeyboard: viewModel.dismissKeyboard,
                    isTextFieldFocused: $isTextFieldFocused
                )
            case .completion:
                CompletionView(username: viewModel.userProfile.username)
            }
        }
        // ✅ APPLICATIONS DES ANIMATIONS DE REBOND
        .scaleEffect(viewModel.contentScale)
        .opacity(viewModel.contentOpacity)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.contentScale)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.contentOpacity)
    }

    
    private var primaryButton: some View {
        Text(viewModel.isLoading ? "Chargement..." : viewModel.buttonTitle)
            .font(.headline.weight(.medium))
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(colorScheme == .dark ? .white : .black)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if !viewModel.isLoading && viewModel.canProceed && !viewModel.isAnimating {
                    viewModel.next()
                }
            }
            .padding(.horizontal, 24)
            .opacity((!viewModel.canProceed || viewModel.isLoading || viewModel.isAnimating) ? 0.6 : 1.0)
    }
    
    private var backButton: some View {
        ZStack {
            if viewModel.currentStep.rawValue > 0 && viewModel.currentStep != .completion {
                Button("Retour") {
                    isTextFieldFocused = false
                    viewModel.back()
                }
                .font(.headline)
                .foregroundColor(.blue)
                .disabled(viewModel.isAnimating)
            } else {
                Text("Retour")
                    .font(.headline)
                    .opacity(0)
            }
        }
        .frame(height: 44)
        .padding(.bottom, 8)
    }
}

// MARK: - Content Views

struct WelcomeView: View {
    private let features: [FeatureItem] = [
        FeatureItem(
            icon: "checkmark.circle.fill",
            title: "Multi-systèmes",
            description: "Obtenez le support de tous les systèmes de notation : France, USA, Allemagne, UK.",
            color: .green
        ),
        FeatureItem(
            icon: "person.2.fill",
            title: "Calculs automatiques",
            description: "Obtenez des moyennes pondérées en temps réel et des prédictions intelligentes.",
            color: .blue
        ),
        FeatureItem(
            icon: "calendar",
            title: "Flashcards intégrées",
            description: "Trouvez un système de révision par cartes directement intégré à l'application.",
            color: .orange
        ),
        FeatureItem(
            icon: "chart.bar.fill",
            title: "Statistiques détaillées",
            description: "Suivez votre progression avec des analyses avancées et des tendances personnelles.",
            color: .purple
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()

                titleSection
                
                Spacer(minLength: 30)

                featuresSection
                
                Spacer()
            }
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .center, spacing: 5) {
            Text("Bienvenue dans")
                .font(.largeTitle.bold())
                .foregroundColor(Color(UIColor.label))

            Text("Gradefy")
                .font(.largeTitle.bold())
                .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
    
    private var featuresSection: some View {
        VStack(spacing: 20) {
            ForEach(features) { feature in
                FeatureRow2(feature: feature)
            }
        }
        .padding(.horizontal, 24)
    }
}

struct FeatureRow2: View {
    let feature: FeatureItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: feature.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(feature.color)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(feature.title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Color(UIColor.label))

                Text(feature.description)
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct SystemView: View {
    @Binding var selectedSystem: String

    private let systems: [(id: String, flag: String, name: String, description: String)] = [
        ("france", "🇫🇷", "France", "0–20"),
        ("usa", "🇺🇸", "USA", "GPA 4.0"),
        ("germany", "🇩🇪", "Allemagne", "1–6"),
        ("uk", "🇬🇧", "UK", "Pourcentages")
    ]

    var body: some View {
        VStack(spacing: 30) {
            Text("Système de Notation")
                .font(.largeTitle.bold())
                .foregroundColor(Color(UIColor.label))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                ForEach(systems, id: \.id) { system in
                    SystemCard(
                        system: system,
                        isSelected: selectedSystem == system.id
                    ) {
                        let selectionFeedback = UISelectionFeedbackGenerator()
                        selectionFeedback.selectionChanged()
                        selectedSystem = system.id
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

struct SystemCard: View {
    let system: (id: String, flag: String, name: String, description: String)
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text(system.flag)
                        .font(.title3)

                    Text(system.name)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Color(UIColor.label))
                }

                Text(system.description)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color(UIColor.label))
            }

            Spacer()

            selectionIndicator
        }
        .padding(16)
        .background(cardBackground)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
    
    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.blue : Color(UIColor.systemGray3), lineWidth: 1.5)
                .frame(width: 20, height: 20)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(UIColor.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
    }
}

struct OnboardingProfileView: View {
    @Binding var userProfile: UserProfileData
    let dismissKeyboard: () -> Void
    @FocusState.Binding var isTextFieldFocused: Bool

    // ✅ NOUVELLE PALETTE : Les mêmes 5 couleurs que ProfileComponents
    private let gradients: [[Color]] = [
        [Color(hex: "9BE8F6"), Color(hex: "5DD5F4")], // Bleu clair inversé
        [Color(hex: "B0F4B6"), Color(hex: "78E089")], // Vert clair inversé
        [Color(hex: "FBB3C7"), Color(hex: "F68EB2")], // Rose vif inversé
        [Color(hex: "DBC7F9"), Color(hex: "C6A8EF")], // Violet pastel inversé
        [Color(hex: "F8C79B"), Color(hex: "F5A26A")]  // Orange doux inversé
    ]

    var body: some View {
        VStack(spacing: 30) {
            Text("Votre Profil")
                .font(.largeTitle.bold())
                .foregroundColor(Color(UIColor.label))
                .multilineTextAlignment(.center)

            VStack(spacing: 20) {
                profilePreview
                inputFields
                colorSelection
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var profilePreview: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: userProfile.selectedGradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Text(userProfile.username.isEmpty ? "" : String(userProfile.username.prefix(1).uppercased()))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(userProfile.username.isEmpty ? "Ajouter un nom" : userProfile.username)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Color(UIColor.label))

                Text(userProfile.userStatus.isEmpty ? "Ajouter un statut" : userProfile.userStatus)
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    private var inputFields: some View {
        VStack(spacing: 12) {
            ModernTextField(
                text: $userProfile.username,
                placeholder: "Ajouter un nom",
                dismissKeyboard: dismissKeyboard,
                isTextFieldFocused: $isTextFieldFocused
            )
            ModernTextField(
                text: $userProfile.userStatus,
                placeholder: "Ajouter un statut",
                dismissKeyboard: dismissKeyboard,
                isTextFieldFocused: $isTextFieldFocused
            )
        }
    }
    
    // ✅ NOUVELLE SECTION COULEUR : Même style que ProfileComponents
    private var colorSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Couleur du profil")
                .font(.headline.weight(.semibold))
                .foregroundColor(Color(UIColor.label))

            // Layout horizontal identique à ProfileComponents
            HStack(spacing: 20) {
                ForEach(gradients.indices, id: \.self) { index in
                    OnboardingGradientButton(
                        gradient: gradients[index],
                        isSelected: userProfile.selectedGradient == gradients[index]
                    ) {
                        let selectionFeedback = UISelectionFeedbackGenerator()
                        selectionFeedback.selectionChanged()
                        userProfile.selectedGradient = gradients[index]
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
}

// ✅ NOUVEAU COMPOSANT : Bouton gradient minimal pour l'onboarding
struct OnboardingGradientButton: View {
    let gradient: [Color]
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: gradient),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 50, height: 50)
            // ✅ AUCUN INDICATEUR : Identique à ProfileComponents
        }
        .buttonStyle(.plain)
    }
}
struct ModernTextField: View {
    @Binding var text: String
    let placeholder: String
    let dismissKeyboard: () -> Void
    @FocusState.Binding var isTextFieldFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.headline)
            .foregroundColor(Color(UIColor.label))
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.tertiarySystemBackground))
            )
            .focused($isTextFieldFocused)
            .submitLabel(.done)
            .onSubmit {
                isTextFieldFocused = false
                dismissKeyboard()
            }
    }
}

struct PeriodView: View {
    @Binding var userProfile: UserProfileData
    let dismissKeyboard: () -> Void
    @FocusState.Binding var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 30) {
            Text("Période Académique")
                .font(.largeTitle.bold())
                .foregroundColor(Color(UIColor.label))
                .multilineTextAlignment(.center)

            VStack(spacing: 20) {
                nameField
                dateSelection
                infoText
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var nameField: some View {
        ModernTextField(
            text: $userProfile.periodName,
            placeholder: "Nom de la période",
            dismissKeyboard: dismissKeyboard,
            isTextFieldFocused: $isTextFieldFocused
        )
    }
    
    private var dateSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dates de la période")
                .font(.headline.weight(.semibold))
                .foregroundColor(Color(UIColor.label))

            HStack(spacing: 16) {
                dateField(title: "Début", date: $userProfile.periodStartDate)
                dateField(title: "Fin", date: $userProfile.periodEndDate)
            }
        }
    }
    
    private func dateField(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Color(UIColor.secondaryLabel))

            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }
    
    private var infoText: some View {
        Text("Cette période servira à organiser vos matières et évaluations.")
            .font(.subheadline)
            .foregroundColor(Color(UIColor.secondaryLabel))
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }
}

struct CompletionView: View {
    let username: String

    var body: some View {
        VStack(spacing: 30) {
            Text("Configuration Terminée")
                .font(.largeTitle.bold())
                .foregroundColor(Color(UIColor.label))
                .multilineTextAlignment(.center)

            VStack(spacing: 24) {
                Text("Gradefy est maintenant configuré selon vos préférences")
                    .font(.title3)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    CompletionItem(icon: "person.circle.fill", text: "Profil personnalisé", color: .green)
                    CompletionItem(icon: "globe", text: "Système de notation configuré", color: .blue)
                    CompletionItem(icon: "calendar.badge.plus", text: "Première période créée", color: .purple)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

struct CompletionItem: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.headline)
                .foregroundColor(Color(UIColor.label))

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.green)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Geometric Pattern Background

struct GeometricPattern: View {
    let colorScheme: ColorScheme

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 40
            let rows = Int(size.height / spacing) + 1
            let cols = Int(size.width / spacing) + 1

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing

                    let rect = CGRect(x: x, y: y, width: 2, height: 2)
                    let color = colorScheme == .dark ?
                        Color.white.opacity(0.1) :
                        Color.black.opacity(0.1)

                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }
}

// MARK: - Preview

struct OnboardingPreview: PreviewProvider {
    static var previews: some View {
        Group {
            AppleStyleOnboardingView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .preferredColorScheme(.light)
                .previewDisplayName("Mode Clair")

            AppleStyleOnboardingView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .preferredColorScheme(.dark)
                .previewDisplayName("Mode Sombre")
        }
    }
}
