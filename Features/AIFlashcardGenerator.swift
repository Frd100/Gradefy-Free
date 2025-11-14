import CommonCrypto
import CoreData
import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import UIKit // ✅ AJOUT - Pour UIDevice

// MARK: - Structures de données

enum GenerationLanguage: String, CaseIterable {
    case french = "Français"
    case english = "English"
    case spanish = "Español"
    case german = "Deutsch"

    var displayName: String {
        return rawValue
    }
}

struct FlashcardGenerationRequest {
    let prompt: String
    let count: Int
    let deck: FlashcardDeck
    let language: GenerationLanguage
}

struct GeneratedFlashcardData: Codable {
    let question: String
    let answer: String
}

struct FlashcardGenerationResponse {
    let flashcards: [GeneratedFlashcardData]
    let success: Bool
    let error: String?
}

struct FlashcardJSONResponse: Codable {
    let flashcards: [GeneratedFlashcardData]
}

enum AIGenerationError: Error {
    case modelNotFound
    case modelLoadFailed
    case generationFailed
    case parsingFailed
    case invalidInput(String)
    case memoryLimitReached
    case timeout

    var localizedDescription: String {
        switch self {
        case .modelNotFound:
            return "Modèle SmolLM3-3B non trouvé"
        case .modelLoadFailed:
            return "Échec du chargement du modèle"
        case .generationFailed:
            return "Échec de la génération des flashcards"
        case .parsingFailed:
            return "Échec du parsing de la réponse"
        case let .invalidInput(message):
            return "Entrée invalide: \(message)"
        case .memoryLimitReached:
            return "Limite de mémoire atteinte"
        case .timeout:
            return "Délai d'attente dépassé"
        }
    }
}

// MARK: - AIFlashcardGenerator avec MLX optimisé

@MainActor
class AIFlashcardGenerator: ObservableObject {
    // MARK: - Propriétés MLX optimisées

    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    private var kvCache: [KVCache] = []
    private var currentModel: ModelContainer? // ✅ AJOUT - Variable manquante
    private var isCacheInitialized = false // ✅ NOUVEAU - Suivi de l'initialisation du cache

    // MARK: - Configuration optimisée

    private let modelName = "SmolLM3-3B-4bit"

    // MARK: - Configuration de génération

    // ✅ Configuration fixe : Tous les appareils ont ≥5GB RAM (vérification dans ModelManager)
    private let maxTokens: Int = 1024
    private let temperature: Float = 0.9
    private let topP: Float = 0.9

    // MARK: - Cache et performance

    private var isModelLoaded = false
    private var lastGenerationTime: Date?
    private let generationTimeout: TimeInterval = 30.0
    private var generationCount = 0 // ✅ NOUVEAU - Compteur de générations
    private let maxGenerationsBeforeReset = 10 // ✅ NOUVEAU - Reset tous les 10 générations

    // MARK: - Singleton optimisé

    static let shared = AIFlashcardGenerator()

    private init() {
        setupModelPath()
    }

    // MARK: - Méthodes isolées pour les propriétés @MainActor

    @MainActor
    private func getKVCache() -> [KVCache] {
        return kvCache
    }

    @MainActor
    private func setKVCache(_ cache: [KVCache]) {
        kvCache = cache
    }

    // MARK: - Configuration du modèle

    private func setupModelPath() {
        let modelPath = getModelPath()
        print("📁 Modèle MLX configuré pour: \(modelPath)")
    }

    private func getModelPath() -> String {
        // Utiliser le même chemin que ModelManager
        let appSupport: URL
        do {
            appSupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            // En cas d'erreur, utiliser un chemin par défaut
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            appSupport = documentsPath
        }
        let modelPath = appSupport.appendingPathComponent("Models").appendingPathComponent(modelName)
        return modelPath.path
    }

    // MARK: - Chargement de modèle optimisé

    func loadModel() async throws {
        guard !isModelLoaded else {
            print("✅ Modèle déjà chargé")
            return
        }

        print("🔄 Chargement du modèle MLX...")

        do {
            let modelPath = getModelPath()

            // ✅ VÉRIFICATION : Modèle téléchargé via ModelManager
            guard FileManager.default.fileExists(atPath: modelPath) else {
                print("❌ Modèle non trouvé à: \(modelPath)")
                print("📥 Veuillez télécharger le modèle via ModelManager")
                throw AIGenerationError.modelNotFound
            }

            // Vérification de l'existence du fichier model.safetensors
            let modelFile = URL(filePath: modelPath).appendingPathComponent("model.safetensors")
            guard FileManager.default.fileExists(atPath: modelFile.path) else {
                print("❌ Fichier model.safetensors non trouvé dans: \(modelPath)")
                print("📥 Le modèle semble incomplet, veuillez le retélécharger via ModelManager")
                throw AIGenerationError.modelNotFound
            }

            print("✅ Modèle trouvé: \(modelPath)")
            print("✅ Fichier model.safetensors trouvé")

            // Configuration du modèle MLX avec paramètres SmolLM3
            let modelConfiguration = ModelConfiguration(directory: URL(filePath: modelPath))

            // Chargement du modèle avec LLMModelFactory
            modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: modelConfiguration)

            isModelLoaded = true
            print("✅ Modèle MLX chargé avec succès")

        } catch {
            print("❌ Erreur de chargement du modèle: \(error)")
            throw AIGenerationError.modelLoadFailed
        }
    }

    // MARK: - Déchargement de modèle

    func unloadModel() {
        print("🔄 Déchargement du modèle MLX...")

        // Libérer le contexte et le conteneur
        setKVCache([]) // ✅ AJOUT CRITIQUE - Nettoyer le cache KV
        isCacheInitialized = false // ✅ NOUVEAU - Reset du flag de cache
        modelContext = nil
        modelContainer = nil
        isModelLoaded = false

        print("✅ Modèle MLX déchargé")
    }

    // MARK: - Génération optimisée

    func generateAndSaveFlashcards(request: FlashcardGenerationRequest, context: NSManagedObjectContext) async -> Bool {
        print("🚀 Début de génération MLX optimisée")

        do {
            // Chargement du modèle si nécessaire
            if !isModelLoaded {
                try await loadModel()
            }

            // ✅ NOUVEAU - Reset préventif tous les 10 générations
            generationCount += 1
            if generationCount >= maxGenerationsBeforeReset {
                print("🔄 Reset préventif après \(generationCount) générations")
                await hardModelReset()
                generationCount = 0
            }

            // Vérification du timeout
            if let lastTime = lastGenerationTime,
               Date().timeIntervalSince(lastTime) < generationTimeout
            {
                print("⏰ Attente du timeout de génération...")
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde
            }

            // Génération avec MLX
            let response = try await generateFlashcardsMLX(request: request)

            if response.success {
                // Sauvegarde optimisée
                let savedCount = await saveFlashcardsToCoreData(
                    flashcards: response.flashcards,
                    deck: request.deck,
                    context: context
                )

                lastGenerationTime = Date()
                print("✅ \(savedCount) flashcards générées et sauvegardées")

                return true
            } else {
                print("❌ Échec de génération: \(response.error ?? "Erreur inconnue")")
                return false
            }

        } catch {
            print("❌ Erreur de génération MLX: \(error)")
            return false
        }
    }

    // MARK: - Génération MLX optimisée

    private func generateFlashcardsMLX(request: FlashcardGenerationRequest) async throws -> FlashcardGenerationResponse {
        print("🔍 [DEBUG] generateFlashcardsMLX - Début génération pour \(request.count) cartes")
        guard let modelContainer = modelContainer else {
            throw AIGenerationError.modelNotFound
        }

        // Prompt optimisé pour MLX
        let optimizedPrompt = createOptimizedPrompt(for: request)

        print("📝 Génération avec prompt optimisé...")
        print("🔍 === PROMPT ENVOYÉ AU MODÈLE ===")
        print(optimizedPrompt)
        print("🔍 === FIN DU PROMPT ===")

        do {
            // Configuration de génération optimisée
            let parameters = GenerateParameters(
                maxTokens: maxTokens,
                temperature: temperature,
                topP: topP,
                repetitionPenalty: 1.1 // ✅ NOUVEAU - Évite les répétitions
            )

            // Génération avec streaming optimisé
            let userInput = UserInput(prompt: optimizedPrompt)

            return try await modelContainer.perform { context in
                let lmInput = try await context.processor.prepare(input: userInput)

                // ✅ OPTIMISATION CRITIQUE - Réutiliser le cache KV
                let cache: [KVCache]
                let cacheInitialized = await MainActor.run { isCacheInitialized }

                if !cacheInitialized {
                    // Créer le cache seulement la première fois
                    print("🆕 Création du cache KV (première génération)")
                    cache = context.model.newCache(parameters: parameters)
                    await MainActor.run {
                        setKVCache(cache)
                        isCacheInitialized = true
                    }
                } else {
                    // Réutiliser le cache existant
                    print("♻️ Réutilisation du cache KV existant")
                    cache = await MainActor.run { getKVCache() }
                }

                let stream = try MLXLMCommon.generate(
                    input: lmInput,
                    cache: cache, // ✅ UTILISER LE CACHE KV (réutilisé ou nouveau)
                    parameters: parameters,
                    context: context
                )

                var generatedText = ""
                var tokenCount = 0

                // Collecte du texte généré
                outerLoop: for await item in stream {
                    switch item {
                    case let .chunk(string):
                        generatedText += string
                        tokenCount += 1

                        // ✅ NOUVEAU - Détection de boucle de répétition
                        if generatedText.count > 200 && generatedText.contains("Sociology is the study of human social behavior") {
                            print("⚠️ Boucle de répétition détectée, arrêt de la génération")
                            break
                        }

                        // ✅ NOUVEAU - Détection de boucle JSON
                        if generatedText.count > 100 && generatedText.contains("{\"flashcards\":[{\"question\":\"\",\"answer\":\"\"}]}") {
                            let jsonPattern = "{\"flashcards\":[{\"question\":\"\",\"answer\":\"\"}]}"
                            let occurrences = generatedText.components(separatedBy: jsonPattern).count - 1
                            if occurrences > 3 {
                                print("⚠️ Boucle JSON détectée (\(occurrences) occurrences), arrêt de la génération")
                                break outerLoop
                            }
                        }

                        // Arrêt si on dépasse la limite
                        if tokenCount >= maxTokens {
                            print("📊 Limite de tokens atteinte: \(tokenCount)")
                            break outerLoop
                        }

                        // ✅ OPTIMISATION : Ne plus parser le JSON pendant la génération
                        // Le parsing se fera une seule fois à la fin, après la boucle

                    case let .info(info):
                        print("✅ Génération terminée: \(info.tokensPerSecond) tokens/s")
                        break outerLoop

                    case .toolCall:
                        break
                    }
                }

                // ✅ AJOUT - Logging de la réponse complète
                print("📄 === RÉPONSE COMPLÈTE DU MODÈLE ===")
                print(generatedText)
                print("📄 === FIN DE LA RÉPONSE ===")

                // Parsing optimisé
                let flashcards = try await parseFlashcardResponseMLX(generatedText, expectedCount: request.count, language: request.language)

                // ✅ NOUVEAU - Nettoyage mémoire après génération
                await cleanupAfterGeneration()

                return FlashcardGenerationResponse(
                    flashcards: flashcards,
                    success: true,
                    error: nil
                )
            }

        } catch {
            print("❌ Erreur de génération MLX: \(error)")

            // ✅ NOUVEAU - Nettoyage même en cas d'erreur
            await cleanupAfterGeneration()

            return FlashcardGenerationResponse(
                flashcards: [],
                success: false,
                error: error.localizedDescription
            )
        }
    }

    // MARK: - Prompt optimisé pour MLX

    private func createOptimizedPrompt(for request: FlashcardGenerationRequest) -> String {
        let count = request.count

        switch request.language {
        case .french:
            return """
            <|system|>
            Tu es un assistant éducatif spécialisé dans la création de flashcards de haute qualité. Réponds UNIQUEMENT avec du JSON valide et complet.
            <|user|>
            Crée exactement \(count) flashcards sur : \(request.prompt)

            Chaque flashcard doit inclure :
            - une question claire et concise
            - une réponse informative mais brève

            IMPORTANT : Réponds UNIQUEMENT avec le JSON complet, sans texte supplémentaire. Assure-toi que le JSON est valide et se termine par les accolades de fermeture.

            Format JSON requis :
            {
              "flashcards":[
                {"question":"Question claire","answer":"Réponse concise"},
                {"question":"Question claire","answer":"Réponse concise"},
                {"question":"Question claire","answer":"Réponse concise"}
              ]
            }
            <|assistant|>
            """

        case .english:
            return """
            <|system|>
            You are an educational assistant specialised in creating high-quality flashcards. Respond ONLY with valid and complete JSON.
            <|user|>
            Create exactly \(count) flashcards about: \(request.prompt)

            Each flashcard must include:
            - a clear and concise question
            - an informative but brief answer

            IMPORTANT: Respond ONLY with complete JSON, no additional text. Ensure the JSON is valid and ends with closing braces.

            Required JSON format:
            {
              "flashcards":[
                {"question":"Clear question","answer":"Concise answer"},
                {"question":"Clear question","answer":"Concise answer"},
                {"question":"Clear question","answer":"Concise answer"}
              ]
            }
            <|assistant|>
            """

        case .spanish:
            return """
            <|system|>
            Eres un asistente educativo especializado en crear flashcards de alta calidad. Responde ÚNICAMENTE con JSON válido y completo.
            <|user|>
            Crea exactamente \(count) flashcards sobre: \(request.prompt)

            Cada flashcard debe incluir:
            - una pregunta clara y concisa
            - una respuesta informativa pero breve

            IMPORTANTE: Responde ÚNICAMENTE con JSON completo, sin texto adicional. Asegúrate de que el JSON sea válido y termine con llaves de cierre.

            Formato JSON requerido:
            {
              "flashcards":[
                {"question":"Pregunta clara","answer":"Respuesta concisa"},
                {"question":"Pregunta clara","answer":"Respuesta concisa"},
                {"question":"Pregunta clara","answer":"Respuesta concisa"}
              ]
            }
            <|assistant|>
            """

        case .german:
            return """
            <|system|>
            Du bist ein Bildungsassistent, der sich auf die Erstellung hochwertiger Lernkarten spezialisiert hat. Antworte NUR mit gültigem und vollständigem JSON.
            <|user|>
            Erstelle genau \(count) Lernkarten über: \(request.prompt)

            Jede Lernkarte muss enthalten:
            - eine klare und prägnante Frage
            - eine informative aber kurze Antwort

            WICHTIG: Antworte NUR mit vollständigem JSON, ohne zusätzlichen Text. Stelle sicher, dass das JSON gültig ist und mit schließenden Klammern endet.

            Erforderliches JSON-Format:
            {
              "flashcards":[
                {"question":"Klare Frage","answer":"Kurze Antwort"},
                {"question":"Klare Frage","answer":"Kurze Antwort"},
                {"question":"Klare Frage","answer":"Kurze Antwort"}
              ]
            }
            <|assistant|>
            """
        }
    }

    // MARK: - Nettoyage mémoire

    private func cleanupAfterGeneration() async {
        print("🧹 === NETTOYAGE MÉMOIRE APRÈS GÉNÉRATION ===")

        // ❌ NE PAS décharger le modèle (on le garde en mémoire)
        // ❌ NE PAS vider le cache KV (on le réutilise)

        // ✅ Forcer l'évaluation des opérations MLX en attente
        MLX.eval([])

        // ✅ Nettoyer le cache GPU
        MLX.GPU.clearCache()

        // ✅ Limiter le cache GPU à 256MB
        MLX.GPU.set(cacheLimit: 256 * 1024 * 1024)

        // ✅ Petit délai pour le nettoyage asynchrone
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconde

        // Log de la mémoire utilisée
        let memoryInfo = getMemoryUsage()
        print("📊 Mémoire après nettoyage: \(memoryInfo.used) MB / \(memoryInfo.total) MB")

        print("🧹 Nettoyage mémoire effectué (modèle et cache conservés)")
        print("✅ === NETTOYAGE TERMINÉ ===")
    }

    private func getMemoryUsage() -> (used: Int, total: Int) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMB = Int(info.resident_size / 1024 / 1024)
            let totalMB = Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024)
            return (used: usedMB, total: totalMB)
        }

        return (used: 0, total: 0)
    }

    // MARK: - Parsing optimisé

    private func parseFlashcardResponseMLX(_ response: String, expectedCount: Int, language: GenerationLanguage) async throws -> [GeneratedFlashcardData] {
        print("🔍 Parsing de la réponse MLX...")
        print("📄 === RÉPONSE BRUTE DU MODÈLE ===")
        print(response)
        print("📄 === FIN DE LA RÉPONSE BRUTE ===")

        // Nettoyage de la réponse
        let cleanedResponse = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .replacingOccurrences(of: "<|end_of_text|>", with: "")

        print("🧹 === RÉPONSE NETTOYÉE ===")
        print(cleanedResponse)
        print("🧹 === FIN DE LA RÉPONSE NETTOYÉE ===")

        // Essayer d'extraire le JSON
        if let jsonObject = extractFirstJSONObject(cleanedResponse) {
            print("🔧 === JSON EXTRACTÉ ===")
            print(jsonObject)
            print("🔧 === FIN DU JSON EXTRACTÉ ===")

            do {
                let data = jsonObject.data(using: .utf8) ?? Data()
                let jsonResponse = try JSONDecoder().decode(FlashcardJSONResponse.self, from: data)

                let flashcards = jsonResponse.flashcards.prefix(expectedCount).map { flashcard in
                    GeneratedFlashcardData(
                        question: flashcard.question.trimmingCharacters(in: .whitespacesAndNewlines),
                        answer: flashcard.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }

                print("✅ \(flashcards.count) flashcards parsées avec succès")
                print("📝 === FLASHCARDS FINALES ===")
                for (index, flashcard) in flashcards.enumerated() {
                    print("Flashcard \(index + 1):")
                    print("  Q: \(flashcard.question)")
                    print("  A: \(flashcard.answer)")
                }
                print("📝 === FIN DES FLASHCARDS FINALES ===")
                return Array(flashcards)

            } catch {
                print("❌ Erreur de parsing JSON extrait: \(error)")
                print("❌ Détails de l'erreur: \(error.localizedDescription)")
            }
        } else {
            print("❌ Aucun JSON trouvé dans la réponse")
        }

        // Fallback: parsing manuel
        print("🔄 Utilisation du parsing manuel de fallback...")
        return try parseFlashcardsManually(cleanedResponse, expectedCount: expectedCount, language: language)
    }

    // MARK: - Extraction JSON robuste

    private nonisolated func extractFirstJSONObject(_ text: String) -> String? {
        // Nettoyer les blocs ```...```
        let cleaned = text.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // ✅ CRITIQUE - Ignorer tout ce qui est avant <|assistant|>
        if let assistantIndex = cleaned.range(of: "<|assistant|>") {
            let afterAssistant = String(cleaned[assistantIndex.upperBound...])
            return extractJSONFromText(afterAssistant)
        }

        // ✅ CRITIQUE - Si pas de <|assistant|>, chercher le premier { et la première } correspondante
        return extractJSONFromText(cleaned)
    }

    private nonisolated func extractJSONFromText(_ text: String) -> String? {
        // Nettoyer les guillemets non échappés dans les valeurs JSON
        let sanitized = text.replacingOccurrences(of: #"([^\\])"([^"]*)"([^\\])"#, with: "$1\\\"$2\\\"$3", options: .regularExpression)

        // Cas 1 : texte commence par { et finit par }
        if sanitized.first == "{", sanitized.last == "}" {
            let jsonString = String(sanitized)
            // ✅ CRITIQUE - Vérifier que ce n'est pas le JSON d'exemple
            if !jsonString.contains("\"question\":\"...\""), !jsonString.contains("\"answer\":\"...\"") {
                return jsonString
            }
        }

        // Cas 2 : isoler le premier bloc {...} équilibré
        var depth = 0
        var startIndex: String.Index?

        for index in sanitized.indices {
            let character = sanitized[index]
            if character == "{" {
                if depth == 0 {
                    startIndex = index
                }
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0, let start = startIndex {
                    let jsonString = String(sanitized[start ... index])

                    // ✅ CRITIQUE - Vérifier que ce n'est pas le JSON d'exemple
                    if !jsonString.contains("\"question\":\"...\""), !jsonString.contains("\"answer\":\"...\"") {
                        return jsonString
                    }
                }
            }
        }

        // ✅ NOUVEAU - Cas 3 : JSON incomplet, essayer de le compléter
        if let start = startIndex, depth > 0 {
            // ✅ OPTIMISATION : Plus de log ici car cette fonction n'est appelée qu'une fois à la fin
            var incompleteJson = String(sanitized[start...])

            // Ajouter les accolades manquantes
            for _ in 0 ..< depth {
                incompleteJson += "}"
            }

            // Vérifier si c'est un JSON valide maintenant
            if let data = incompleteJson.data(using: .utf8),
               let _ = try? JSONSerialization.jsonObject(with: data)
            {
                print("✅ JSON complété automatiquement")
                return incompleteJson
            }
        }

        return nil
    }

    // MARK: - Parsing manuel de fallback

    private func parseFlashcardsManually(_ text: String, expectedCount: Int, language _: GenerationLanguage = .french) throws -> [GeneratedFlashcardData] {
        print("🔄 Utilisation du parsing manuel amélioré...")
        print("📄 === TEXTE À PARSER MANUELLEMENT ===")
        print(text)
        print("📄 === FIN DU TEXTE À PARSER ===")

        var flashcards: [GeneratedFlashcardData] = []

        // ✅ NOUVEAU - Essayer d'abord de parser le JSON incomplet
        if let jsonFlashcards = tryParseIncompleteJSON(text) {
            print("✅ JSON incomplet parsé avec succès: \(jsonFlashcards.count) flashcards")
            return Array(jsonFlashcards.prefix(expectedCount))
        }

        let sanitizedText = text
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "<|assistant|>", with: "")
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .replacingOccurrences(of: "<|end_of_text|>", with: "")
            .replacingOccurrences(of: "[question]", with: "", options: .caseInsensitive, range: nil)
            .replacingOccurrences(of: "[réponse]", with: "", options: .caseInsensitive, range: nil)
            .replacingOccurrences(of: "[answer]", with: "", options: .caseInsensitive, range: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lines = sanitizedText.components(separatedBy: .newlines)
        var currentQuestion: String?
        var currentAnswer: String?

        func appendCurrentPair() {
            guard let question = currentQuestion?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let answer = currentAnswer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !question.isEmpty,
                  !answer.isEmpty else { return }
            flashcards.append(GeneratedFlashcardData(question: question, answer: answer))
            print("    ✅ Flashcard ajoutée: Q='\(question)' A='\(answer)'")
        }

        print("🔍 === ANALYSE LIGNE PAR LIGNE ===")
        for (index, rawLine) in lines.enumerated() {
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowerLine = trimmedLine.lowercased()
            print("  Ligne \(index + 1): '\(trimmedLine)'")

            guard !trimmedLine.isEmpty else {
                print("    → IGNORÉ: Ligne vide")
                continue
            }

            if let question = extractQuestion(from: trimmedLine, lowercased: lowerLine) {
                appendCurrentPair()
                currentQuestion = question
                currentAnswer = nil
                print("    → QUESTION détectée: \(question)")
                continue
            }

            if let answer = extractAnswer(from: trimmedLine, lowercased: lowerLine) {
                currentAnswer = answer
                print("    → RÉPONSE détectée: \(answer)")
                continue
            }

            if currentQuestion != nil, currentAnswer == nil {
                currentAnswer = trimmedLine
                print("    → UTILISÉ COMME RÉPONSE: \(trimmedLine)")
            } else {
                print("    → IGNORÉ: Sans contexte")
            }
        }

        appendCurrentPair()

        guard !flashcards.isEmpty else {
            throw AIGenerationError.parsingFailed
        }

        if flashcards.count < expectedCount {
            print("⚠️ Moins de flashcards que demandé (\(flashcards.count)/\(expectedCount))")
        }

        print("✅ Parsing manuel terminé: \(flashcards.count) flashcards créées")
        print("📝 === FLASHCARDS MANUELLES FINALES ===")
        for (index, flashcard) in flashcards.enumerated() {
            print("Flashcard \(index + 1):")
            print("  Q: \(flashcard.question)")
            print("  A: \(flashcard.answer)")
        }
        print("📝 === FIN DES FLASHCARDS MANUELLES ===")
        return Array(flashcards.prefix(expectedCount))
    }

    // ✅ NOUVEAU - Parser JSON incomplet
    private func tryParseIncompleteJSON(_ text: String) -> [GeneratedFlashcardData]? {
        // Chercher les patterns de question/réponse dans le JSON incomplet
        let questionPattern = #""question"\s*:\s*"([^"]+)""#
        let answerPattern = #""answer"\s*:\s*"([^"]+)""#

        var flashcards: [GeneratedFlashcardData] = []

        do {
            let questionRegex = try NSRegularExpression(pattern: questionPattern, options: [])
            let answerRegex = try NSRegularExpression(pattern: answerPattern, options: [])

            let range = NSRange(text.startIndex..., in: text)
            let questionMatches = questionRegex.matches(in: text, options: [], range: range)
            let answerMatches = answerRegex.matches(in: text, options: [], range: range)

            let minCount = min(questionMatches.count, answerMatches.count)

            for matchIndex in 0 ..< minCount {
                if let questionRange = Range(questionMatches[matchIndex].range(at: 1), in: text),
                   let answerRange = Range(answerMatches[matchIndex].range(at: 1), in: text)
                {
                    let question = String(text[questionRange])
                    let answer = String(text[answerRange])

                    flashcards.append(GeneratedFlashcardData(
                        question: question.trimmingCharacters(in: .whitespacesAndNewlines),
                        answer: answer.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
            }

            return flashcards.isEmpty ? nil : flashcards

        } catch {
            print("❌ Erreur regex JSON incomplet: \(error)")
            return nil
        }
    }

    private func captureGroup(pattern: String, in string: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: string)
        else {
            return nil
        }
        return String(string[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractQuestion(from line: String, lowercased _: String) -> String? {
        let patterns = [
            #"^\d+[\.\)\-]\s*(.+)$"#,
            #"^(?:question|pregunta|frage)\s*\d*\s*[:\-]\s*(.+)$"#,
            #"^(?:question|pregunta|frage)\s*\d*\.?\s*(.+)$"#,
            #"^(?:q)\s*[:\-]\s*(.+)$"#,
        ]
        for pattern in patterns {
            if let result = captureGroup(pattern: pattern, in: line) {
                return result
            }
        }
        return nil
    }

    private func extractAnswer(from line: String, lowercased _: String) -> String? {
        let patterns = [
            #"^(?:réponse|answer|respuesta|antwort)\s*\d*\s*[:\-]\s*(.+)$"#,
            #"^(?:réponse|answer|respuesta|antwort)\s*\d*\.?\s*(.+)$"#,
            #"^(?:a)\s*[:\-]\s*(.+)$"#,
        ]
        for pattern in patterns {
            if let result = captureGroup(pattern: pattern, in: line) {
                return result
            }
        }
        return nil
    }

    // MARK: - Sauvegarde optimisée

    private func saveFlashcardsToCoreData(flashcards: [GeneratedFlashcardData], deck: FlashcardDeck, context: NSManagedObjectContext) async -> Int {
        print("🔍 [DEBUG] saveFlashcardsToCoreData - Début sauvegarde de \(flashcards.count) flashcards")
        print("🔍 [DEBUG] Deck ID: \(deck.id?.uuidString.prefix(8) ?? "nil")")
        print("💾 Sauvegarde de \(flashcards.count) flashcards...")

        var savedCount = 0

        let deckObjectID = deck.objectID
        await context.perform {
            guard let deck = context.object(with: deckObjectID) as? FlashcardDeck else { return }

            for flashcardData in flashcards {
                let flashcard = Flashcard(context: context)
                flashcard.id = UUID()
                flashcard.question = flashcardData.question
                flashcard.answer = flashcardData.answer
                flashcard.deck = deck
                flashcard.createdAt = Date()
                flashcard.lastReviewed = nil
                flashcard.reviewCount = 0
                flashcard.correctCount = 0
                flashcard.interval = 1.0
                flashcard.easeFactor = 2.5
                flashcard.nextReviewDate = Date()

                savedCount += 1
            }

            do {
                try context.save()
                print("🔍 [DEBUG] saveFlashcardsToCoreData - Sauvegarde réussie: \(savedCount) flashcards")
                print("✅ \(savedCount) flashcards sauvegardées dans Core Data")
            } catch {
                print("❌ Erreur de sauvegarde Core Data: \(error)")
            }
        }

        return savedCount
    }

    // MARK: - Gestion de la mémoire

    func cleanupMemory() {
        print("🧹 Nettoyage de la mémoire MLX...")

        // ✅ AJOUT - Nettoyage complet avec cache KV
        setKVCache([])
        MLX.GPU.clearCache()

        // Libérer la mémoire si le modèle est chargé
        if isModelLoaded {
            unloadModel()
        }

        print("🗑️ Nettoyage mémoire effectué avec cache KV")
    }

    // MARK: - Statut du modèle

    var isReady: Bool {
        return isModelLoaded && modelContainer != nil
    }

    var modelStatus: String {
        if isModelLoaded {
            return "✅ Modèle MLX chargé et prêt"
        } else {
            return "❌ Modèle MLX non chargé"
        }
    }
}

// MARK: - Extensions utilitaires

extension AIFlashcardGenerator {
    func getModelInfo() async -> String {
        return """
        📊 Informations du modèle MLX:
        - Nom: \(modelName)
        - Chargé: \(isModelLoaded ? "Oui" : "Non")
        - Max tokens: \(maxTokens)
        - Température: \(temperature)
        - Top-P: \(topP)
        - Cache KV: \(getKVCache().isEmpty ? "Inactif" : "Actif")
        """
    }

    func resetGenerationState() {
        lastGenerationTime = nil
        print("🔄 État de génération réinitialisé")
    }

    // MARK: - Reset complet du modèle

    private func hardModelReset() async {
        print("🔄 === RESET COMPLET DU MODÈLE ===")

        // 1. Déchargement complet
        modelContainer = nil
        setKVCache([])
        isCacheInitialized = false
        isModelLoaded = false

        // 2. Nettoyage profond de la mémoire MLX
        MLX.eval([])
        MLX.GPU.clearCache()
        MLX.GPU.set(cacheLimit: 256 * 1024 * 1024)

        // 3. Attendre que le système libère la mémoire
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconde

        // 4. Rechargement du modèle
        do {
            try await loadModel()
            print("✅ Reset complet terminé - Modèle rechargé")
        } catch {
            print("❌ Erreur lors du rechargement après reset: \(error)")
        }

        print("✅ === RESET COMPLET TERMINÉ ===")
    }
}
