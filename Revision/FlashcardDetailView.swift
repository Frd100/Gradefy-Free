//
//  FlashcardDetailView.swift
//  PARALLAX
//
//  Vue détaillée d'une flashcard avec support multimédia
//

import SwiftUI
import AVFoundation

struct FlashcardDetailView: View {
    let flashcard: Flashcard
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var audioManager = AudioManager.shared
    
    // États pour la gestion des médias
    @State private var isQuestionAudioPlaying = false
    @State private var isAnswerAudioPlaying = false
    
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                adaptiveBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Section Question
                        questionSection
                        
                        // Section Réponse
                        answerSection
                        
                        // Section Métadonnées
                        metadataSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Détails de la carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                

            }
        }
        .onDisappear {
            // Arrêter l'audio quand on quitte la vue
            audioManager.stopAudio()
        }
    }
    
    // MARK: - Section Question
    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête de section simplifié
            Text("Question")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Contenu de la question
            switch flashcard.questionContentType {
            case .text:
                if let questionText = flashcard.question, !questionText.isEmpty {
                    Text(questionText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                } else {
                    emptyContentPlaceholder("Aucune question textuelle")
                }
                
            case .image:
                if let imageFileName = flashcard.questionImageFileName {
                    VStack(spacing: 12) {
                        if let image = MediaStorageManager.shared.loadImage(
                            fileName: imageFileName,
                            data: flashcard.questionImageData
                        ) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            imageErrorPlaceholder
                        }
                        
                        if let questionText = flashcard.question, !questionText.isEmpty {
                            Text(questionText)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                        }
                    }
                } else {
                    emptyContentPlaceholder("Aucune image de question")
                }
                
            case .audio:
                if let audioFileName = flashcard.questionAudioFileName {
                    VStack(spacing: 12) {
                        audioPlayerView(
                            fileName: audioFileName,
                            isPlaying: $isQuestionAudioPlaying
                        )
                        
                        if let questionText = flashcard.question, !questionText.isEmpty {
                            Text(questionText)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                        }
                    }
                } else {
                    emptyContentPlaceholder("Aucun audio de question")
                }
            }
        }
    }
    
    // MARK: - Section Réponse
    private var answerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête de section simplifié
            Text("Réponse")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Contenu de la réponse
            switch flashcard.answerContentType {
            case .text:
                if let answerText = flashcard.answer, !answerText.isEmpty {
                    Text(answerText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                } else {
                    emptyContentPlaceholder("Aucune réponse textuelle")
                }
                
            case .image:
                if let imageFileName = flashcard.answerImageFileName {
                    VStack(spacing: 12) {
                        if let image = MediaStorageManager.shared.loadImage(
                            fileName: imageFileName,
                            data: flashcard.answerImageData
                        ) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            imageErrorPlaceholder
                        }
                        
                        if let answerText = flashcard.answer, !answerText.isEmpty {
                            Text(answerText)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                        }
                    }
                } else {
                    emptyContentPlaceholder("Aucune image de réponse")
                }
                
            case .audio:
                if let audioFileName = flashcard.answerAudioFileName {
                    VStack(spacing: 12) {
                        audioPlayerView(
                            fileName: audioFileName,
                            isPlaying: $isAnswerAudioPlaying
                        )
                        
                        if let answerText = flashcard.answer, !answerText.isEmpty {
                            Text(answerText)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                        }
                    }
                } else {
                    emptyContentPlaceholder("Aucun audio de réponse")
                }
            }
        }
    }
    
    // MARK: - Section Métadonnées
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête de section simplifié
            Text("Informations")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Liste d'informations verticale
            VStack(spacing: 8) {
                metadataCard(
                    title: "Créée le",
                    value: formatDate(flashcard.createdAt),
                    icon: "",
                    color: .blue
                )
                
                metadataCard(
                    title: "Dernière révision",
                    value: formatDate(flashcard.lastReviewDate),
                    icon: "",
                    color: .green
                )
                
                metadataCard(
                    title: "Réponses correctes",
                    value: "\(flashcard.correctCount)",
                    icon: "",
                    color: .green
                )
                
            }
        }
    }
    
    // MARK: - Composants utilitaires
    
    private func emptyContentPlaceholder(_ message: String) -> some View {
        HStack {
            Image(systemName: "minus.circle")
                .foregroundColor(.secondary)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .italic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
    
    private var imageErrorPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Image non disponible")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
    
    private func audioPlayerView(fileName: String, isPlaying: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                if isPlaying.wrappedValue {
                    audioManager.stopAudio()
                    isPlaying.wrappedValue = false
                } else {
                    audioManager.togglePlayback(fileName: fileName)
                    isPlaying.wrappedValue = true
                }
            }) {
                Image(systemName: isPlaying.wrappedValue ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            
            Text("Audio")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
            // Remettre l'icône en "play" à la fin de l'audio
            DispatchQueue.main.async {
                isPlaying.wrappedValue = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)) { _ in
            // Remettre l'icône en "play" en cas d'erreur
            DispatchQueue.main.async {
                isPlaying.wrappedValue = false
            }
        }
    }
    
    private func metadataCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Jamais" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current // Utilise les paramètres système de l'utilisateur
        
        return formatter.string(from: date)
    }
}

// MARK: - Sheet pour les images en plein écran
struct ImageFullScreenView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 4)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                },
                            DragGesture()
                                .onChanged { value in
                                    let delta = CGSize(
                                        width: value.translation.width - lastOffset.width,
                                        height: value.translation.height - lastOffset.height
                                    )
                                    lastOffset = value.translation
                                    offset = CGSize(
                                        width: offset.width + delta.width,
                                        height: offset.height + delta.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = .zero
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                            } else {
                                scale = 2
                            }
                        }
                    }
            }
            .navigationTitle("Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Preview
struct FlashcardDetailView_Previews: PreviewProvider {
    static var previews: some View {
        FlashcardDetailView(flashcard: sampleFlashcard)
    }
    
    static var sampleFlashcard: Flashcard {
        let card = Flashcard()
        card.question = "Qu'est-ce que la photosynthèse ?"
        card.answer = "La photosynthèse est le processus par lequel les plantes convertissent la lumière solaire en énergie chimique."
        card.questionContentType = .text
        card.answerContentType = .text
        card.createdAt = Date()
        card.lastReviewDate = Date().addingTimeInterval(-86400)
        card.reviewCount = 5
        card.correctCount = 4
        card.easeFactor = 2.5
        card.nextReviewDate = Date().addingTimeInterval(86400 * 3)
        return card
    }
}
