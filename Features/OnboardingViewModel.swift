//
// OnboardingViewModel.swift
// PARALLAX
//
// Created by  on 6/27/25.
//

import Combine
import CoreData
import Foundation
import SwiftUI
import UIKit

// MARK: - Models

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case intro = 0
    case welcome = 1
    case system = 2
    case profile = 3
    case period = 4
    case completion = 5

    var id: Int { rawValue }

    var title: String {
        print("🔍 [OnboardingStep] Getting title for step: \(self)")
        switch self {
        case .intro: return ""
        case .welcome: return ""
        case .system: return ""
        case .profile: return ""
        case .period: return ""
        case .completion: return ""
        }
    }

    var icon: String {
        print("🔍 [OnboardingStep] Getting icon for step: \(self)")
        switch self {
        case .intro: return "app.fill"
        case .welcome: return "graduationcap.fill"
        case .system: return "gear"
        case .profile: return "person.circle"
        case .period: return "calendar.badge.plus"
        case .completion: return "checkmark.seal.fill"
        }
    }

    var iconColor: Color {
        print("🔍 [OnboardingStep] Getting iconColor for step: \(self)")
        switch self {
        case .intro: return .blue
        case .welcome: return .blue
        case .system: return .green
        case .profile: return .orange
        case .period: return .cyan
        case .completion: return .green
        }
    }

    var showIcon: Bool {
        print("🔍 [OnboardingStep] Getting showIcon for step: \(self)")
        switch self {
        case .intro: return false
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
    var selectedGradient: [Color] = [Color(hex: "8B95A8"), Color(hex: "4A5568")]
    var selectedSystem: String = UserDefaults.standard.string(forKey: "GradingSystem") ?? "usa"
    var periodName: String = ""
    var periodStartDate: Date = .init()
    var periodEndDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()

    var isValid: Bool {
        print("🔍 [UserProfileData] Checking isValid - username: '\(username)'")
        return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isPeriodValid: Bool {
        print("🔍 [UserProfileData] Checking isPeriodValid - periodName: '\(periodName)'")
        return !periodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var path = NavigationPath() {
        didSet {
            print("🔍 [OnboardingViewModel] path changed - count: \(path.count)")
            currentStepRaw = path.count
            // Invalider les caches quand le path change
            invalidateCaches()
        }
    }

    @Published var userProfile = UserProfileData() {
        didSet {
            print("🔍 [OnboardingViewModel] userProfile changed")
            _cachedCanProceed = nil // Invalider seulement canProceed
        }
    }

    @Published var isLoading = false {
        didSet {
            print("🔍 [OnboardingViewModel] isLoading changed: \(isLoading)")
            _cachedCanProceed = nil
            _cachedButtonTitle = nil
        }
    }

    @Published var errorMessage: String?
    @Published var isOnboardingCompleted = false

    @Published private var currentStepRaw: Int = 0

    // ✅ AJOUT : Cache pour éviter les recalculs constants
    private var _cachedCanProceed: Bool?
    private var _cachedButtonTitle: String?

    var onOnboardingComplete: (() -> Void)?

    private let persistentContainer: NSPersistentContainer
    private var cancellables = Set<AnyCancellable>()

    init() {
        print("🔍 [OnboardingViewModel] init() appelé")
        persistentContainer = PersistenceController.shared.container
        setupValidation()
    }

    // ✅ MÉTHODE OPTIMISÉE avec cache
    var currentStep: OnboardingStep {
        let step = OnboardingStep(rawValue: currentStepRaw) ?? .intro
        print("🔍 [OnboardingViewModel] currentStep calculé: \(step) (raw value: \(currentStepRaw))")
        return step
    }

    // ✅ MÉTHODE OPTIMISÉE avec cache
    var canProceed: Bool {
        if let cached = _cachedCanProceed {
            return cached
        }

        let result: Bool
        let step = currentStep

        switch step {
        case .intro, .welcome, .system, .completion:
            result = true
        case .profile:
            result = !userProfile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .period:
            result = !userProfile.periodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
        }

        _cachedCanProceed = result
        print("🔍 [OnboardingViewModel] canProceed calculé pour \(step): \(result)")
        return result
    }

    var buttonTitle: String {
        if let cached = _cachedButtonTitle {
            return cached
        }

        if isLoading {
            _cachedButtonTitle = String(localized: "onboarding_loading")
            return String(localized: "onboarding_loading")
        }

        let title: String
        switch currentStep {
        case .intro:
            title = String(localized: "onboarding_start")
        case .welcome:
            title = String(localized: "onboarding_continue")
        case .completion:
            title = String(localized: "onboarding_use_app")
        case .period:
            title = String(localized: "onboarding_create_period")
        default:
            title = String(localized: "onboarding_continue")
        }

        _cachedButtonTitle = title
        print("🔍 [OnboardingViewModel] buttonTitle calculé: '\(title)'")
        return title
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
        print("🔍 [OnboardingViewModel] validateDates() appelé")
        print("🔍 [OnboardingViewModel] Start date: \(userProfile.periodStartDate)")
        print("🔍 [OnboardingViewModel] End date: \(userProfile.periodEndDate)")

        if userProfile.periodEndDate <= userProfile.periodStartDate {
            userProfile.periodEndDate = Calendar.current.date(byAdding: .month, value: 1, to: userProfile.periodStartDate) ?? Date()
            print("⚠️ [OnboardingViewModel] Date corrigée: \(userProfile.periodEndDate)")
        }
    }

    // ✅ NOUVELLE MÉTHODE pour invalider tous les caches
    private func invalidateCaches() {
        print("🧹 [OnboardingViewModel] Invalidation de tous les caches")
        _cachedCanProceed = nil
        _cachedButtonTitle = nil
    }

    // ✅ MÉTHODE AMÉLIORÉE de reset
    func resetToInitialState() {
        print("🔄 [OnboardingViewModel] resetToInitialState() appelé")

        // Reset complet avec invalidation des caches
        path = NavigationPath()
        currentStepRaw = 0
        userProfile = UserProfileData()
        isLoading = false
        errorMessage = nil
        isOnboardingCompleted = false

        // Invalidation explicite des caches
        invalidateCaches()

        // Reset des observateurs
        cancellables.removeAll()
        setupValidation()

        print("✅ [OnboardingViewModel] État complètement réinitialisé")
    }

    // Reste de vos méthodes inchangées...
    func nextStep() {
        guard canProceed else {
            print("⚠️ [OnboardingViewModel] Cannot proceed")
            return
        }
        guard !isLoading else {
            print("⚠️ [OnboardingViewModel] Loading in progress")
            return
        }

        print("🔍 === [NEXT_STEP] DÉBUT ===")
        print("🔍 [NEXT_STEP] Current step: \(currentStep)")
        print("🔍 [NEXT_STEP] Path count: \(path.count)")

        // Invalider les caches avant la transition
        invalidateCaches()

        HapticFeedbackManager.shared.impact(style: .medium)

        if currentStep == .profile {
            print("📝 [NEXT_STEP] Étape PROFILE - sauvegarde des données")
            saveProfileData()
        }

        if currentStep == .period {
            print("📅 [NEXT_STEP] Étape PERIOD - création de la période")
            Task {
                await createPeriod()
                if errorMessage == nil {
                    print("✅ [TASK] Période créée - transition vers completion")
                    await MainActor.run {
                        let nextRaw = currentStep.rawValue + 1
                        currentStepRaw = nextRaw
                        withAnimation(.easeInOut(duration: 0.3)) {
                            path.append(nextRaw)
                        }
                    }
                }
            }
            return
        }

        if currentStep == .completion {
            print("🎉 [NEXT_STEP] Étape COMPLETION - finalisation onboarding")
            finishOnboarding()
            return
        }

        print("➡️ [NEXT_STEP] Transition normale vers étape suivante")
        let nextRaw = currentStep.rawValue + 1
        currentStepRaw = nextRaw
        withAnimation(.easeInOut(duration: 0.3)) {
            path.append(nextRaw)
        }
    }

    // ✅ ANCIENNE MÉTHODE - Ne touche PAS au système de notation
    private func saveProfileData() {
        print("🔍 --- DEBUT saveProfileData() ---")
        print("🔍 Username: '\(userProfile.username)'")
        print("🔍 Système sélectionné: '\(userProfile.selectedSystem)'")

        // ✅ SEULEMENT username et couleurs - PAS le système
        UserDefaults.standard.set(userProfile.username, forKey: "username")

        if userProfile.selectedGradient.count >= 2 {
            let profileGradientStartHex = userProfile.selectedGradient[0].toHex()
            let profileGradientEndHex = userProfile.selectedGradient[1].toHex()

            UserDefaults.standard.set(profileGradientStartHex, forKey: "profileGradientStartHex")
            UserDefaults.standard.set(profileGradientEndHex, forKey: "profileGradientEndHex")

            print("🔍 Couleurs sauvegardées: \(profileGradientStartHex) -> \(profileGradientEndHex)")
        }

        UserDefaults.standard.synchronize()
        print("✅ Profil sauvegardé dans UserDefaults")
        print("🔍 --- FIN saveProfileData() ---")
    }

    private func finishOnboarding() {
        print("🎉 ===== ONBOARDING TERMINÉ =====")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.synchronize()

        NotificationCenter.default.post(
            name: NSNotification.Name("OnboardingCompleted"),
            object: nil
        )

        print("✅ hasCompletedOnboarding = true")
        print("🎉 ===== NAVIGATION VERS APP PRINCIPALE =====")

        onOnboardingComplete?()
    }

    // ✅ ANCIENNE MÉTHODE - Avec continuation et background context
    private func createPeriod() async {
        print("🏗️ === [CREATE_PERIOD] DÉBUT ===")

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            // ✅ ANCIENNE MÉTHODE avec withCheckedThrowingContinuation
            let createdPeriodID = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UUID, Error>) in
                persistentContainer.performBackgroundTask { backgroundContext in
                    do {
                        print("💾 [BACKGROUND] Création Period dans background context")

                        let newPeriod = Period(context: backgroundContext)
                        newPeriod.id = UUID()
                        newPeriod.name = self.userProfile.periodName
                        newPeriod.startDate = self.userProfile.periodStartDate
                        newPeriod.endDate = self.userProfile.periodEndDate
                        newPeriod.createdAt = Date()

                        print("💾 [BACKGROUND] Période configurée: '\(newPeriod.name ?? "sans nom")'")

                        try backgroundContext.save()
                        let periodID = newPeriod.id ?? UUID()

                        print("✅ [BACKGROUND] Période sauvegardée avec ID: \(periodID)")
                        continuation.resume(returning: periodID)

                    } catch {
                        print("❌ [BACKGROUND] Erreur création période: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }

            // ✅ SAUVEGARDE CONFIGURATION après création période
            print("⚙️ [CREATE_PERIOD] Sauvegarde configuration centralisée")
            await saveConfigurationCentralized(activePeriodID: createdPeriodID.uuidString)

        } catch {
            print("❌ [CREATE_PERIOD] Erreur: \(error)")
            await MainActor.run {
                errorMessage = "Erreur lors de la création de la période: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isLoading = false
        }

        print("🏗️ === [CREATE_PERIOD] FIN ===")
    }

    // ✅ ANCIENNE MÉTHODE - Configuration centralisée simple
    private func saveConfigurationCentralized(activePeriodID: String) async {
        print("⚙️ === [SAVE_CONFIG] DÉBUT ===")

        let configManager = ConfigurationManager(context: persistentContainer.viewContext)

        // Extraction couleurs
        let startHex: String
        let endHex: String

        if userProfile.selectedGradient.count >= 2 {
            startHex = userProfile.selectedGradient[0].toHex()
            endHex = userProfile.selectedGradient[1].toHex()
            print("🎨 [SAVE_CONFIG] Couleurs extraites: \(startHex) -> \(endHex)")
        } else {
            startHex = "#8B95A8"
            endHex = "#4A5568"
            print("⚠️ [SAVE_CONFIG] Utilisation des couleurs par défaut")
        }

        do {
            // ✅ ANCIENNE MÉTHODE - Configuration simple et directe
            try await configManager.saveUserConfiguration(
                username: userProfile.username,
                selectedSystem: userProfile.selectedSystem,
                profileGradientStart: startHex.hasPrefix("#") ? startHex : "#\(startHex)",
                profileGradientEnd: endHex.hasPrefix("#") ? endHex : "#\(endHex)",
                activePeriodID: activePeriodID
            )

            print("✅ [SAVE_CONFIG] Configuration sauvegardée")
            print("✅ [SAVE_CONFIG] Système final: \(userProfile.selectedSystem)")

        } catch {
            print("❌ [SAVE_CONFIG] Erreur sauvegarde: \(error)")
            await MainActor.run {
                errorMessage = "Erreur lors de la sauvegarde: \(error.localizedDescription)"
            }
        }

        print("⚙️ === [SAVE_CONFIG] FIN ===")
    }

    func clearError() {
        print("🔍 [OnboardingViewModel] clearError() appelé")
        errorMessage = nil
    }

    func dismissKeyboard() {
        print("🔍 [OnboardingViewModel] dismissKeyboard() appelé")
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct IntroView: View {
    var body: some View {
        print("👀 [IntroView] body appelé")
        return VStack(spacing: 40) {
            Spacer()

            // Logo de l'application
            Image("AppIconPreview")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .onAppear {
                    print("👀 [IntroView] Logo appeared")
                }

            // Titre et sous-titre
            VStack(spacing: 16) {
                Text(String(localized: "intro_welcome_title"))
                    .font(.title.bold())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(String(localized: "intro_subtitle"))
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            print("👀 [IntroView] View appeared")
        }
        .onDisappear {
            print("👋 [IntroView] View disappeared")
        }
    }
}

// MARK: - Main View

struct AppleStyleOnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.colorScheme) var colorScheme

    // ✅ AJOUT : Stabilité de l'instance
    @State private var viewID = UUID()

    let onCompletion: () -> Void

    init(onCompletion: @escaping () -> Void) {
        print("🔍 [AppleStyleOnboardingView] init() appelé")
        self.onCompletion = onCompletion
    }

    var body: some View {
        _ = print("👀 [AppleStyleOnboardingView] body appelé - viewID: \(viewID)")

        return NavigationStack(path: $viewModel.path) {
            viewForStep(.intro)
                .navigationBarHidden(viewModel.currentStep == .intro || viewModel.currentStep == .welcome)
                .navigationDestination(for: Int.self) { stepValue in
                    _ = print("🧭 [AppleStyleOnboardingView] Navigation to step: \(stepValue)")
                    return viewForStep(OnboardingStep(rawValue: stepValue) ?? .intro)
                        .navigationTitle(OnboardingStep(rawValue: stepValue)?.title ?? "")
                        .navigationBarTitleDisplayMode(.large)
                        .navigationBarBackButtonHidden(true)
                        .onAppear {
                            print("👀 [AppleStyleOnboardingView] Navigation destination appeared for step: \(stepValue)")
                            // Désactiver le geste de retour
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first,
                               let navigationController = window.rootViewController as? UINavigationController ??
                               window.rootViewController?.navigationController
                            {
                                navigationController.interactivePopGestureRecognizer?.isEnabled = false
                            }
                        }
                }
        }
        .id(viewID) // ✅ Identifiant stable pour cette instance
        .onAppear {
            print("👀 [AppleStyleOnboardingView] Main view appeared - viewID: \(viewID)")
        }
        .onDisappear {
            print("👋 [AppleStyleOnboardingView] Main view disappeared - viewID: \(viewID)")
            // Reset du ViewModel quand la vue disparaît
            viewModel.resetToInitialState()
        }
        .alert("Erreur", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                print("🔍 [AppleStyleOnboardingView] Error alert dismissed")
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    @ViewBuilder
    private func viewForStep(_ step: OnboardingStep) -> some View {
        _ = print("🔍 [AppleStyleOnboardingView] viewForStep appelé pour: \(step)")
        GeometryReader { geometry in
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                // Contenu principal
                VStack(spacing: 0) {
                    currentStepContent(step)

                    // Spacer pour pousser le contenu vers le haut
                    Spacer()
                }

                // Bouton fixe en overlay
                VStack {
                    Spacer()

                    primaryButton
                        .padding(.horizontal, 30)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                        .background(
                            // Fond blanc pour masquer le contenu qui scroll derrière
                            Rectangle()
                                .fill(Color(UIColor.systemBackground))
                                .frame(height: 120)
                                .blur(radius: 0.5)
                        )
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onTapGesture(perform: viewModel.dismissKeyboard)
    }

    @ViewBuilder
    private func currentStepContent(_ step: OnboardingStep) -> some View {
        _ = print("🔍 [AppleStyleOnboardingView] currentStepContent pour: \(step)")
        switch step {
        case .intro:
            IntroView()
        case .welcome:
            WelcomeView()
        case .system:
            SystemView(selectedSystem: $viewModel.userProfile.selectedSystem)
        case .profile:
            OnboardingProfileView(userProfile: $viewModel.userProfile)
        case .period:
            PeriodView(userProfile: $viewModel.userProfile)
        case .completion:
            CompletionView(username: viewModel.userProfile.username)
                .onAppear {
                    print("🎉 === COMPLETION VIEW APPEARED ===")
                    print("🔍 Current step: \(viewModel.currentStep)")
                    print("🔍 Path count: \(viewModel.path.count)")
                }
        }
    }

    private var primaryButton: some View {
        print("🔍 [AppleStyleOnboardingView] primaryButton créé")
        return Button(action: {
            print("🔍 [AppleStyleOnboardingView] primaryButton tapped")
            viewModel.nextStep()
        }) {
            Text(viewModel.isLoading ? "Chargement..." : viewModel.buttonTitle)
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(viewModel.canProceed && !viewModel.isLoading ? Color.blue : Color.gray)
                )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canProceed || viewModel.isLoading)
    }
}

struct WelcomeView: View {
    private var features: [FeatureItem] {
        [
            FeatureItem(
                icon: "plus.forwardslash.minus",
                title: String(localized: "feature_calculations_title"),
                description: String(localized: "feature_calculations_description"),
                color: .green
            ),
            FeatureItem(
                icon: "rectangle.portrait.on.rectangle.portrait.angled",
                title: String(localized: "feature_revision_title"),
                description: String(localized: "feature_revision_description"),
                color: .blue
            ),
            FeatureItem(
                icon: "calendar.badge.clock",
                title: String(localized: "feature_tracking_title"),
                description: String(localized: "feature_tracking_description"),
                color: .orange
            ),
            FeatureItem(
                icon: "stopwatch",
                title: String(localized: "feature_weekly_title"),
                description: String(localized: "feature_weekly_description"),
                color: .mint
            ),
        ]
    }

    var body: some View {
        print("👀 [WelcomeView] body appelé")
        return VStack(spacing: 40) {
            Spacer()

            // Titre simple comme dans IntroView
            Text(String(localized: "welcome_features_title"))
                .font(.title.bold())
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            // Features directement sans wrapper List
            VStack(spacing: 24) {
                ForEach(features) { feature in
                    FeatureRow2(feature: feature)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            print("👀 [WelcomeView] View appeared")
        }
        .onDisappear {
            print("👋 [WelcomeView] View disappeared")
        }
    }
}

struct FeatureRow2: View {
    let feature: FeatureItem

    var body: some View {
        print("👀 [FeatureRow2] body pour feature: \(feature.title)")
        return HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.title3.weight(.medium))
                .foregroundColor(feature.color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))

                Text(feature.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // ✅ AJOUTÉ : Le Spacer pousse tout le contenu à gauche.
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct KeyboardAdaptive: ViewModifier {
    func body(content: Content) -> some View {
        print("🔍 [KeyboardAdaptive] Modifier appliqué")
        return content
            .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        modifier(KeyboardAdaptive())
    }
}

struct OnboardingProfileView: View {
    @Binding var userProfile: UserProfileData
    @FocusState private var isTextFieldFocused: Bool

    // ✅ EXACTEMENT LES MÊMES GRADIENTS QUE EditProfileSheet
    private let availableGradients: [[Color]] = [
        // Gris bleu clair → Gris bleu foncé
        [Color(hex: "8B95A8"), Color(hex: "4A5568")],

        // Violet lavande clair → Violet lavande foncé
        [Color(hex: "B8A9DC"), Color(hex: "6B46C1")],

        // Bleu ciel clair → Bleu ciel foncé
        [Color(hex: "87CEEB"), Color(hex: "2563EB")],

        // Rose clair → Rose foncé
        [Color(hex: "F8BBD9"), Color(hex: "EC4899")],

        // Beige/Jaune clair → Beige/Jaune foncé
        [Color(hex: "F3E8A6"), Color(hex: "D69E2E")],

        // Vert menthe clair → Vert menthe foncé
        [Color(hex: "A7E6A3"), Color(hex: "16A085")],

        // Taupe/Marron clair → Taupe/Marron foncé
        [Color(hex: "C8A882"), Color(hex: "8B5A2B")],

        // Orange pêche clair → Orange pêche foncé
        [Color(hex: "FFB07A"), Color(hex: "E67E22")],

        // Lavande gris clair → Lavande gris foncé
        [Color(hex: "D1C4E9"), Color(hex: "7B1FA2")],

        // Bleu acier clair → Bleu acier foncé
        [Color(hex: "90A4AE"), Color(hex: "263238")],

        // Turquoise menthe clair → Turquoise menthe foncé
        [Color(hex: "A8E6CF"), Color(hex: "00695C")],

        // Violet magenta clair → Violet magenta foncé
        [Color(hex: "E1BEE7"), Color(hex: "8E24AA")],

        // Cyan aqua clair → Cyan aqua foncé
        [Color(hex: "81D4FA"), Color(hex: "0097A7")],

        // Vert lime clair → Vert lime foncé
        [Color(hex: "C8E6C9"), Color(hex: "388E3C")],
    ]

    var body: some View {
        print("👀 [OnboardingProfileView] body appelé - username: '\(userProfile.username)'")
        return VStack(spacing: 0) {
            // Header fixe - ne bouge jamais
            VStack(spacing: 32) {
                Text(String(localized: "profile_title"))
                    .font(.title.bold())
                    .foregroundColor(.primary)

                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: userProfile.selectedGradient),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(userProfile.username.isEmpty ? "" :
                            String(userProfile.username.prefix(1).uppercased()))
                            .font(.title.bold())
                            .foregroundColor(.white)
                    )
            }
            .padding(.top, 40)
            .padding(.bottom, 20)

            // Zone scrollable avec le contenu
            ScrollView {
                VStack(spacing: 24) {
                    // Champ de texte avec focus automatique
                    TextField(String(localized: "field_name"), text: $userProfile.username)
                        .focused($isTextFieldFocused)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                        .onChange(of: userProfile.username) { _, newValue in
                            print("🔍 [OnboardingProfileView] Username changed to: '\(newValue)'")
                        }

                    // Sélection de couleurs - MÊME LOGIQUE QUE EditProfileSheet
                    colorSelectionGrid

                    // Espacement pour éviter que le contenu soit masqué
                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            print("👀 [OnboardingProfileView] View appeared")
            // Focus automatique sur le TextField avec un petit délai
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔍 [OnboardingProfileView] Setting focus on text field")
                isTextFieldFocused = true
            }
        }
        .onDisappear {
            print("👋 [OnboardingProfileView] View disappeared")
        }
    }

    private var colorSelectionGrid: some View {
        print("🔍 [OnboardingProfileView] colorSelectionGrid créé")
        return VStack(spacing: 12) {
            // Première ligne (0 à 6) - IDENTIQUE À EditProfileSheet
            HStack(spacing: 16) {
                ForEach(0 ..< 7, id: \.self) { index in
                    MinimalGradientButton(
                        gradient: availableGradients[index],
                        isSelected: userProfile.selectedGradient == availableGradients[index]
                    ) {
                        print("🎨 [OnboardingProfileView] Gradient sélectionné: index \(index)")
                        HapticFeedbackManager.shared.selection()
                        userProfile.selectedGradient = availableGradients[index]
                    }
                }
            }

            // Deuxième ligne (7 à 13) - IDENTIQUE À EditProfileSheet
            HStack(spacing: 16) {
                ForEach(7 ..< 14, id: \.self) { index in
                    MinimalGradientButton(
                        gradient: availableGradients[index],
                        isSelected: userProfile.selectedGradient == availableGradients[index]
                    ) {
                        print("🎨 [OnboardingProfileView] Gradient sélectionné: index \(index)")
                        HapticFeedbackManager.shared.selection()
                        userProfile.selectedGradient = availableGradients[index]
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct OnboardingGradientButton: View {
    let gradient: [Color]
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        print("👀 [OnboardingGradientButton] body - isSelected: \(isSelected)")
        return Button(action: action) {
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: gradient),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 40, height: 40) // Réduit de 50 à 40 pour mieux s'adapter
                .overlay(
                    Circle()
                        .stroke(Color.blue, lineWidth: isSelected ? 3 : 0)
                        .animation(.spring(), value: isSelected)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PeriodView: View {
    @Binding var userProfile: UserProfileData
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        print("👀 [PeriodView] body appelé - periodName: '\(userProfile.periodName)'")
        return VStack(spacing: 40) {
            Spacer()

            // ✅ TITRE CENTRÉ
            Text(String(localized: "period_title"))
                .font(.title.bold())
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            VStack(spacing: 32) {
                // ✅ SECTION NOM DE LA PÉRIODE
                VStack(spacing: 8) {
                    TextField(String(localized: "field_name"), text: $userProfile.periodName)
                        .focused($isTextFieldFocused)
                        .submitLabel(.next)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                        .onChange(of: userProfile.periodName) { _, newValue in
                            print("🔍 [PeriodView] Period name changed to: '\(newValue)'")
                        }
                }

                // ✅ SECTION DATES
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        DatePicker(String(localized: "field_start_date"), selection: $userProfile.periodStartDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemBackground))
                            )
                            .onChange(of: userProfile.periodStartDate) { _, newValue in
                                print("🔍 [PeriodView] Start date changed to: \(newValue)")
                            }

                        DatePicker(String(localized: "field_end_date"), selection: $userProfile.periodEndDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemBackground))
                            )
                            .onChange(of: userProfile.periodEndDate) { _, newValue in
                                print("🔍 [PeriodView] End date changed to: \(newValue)")
                            }
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()
            Spacer()
            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            print("👀 [PeriodView] View appeared")
            isTextFieldFocused = true
        }
        .onDisappear {
            print("👋 [PeriodView] View disappeared")
        }
    }
}

struct CompletionView: View {
    let username: String

    var body: some View {
        print("👀 [CompletionView] body appelé - username: '\(username)'")
        return VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            VStack(spacing: 16) {
                Text(String(localized: "completion_ready_title").replacingOccurrences(of: "%@", with: username))
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(String(localized: "completion_configured"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                CompletionItem(
                    icon: "person.circle.fill",
                    text: String(localized: "completion_profile"),
                    color: .green
                )
                CompletionItem(
                    icon: "globe",
                    text: String(localized: "completion_grading_system"),
                    color: .blue
                )
                CompletionItem(
                    icon: "calendar.badge.plus",
                    text: String(localized: "completion_academic_period"),
                    color: .purple
                )
            }
            .padding(.top, 20)

            Spacer()
            Spacer()
            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            print("👀 [CompletionView] View appeared")
        }
        .onDisappear {
            print("👋 [CompletionView] View disappeared")
        }
    }
}

// N'oubliez pas de garder cette struct que nous avons créée précédemment.
struct SystemView: View {
    @Binding var selectedSystem: String

    private var systems: [SystemItem] {
        [
            SystemItem(id: "usa", flag: "🇺🇸", name: String(localized: "country_usa"), description: "GPA"),
            SystemItem(id: "canada", flag: "🇨🇦", name: String(localized: "country_canada"), description: "GPA"),
            SystemItem(id: "france", flag: "🇫🇷", name: String(localized: "country_france"), description: "0–20"),
            SystemItem(id: "germany", flag: "🇩🇪", name: String(localized: "country_germany"), description: "1–6"),
            SystemItem(id: "spain", flag: "🇪🇸", name: String(localized: "country_spain"), description: "0–10"),
        ]
    }

    var body: some View {
        print("👀 [SystemView] body appelé - selectedSystem: '\(selectedSystem)'")
        return VStack(spacing: 20) {
            Spacer()

            Text(String(localized: "system_selection_title"))
                .font(.title.bold())
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            // ✅ REMPLACEMENT : VStack au lieu de List
            VStack(spacing: 16) {
                ForEach(systems) { system in
                    SystemCardDisplay(
                        system: system,
                        isSelected: selectedSystem == system.id
                    )
                    .onTapGesture {
                        print("🔍 [SystemView] System selected: \(system.id)")
                        HapticFeedbackManager.shared.selection()
                        selectedSystem = system.id
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedSystem == system.id ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1.5)
                    )
                }
            }
            .padding(.horizontal, 0)

            Spacer()
            Spacer()
            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            print("👀 [SystemView] View appeared")
        }
        .onDisappear {
            print("👋 [SystemView] View disappeared")
        }
    }
}

// Nouvelle version sans gestion de tap
struct SystemCardDisplay: View {
    let system: SystemItem
    let isSelected: Bool

    var body: some View {
        print("👀 [SystemCardDisplay] body - system: \(system.id), isSelected: \(isSelected)")
        return HStack(spacing: 16) {
            Text(system.flag)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(system.name)
                    .font(.headline)

                Text(system.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .transition(.scale.animation(.spring(response: 0.3, dampingFraction: 0.7)))
            }
        }
        .padding()
        .contentShape(Rectangle())
    }
}

struct SystemItem: Identifiable {
    let id: String
    let flag: String
    let name: String
    let description: String
}

// SystemCard reste la même, elle fonctionne parfaitement dans une List
struct SystemCard: View {
    let system: SystemItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        print("👀 [SystemCard] body - system: \(system.id), isSelected: \(isSelected)")
        return HStack(spacing: 16) {
            Text(system.flag)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(system.name)
                    .font(.headline)

                Text(system.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .transition(.scale.animation(.spring(response: 0.3, dampingFraction: 0.7)))
            }
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            print("🔍 [SystemCard] Tapped: \(system.id)")
            onTap()
        }
    }
}

struct CompletionItem: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        print("👀 [CompletionItem] body - text: '\(text)'")
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.headline)
                .foregroundColor(Color(UIColor.label))

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.headline)
                .foregroundColor(.green)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

struct OnboardingProfileView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingProfileView(userProfile: .constant(UserProfileData()))
            .previewDisplayName("Vue Profil")
    }
}
