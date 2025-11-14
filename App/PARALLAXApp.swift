//
//  PARALLAXApp.swift
//  PARALLAX
//
//  Created by  on 7/9/25.
//

import CoreData
import os.log
import SwiftUI
import TipKit
import UserNotifications
import WidgetKit

// MARK: - Main App Structure

@main
struct PARALLAXApp: App {
    let persistenceController = PersistenceController.shared
    private let logger = Logger(subsystem: "com.gradefy.app", category: "AppMain")

    // MARK: - State Management

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false {
        didSet {
            print("🔄 [PARALLAXApp] hasCompletedOnboarding changed: \(oldValue) -> \(hasCompletedOnboarding)")
        }
    }

    @AppStorage("darkModeEnabled") private var darkModeEnabled: Bool = false {
        didSet {
            print("🌙 [PARALLAXApp] darkModeEnabled changed: \(oldValue) -> \(darkModeEnabled)")
        }
    }

    @AppStorage("onboardingCompletedTimestamp") private var onboardingTimestamp: Double = 0 {
        didSet {
            print("⏰ [PARALLAXApp] onboardingTimestamp changed: \(oldValue) -> \(onboardingTimestamp)")
        }
    }

    // MARK: - Import Management

    @State private var pendingImportDeck: ShareableDeck?
    @State private var pendingImportFromURL: ShareableDeck?
    @State private var shouldShowImportAfterLoad = false
    @State private var selectedDetent: PresentationDetent = .fraction(0.6)

    // MARK: - App State

    @State private var featureManager = FeatureManager.shared
    @State private var isInitialized = false {
        didSet {
            print("🚀 [PARALLAXApp] isInitialized changed: \(oldValue) -> \(isInitialized)")
        }
    }

    @State private var isAppFullyLoaded = false {
        didSet {
            print("📱 [PARALLAXApp] isAppFullyLoaded changed: \(oldValue) -> \(isAppFullyLoaded)")
        }
    }

    // ✅ MODIFIÉ : Supprimé - Application entièrement gratuite

    // MARK: - Onboarding Protection

    @State private var lastPremiumValidation: Date = .distantPast
    @State private var onboardingCompletionInProgress = false {
        didSet {
            print("⏳ [PARALLAXApp] onboardingCompletionInProgress changed: \(oldValue) -> \(onboardingCompletionInProgress)")
        }
    }

    @State private var hasProcessedOnboardingCompletion = false {
        didSet {
            print("✅ [PARALLAXApp] hasProcessedOnboardingCompletion changed: \(oldValue) -> \(hasProcessedOnboardingCompletion)")
        }
    }

    private let premiumValidationCooldown: TimeInterval = 5.0

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase

    @State private var onboardingViewID = UUID() {
        didSet {
            print("🆔 [PARALLAXApp] onboardingViewID changed: \(onboardingViewID)")
        }
    }

    @State private var isTransitioningToOnboarding = false {
        didSet {
            print("🔄 [PARALLAXApp] isTransitioningToOnboarding: \(isTransitioningToOnboarding)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                        .onAppear {
                            print("👀 [PARALLAXApp] ContentView.onAppear appelé")
                        }
                        .onDisappear {
                            print("👋 [PARALLAXApp] ContentView.onDisappear appelé")
                        }
                } else {
                    AppleStyleOnboardingView(onCompletion: {
                        print("🎉 [PARALLAXApp] AppleStyleOnboardingView completion callback appelé")
                        logger.info("🔍 Onboarding workflow terminé - transition gérée par notification uniquement")
                        // ❌ NE JAMAIS appeler completeOnboarding() ici
                    })
                    .id(onboardingViewID)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    .onAppear {
                        print("👀 [PARALLAXApp] AppleStyleOnboardingView.onAppear appelé")
                    }
                    .onDisappear {
                        print("👋 [PARALLAXApp] AppleStyleOnboardingView.onDisappear appelé")
                    }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: hasCompletedOnboarding)
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .preferredColorScheme(darkModeEnabled ? .dark : nil)
            .onOpenURL { url in
                print("🔗 [PARALLAXApp] onOpenURL appelé avec: \(url)")
                handleIncomingURL(url)
            }
            .sheet(item: $pendingImportDeck) { shareableDeck in
                ImportDeckView(
                    shareableDeck: shareableDeck,
                    onImport: { deck, importAll in
                        print("📥 [PARALLAXApp] ImportDeckView onImport appelé - importAll: \(importAll)")
                        importDeck(deck, importAll: importAll)
                    },
                    onCancel: {
                        print("❌ [PARALLAXApp] ImportDeckView onCancel appelé")
                        pendingImportDeck = nil
                    }
                )
                .presentationDetents([.fraction(0.60)], selection: $selectedDetent)
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(55)
                .presentationCompactAdaptation(.sheet)
                .presentationBackground(.regularMaterial)
                .onAppear {
                    print("👀 [PARALLAXApp] ImportDeckView sheet.onAppear")
                    print("📋 [PARALLAXApp] Sheet ImportDeckView présentée pour: \(shareableDeck.metadata.name)")
                    selectedDetent = .fraction(0.60)
                }
            }
            // ✅ MODIFIÉ : Supprimé - Application entièrement gratuite

            // MARK: - App Lifecycle

            .onAppear {
                print("👀 [PARALLAXApp] App body.onAppear appelé")
                initializeAppOnce()
            }
            .onChange(of: hasCompletedOnboarding) { _, newValue in
                print("🔄 [PARALLAXApp] onChange hasCompletedOnboarding: \(newValue)")
                if newValue {
                    print("⏰ [PARALLAXApp] Onboarding terminé - planification délai 1.0s pour isAppFullyLoaded")
                    // Délai pour s'assurer que l'UI est stable
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("⏰ [PARALLAXApp] Délai 1.0s écoulé - isAppFullyLoaded = true + checkForPendingImport")
                        isAppFullyLoaded = true
                        checkForPendingImport()
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                print("🔄 [PARALLAXApp] scenePhase changed: \(oldPhase) -> \(newPhase)")

                // Sauvegarde forcée de la période active lors de la mise en arrière-plan
                if newPhase == .background || newPhase == .inactive {
                    print("💾 [PARALLAXApp] Sauvegarde forcée avant arrière-plan")

                    // Synchronisation forcée de tous les UserDefaults
                    UserDefaults.standard.synchronize()

                    // Sauvegarder dans Core Data si nécessaire
                    PersistenceController.shared.save()

                    // Envoyer notification pour sauvegarder la période active
                    NotificationCenter.default.post(name: .saveActivePeriod, object: nil)
                }

                // Gestion des imports en attente quand l'app revient active
                if newPhase == .active && pendingImportDeck != nil {
                    print("🎯 [PARALLAXApp] App active avec import en attente - reset detent")
                    selectedDetent = .fraction(0.6)
                }
            }

            // MARK: - Notification Observers

            .onReceive(NotificationCenter.default.publisher(for: .fullAccessStatusChanged)) { notification in
                print("📬 [PARALLAXApp] Notification fullAccessStatusChanged reçue")
                handlePremiumStatusChange(notification)
            }
            .onAppear {
                print("👀 [PARALLAXApp] onAppear pour debugUserDefaults")
                debugUserDefaults()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OnboardingCompleted"))) { _ in
                print("📬 [PARALLAXApp] Notification OnboardingCompleted reçue")
                print("📊 [PARALLAXApp] État avant traitement - hasProcessed: \(hasProcessedOnboardingCompletion), inProgress: \(onboardingCompletionInProgress)")
                logger.info("📢 Notification OnboardingCompleted reçue")

                guard !hasProcessedOnboardingCompletion else {
                    print("⚠️ [PARALLAXApp] OnboardingCompleted déjà traité, ignorer")
                    logger.warning("⚠️ OnboardingCompleted déjà traité, ignoré")
                    return
                }

                hasProcessedOnboardingCompletion = true

                print("⏰ [PARALLAXApp] Planification délai 1.5s pour completeOnboarding()")
                // Délai pour permettre interaction utilisateur
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    print("⏰ [PARALLAXApp] Délai 1.5s écoulé - appel completeOnboarding()")
                    self.completeOnboarding()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RestartOnboarding"))) { _ in
                print("📬 [PARALLAXApp] Notification RestartOnboarding reçue")
                logger.info("🔄 Redémarrage de l'onboarding demandé")
                resetOnboardingState()
            }
        }
    }

    // MARK: - Pending Import Management

    private func checkForPendingImport() {
        print("🔍 [PARALLAXApp] checkForPendingImport() appelé")
        print("📊 [PARALLAXApp] shouldShow: \(shouldShowImportAfterLoad), pendingDeck: \(pendingImportFromURL?.metadata.name ?? "nil"), isFullyLoaded: \(isAppFullyLoaded)")

        guard shouldShowImportAfterLoad,
              let pendingDeck = pendingImportFromURL,
              isAppFullyLoaded
        else {
            print("⚠️ [PARALLAXApp] Conditions non remplies pour import différé")
            return
        }

        logger.info("✅ App prête - Affichage différé de la sheet d'import")

        print("⏰ [PARALLAXApp] Planification délai 0.3s pour affichage sheet")
        // Délai supplémentaire pour animation fluide
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("⏰ [PARALLAXApp] Délai 0.3s écoulé - affichage sheet avec animation")
            withAnimation(.easeInOut(duration: 0.3)) {
                self.pendingImportDeck = pendingDeck
            }

            // Nettoyer les variables temporaires
            self.pendingImportFromURL = nil
            self.shouldShowImportAfterLoad = false
            print("🧹 [PARALLAXApp] Variables temporaires nettoyées")
        }
    }

    // MARK: - Initialization

    private func initializeAppOnce() {
        print("🚀 [PARALLAXApp] initializeAppOnce() appelé - isInitialized: \(isInitialized)")

        guard !isInitialized else {
            print("⚠️ [PARALLAXApp] App déjà initialisée, ignorer")
            logger.warning("⚠️ App déjà initialisée, ignoré")
            return
        }

        logger.info("🚀 Initialisation de PARALLAX...")
        isInitialized = true

        migrateFlashcardsIfNeeded()

        print("🔄 [PARALLAXApp] Reset des flags de protection")
        // Réinitialiser les flags de protection
        hasProcessedOnboardingCompletion = false
        onboardingCompletionInProgress = false

        // Afficher l'état initial
        logger.info("📱 État initial: Onboarding \(hasCompletedOnboarding ? "terminé" : "requis")")
        print("📱 [PARALLAXApp] État initial onboarding: \(hasCompletedOnboarding ? "terminé" : "requis")")

        // Test App Group pour diagnostic
        testAppGroup()

        // ✅ CORRECTION : Si onboarding déjà terminé, marquer l'app comme prête
        if hasCompletedOnboarding {
            print("✅ [PARALLAXApp] Onboarding déjà terminé - planification délai 1.5s pour isAppFullyLoaded")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                print("⏰ [PARALLAXApp] Délai 1.5s écoulé - isAppFullyLoaded = true + checkForPendingImport")
                self.isAppFullyLoaded = true
                self.checkForPendingImport()
            }
        }

        print("🔄 [PARALLAXApp] Lancement initialisation background")
        // Initialisation en arrière-plan
        Task {
            await performBackgroundInitialization()
        }
    }

    private func migrateFlashcardsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "FlashcardMediaMigrationCompleted") else {
            return
        }

        print("🛠️ [PARALLAXApp] Démarrage migration flashcards en arrière-plan")

        let container = PersistenceController.shared.container
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            context.name = "FlashcardMigrationContext"

            let request: NSFetchRequest<Flashcard> = Flashcard.fetchRequest()
            request.predicate = NSPredicate(format: "questionType == nil OR answerType == nil")

            do {
                let flashcards = try context.fetch(request)

                if flashcards.isEmpty {
                    print("ℹ️ [PARALLAXApp] Aucune flashcard à migrer")
                    UserDefaults.standard.set(true, forKey: "FlashcardMediaMigrationCompleted")
                    return
                }

                var updatedCount = 0
                for flashcard in flashcards {
                    var didUpdate = false

                    if flashcard.questionType == nil {
                        flashcard.questionType = "text"
                        didUpdate = true
                    }
                    if flashcard.answerType == nil {
                        flashcard.answerType = "text"
                        didUpdate = true
                    }

                    if didUpdate {
                        updatedCount += 1
                    }
                }

                if context.hasChanges {
                    try context.save()
                    print("✅ [PARALLAXApp] Migration terminée pour \(updatedCount) flashcards")
                } else {
                    print("ℹ️ [PARALLAXApp] Migration sans changement nécessaire")
                }

                UserDefaults.standard.set(true, forKey: "FlashcardMediaMigrationCompleted")
            } catch {
                print("❌ [PARALLAXApp] Erreur migration: \(error)")
            }
        }
    }

    // Puis appelle cette fonction dans didFinishLaunchingWithOptions:
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Ajoute cette ligne :
        migrateFlashcardsIfNeeded()

        return true
    }

    func testAppGroup() {
        print("🧪 [PARALLAXApp] testAppGroup() appelé")
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.Coefficient.PARALLAX2"
        ) {
            print("✅ [PARALLAXApp] App Group accessible : \(groupURL)")
            logger.info("✅ App Group accessible : \(groupURL)")

            // Test d'écriture
            let testFile = groupURL.appendingPathComponent("test.txt")
            do {
                try "Test App Group".write(to: testFile, atomically: true, encoding: .utf8)
                print("✅ [PARALLAXApp] Écriture App Group réussie")
                logger.info("✅ Écriture App Group réussie")
            } catch {
                print("❌ [PARALLAXApp] Erreur écriture App Group : \(error)")
                logger.error("❌ Erreur écriture App Group : \(error)")
            }
        } else {
            print("❌ [PARALLAXApp] App Group inaccessible")
            logger.error("❌ App Group inaccessible")
        }
    }

    private func performBackgroundInitialization() async {
        print("🔄 [PARALLAXApp] performBackgroundInitialization() démarré")
        let systemAtStart = UserDefaults.standard.string(forKey: "GradingSystem") ?? "france"
        print("🚀 [APP_INIT] Système au démarrage: '\(systemAtStart)'")

        logger.info("🔄 Initialisation en arrière-plan...")

        // ✅ NOUVEAU : ConfigurationManager ne fait plus de sync automatique
        let configManager = ConfigurationManager(context: PersistenceController.shared.container.viewContext)

        print("🔧 [PARALLAXApp] Appel fixUSASystemOnce()")
        // ✅ Correction USA ponctuelle (une seule fois)
        configManager.fixUSASystemOnce()

        print("🔧 [PARALLAXApp] Appel initializeUserDefaultsIfNeeded()")
        // ✅ Initialisation si nécessaire (premier lancement)
        configManager.initializeUserDefaultsIfNeeded()

        let systemAfterFix = UserDefaults.standard.string(forKey: "GradingSystem") ?? "france"
        print("🔧 [APP_INIT] Système après correction: '\(systemAfterFix)'")

        print("💡 [PARALLAXApp] Appel initializeTipKit()")
        await initializeTipKit()
        // ... reste de votre code
        print("✅ [PARALLAXApp] performBackgroundInitialization() terminé")
    }

    private func initializeLocalConfiguration() async {
        print("🔄 [PARALLAXApp] initializeLocalConfiguration() appelé")
        print("🔄 Initialisation de la configuration locale...")

        // ✅ Plus de restoreFromLocalStorage qui écrase tout !
        print("✅ Configuration locale préservée (pas de sync automatique)")
        print("✅ [PARALLAXApp] initializeLocalConfiguration() terminé")
    }

    private func debugUserDefaults() {
        print("=== [PARALLAXApp] DIAGNOSTIC USERDEFAULTS ===")

        // Standard UserDefaults
        let standardSystem = UserDefaults.standard.string(forKey: "GradingSystem")
        print("📱 Standard UserDefaults GradingSystem: '\(standardSystem ?? "nil")'")

        // App Group UserDefaults (si utilisé)
        if let groupDefaults = UserDefaults(suiteName: "group.com.Coefficient.PARALLAX2") {
            let groupSystem = groupDefaults.string(forKey: "GradingSystem")
            print("📦 App Group UserDefaults GradingSystem: '\(groupSystem ?? "nil")'")
        }

        // Lister toutes les clés UserDefaults
        print("🔑 Toutes les clés Standard UserDefaults:")
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            if key.contains("Grading") || key.contains("username") || key.contains("profile") {
                print("    \(key): \(value)")
            }
        }

        print("================================")
    }

    private func initializeTipKit() async {
        print("💡 [PARALLAXApp] initializeTipKit() démarré")
        logger.info("💡 Initialisation TipKit...")

        do {
            try Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault),
            ])
            print("✅ [PARALLAXApp] TipKit initialisé avec succès")
            logger.info("✅ TipKit initialisé avec succès")
        } catch {
            print("❌ [PARALLAXApp] Erreur initialisation TipKit: \(error)")
            logger.error("❌ Erreur initialisation TipKit: \(error)")
        }
    }

    private func initializeStoreKit() async {
        print("🛍️ [PARALLAXApp] initializeStoreKit() démarré")
        logger.info("🛍️ Initialisation StoreKit...")

        do {
            try await StoreKitHelper.shared.loadProducts()
            print("✅ [PARALLAXApp] StoreKit initialisé avec succès")
            logger.info("✅ StoreKit initialisé avec succès")
        } catch {
            print("❌ [PARALLAXApp] Erreur initialisation StoreKit: \(error)")
            logger.error("❌ Erreur initialisation StoreKit: \(error)")
        }
    }

    // MARK: - URL Handling

    private func handleIncomingURL(_ url: URL) {
        print("🔗 [PARALLAXApp] handleIncomingURL() appelé avec: \(url)")
        logger.info("🔗 URL reçue : \(url)")

        // Vérifier si c'est un deck à importer
        if isDeckImportURL(url) {
            print("📦 [PARALLAXApp] URL identifiée comme deck à importer")
            processDeckImportURL(url)
        } else {
            print("🔗 [PARALLAXApp] URL identifiée comme deep link")
            // Autre type d'URL (gradefy://, etc.)
            handleDeepLink(url: url)
        }
    }

    private func isDeckImportURL(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        let result = pathExtension == "json" || pathExtension == "gradefy" ||
            (url.scheme == "file" && (pathExtension == "json" || pathExtension == "gradefy"))
        print("🔍 [PARALLAXApp] isDeckImportURL(\(url)) = \(result)")
        return result
    }

    private func processDeckImportURL(_ url: URL) {
        print("📦 [PARALLAXApp] processDeckImportURL() appelé avec: \(url)")
        do {
            let shareableDeck = try DeckSharingManager.shared.parseSharedFile(url: url)
            print("✅ [PARALLAXApp] Deck parsé: \(shareableDeck.metadata.name)")

            if hasCompletedOnboarding, isAppFullyLoaded {
                print("📥 [PARALLAXApp] Import immédiat du deck")
                // App déjà chargée : import immédiat
                logger.info("📥 Import immédiat du deck : \(shareableDeck.metadata.name)")
                DispatchQueue.main.async {
                    self.pendingImportDeck = shareableDeck
                }
            } else {
                print("📥 [PARALLAXApp] Deck mis en attente pour import différé")
                // App en cours de chargement : différer l'import
                logger.info("📥 Deck mis en attente pour import différé : \(shareableDeck.metadata.name)")
                pendingImportFromURL = shareableDeck
                shouldShowImportAfterLoad = true
            }
        } catch {
            print("❌ [PARALLAXApp] Erreur parsing deck: \(error)")
            handleImportError("Erreur parsing deck depuis URL : \(error.localizedDescription)")
        }
    }

    private func handleDeepLink(url: URL) {
        print("🔗 [PARALLAXApp] handleDeepLink() appelé avec: \(url)")
        logger.info("🔗 Deep link reçu : \(url)")

        guard let scheme = url.scheme else {
            print("❌ [PARALLAXApp] Scheme manquant")
            logger.error("❌ Scheme manquant")
            return
        }

        print("🔍 [PARALLAXApp] Scheme détecté: \(scheme)")
        switch scheme.lowercased() {
        case "gradefy":
            print("🎓 [PARALLAXApp] Traitement URL Gradefy")
            handleGradefyUrl(url)
        case "http", "https":
            print("🌐 [PARALLAXApp] Traitement URL Web")
            handleWebUrl(url)
        case "file":
            print("📁 [PARALLAXApp] Traitement fichier local")
            handleLocalFile(url: url)
        default:
            print("❌ [PARALLAXApp] Scheme non reconnu : \(scheme)")
            logger.error("❌ Scheme non reconnu : \(scheme)")
        }
    }

    private func handleLocalFile(url: URL) {
        print("📁 [PARALLAXApp] handleLocalFile() appelé avec: \(url.lastPathComponent)")
        logger.info("📁 Fichier local reçu : \(url.lastPathComponent)")

        let pathExtension = url.pathExtension.lowercased()
        print("🔍 [PARALLAXApp] Extension détectée: \(pathExtension)")
        if pathExtension == "json" || pathExtension == "gradefy" {
            print("✅ [PARALLAXApp] Type de fichier supporté")
            logger.info("✅ Type de fichier supporté : \(pathExtension)")
            handleDeckImport(url: url)
        } else {
            print("❌ [PARALLAXApp] Type de fichier non supporté")
            logger.error("❌ Type de fichier non supporté : \(pathExtension)")
        }
    }

    private func handleDeckImport(url: URL) {
        print("📦 [PARALLAXApp] handleDeckImport() appelé avec: \(url.lastPathComponent)")
        logger.info("📦 Import deck : \(url.lastPathComponent)")

        // Vérification existence fichier
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ [PARALLAXApp] Fichier introuvable")
            handleImportError("Fichier introuvable : \(url.lastPathComponent)")
            return
        }

        print("✅ [PARALLAXApp] Fichier trouvé, accès sécurisé...")
        // Accès sécurisé
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                print("🔓 [PARALLAXApp] Arrêt accès sécurisé")
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            print("🔄 [PARALLAXApp] Parsing du deck...")
            let shareableDeck = try DeckSharingManager.shared.parseSharedFile(url: url)

            logger.info("✅ Deck parsé : \(shareableDeck.metadata.name)")
            logger.info("📊 Cartes : \(shareableDeck.flashcards.count)")
            print("✅ [PARALLAXApp] Deck parsé : \(shareableDeck.metadata.name) (\(shareableDeck.flashcards.count) cartes)")

            DispatchQueue.main.async {
                print("📋 [PARALLAXApp] Affectation pendingImportDeck")
                self.pendingImportDeck = shareableDeck
            }

        } catch {
            print("❌ [PARALLAXApp] Erreur parsing: \(error)")
            handleImportError("Erreur parsing deck : \(error.localizedDescription)")
        }
    }

    private func handleImportError(_ message: String) {
        print("❌ [PARALLAXApp] handleImportError: \(message)")
        logger.error("❌ \(message)")
        DispatchQueue.main.async {
            HapticFeedbackManager.shared.notification(type: .error)
        }
    }

    private func getFileSize(url: URL) -> Int {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as? Int ?? 0
            print("📏 [PARALLAXApp] Taille fichier \(url.lastPathComponent): \(size) bytes")
            return size
        } catch {
            print("❌ [PARALLAXApp] Erreur lecture taille fichier: \(error)")
            return 0
        }
    }

    // MARK: - Gradefy URL Handling

    private func handleGradefyUrl(_ url: URL) {
        print("🎓 [PARALLAXApp] handleGradefyUrl() appelé avec: \(url)")
        logger.info("🔗 URL Gradefy reçue : \(url)")

        let pathComponents = url.pathComponents
        print("🔍 [PARALLAXApp] PathComponents: \(pathComponents)")
        guard pathComponents.count > 1 else {
            print("❌ [PARALLAXApp] URL Gradefy malformée - pas assez de composants")
            logger.error("❌ URL Gradefy malformée")
            return
        }

        let path = pathComponents[1]
        print("🔍 [PARALLAXApp] Path extrait: \(path)")

        switch path.lowercased() {
        case "premium":
            print("💎 [PARALLAXApp] Traitement URL premium")
            handlePremiumURL()
        case "evaluations":
            print("📊 [PARALLAXApp] Traitement URL evaluations")
            handleEvaluationsURL()
        case "stats":
            print("📈 [PARALLAXApp] Traitement URL stats")
            handleWeeklyStatsURL()
        default:
            print("❌ [PARALLAXApp] Chemin Gradefy non reconnu : \(path)")
            logger.error("❌ Chemin Gradefy non reconnu : \(path)")
        }
    }

    private func handleWebUrl(_ url: URL) {
        print("🌐 [PARALLAXApp] handleWebUrl() appelé avec: \(url)")
        logger.info("🌐 URL Web reçue : \(url)")

        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                print("✅ [PARALLAXApp] Ouverture URL dans navigateur")
                UIApplication.shared.open(url)
            } else {
                print("❌ [PARALLAXApp] Impossible d'ouvrir l'URL")
                self.logger.error("❌ Impossible d'ouvrir l'URL : \(url)")
            }
        }
    }

    // ✅ MODIFIÉ : Supprimé - Application entièrement gratuite
    private func handlePremiumURL() {
        // Plus de redirection vers premium - Application entièrement gratuite
        print("💎 [PARALLAXApp] handlePremiumURL() appelé mais ignoré - Application entièrement gratuite")
    }

    private func handleEvaluationsURL() {
        print("📊 [PARALLAXApp] handleEvaluationsURL() appelé")
        logger.info("🔗 Navigation vers Évaluations")
        DispatchQueue.main.async {
            print("📊 [PARALLAXApp] Envoi notification navigateToEvaluations")
            NotificationCenter.default.post(
                name: .navigateToEvaluations,
                object: nil
            )
        }
    }

    private func handleWeeklyStatsURL() {
        print("📈 [PARALLAXApp] handleWeeklyStatsURL() appelé")
        logger.info("🔗 Navigation vers Statistiques Hebdomadaires")
        DispatchQueue.main.async {
            print("📈 [PARALLAXApp] Envoi notification navigateToWeeklyStats")
            NotificationCenter.default.post(
                name: .navigateToWeeklyStats,
                object: nil
            )
        }
    }

    // MARK: - Import Management

    private func importDeck(_ shareableDeck: ShareableDeck, importAll: Bool) {
        print("📥 [PARALLAXApp] importDeck() appelé - importAll: \(importAll)")
        Task {
            do {
                let limitToFree = !importAll
                print("🔄 [PARALLAXApp] Import en cours - limitToFree: \(limitToFree)")

                _ = try await DeckSharingManager.shared.importDeckDirect(
                    shareableDeck: shareableDeck,
                    context: PersistenceController.shared.container.viewContext,
                    limitToFreeQuota: limitToFree
                )

                await MainActor.run {
                    print("✅ [PARALLAXApp] Import réussi - nettoyage pendingImportDeck")
                    pendingImportDeck = nil
                    HapticFeedbackManager.shared.notification(type: .success)
                    logger.info("✅ Deck importé avec succès")
                }
            } catch {
                print("❌ [PARALLAXApp] Erreur import: \(error)")
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .error)
                    logger.error("❌ Erreur import deck: \(error)")
                }
            }
        }
    }

    // MARK: - Premium Status Management

    private func handlePremiumStatusChange(_ notification: Notification) {
        print("💎 [PARALLAXApp] handlePremiumStatusChange() appelé")
        let guards = [
            ("onboarding", !hasCompletedOnboarding),
            ("cooldown", Date().timeIntervalSince(lastPremiumValidation) <= premiumValidationCooldown),
            ("validating", featureManager.isValidating),
        ]

        print("🔍 [PARALLAXApp] Vérification guards:")
        for (reason, condition) in guards {
            print("  - \(reason): \(condition)")
        }

        #if DEBUG
            if featureManager.debugOverride {
                print("🐛 [PARALLAXApp] Mode debug actif - validation ignorée")
                logger.info("🐛 Validation ignorée - mode debug actif")
                return
            }
        #endif

        for (reason, condition) in guards {
            if condition {
                print("⚠️ [PARALLAXApp] Validation ignorée - \(reason)")
                logger.warning("⚠️ Validation ignorée - \(reason)")
                return
            }
        }

        // Vérifier changement réel
        if let userInfo = notification.userInfo,
           let previousValue = userInfo["previousValue"] as? Bool,
           let newValue = userInfo["newValue"] as? Bool,
           previousValue == newValue
        {
            print("⚠️ [PARALLAXApp] Pas de changement réel - validation ignorée")
            logger.warning("⚠️ Validation ignorée - pas de changement réel")
            return
        }

        lastPremiumValidation = Date()
        print("🔄 [PARALLAXApp] Lancement validation subscription")
        Task {
            await featureManager.validateSubscription()
        }
    }

    // MARK: - Onboarding Management

    private func completeOnboarding() {
        print("🔄 [PARALLAXApp] === DÉBUT completeOnboarding() ===")
        logger.info("🔄 === DÉBUT completeOnboarding() ===")

        print("📊 [PARALLAXApp] État avant guards - hasCompleted: \(hasCompletedOnboarding), inProgress: \(onboardingCompletionInProgress)")

        // Protection principale
        guard !hasCompletedOnboarding else {
            print("⚠️ [PARALLAXApp] completeOnboarding() déjà appelé, ignorer")
            logger.warning("⚠️ completeOnboarding() déjà appelé, ignoré")
            return
        }

        // Protection secondaire
        guard !onboardingCompletionInProgress else {
            print("⚠️ [PARALLAXApp] completeOnboarding() déjà en cours, ignorer")
            logger.warning("⚠️ completeOnboarding() déjà en cours, ignoré")
            return
        }

        onboardingCompletionInProgress = true

        print("✅ [PARALLAXApp] Marquage hasCompletedOnboarding = true")
        // Marquer l'onboarding comme terminé
        hasCompletedOnboarding = true
        onboardingTimestamp = Date().timeIntervalSince1970

        logger.info("✅ Onboarding terminé - hasCompletedOnboarding = \(hasCompletedOnboarding)")

        print("🔄 [PARALLAXApp] Lancement tâches post-onboarding")
        // Tâches post-onboarding
        Task {
            await performPostOnboardingTasks()

            await MainActor.run {
                print("✅ [PARALLAXApp] onboardingCompletionInProgress = false")
                self.onboardingCompletionInProgress = false
            }
        }

        logger.info("🔄 === FIN completeOnboarding() ===")
        print("🔄 [PARALLAXApp] === FIN completeOnboarding() ===")
    }

    private func performPostOnboardingTasks() async {
        print("🎉 [PARALLAXApp] performPostOnboardingTasks() démarré")
        logger.info("🎉 Tâches post-onboarding...")

        print("🎨 [PARALLAXApp] Initialisation widgets")
        // Initialiser les widgets
        await initializeWidgets()

        logger.info("✅ Configuration post-onboarding terminée")
        print("✅ [PARALLAXApp] performPostOnboardingTasks() terminé")
    }

    private func initializeWidgets() async {
        print("🎨 [PARALLAXApp] initializeWidgets() démarré")
        if featureManager.hasFullAccess {
            print("💎 [PARALLAXApp] Widgets premium disponibles")
            logger.info("🎨 Widgets premium disponibles")
        } else {
            print("📱 [PARALLAXApp] Widgets de base uniquement")
            logger.info("📱 Widgets de base uniquement")
        }

        #if !targetEnvironment(simulator)
            print("🔄 [PARALLAXApp] Rechargement des widgets")
            WidgetCenter.shared.reloadAllTimelines()
            logger.info("✅ Widgets rechargés")
        #else
            print("⚠️ [PARALLAXApp] Widgets non disponibles sur simulateur")
            logger.info("⚠️ Widgets non disponibles sur simulateur")
        #endif

        print("✅ [PARALLAXApp] initializeWidgets() terminé")
    }

    private func resetOnboardingState() {
        print("🔄 [PARALLAXApp] === DÉBUT resetOnboardingState() ===")
        print("📊 [PARALLAXApp] État avant reset:")
        print("  - hasCompletedOnboarding: \(hasCompletedOnboarding)")
        print("  - onboardingViewID: \(onboardingViewID)")
        print("  - isTransitioningToOnboarding: \(isTransitioningToOnboarding)")

        // Phase 1: État de transition
        isTransitioningToOnboarding = true

        // Phase 2: Reset après délai court pour éviter les conflits
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("🔄 [PARALLAXApp] Phase 2 - Reset des états")

            // Générer un nouvel UUID pour forcer une instance complètement nouvelle
            self.onboardingViewID = UUID()

            // Reset de tous les états
            self.hasCompletedOnboarding = false
            self.onboardingTimestamp = 0
            self.onboardingCompletionInProgress = false
            self.hasProcessedOnboardingCompletion = false
            self.isAppFullyLoaded = false
            self.shouldShowImportAfterLoad = false
            self.pendingImportFromURL = nil

            // Phase 3: Fin de la transition après un délai supplémentaire
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🔄 [PARALLAXApp] Phase 3 - Fin de transition")
                self.isTransitioningToOnboarding = false

                print("📊 [PARALLAXApp] État après reset:")
                print("  - hasCompletedOnboarding: \(self.hasCompletedOnboarding)")
                print("  - onboardingViewID: \(self.onboardingViewID)")
                print("  - isTransitioningToOnboarding: \(self.isTransitioningToOnboarding)")
                print("🔄 [PARALLAXApp] === FIN resetOnboardingState() ===")
            }
        }
    }
}

// MARK: - Extensions

extension NSNotification.Name {
    static let navigateToEvaluations = NSNotification.Name("NavigateToEvaluations")
    static let navigateToWeeklyStats = NSNotification.Name("NavigateToWeeklyStats")
}

// MARK: - App Utilities

extension PARALLAXApp {
    func restartApp() {
        print("🔄 [PARALLAXApp] restartApp() appelé")
        isInitialized = false
        onboardingCompletionInProgress = false
        hasProcessedOnboardingCompletion = false
        isAppFullyLoaded = false
        Task {
            print("🔄 [PARALLAXApp] Relancement performBackgroundInitialization")
            await performBackgroundInitialization()
        }
    }

    func resetOnboarding() {
        print("🔄 [PARALLAXApp] resetOnboarding() appelé")
        logger.info("🔄 Reset complet de l'onboarding...")
        resetOnboardingState()
        isInitialized = false

        // Reset des tips
        do {
            try Tips.resetDatastore()
            print("✅ [PARALLAXApp] Tips datastore reset")
        } catch {
            print("❌ [PARALLAXApp] Erreur reset tips: \(error)")
        }

        logger.info("✅ Reset terminé")
        print("✅ [PARALLAXApp] resetOnboarding() terminé")
    }

    func softResetOnboarding() {
        print("🔄 [PARALLAXApp] softResetOnboarding() appelé")
        logger.info("🔄 Reset partiel de l'onboarding...")
        onboardingCompletionInProgress = false
        hasProcessedOnboardingCompletion = false
        logger.info("✅ Reset partiel terminé")
        print("✅ [PARALLAXApp] softResetOnboarding() terminé")
    }
}

// MARK: - Debug Utilities

#if DEBUG
    extension PARALLAXApp {
        func forceOnboarding() {
            print("🧪 [PARALLAXApp] forceOnboarding() appelé")
            resetOnboarding()
        }

        func debugOnboardingState() {
            print("🐛 [PARALLAXApp] === DEBUG ONBOARDING STATE ===")
            logger.info("🐛 === DEBUG ONBOARDING STATE ===")
            logger.info("- hasCompletedOnboarding: \(hasCompletedOnboarding)")
            logger.info("- onboardingTimestamp: \(onboardingTimestamp)")
            logger.info("- onboardingCompletionInProgress: \(onboardingCompletionInProgress)")
            logger.info("- hasProcessedOnboardingCompletion: \(hasProcessedOnboardingCompletion)")
            logger.info("- isInitialized: \(isInitialized)")
            logger.info("- isAppFullyLoaded: \(isAppFullyLoaded)")
            logger.info("- shouldShowImportAfterLoad: \(shouldShowImportAfterLoad)")
            logger.info("================================")
            print("================================")
        }

        func debugInfo() {
            print("🐛 [PARALLAXApp] === DEBUG INFO COMPLET ===")
            logger.info("🐛 === DEBUG INFO COMPLET ===")
            logger.info("- Onboarding terminé: \(hasCompletedOnboarding)")
            logger.info("- Onboarding en cours: \(onboardingCompletionInProgress)")
            logger.info("- Notification traitée: \(hasProcessedOnboardingCompletion)")
            logger.info("- App chargée: \(isAppFullyLoaded)")
            logger.info("- Import en attente: \(shouldShowImportAfterLoad)")
            logger.info("- Premium: \(featureManager.hasFullAccess)")
            logger.info("- Dark Mode: \(darkModeEnabled)")
            logger.info("- Initialized: \(isInitialized)")
            logger.info("============================")
            print("============================")
        }

        func simulateOnboardingCompletion() {
            print("🧪 [PARALLAXApp] simulateOnboardingCompletion() appelé")
            logger.info("🧪 Simulation completion onboarding pour testing...")
            NotificationCenter.default.post(
                name: NSNotification.Name("OnboardingCompleted"),
                object: nil
            )
        }

        func manualTestAppGroup() {
            print("🧪 [PARALLAXApp] manualTestAppGroup() appelé")
            testAppGroup()
        }
    }
#endif
