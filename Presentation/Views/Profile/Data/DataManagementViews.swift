//
//  DataOptionsView.swift
//  PARALLAX
//
//  Created by  on 7/21/25.
//
import SwiftUI
import CoreData
import UIKit
import WidgetKit
import Lottie
import UniformTypeIdentifiers
import Combine
import Foundation

struct DataOptionsView: View {
    @Binding var navigationPath: NavigationPath
    @State private var showingResetAlert = false {
        didSet {
            print("🔍 [DataOptionsView] showingResetAlert changed: \(oldValue) -> \(showingResetAlert)")
        }
    }
    @State private var isResetting = false {
        didSet {
            print("🔍 [DataOptionsView] isResetting changed: \(oldValue) -> \(isResetting)")
        }
    }
    @Environment(\.managedObjectContext) private var viewContext
    
    // États pour les document pickers
    @State private var showingExportPicker = false {
        didSet {
            print("🔍 [DataOptionsView] showingExportPicker changed: \(oldValue) -> \(showingExportPicker)")
        }
    }
    @State private var showingImportPicker = false {
        didSet {
            print("🔍 [DataOptionsView] showingImportPicker changed: \(oldValue) -> \(showingImportPicker)")
        }
    }
    @State private var exportURL: URL? {
        didSet {
            print("🔍 [DataOptionsView] exportURL changed: \(String(describing: oldValue)) -> \(String(describing: exportURL))")
        }
    }
    @StateObject private var importExportManager = DataImportExportManager()
    
    var body: some View {
        print("👀 [DataOptionsView] body appelé")
        print("📊 [DataOptionsView] États actuels:")
        print("  - showingResetAlert: \(showingResetAlert)")
        print("  - isResetting: \(isResetting)")
        print("  - showingExportPicker: \(showingExportPicker)")
        print("  - showingImportPicker: \(showingImportPicker)")
        print("  - exportURL: \(String(describing: exportURL))")
        
        return List {
            // Section animation
            animationSection
            
            Section(String(localized: "data_backup_section")) {
                // Bouton d'export désormais accessible à tous
                Button(action: {
                    print("🔍 [DataOptionsView] Bouton Export tappé")
                    HapticFeedbackManager.shared.impact(style: .light)
                    handleExportAction()
                }) {
                    HStack {
                        Text(String(localized: "action_export_data"))
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // ✅ Garder seulement l'indicateur à droite
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .frame(maxWidth: 24, alignment: .center)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    print("🔍 [DataOptionsView] Bouton Import tappé")
                    HapticFeedbackManager.shared.impact(style: .light)
                    handleImportAction()
                }) {
                    HStack {
                        Text(String(localized: "action_import_data"))
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // ✅ Garder seulement l'indicateur à droite
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .frame(maxWidth: 24, alignment: .center)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            Section(String(localized: "data_reset_section")) {
                Button(action: {
                    print("🔍 [DataOptionsView] Bouton Réinitialiser tappé")
                    HapticFeedbackManager.shared.impact(style: .medium)
                    showingResetAlert = true
                }) {
                    HStack {
                        if isResetting {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(String(localized: "action_resetting"))
                                    .foregroundColor(.red)
                            }
                        } else {
                            Text(String(localized: "action_reset"))
                                .foregroundColor(.red)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                .disabled(isResetting)
            }
        }
        .navigationTitle(String(localized: "nav_data_backup"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("👀 [DataOptionsView] Vue apparue")
            print("🔍 [DataOptionsView] Configuration importExportManager avec context")
            importExportManager.setContext(viewContext)
        }
        .onDisappear {
            print("👋 [DataOptionsView] Vue disparue")
        }
        
        // Document picker pour l'import
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json, .zip],
            allowsMultipleSelection: false
        ) { result in
            print("📁 [DataOptionsView] FileImporter result reçu")
            handleImportResult(result)
        }
        
        // Document picker pour l'export
        .fileExporter(
            isPresented: $showingExportPicker,
            document: exportURL != nil ? ZIPDocument(url: exportURL!) : nil,
            contentType: .zip,
            defaultFilename: generateExportFilename()
        ) { result in
            print("📁 [DataOptionsView] FileExporter result reçu")
            handleExportResult(result)
        }
        
        .alert(String(localized: "alert_complete_reset"), isPresented: $showingResetAlert) {
            Button(String(localized: "action_cancel"), role: .cancel) {
                print("🔍 [DataOptionsView] Alert Réinitialisation - Bouton Annuler tappé")
            }
            Button(String(localized: "action_reset"), role: .destructive) {
                print("🔍 [DataOptionsView] Alert Réinitialisation - Bouton Réinitialiser tappé")
                performCompleteReset()
            }
        } message: {
            Text(String(localized: "alert_reset_message"))
        }
    }
    
    // Fonctions de gestion des actions premium
    private func handleExportAction() {
        print("🔍 [DataOptionsView] === DÉBUT handleExportAction() ===")
        print("✅ [DataOptionsView] Export disponible pour tous - lancement export")
        exportData()
        print("🔍 [DataOptionsView] === FIN handleExportAction() ===")
    }

    private func handleImportAction() {
        print("🔍 [DataOptionsView] === DÉBUT handleImportAction() ===")
        print("✅ [DataOptionsView] Import disponible pour tous - ouverture file picker")
        showingImportPicker = true
        print("🔍 [DataOptionsView] === FIN handleImportAction() ===")
    }
    
    // MARK: - Section Animation
    private var animationSection: some View {
        print("🎬 [DataOptionsView] animationSection créée")
        return Section {
            VStack(spacing: 10) {
                LottieView(animation: .named("folder"))
                    .playing()
                    .frame(width: AppConstants.Animation.lottieSize, height: AppConstants.Animation.lottieSize)
                    .onAppear {
                        print("🎬 [DataOptionsView] LottieView folder apparue")
                    }
                Text(String(localized: "data_management_description"))
                    .font(.caption.weight(.regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 1)
            .padding(.bottom, 0)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }
    
    private func exportData() {
        print("🔍 [DataOptionsView] === DÉBUT exportData() ===")
        Task {
            do {
                print("🔍 === [DATA_OPTIONS] DÉBUT EXPORT ===")
                print("🔍 [DATA_OPTIONS] Manager context: \(importExportManager)")
                
                let exportedURL = try await importExportManager.exportAllData()
                
                print("✅ [DATA_OPTIONS] Export réussi - URL: \(exportedURL)")
                
                // ✅ Code corrigé - Conversion Data vers URL temporaire
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("gradefy_export_\(Date().timeIntervalSince1970).zip")

                do {
                    try exportedURL.write(to: tempURL)
                    print("✅ [DATA_OPTIONS] Fichier temporaire créé: \(tempURL)")
                    
                    await MainActor.run {
                        print("🔄 [DataOptionsView] MainActor - mise à jour UI export")
                        exportURL = tempURL  // ✅ Maintenant c'est un URL
                        showingExportPicker = true
                        HapticFeedbackManager.shared.notification(type: .success)
                        print("✅ [DataOptionsView] Export UI mise à jour terminée")
                    }
                } catch {
                    print("❌ [DATA_OPTIONS] Erreur création fichier temporaire: \(error)")
                    await MainActor.run {
                        print("❌ [DataOptionsView] MainActor - erreur export")
                        HapticFeedbackManager.shared.notification(type: .error)
                    }
                }

            } catch {
                print("❌ [DATA_OPTIONS] Erreur lors de l'export : \(error)")
                print("❌ [DATA_OPTIONS] Description: \(error.localizedDescription)")
                
                await MainActor.run {
                    print("❌ [DataOptionsView] MainActor - erreur export générale")
                    HapticFeedbackManager.shared.notification(type: .error)
                }
            }
        }
        print("🔍 [DataOptionsView] === FIN exportData() ===")
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        print("🔍 [DataOptionsView] === DÉBUT handleImportResult() ===")
        switch result {
        case .success(let urls):
            print("✅ [DataOptionsView] URLs reçues: \(urls)")
            guard let url = urls.first else {
                print("❌ [DATA_OPTIONS] Aucune URL fournie")
                return
            }
            
            print("🔍 === [DATA_OPTIONS] DÉBUT IMPORT ===")
            print("🔍 [DATA_OPTIONS] URL sélectionnée: \(url)")
            print("📁 [DATA_OPTIONS] Type de fichier: \(url.pathExtension)")
            
            // Gestion automatique des permissions
            print("🔍 [DataOptionsView] Demande d'accès sécurisé au fichier")
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ [DATA_OPTIONS] Impossible d'accéder au fichier")
                return
            }
            
            defer {
                print("🔍 [DataOptionsView] Arrêt accès sécurisé au fichier")
                url.stopAccessingSecurityScopedResource()
            }
            
            do {
                print("🔍 [DataOptionsView] Lecture des données du fichier")
                let data = try Data(contentsOf: url)
                print("📊 [DATA_OPTIONS] Données lues: \(data.count) bytes")
                
                // Détecter le type de fichier
                if data.count >= 4 {
                    let signature = data.prefix(4)
                    if signature[0] == 0x50 && signature[1] == 0x4B {
                        print("📦 [DATA_OPTIONS] Fichier ZIP détecté")
                    } else {
                        print("📄 [DATA_OPTIONS] Fichier JSON détecté")
                    }
                }
                
                print("🔍 [DataOptionsView] Lancement de l'import en Task")
                Task {
                    do {
                        print("🔄 [DataOptionsView] Import en cours...")
                        try await importExportManager.importAllData(from: data)
                        
                        await MainActor.run {
                            print("✅ [DataOptionsView] MainActor - import réussi")
                            HapticFeedbackManager.shared.notification(type: .success)
                            print("✅ [DATA_OPTIONS] Import réussi depuis : \(url.lastPathComponent)")
                        }
                        
                    } catch {
                        print("❌ [DATA_OPTIONS] Erreur lors de l'import : \(error)")
                        print("❌ [DATA_OPTIONS] Description: \(error.localizedDescription)")
                        
                        await MainActor.run {
                            print("❌ [DataOptionsView] MainActor - erreur import")
                            HapticFeedbackManager.shared.notification(type: .error)
                        }
                    }
                }
                
            } catch {
                print("❌ [DATA_OPTIONS] Erreur lecture fichier : \(error)")
                HapticFeedbackManager.shared.notification(type: .error)
            }
            
        case .failure(let error):
            print("❌ [DATA_OPTIONS] Erreur sélection fichier : \(error)")
            HapticFeedbackManager.shared.notification(type: .error)
        }
        print("🔍 [DataOptionsView] === FIN handleImportResult() ===")
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        print("🔍 [DataOptionsView] === DÉBUT handleExportResult() ===")
        switch result {
        case .success(let url):
            print("✅ Export réussi vers : \(url.lastPathComponent)")
            print("✅ [DataOptionsView] Export réussi, nettoyage fichier temporaire")
            HapticFeedbackManager.shared.notification(type: .success)
            // Nettoyer le fichier temporaire
            if let tempURL = exportURL {
                do {
                    try FileManager.default.removeItem(at: tempURL)
                    print("✅ [DataOptionsView] Fichier temporaire supprimé: \(tempURL)")
                } catch {
                    print("⚠️ [DataOptionsView] Erreur suppression fichier temporaire: \(error)")
                }
            }
        case .failure(let error):
            print("❌ Erreur lors de l'export : \(error)")
            print("❌ [DataOptionsView] Export échoué")
            HapticFeedbackManager.shared.notification(type: .error)
        }
        print("🔍 [DataOptionsView] === FIN handleExportResult() ===")
    }
    
    private func createTemporaryExportFile(with data: Data) throws -> URL {
        print("🔍 [DataOptionsView] === DÉBUT createTemporaryExportFile() ===")
        let tempDir = FileManager.default.temporaryDirectory
        let filename = generateExportFilename()
        let tempURL = tempDir.appendingPathComponent(filename)
        
        print("🔍 [DataOptionsView] Fichier temporaire: \(tempURL)")
        
        // Nettoyer le fichier existant si nécessaire
        if FileManager.default.fileExists(atPath: tempURL.path) {
            print("🗑️ [DataOptionsView] Suppression fichier temporaire existant")
            try FileManager.default.removeItem(at: tempURL)
        }
        
        // Écrire les données dans le fichier temporaire
        print("✍️ [DataOptionsView] Écriture données dans fichier temporaire")
        try data.write(to: tempURL)
        print("✅ [DataOptionsView] Fichier temporaire créé avec succès")
        print("🔍 [DataOptionsView] === FIN createTemporaryExportFile() ===")
        return tempURL
    }
    
    private func generateExportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "Gradefy_Export_\(timestamp).zip"
        print("🔍 [DataOptionsView] Nom fichier généré: \(filename)")
        return filename
    }
    
    // MARK: - Fonction de réinitialisation complète
    private func performCompleteReset() {
        print("🔍 [DataOptionsView] === DÉBUT performCompleteReset() ===")
        print("🔄 [DataOptionsView] Début réinitialisation complète")
        isResetting = true
        
        // Entités de votre modèle Core Data
        let entityNames = [
            "Evaluation",
            "Flashcard",
            "FlashcardDeck",
            "Period",
            "Subject",
            "UserConfiguration"
        ]
        
        var totalDeleted = 0
        
        for entityName in entityNames {
            print("🗑️ [DataOptionsView] Suppression entité: \(entityName)")
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .resultTypeCount
            
            do {
                let result = try viewContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
                let deletedCount = result?.result as? Int ?? 0
                totalDeleted += deletedCount
                print("✅ \(deletedCount) objets supprimés de l'entité '\(entityName)'")
            } catch {
                print("❌ Erreur lors de la suppression de '\(entityName)': \(error)")
            }
        }
        
        // Sauvegarde des changements
        do {
            print("💾 [DataOptionsView] Sauvegarde des changements Core Data")
            try viewContext.save()
            print("✅ Réinitialisation complète effectuée - \(totalDeleted) objets supprimés")
            
            // Réinitialiser les UserDefaults
            print("🔄 [DataOptionsView] Réinitialisation UserDefaults")
            resetUserDefaultsCompletely()
            
            // Feedback de succès
            print("✅ [DataOptionsView] Feedback de succès")
            HapticFeedbackManager.shared.notification(type: .success)
            
            // Navigation vers l'onboarding après un délai
            print("⏰ [DataOptionsView] Planification navigation vers onboarding dans 1.0s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🧭 [DataOptionsView] Lancement navigation vers onboarding")
                navigateToOnboarding()
            }
        } catch {
            print("❌ Erreur lors de la sauvegarde: \(error)")
            HapticFeedbackManager.shared.notification(type: .error)
            isResetting = false
        }
        
        print("🔍 [DataOptionsView] === FIN performCompleteReset() ===")
    }
    
    private func resetUserDefaultsCompletely() {
        print("🔍 [DataOptionsView] === DÉBUT resetUserDefaultsCompletely() ===")
        let defaults = UserDefaults.standard
        // Supprimer TOUTES les clés UserDefaults de l'app
        if let bundleID = Bundle.main.bundleIdentifier {
            print("🗑️ [DataOptionsView] Suppression domaine persistant: \(bundleID)")
            defaults.removePersistentDomain(forName: bundleID)
            defaults.synchronize()
        }
        print("✅ UserDefaults complètement réinitialisés")
        print("🔍 [DataOptionsView] === FIN resetUserDefaultsCompletely() ===")
    }
    
    private func navigateToOnboarding() {
        print("🔍 [DataOptionsView] === DÉBUT navigateToOnboarding() ===")
        // Envoyer une notification pour déclencher l'onboarding
        print("📡 [DataOptionsView] Envoi notification resetToOnboarding")
        NotificationCenter.default.post(name: .resetToOnboarding, object: nil)
        isResetting = false
        print("✅ [DataOptionsView] Navigation vers onboarding terminée")
        print("🔍 [DataOptionsView] === FIN navigateToOnboarding() ===")
    }
}

struct DataManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showResetAlert = false
    @State private var isResetting = false
    
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    var body: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                VStack(spacing: 12) {
                    Text(String(localized: "alert_complete_reset"))
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text(String(localized: "reset_app_description"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        HapticFeedbackManager.shared.impact(style: .heavy)
                        showResetAlert = true
                    }) {
                        HStack {
                            if isResetting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.headline.weight(.semibold))
                            }
                            
                            Text(isResetting ? String(localized: "action_resetting") : String(localized: "action_reset_app"))
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red)
                        )
                    }
                    .disabled(isResetting)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
        }
        .navigationTitle(String(localized: "action_reset"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "alert_complete_reset"), isPresented: $showResetAlert) {
            Button(String(localized: "action_reset"), role: .destructive) {
                performCompleteReset()
            }
            Button(String(localized: "action_cancel"), role: .cancel) { }
        } message: {
            Text(String(localized: "alert_reset_confirmation"))
        }
    }
    
    private func performCompleteReset() {
        isResetting = true
        HapticFeedbackManager.shared.impact(style: .heavy)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completeApplicationReset()
        }
    }
    
    // ✅ Version avancée du reset complet
    private func completeApplicationReset() {
        isResetting = true
        HapticFeedbackManager.shared.impact(style: .heavy)
        
        Task {
            do {
                // 1. Arrêter les syncs et observateurs
                NotificationCenter.default.removeObserver(self)
                
                // 2. Suppression Core Data avec store physique
                try await clearCoreDataCompletely()
                
                // 3. Suppression Keychain
                await MainActor.run { clearKeychain() }
                
                // 4. Suppression fichiers système
                try await clearAllFileSystemData()
                
                // 5. Nettoyage App Groups (si applicable)
                await MainActor.run { clearAppGroupData() }
                
                // 6. UserDefaults (en dernier)
                await MainActor.run { clearUserDefaults() }
                
                // 7. Recharger widgets
                await MainActor.run { reloadWidgets() }
                
                await MainActor.run {
                    self.finalizeReset()
                }
                
            } catch {
                await MainActor.run {
                    print("❌ Erreur reset complet: \(error)")
                    self.isResetting = false
                    // Afficher erreur à l'utilisateur
                }
            }
        }
    }
    
    private func finalizeReset() {
        isResetting = false
        showConfirmationAlert()
    }
    
    // ✅ CORRECTION : Remplacement d'exit(0) par notification
    private func showConfirmationAlert() {
        let alert = UIAlertController(
            title: String(localized: "alert_reset_completed"),
            message: "L'application va redémarrer l'onboarding.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: String(localized: "alert_ok"), style: .default) { _ in
            HapticFeedbackManager.shared.notification(type: .success)
            
            // ✅ Redémarrage immédiat et propre
            DispatchQueue.main.async {
                self.restartOnboardingCleanly()
            }
        })
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                var topController = window.rootViewController
                while let presentedController = topController?.presentedViewController {
                    topController = presentedController
                }
                topController?.present(alert, animated: true) {
                    print("✅ Alerte de confirmation affichée")
                }
            }
        }
    }

    private func restartOnboardingCleanly() {
        // Fermer toutes les vues modales
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            // Réinitialiser complètement la fenêtre
            window.rootViewController?.dismiss(animated: false)
            
            // Déclencher le redémarrage via notification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("RestartOnboarding"),
                    object: nil
                )
            }
        }
    }
    
    // MARK: - Keychain Cleanup
    private func clearKeychain() {
        let secClasses = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]
        
        for secClass in secClasses {
            let query: [String: Any] = [kSecClass as String: secClass]
            let status = SecItemDelete(query as CFDictionary)
            print("🗑️ Keychain \(secClass): \(status)")
        }
    }
    
    // MARK: - File System Cleanup
    private func clearAllFileSystemData() async throws {
        await Task.detached {
            let fileManager = FileManager.default
            
            // Documents Directory
            if let documentsURL = fileManager.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first {
                try? fileManager.removeItem(at: documentsURL)
                try? fileManager.createDirectory(at: documentsURL,
                                              withIntermediateDirectories: true)
                print("🗑️ Documents Directory nettoyé")
            }
            
            // Caches Directory
            if let cachesURL = fileManager.urls(for: .cachesDirectory,
                                               in: .userDomainMask).first {
                try? fileManager.removeItem(at: cachesURL)
                try? fileManager.createDirectory(at: cachesURL,
                                              withIntermediateDirectories: true)
                print("🗑️ Caches Directory nettoyé")
            }
            
            // Application Support
            if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first {
                try? fileManager.removeItem(at: appSupportURL)
                try? fileManager.createDirectory(at: appSupportURL,
                                              withIntermediateDirectories: true)
                print("🗑️ Application Support nettoyé")
            }
        }.value
    }
    
    private func clearAppGroupData() {
        // Utilisation du seul App Group effectif pour la réinitialisation
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.Coefficient.PARALLAX2"
        ) else {
            print("⚠️ Aucun App Group configuré")
            return
        }
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: groupURL,
                includingPropertiesForKeys: nil
            )
            for url in contents {
                try FileManager.default.removeItem(at: url)
            }
            print("🗑️ App Group nettoyé")
        } catch {
            print("❌ Erreur nettoyage App Group: \(error)")
        }
    }
    
    // MARK: - Core Data Physical Files
    private func clearCoreDataStore() throws {
        let coordinator = viewContext.persistentStoreCoordinator
        
        for store in coordinator?.persistentStores ?? [] {
            if let storeURL = store.url {
                try coordinator?.remove(store)
                try FileManager.default.removeItem(at: storeURL)
                
                // Supprimer les fichiers associés
                let walURL = storeURL.appendingPathExtension("sqlite-wal")
                let shmURL = storeURL.appendingPathExtension("sqlite-shm")
                
                try? FileManager.default.removeItem(at: walURL)
                try? FileManager.default.removeItem(at: shmURL)
                
                print("🗑️ Store Core Data physique supprimé")
            }
        }
    }
    
    // MARK: - Complete Core Data Cleanup
    private func clearCoreDataCompletely() async throws {
        try await viewContext.perform {
            print("🗑️ Début suppression données Core Data...")
            
            let entities: [NSFetchRequest] = [
                Flashcard.fetchRequest(),
                FlashcardDeck.fetchRequest(),
                Evaluation.fetchRequest(),
                Subject.fetchRequest(),
                Period.fetchRequest()
            ]
            
            for entityRequest in entities {
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: entityRequest)
                deleteRequest.resultType = .resultTypeObjectIDs
                
                let result = try self.viewContext.execute(deleteRequest) as? NSBatchDeleteResult
                
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.viewContext])
                }
                
                print("✅ \(entityRequest.entityName ?? "Entity") supprimée")
            }
            
            try self.viewContext.save()
            self.viewContext.refreshAllObjects()
            print("✅ Toutes les données Core Data supprimées")
        }
    }
    
    // MARK: - Widgets Reload
    private func reloadWidgets() {
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
            print("🔄 Widgets rechargés")
        }
    }
    
    // MARK: - Enhanced UserDefaults Cleanup
    private func clearUserDefaults() {
        // Supprimer le domaine persistant
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
            print("🗑️ UserDefaults domaine supprimé")
        }
        
        // Réinitialiser UNIQUEMENT les valeurs par défaut de l'app
        let defaults: [String: Any] = [
            "hasCompletedOnboarding": false,
            "onboardingPeriodProcessed": false,
            "GradingSystem": "france",
            "enableHaptics": true,
            "darkModeEnabled": false,
            "username": "",
            "profileSubtitle": "",
            "profileGradientStartHex": "90A4AE",
            "profileGradientEndHex": "253137"
        ]
        
        for (key, value) in defaults {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        UserDefaults.standard.synchronize()
        print("✅ UserDefaults réinitialisés")
    }
}
