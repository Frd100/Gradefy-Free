import SwiftUI
import CoreData

// MARK: - Vue de génération IA avec MLX optimisé

struct AIGenerationView: View {
    let deck: FlashcardDeck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var prompt = ""
    @State private var numberOfFlashcards = 3
    @State private var selectedLanguage: GenerationLanguage = .french
    @State private var isGenerating = false
    @State private var generationProgress = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Instance MLX optimisée
    @StateObject private var aiGenerator = AIFlashcardGenerator.shared
    
    var body: some View {
        VStack(spacing: 24) {
            // Header avec bouton X
            HStack {
                Spacer()
                Button {
                    HapticFeedbackManager.shared.impact(style: .light)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                }
            }
            .padding(.horizontal)
            
            // Titre
            VStack(spacing: 8) {
                Text("AI Flashcard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            

            
            // Zone de prompt
            VStack(alignment: .leading, spacing: 12) {
                Text("Contexte pour la génération")
                    .font(.headline)
                
                TextEditor(text: $prompt)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
            .padding(.horizontal)
            
            // Sélecteur de langue
            VStack(alignment: .leading, spacing: 12) {
                Text("Langue")
                    .font(.headline)
                
                Menu {
                    ForEach(GenerationLanguage.allCases, id: \.self) { language in
                        Button(language.displayName) {
                            selectedLanguage = language
                            HapticFeedbackManager.shared.impact(style: .light)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        Text(selectedLanguage.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)
            
            // Sélecteur de nombre
            VStack(alignment: .leading, spacing: 12) {
                Text("Nombre de cartes")
                    .font(.headline)
                
                Picker("Nombre", selection: $numberOfFlashcards) {
                    ForEach([1, 2, 3, 4, 5], id: \.self) { number in
                        Text("\(number)").tag(number)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal)
            
            // Bouton de génération
            VStack(spacing: 16) {
                Button {
                    HapticFeedbackManager.shared.impact(style: .soft)
                    generateFlashcards()
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        
                        Text(isGenerating ? "Génération en cours..." : "Générer")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isGenerating ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isGenerating || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                // Progression
                if isGenerating {
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(LinearProgressViewStyle())
                            .scaleEffect(y: 0.8)
                        
                        Text(generationProgress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.vertical)
        .alert("Erreur de génération", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }

        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - Méthodes privées
    
    private func setupInitialState() {
        // Suggestion de prompt basée sur le nom du deck
        if prompt.isEmpty {
            let deckName = deck.name ?? "ce deck"
            prompt = "Créez des flashcards variées et progressives pour \(deckName). Incluez des questions de différents niveaux de difficulté."
        }
        
        // Vérification du statut du modèle
        Task {
            if !aiGenerator.isReady {
                generationProgress = "Vérification du modèle MLX..."
            }
        }
    }
    
    private func generateFlashcards() {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Veuillez saisir un contexte pour la génération"
            showError = true
            return
        }
        
        isGenerating = true
        generationProgress = "Préparation de la génération..."
        
        let request = FlashcardGenerationRequest(
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            count: numberOfFlashcards,
            deck: deck,
            language: selectedLanguage
        )
        
        Task {
            generationProgress = "Chargement du modèle MLX..."
            
            let success = await aiGenerator.generateAndSaveFlashcards(
                request: request,
                context: viewContext
            )
            
            await MainActor.run {
                isGenerating = false
                
                if success {
                    HapticFeedbackManager.shared.impact(style: .soft)
                    dismiss()
                } else {
                    errorMessage = "La génération a échoué. Veuillez réessayer."
                    showError = true
                    HapticFeedbackManager.shared.impact(style: .soft)
                }
            }
        }
    }
}

// MARK: - Vue asynchrone pour les appels async

struct AsyncView<Content: View>: View {
    let content: () async -> Content
    @State private var result: Content?
    
    init(@ViewBuilder content: @escaping () async -> Content) {
        self.content = content
    }
    
    var body: some View {
        Group {
            if let result = result {
                result
            } else {
                ProgressView()
                    .onAppear {
                        Task {
                            result = await content()
                        }
                    }
            }
        }
    }
}



