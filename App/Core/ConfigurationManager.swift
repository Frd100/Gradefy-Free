import CoreData
import Foundation

@MainActor
class ConfigurationManager: ObservableObject {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Core Data Operations ONLY

    /// Récupère la configuration depuis Core Data (pas de sync UserDefaults)
    func fetchUserConfiguration() async throws -> UserConfiguration? {
        return try await context.perform {
            let request: NSFetchRequest<UserConfiguration> = UserConfiguration.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \UserConfiguration.lastModifiedDate, ascending: false)]
            request.fetchLimit = 1

            let configurations = try self.context.fetch(request)
            return configurations.first
        }
    }

    /// Sauvegarde UNIQUEMENT dans Core Data (ne touche PAS aux UserDefaults)
    func saveUserConfiguration(
        username: String,
        selectedSystem: String,
        profileGradientStart: String,
        profileGradientEnd: String,
        activePeriodID: String
    ) async throws {
        try await context.perform {
            let request: NSFetchRequest<UserConfiguration> = UserConfiguration.fetchRequest()
            let configurations = try self.context.fetch(request)

            let config: UserConfiguration
            if let existingConfig = configurations.first {
                config = existingConfig
            } else {
                config = UserConfiguration(context: self.context)
                config.id = UUID()
                config.createdDate = Date()
            }

            // ✅ Mise à jour complète
            config.username = username
            config.selectedSystem = selectedSystem
            config.profileGradientStart = profileGradientStart
            config.profileGradientEnd = profileGradientEnd
            config.activePeriodID = activePeriodID
            config.hasCompletedOnboarding = true
            config.lastModifiedDate = Date()

            try self.context.save()

            // ✅ Synchronisation UserDefaults
            UserDefaults.standard.set(selectedSystem, forKey: "GradingSystem")
            UserDefaults.standard.set(username, forKey: "Username")
            UserDefaults.standard.set(profileGradientStart, forKey: "ProfileGradientStart")
            UserDefaults.standard.set(profileGradientEnd, forKey: "ProfileGradientEnd")
            UserDefaults.standard.set(activePeriodID, forKey: "ActivePeriodID")
            UserDefaults.standard.synchronize()
        }
    }

    // MARK: - UserDefaults Operations ONLY

    /// Lit les préférences actuelles depuis UserDefaults
    func getCurrentUserPreferences() -> UserPreferences {
        let preferences = UserPreferences(
            username: UserDefaults.standard.string(forKey: "username") ?? "",
            selectedSystem: UserDefaults.standard.string(forKey: "GradingSystem") ?? "france",
            profileGradientStart: UserDefaults.standard.string(forKey: "profileGradientStartHex") ?? "90A4AE",
            profileGradientEnd: UserDefaults.standard.string(forKey: "profileGradientEndHex") ?? "253137"
        )

        print("📖 [CONFIG] Préférences lues depuis UserDefaults: \(preferences)")
        return preferences
    }

    /// Sauvegarde les préférences UserDefaults vers Core Data (direction inverse)
    func saveCurrentPreferencesToCoreData() async {
        let preferences = getCurrentUserPreferences()

        do {
            try await saveUserConfiguration(
                username: preferences.username,
                selectedSystem: preferences.selectedSystem,
                profileGradientStart: preferences.profileGradientStart,
                profileGradientEnd: preferences.profileGradientEnd,
                activePeriodID: UserDefaults.standard.string(forKey: "selectedPeriodID") ?? ""
            )
            print("✅ [CONFIG] Préférences UserDefaults → Core Data")
        } catch {
            print("❌ [CONFIG] Erreur sauvegarde vers Core Data: \(error)")
        }
    }

    // MARK: - Initialization ONLY (no overriding)

    /// Initialise les UserDefaults UNIQUEMENT si vides (premier lancement)
    func initializeUserDefaultsIfNeeded() {
        // Ne pas écraser si onboarding terminé
        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            return
        }

        if UserDefaults.standard.string(forKey: "GradingSystem") == nil {
            UserDefaults.standard.set("france", forKey: "GradingSystem")
        }
    }

    func fixUSASystemOnce() {
        let hasBeenFixed = UserDefaults.standard.bool(forKey: "USASystemFixed")
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        // ✅ Ne pas corriger après onboarding
        if hasBeenFixed || hasCompletedOnboarding {
            return
        }

        if UserDefaults.standard.string(forKey: "GradingSystem") == "usa" {
            UserDefaults.standard.set("france", forKey: "GradingSystem")
        }
        UserDefaults.standard.set(true, forKey: "USASystemFixed")
    }

    // MARK: - Debug and Diagnostics

    func debugUserPreferences() {
        let preferences = getCurrentUserPreferences()

        print("=== DEBUG USER PREFERENCES ===")
        print("Username: '\(preferences.username)'")
        print("Système: '\(preferences.selectedSystem)'")
        print("Couleur start: '\(preferences.profileGradientStart)'")
        print("Couleur end: '\(preferences.profileGradientEnd)'")
        print("==============================")
    }
}

// MARK: - Supporting Types

struct UserPreferences {
    let username: String
    let selectedSystem: String
    let profileGradientStart: String
    let profileGradientEnd: String
}
