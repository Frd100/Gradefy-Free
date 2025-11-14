//
//  AudioService.swift
//  PARALLAX
//
//  Created by Farid on 8/3/25.
//


import AVFoundation

// ✅ SANS @MainActor pour éviter les conflits
class AudioService: ObservableObject {
    static let shared = AudioService()
    
    @Published var isPlaying = false
    @Published var playingFileName: String?
    
    private var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    // ✅ ARRÊT ULTRA-RAPIDE sans blocage
    func quickStop() {
        isPlaying = false
        playingFileName = nil
        
        // Arrêt immédiat sur thread dédié
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.audioPlayer?.stop()
        }
    }
    
    @MainActor
    func quickPlay(fileName: String) {
        guard let url = getAudioURL(fileName: fileName) else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            
            isPlaying = true
            playingFileName = fileName
        } catch {
            print("❌ Erreur lecture: \(error)")
        }
    }
    
    @MainActor
    private func getAudioURL(fileName: String) -> URL? {
        // Votre logique pour obtenir l'URL du fichier audio
        return MediaStorageManager.shared.getAudioURL(fileName: fileName)
    }
}
