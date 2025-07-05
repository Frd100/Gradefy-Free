import AppIntents
import ActivityKit

struct PauseResumeRevisionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause ou Reprendre"
    static var description = IntentDescription("Met en pause ou reprend la session de révision.")

    // Paramètre optionnel si tu veux passer un état (ici non utilisé)
    init() {}

    func perform() async throws -> some IntentResult {
        // Exemple : enregistrer l'action dans UserDefaults (App Group) pour que l'app principale la récupère
        let defaults = UserDefaults(suiteName: "group.com.coefficient.revision")
        defaults?.set(Date().timeIntervalSince1970, forKey: "pauseResumeRequested")
        // Tu peux aussi poster une notification locale pour debug
        return .result()
    }
}

