//
//  AudioActionBar.swift
//  PARALLAX
//
//  Created by Farid on 7/28/25.
//


// Nouveau fichier : AudioActionBar.swift
import SwiftUI

struct AudioActionBar: View {
    let fileName: String
    let duration: TimeInterval
    let onPlayPause: () -> Void
    let onReRecord: () -> Void
    let onDelete: () -> Void
    
    @StateObject private var audioManager = AudioManager.shared
    
    // Animation pour le bouton play
    @State private var playButtonScale: CGFloat = 1.0
    
    private var isCurrentlyPlaying: Bool {
        audioManager.isPlaying && audioManager.playingFileName == fileName
    }
    
    var body: some View {
        HStack(spacing: 12) {
            playPauseButton
            waveformView
            reRecordButton
            deleteButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(height: 60)
        .background(audioBarBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .scaleEffect(playButtonScale)
        .animation(.easeInOut(duration: 0.15), value: playButtonScale)
    }
    
    // MARK: - Bouton Play/Pause
    
    private var playPauseButton: some View {
        Button(action: handlePlayPause) {
            Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.blue.opacity(0.15))
                )
                .scaleEffect(isCurrentlyPlaying ? 1.1 : 1.0)
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(isCurrentlyPlaying ? "Pause audio" : "Play audio")
        .accessibilityHint("Double tap to \(isCurrentlyPlaying ? "pause" : "play") the recorded audio")
    }
    
    // MARK: - Waveform statique
    
    private var waveformView: some View {
        HStack(spacing: 2) {
            ForEach(waveformHeights.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.blue.opacity(isCurrentlyPlaying ? 0.8 : 0.5))
                    .frame(width: 3, height: waveformHeights[index])
                    .scaleEffect(y: isCurrentlyPlaying ? 1.0 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: isCurrentlyPlaying
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
    
    // MARK: - Bouton Re-record
    
    private var reRecordButton: some View {
        Button(action: handleReRecord) {
            Image(systemName: "mic.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(.blue.opacity(0.15))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Re-record audio")
        .accessibilityHint("Double tap to record a new audio")
    }
    
    // MARK: - Bouton Delete
    
    private var deleteButton: some View {
        Button(action: handleDelete) {
            Image(systemName: "trash.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(.red.opacity(0.15))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Delete audio")
        .accessibilityHint("Double tap to permanently delete this audio recording")
    }
    
    // MARK: - Background
    
    private var audioBarBackground: some View {
        RoundedRectangle(cornerRadius: 30)
            .fill(.ultraThinMaterial)
            .background(Color.clear)
    }
    
    // MARK: - Actions
    
    private func handlePlayPause() {
        HapticFeedbackManager.shared.impact(style: .light)
        
        // Animation du bouton
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            playButtonScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                playButtonScale = 1.0
            }
        }
        
        audioManager.togglePlayback(fileName: fileName)
    }

    private func handleReRecord() {
        HapticFeedbackManager.shared.impact(style: .medium)
        onReRecord()
    }
    
    private func handleDelete() {
        HapticFeedbackManager.shared.notification(type: .warning)
        onDelete()
    }
    
    // MARK: - Données Waveform
    
    private let waveformHeights: [CGFloat] = [
        12, 18, 8, 24, 16, 10, 20, 6, 22, 14,
        9, 25, 11, 19, 13, 7, 21, 15, 17, 23
    ]
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        AudioActionBar(
            fileName: "sample.m4a",
            duration: 5.2,
            onPlayPause: { print("Play/Pause tapped") },
            onReRecord: { print("Re-record tapped") },
            onDelete: { print("Delete tapped") }
        )
        .padding()
        
        AudioActionBar(
            fileName: "sample2.m4a",
            duration: 12.8,
            onPlayPause: { print("Play/Pause tapped") },
            onReRecord: { print("Re-record tapped") },
            onDelete: { print("Delete tapped") }
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
