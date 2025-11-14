//
//  AudioManager.swift - VERSION CORRIGÉE OPTIMISÉE
//  PARALLAX
//

import AVFoundation
import Combine

@available(iOS 17.0, *)
class AudioManager: NSObject, ObservableObject {
    // Gardez seulement les @Published properties
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var playingFileName: String?
    static let shared = AudioManager()
    
    @Published var recordingDuration: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var currentRecordingURL: URL?
    
    @MainActor
    private var mediaStorage: MediaStorageManager {
        MediaStorageManager.shared  // ✅ Accès sécurisé
    }
    private var isSessionPreConfigured = false
    
    override init() {
        super.init()
        setupInitialAudioSession()
        Task {
            await preconfigureAudioSession()
        }
    }
        
    private func setupInitialAudioSession() {
        print("🔴 DEBUG setupInitialAudioSession() - DÉBUT")
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [])
            try session.setActive(false)
            print("✅ Session audio initialisée en mode ambient")
        } catch {
            print("❌ Erreur setup initial: \(error)")
        }
    }
    
    // ✅ Pré-configuration intelligente pour performances
    private func preconfigureAudioSession() async {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // Pré-configure pour l'enregistrement
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth, .defaultToSpeaker]
            )
            
            isSessionPreConfigured = true
            print("✅ Session audio pré-configurée")
            
        } catch {
            print("⚠️ Erreur pré-configuration: \(error)")
        }
    }
    
    // ✅ CORRECTION : Configuration unique et adaptative
    private func configureSessionForRecording() async throws {
        let session = AVAudioSession.sharedInstance()
        
        print("🔧 Configuration session pour enregistrement...")
        
        // ✅ CORRECTION : Utiliser la pré-configuration existante si disponible
        if !isSessionPreConfigured {
            // Si pas encore pré-configuré, le faire maintenant
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth, .defaultToSpeaker]
            )
            isSessionPreConfigured = true
            print("✅ Session audio configurée")
        } else {
            print("✅ Session audio déjà pré-configurée")
        }
        
        // ✅ Activation avec gestion d'erreur
        do {
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
            print("✅ Session activée")
        } catch {
            print("❌ Erreur activation session: \(error)")
            throw error
        }
        
        // ✅ Délai minimal pour stabilisation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        let effectiveRoute = session.currentRoute.inputs.first
        print("🔍 Route effective: \(effectiveRoute?.portType.rawValue ?? "none") - \(effectiveRoute?.portName ?? "none")")
        
        // ✅ Vérification que la route est valide
        guard effectiveRoute != nil else {
            print("❌ Aucune route audio disponible")
            throw AudioSessionError.noAudioRoute
        }
    }
    
    @MainActor  // ✅ AJOUTEZ cette ligne
    func togglePlayback(fileName: String) {
        if isPlaying && playingFileName == fileName {
            stopAudio()
        } else {
            playAudio(fileName: fileName)  // ✅ Plus d'erreur
        }
    }
    @MainActor
    func toggleRecording() async -> String? {
        print("🎙️ === TOGGLE RECORDING - isRecording: \(isRecording) ===")
        
        if isRecording {
            // ✅ ARRÊT : Déjà sur MainActor
            print("🛑 Arrêt de l'enregistrement...")
            return await stopRecordingAndFinalize()
        } else {
            // ✅ DÉMARRAGE : Nettoyage préventif sur MainActor
            print("▶️ Démarrage nouvel enregistrement...")
            
            // Nettoyage préventif
            if audioRecorder != nil {
                print("⚠️ Nettoyage recorder résiduel...")
                audioRecorder?.stop()
                audioRecorder = nil
            }
            
            recordingTimer?.invalidate()
            recordingTimer = nil
            currentRecordingURL = nil
            recordingDuration = 0
            
            // Démarrage sécurisé
            return await startRecording()
        }
    }
    
    // MARK: - Enregistrement Instantané
    @MainActor
    func startRecordingInstantly() {
        print("🎙️ === DÉMARRAGE INSTANTANÉ ===")
        
        // ✅ Nettoyage préventif rapide
        if let oldRecorder = audioRecorder {
            oldRecorder.stop()
            audioRecorder = nil
            print("🧹 Ancien recorder nettoyé")
        }
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        currentRecordingURL = nil
        recordingDuration = 0
        
        // ✅ Générer nom fichier et URL immédiatement
        let fileName = "\(UUID().uuidString).m4a"
        let audioURL = mediaStorage.getAudioURL(fileName: fileName)
        currentRecordingURL = audioURL
        
        // ✅ Configuration session synchrone (pas d'await)
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
            
            // ✅ Settings audio optimisés
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
                AVEncoderBitRateKey: 64000
            ]
            
            // ✅ Créer et démarrer le recorder IMMÉDIATEMENT
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            
            guard let recorder = audioRecorder else {
                print("❌ Recorder nil")
                return
            }
            
            recorder.delegate = self
            recorder.isMeteringEnabled = false
            
            // ✅ Démarrage instantané sans prepareToRecord()
            let success = recorder.record()
            
            if success {
                // ✅ Mettre à jour l'état IMMÉDIATEMENT
                isRecording = true
                recordingDuration = 0
                
                // ✅ Démarrer le timer
                startRecordingTimer()
                
                print("✅ ENREGISTREMENT DÉMARRÉ INSTANTANÉMENT")
                HapticFeedbackManager.shared.impact(style: .medium)
                
            } else {
                print("❌ record() a échoué")
                audioRecorder = nil
            }
            
        } catch {
            print("❌ Erreur enregistrement instantané: \(error)")
            audioRecorder = nil
        }
    }


    
    @MainActor
    private func startRecording() async -> String? {
        print("🎙️ === DÉMARRAGE ENREGISTREMENT RAPIDE ===")
        
        // ✅ Nettoyage rapide
        if let oldRecorder = audioRecorder {
            oldRecorder.stop()
            audioRecorder = nil
            print("🧹 Ancien recorder nettoyé")
        }
        
        // ✅ Vérification permissions (instantané si déjà accordées)
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🔍 Status permissions: \(permissionStatus.rawValue)")
        
        switch permissionStatus {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            guard granted else {
                print("❌ Permissions refusées")
                return nil
            }
        case .denied, .restricted:
            print("❌ Permissions non accordées")
            return nil
        @unknown default:
            print("❌ État permissions inconnu")
            return nil
        }
        
        // ✅ Générer nom fichier et URL
        let fileName = "\(UUID().uuidString).m4a"
        let audioURL = mediaStorage.getAudioURL(fileName: fileName)
        currentRecordingURL = audioURL
        
        print("🔍 Fichier cible: \(audioURL.path)")
        
        // ✅ Préparer le dossier
        let parentDir = audioURL.deletingLastPathComponent()
        do {
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
                print("✅ Dossier créé")
            }
            
            if FileManager.default.fileExists(atPath: audioURL.path) {
                try FileManager.default.removeItem(at: audioURL)
                print("🗑️ Ancien fichier supprimé")
            }
        } catch {
            print("❌ Erreur préparation fichier: \(error)")
            return nil
        }
        
        // ✅ Configuration session
        do {
            try await configureSessionForRecording()
        } catch {
            print("❌ Erreur configuration session: \(error)")
            return nil
        }
        
        // ✅ Settings optimisés
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 64000
        ]
        
        do {
            // ✅ Créer le recorder
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            
            guard let recorder = audioRecorder else {
                print("❌ Recorder nil")
                return nil
            }
            
            recorder.delegate = self
            recorder.isMeteringEnabled = false
            
            // ✅ Préparer l'enregistrement
            guard recorder.prepareToRecord() else {
                print("❌ prepareToRecord() échoué")
                audioRecorder = nil
                return nil
            }
            
            print("⏳ Stabilisation...")
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            
            // ✅ Démarrer l'enregistrement
            let success = recorder.record()
            print("🔍 record() result: \(success)")
            
            if success {
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                
                if recorder.isRecording {
                    print("✅ ENREGISTREMENT ULTRA-RAPIDE")
                    
                    // ✅ Mettre à jour l'état sur le thread principal
                    isRecording = true
                    recordingDuration = 0
                    
                    // ✅ Démarrer le timer
                    startRecordingTimer()
                    
                    return fileName
                } else {
                    print("❌ isRecording = false après record()")
                    audioRecorder = nil
                    return nil
                }
            } else {
                print("❌ record() a retourné false")
                audioRecorder = nil
                return nil
            }
            
        } catch {
            print("❌ Erreur création recorder: \(error)")
            audioRecorder = nil
            return nil
        }
    }
    
    @MainActor
    func forceCleanState() {
        print("🧹 === NETTOYAGE FORCÉ ÉTAT AUDIO ===")
        
        // Arrêt brutal de tout
        audioRecorder?.stop()
        audioRecorder = nil
        audioPlayer?.stop()
        audioPlayer = nil
        
        // ✅ CRITIQUE : Reset des @Published sur MainActor
        isRecording = false
        isPlaying = false
        recordingDuration = 0
        playingFileName = nil
        currentRecordingURL = nil
        
        // Nettoyage timers
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        print("✅ État audio complètement nettoyé")
    }

    // ✅ Arrêter l'enregistrement et finaliser
    @MainActor
    private func stopRecordingAndFinalize() async -> String? {
        print("⏹️ === ARRÊT ENREGISTREMENT ===")
        
        guard let recorder = audioRecorder,
              let recordingURL = currentRecordingURL else {
            print("❌ Pas d'enregistrement en cours")
            return nil
        }
        
        // ✅ Arrêter l'enregistrement sur le thread principal
        recorder.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        let finalDuration = recordingDuration
        let fileName = recordingURL.lastPathComponent
        
        // ✅ CRITIQUE : Mise à jour des @Published sur MainActor
        isRecording = false
        recordingDuration = 0
        audioRecorder = nil
        currentRecordingURL = nil
        
        print("✅ Enregistrement arrêté - durée: \(finalDuration)s")
        
        // ✅ Vérification fichier
        if FileManager.default.fileExists(atPath: recordingURL.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: recordingURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                if fileSize > 1000 && finalDuration > 0.5 {
                    print("✅ Fichier valide: \(fileName) (\(fileSize) bytes, \(finalDuration)s)")
                    
                    // ✅ NOUVEAU : Compression audio si nécessaire
                    await compressAudioIfNeeded(recordingURL)
                    
                    return fileName
                } else {
                    print("⚠️ Fichier trop petit ou durée insuffisante, suppression")
                    try? FileManager.default.removeItem(at: recordingURL)
                    return nil
                }
            } catch {
                print("❌ Erreur vérification fichier: \(error)")
                return nil
            }
        } else {
            print("❌ Fichier n'existe pas après enregistrement")
            return nil
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self,
                      let recorder = self.audioRecorder else {
                    self?.recordingTimer?.invalidate()
                    return
                }
                
                // ✅ CORRECTION : Utiliser currentTime du recorder (temps réel)
                let currentTime = recorder.currentTime
                self.recordingDuration = currentTime
                
                // ✅ LIMITE : 30 secondes maximum pour éviter les fichiers trop gros
                if currentTime >= 30.0 {
                    print("⏰ Enregistrement arrêté automatiquement à 30 secondes")
                    
                    // ✅ CORRECTION : Appeler toggleRecording() pour notifier l'UI
                    let finalFileName = await self.toggleRecording()
                    
                    print("✅ Fichier sauvegardé automatiquement: \(finalFileName ?? "nil")")
                    
                    // ✅ NOTIFICATION : Poster une notification pour que l'UI se mette à jour
                    NotificationCenter.default.post(
                        name: .init("RecordingFinishedAutomatically"),
                        object: finalFileName
                    )
                    
                    return
                }
                
                // Log toutes les secondes pour debug
                if Int(currentTime * 10) % 10 == 0 && currentTime > 0 {
                    print("🎙️ Enregistrement: \(String(format: "%.1f", currentTime))s")
                }
                
                // Détection arrêt inattendu
                if !recorder.isRecording && self.isRecording {
                    print("⚠️ Enregistrement arrêté de façon inattendue")
                    self.isRecording = false
                    self.recordingTimer?.invalidate()
                    self.recordingTimer = nil
                }
            }
        }
    }
    
    func stopAudioSilently() {
        // Arrêt direct du player sans déclencher les @Published immédiatement
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Mise à jour des états en différé pour éviter les animations conflictuelles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPlaying = false
            self.playingFileName = nil
        }
    }
    @MainActor
    func forceStopRecording() {
        guard isRecording else { return }
        Task {
            _ = await stopRecordingAndFinalize()
        }
    }
    
    // ✅ NOUVEAU : Compression audio intelligente avec garde-fous
    private func compressAudioIfNeeded(_ url: URL) async {
        // Vérifier la taille du fichier
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        
        // 🛡️ GARDE-FOU 1 : Ne pas re-compresser un fichier déjà compressé
        guard shouldCompress(url, size: fileSize) else {
            print("⏭️ [AUDIO_MANAGER] Skip compression: fichier déjà optimisé")
            return
        }
        
        // 🛡️ GARDE-FOU 2 : Skip pendant enregistrement actif
        guard !isRecording else {
            print("⏭️ [AUDIO_MANAGER] Skip compression: enregistrement en cours")
            return
        }
        
        // 🛡️ GARDE-FOU 3 : Cas extrême / bug périphérique
        if fileSize > 5_000_000 { // 5MB
            print("⚠️ [AUDIO_MANAGER] Fichier anormalement gros, forcer compression 96kbps")
            await forceCompressLargeFile(url, fileSize: fileSize)
            return
        }
        
        // Compression normale
        if fileSize > 500_000 { // 500KB
            print("🔄 [AUDIO_MANAGER] Compression audio en cours... (taille: \(fileSize/1024)KB)")
            
            // Compression en arrière-plan pour ne pas bloquer l'UI
            Task.detached(priority: .utility) {
                await self.performCompression(url: url, fileSize: fileSize)
            }
        } else {
            print("✅ [AUDIO_MANAGER] Fichier < 500KB, pas de compression nécessaire")
        }
    }
    
    // 🛡️ GARDE-FOU 1 : Vérifier si le fichier doit être compressé
    private func shouldCompress(_ url: URL, size: Int) -> Bool {
        guard size > 500_000 else { return false }
        let name = url.lastPathComponent.lowercased()
        return !name.contains("compressed") // évite double passe
    }
    
    // 🛡️ GARDE-FOU 3 : Compression forcée pour fichiers très gros
    private func forceCompressLargeFile(_ url: URL, fileSize: Int) async {
        Task.detached(priority: .utility) {
            if let tmpURL = await AudioCompressor.shared.compressAudio(at: url, bitrate: 96000) {
                do {
                    let _ = try FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
                    print("✅ [AUDIO_MANAGER] Compression forcée réussie (96kbps)")
                } catch {
                    print("❌ [AUDIO_MANAGER] ReplaceItemAt a échoué: \(error)")
                }
            }
        }
    }
    
    // 🛡️ GARDE-FOU 2 : Compression avec remplacement atomique
    private func performCompression(url: URL, fileSize: Int) async {
        // 🎵 BONUS : Forcer mono pour réduire encore ~50% sans perte utile
        let forceMono = fileSize > 1_000_000 // 1MB
        
        if let tmpURL = await AudioCompressor.shared.compressAudio(at: url, bitrate: 128000, forceMono: forceMono) {
            do {
                let _ = try FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
                print("✅ [AUDIO_MANAGER] Remplacement atomique OK")
            } catch {
                print("❌ [AUDIO_MANAGER] ReplaceItemAt a échoué: \(error)")
                // Fallback : essayer moveItem
                do {
                    try FileManager.default.removeItem(at: url)
                    try FileManager.default.moveItem(at: tmpURL, to: url)
                    print("✅ [AUDIO_MANAGER] Fallback moveItem OK")
                } catch {
                    print("❌ [AUDIO_MANAGER] Fallback aussi échoué: \(error)")
                }
            }
        } else {
            print("⚠️ [AUDIO_MANAGER] Échec compression, garde fichier original")
        }
    }
    
    @MainActor
    func playAudio(fileName: String) {
        print("🎵 === DÉBUT playAudio() ===")
        print("🎵 Fichier demandé: \(fileName)")
        
        // ✅ Arrêt immédiat de tout audio précédent
        stopAudioFast()
        
        let audioURL = mediaStorage.getAudioURL(fileName: fileName)
        print("🎵 Path complet: \(audioURL.path)")
        
        // ✅ CRITIQUE : Vérifier que le fichier existe
        let fileExists = FileManager.default.fileExists(atPath: audioURL.path)
        print("🎵 Fichier existe: \(fileExists)")
        
        if !fileExists {
            print("❌ ERREUR CRITIQUE : Le fichier audio n'existe pas !")
            print("❌ Path recherché: \(audioURL.path)")
            
            // Lister les fichiers du dossier pour debug
            let parentDir = audioURL.deletingLastPathComponent()
            if let files = try? FileManager.default.contentsOfDirectory(atPath: parentDir.path) {
                print("📁 Fichiers dans le dossier audio:")
                files.prefix(10).forEach { print("  - \($0)") }
            }
            
            stopAudioFast()
            return
        }
        
        // Vérifier la taille du fichier
        if let attributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
           let fileSize = attributes[.size] as? Int64 {
            print("🎵 Taille fichier: \(fileSize) bytes")
            
            if fileSize == 0 {
                print("❌ ERREUR : Fichier audio vide (0 bytes)")
                stopAudioFast()
                return
            }
        }
        
        do {
            print("🎵 Création AVAudioPlayer...")
            // ✅ Création et lecture immédiate
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            
            print("🎵 Durée audio: \(audioPlayer?.duration ?? 0)s")
            print("🎵 prepareToPlay()...")
            audioPlayer?.prepareToPlay()
            
            print("🎵 Lancement play()...")
            if audioPlayer?.play() == true {
                isPlaying = true
                playingFileName = fileName
                print("✅ Lecture démarrée avec succès: \(fileName)")
            } else {
                print("❌ ERREUR : play() a retourné false")
                print("❌ isPlaying du player: \(audioPlayer?.isPlaying ?? false)")
                stopAudioFast()
            }
        } catch {
            print("❌ ERREUR création AVAudioPlayer: \(error)")
            print("❌ Error localized: \(error.localizedDescription)")
            stopAudioFast()
        }
        
        print("🎵 === FIN playAudio() ===")
    }

    
    func stopAudioFast() {
        isPlaying = false
        playingFileName = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    func stopAudio() {
        // ✅ Mise à jour immédiate de l'état
        isPlaying = false
        playingFileName = nil
        print("🎵 AudioManager.stopAudio() - État mis à jour: isPlaying=\(isPlaying), fileName=nil")
        
        // Arrêter le player
        audioPlayer?.stop()
        audioPlayer = nil
        
        // ✅ Notifications d'arrêt
        NotificationCenter.default.post(name: .audioDidStop, object: nil)
    }
}

// MARK: - Error Types
enum AudioSessionError: Error {
    case noAudioRoute
}

// MARK: - Delegates
extension AudioManager: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            print("📁 audioRecorderDidFinishRecording: \(flag ? "succès" : "échec")")
        }
    }
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            // ✅ CRITIQUE : Modification des @Published sur MainActor
            isPlaying = false
            playingFileName = nil
            
            NotificationCenter.default.post(
                name: .audioDidFinish,
                object: nil
            )
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            print("❌ audioRecorderEncodeErrorDidOccur: \(error?.localizedDescription ?? "unknown")")
            self.forceStopRecording()
        }
    }
}

extension Notification.Name {
    static let audioDidStop = Notification.Name("audioDidStop")
    static let audioDidFinish = Notification.Name("audioDidFinish")
}
