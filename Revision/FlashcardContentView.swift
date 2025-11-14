//
//  FlashcardContentView.swift
//  PARALLAX
//
//  Created by Farid on 7/27/25.
//

import PhotosUI
import SwiftUI

struct FlashcardContentView: View {
    let contentType: FlashcardContentType
    let text: String?
    let imageData: Data?
    let imageFileName: String?
    let audioFileName: String?
    let audioDuration: TimeInterval
    let autoplayManager: AutoplayManager?

    private let mediaStorage = MediaStorageManager.shared
    @StateObject private var audioManager = AudioManager.shared
    @State private var isAnimating = false
    @State private var isFlipped = false

    private func handleFlip() {
        // ✅ 1. Arrêt audio silencieux avec la méthode publique
        if audioManager.isPlaying {
            audioManager.stopAudioSilently() // ✅ Utilise la méthode publique
        }

        // ✅ 2. Animation pure sans interférence audio
        HapticFeedbackManager.shared.selection()
        withAnimation(.linear(duration: 0.3)) {
            isFlipped.toggle()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Partie haute - Texte ou Spacer
            if let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack {
                    Spacer()

                    Text(text)
                        .font(.title.weight(.regular))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()
                }
            } else {
                Spacer()
            }

            // Divider au milieu (si on a du texte ET un média)
            if let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               imageFileName != nil || audioFileName != nil
            {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }

            // Partie basse - Média ou Texte
            switch contentType {
            case .text:
                if let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Texte déjà affiché en haut, rien en bas
                } else {
                    VStack {
                        Spacer()

                        Text(text ?? "—")
                            .font(.title.weight(.regular))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding()

                        Spacer()
                    }
                }

            case .image:
                if let fileName = imageFileName,
                   let image = mediaStorage.loadImage(fileName: fileName, data: imageData)
                {
                    VStack {
                        Spacer()

                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .clipped()
                            .background(Color.clear)
                            .compositingGroup()
                            .padding()

                        Spacer()
                    }
                } else {
                    VStack {
                        Spacer()

                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Image introuvable")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()

                        Spacer()
                    }
                }

            case .audio:
                if let fileName = audioFileName {
                    VStack {
                        Spacer()

                        VStack(spacing: 20) {
                            Button(action: {
                                guard !isAnimating else { return }

                                // ✅ CORRECTION : Ne pas arrêter l'autoplay lors de la lecture audio manuelle
                                // L'autoplay doit continuer après la lecture audio

                                if audioManager.isPlaying, audioManager.playingFileName == fileName {
                                    audioManager.stopAudio()
                                } else {
                                    audioManager.playAudio(fileName: fileName)
                                }
                            }) {
                                Image(systemName: audioManager.isPlaying && audioManager.playingFileName == fileName ? "pause.fill" : "play.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                                    .frame(width: 70, height: 70)
                                    .background(
                                        RoundedRectangle(cornerRadius: 40)
                                            .fill(Color.blue)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 40)
                                                    .stroke(Color.blue, lineWidth: 0)
                                            )
                                    )
                                    .contentTransition(.identity)
                                    .transaction { $0.animation = nil }
                            }
                            .buttonStyle(NoEffectButtonStyle())
                            .transaction { $0.animation = nil }
                        }
                        .padding()

                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NoEffectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
        // ✅ Absolument aucun changement, même lors de la pression
    }
}
