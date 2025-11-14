//
//  CardFaceContentEditor.swift
//  PARALLAX
//
//  Created by Farid on 7/28/25.
//

import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct CardFaceContentEditor: View {
    @Binding var content: String
    @Binding var contentType: FlashcardContentType
    @Binding var imageData: Data?
    @Binding var fileName: String?
    @Binding var audioDuration: TimeInterval?
    
    let isQuestion: Bool
    let onContentChange: () -> Void
    
    // MARK: - États internes
    // ✅ CORRECTION 1 : Utilisation correcte du singleton
    @ObservedObject private var audioManager = AudioManager.shared
    @State private var isProcessingAction = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    // ✅ CORRECTION 2 : Gestion simplifiée des présentations
    @State private var showingImagePicker = false
    @State private var showingAudioMenu = false
    @State private var showingFilePicker = false
    
    // ✅ NOUVEAU : États pour l'alerte audio
    @State private var showAudioDurationAlert = false
    @State private var audioDurationAlertMessage = ""
    
    // MARK: - Variables calculées
    private var imageFileName: Binding<String?> {
        Binding(
            get: { contentType == .image ? fileName : nil },
            set: { fileName = $0 }
        )
    }
    
    private var audioFileName: Binding<String?> {
        Binding(
            get: { contentType == .audio ? fileName : nil },
            set: { fileName = $0 }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête avec sélecteur de type
            HStack {
                Text(isQuestion ? "Question" : "Réponse")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                contentTypeSelector
            }
            
            // Contenu selon le type
            contentEditor
        }
        .photosPicker(
            isPresented: $showingImagePicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            handleAudioImport(result: result)
        }
        // ✅ NOUVEAU : Alerte SwiftUI pour la durée audio
        .alert("Durée audio limitée", isPresented: $showAudioDurationAlert) {
            Button("OK") { }
        } message: {
            Text(audioDurationAlertMessage)
        }
        .confirmationDialog(
            "Options Audio",
            isPresented: $showingAudioMenu,
            titleVisibility: .visible
        ) {
            Button("Enregistrer un audio") {
                showingAudioMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    startRecording()
                }
            }
            
            Button("Importer un fichier audio") {
                showingAudioMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showingFilePicker = true
                }
            }
            
            Button("Annuler", role: .cancel) {
                showingAudioMenu = false
            }
        }
        .onChange(of: selectedPhotoItem) {
            handleImageSelection()
        }
    }
    
    // MARK: - Sélecteur de type de contenu
    
    private var contentTypeSelector: some View {
        HStack(spacing: 8) {
            ForEach([FlashcardContentType.text, .image, .audio], id: \.self) { type in
                Button(action: {
                    handleContentTypeChange(to: type)
                }) {
                    Image(systemName: type.iconName)
                        .foregroundColor(contentType == type ? .white : .blue)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(contentType == type ? Color.blue : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isProcessingAction)
                .contentShape(Rectangle())
            }
        }
    }
    
    // MARK: - Éditeur de contenu
    
    private var contentEditor: some View {
        Group {
            switch contentType {
            case .text:
                textEditor
            case .image:
                imageEditor
            case .audio:
                audioEditor
            }
        }
    }
    
    private var textEditor: some View {
        TextField("Tapez votre \(isQuestion ? "question" : "réponse")...", text: $content, axis: .vertical)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .lineLimit(3...6)
            .onChange(of: content) {
                onContentChange()
            }
    }
    
    private var imageEditor: some View {
        VStack(spacing: 12) {
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        print("🖼️ Image tapped - showing picker")
                        showingImagePicker = true
                    }
                
                Button("Changer l'image") {
                    print("🔄 Change image button tapped")
                    showingImagePicker = true
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .contentShape(Rectangle())
                
            } else {
                Button("Sélectionner une image") {
                    print("📷 Select image button tapped")
                    showingImagePicker = true
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
        }
    }
    
    private var audioEditor: some View {
        VStack(spacing: 12) {
            if let audioFile = audioFileName.wrappedValue, audioDuration ?? 0 > 0 {
                // Audio existant
                AudioActionBar(
                    fileName: audioFile,
                    duration: audioDuration ?? 0,
                    onPlayPause: {
                        if audioManager.isPlaying && audioManager.playingFileName == audioFile {
                            audioManager.stopAudio()
                        } else {
                            audioManager.playAudio(fileName: audioFile)
                        }
                    },
                    onReRecord: {
                        startRecording()
                    },
                    onDelete: {
                        deleteAudio()
                    }
                )
            } else {
                // ✅ SIMPLIFIÉ : Bouton unique avec changement de couleur
                Button(audioManager.isRecording ? "Arrêter l'enregistrement" : "Ajouter un audio") {
                    print("🎙️ Audio button tapped - recording: \(audioManager.isRecording)")
                    
                    if audioManager.isRecording {
                        // Arrêter l'enregistrement
                        stopRecording()
                    } else {
                        // Afficher le menu d'options
                        showingAudioMenu = true
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding()
                .background(audioManager.isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
                .disabled(isProcessingAction)
                // ✅ Animation subtile pour le changement de couleur
                .transaction { $0.animation = nil }
            }
        }
    }
    
    private func handleContentTypeChange(to newType: FlashcardContentType) {
        print("🔄 Content type change: \(contentType) -> \(newType)")
        guard newType != contentType else { return }
        
        contentType = newType
        onContentChange()
        
        switch newType {
        case .audio:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🎙️ Opening audio menu")
                showingAudioMenu = true
            }
        case .image:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("📷 Opening image picker")
                showingImagePicker = true
            }
        case .text:
            print("📝 Text type selected")
            break
        }
    }
    
    // MARK: - Gestion des images
    
    private func handleImageSelection() {
        guard let selectedPhotoItem = selectedPhotoItem else { return }
        
        print("🖼️ Processing selected image")
        
        Task {
            do {
                if let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let result = MediaStorageManager.shared.storeImage(image) {
                    
                    await MainActor.run {
                        self.imageData = result.shouldStoreInFileManager ? nil : result.data
                        self.fileName = result.fileName
                        self.onContentChange()
                        
                        // Reset
                        self.selectedPhotoItem = nil
                        self.showingImagePicker = false
                        
                        print("✅ Image stored: \(result.fileName)")
                    }
                }
            } catch {
                print("❌ Error loading image: \(error)")
                await MainActor.run {
                    self.selectedPhotoItem = nil
                    self.showingImagePicker = false
                }
            }
        }
    }
    
    // MARK: - Gestion de l'audio
    
    // ✅ CORRECTION 3 : Utilisation de la nouvelle API toggleRecording()
    private func startRecording() {
        print("🎙️ Starting recording")
        
        guard !isProcessingAction && !audioManager.isRecording else {
            print("❌ Recording blocked - processing: \(isProcessingAction), recording: \(audioManager.isRecording)")
            return
        }
        
        isProcessingAction = true
        
        Task {
            if let newFileName = await audioManager.toggleRecording() {
                await MainActor.run {
                    self.fileName = newFileName
                    self.isProcessingAction = false
                    print("✅ Recording started: \(newFileName)")
                }
            } else {
                await MainActor.run {
                    print("❌ Failed to start recording")
                    self.isProcessingAction = false
                }
            }
        }
    }
    
    // ✅ CORRECTION 4 : Utilisation de la nouvelle API toggleRecording()
    private func stopRecording() {
        print("⏹️ Stopping recording")
        
        guard audioManager.isRecording else {
            print("❌ No recording in progress")
            return
        }
        
        isProcessingAction = true
        
        Task {
            if let finalFileName = await audioManager.toggleRecording() {
                await MainActor.run {
                    // L'enregistrement est terminé, récupérer la durée
                    self.audioDuration = audioManager.recordingDuration > 0 ? audioManager.recordingDuration : 1.0
                    self.fileName = finalFileName
                    self.isProcessingAction = false
                    self.onContentChange()
                    
                    print("✅ Recording stopped and saved: \(finalFileName)")
                }
            } else {
                await MainActor.run {
                    print("❌ Failed to finalize recording")
                    self.isProcessingAction = false
                }
            }
        }
    }
    
    // ✅ CORRECTION 5 : Utilisation de forceStopRecording() pour l'annulation
    private func cancelRecording() {
        print("❌ Cancelling recording")
        
        audioManager.forceStopRecording()
        
        Task { @MainActor in
            if let currentFileName = fileName {
                MediaStorageManager.shared.deleteAudio(fileName: currentFileName)
            }
            
            self.fileName = nil
            self.audioDuration = nil
            self.isProcessingAction = false
        }
    }
    
    private func deleteAudio() {
        print("🗑️ Deleting audio")
        
        if let currentFileName = fileName {
            MediaStorageManager.shared.deleteAudio(fileName: currentFileName)
        }
        
        fileName = nil
        audioDuration = nil
        onContentChange()
    }
    
    // MARK: - Import audio
    
    private func handleAudioImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let sourceURL = urls.first else { return }
            
            print("🔍 Importing audio from: \(sourceURL.path)")
            
            Task {
                let shouldStopAccessing = sourceURL.startAccessingSecurityScopedResource()
                
                defer {
                    if shouldStopAccessing {
                        sourceURL.stopAccessingSecurityScopedResource()
                        print("🔒 Security-scoped resource released")
                    }
                }
                
                do {
                    let audioData: Data
                    do {
                        audioData = try Data(contentsOf: sourceURL)
                        print("✅ Audio data read: \(audioData.count) bytes")
                    } catch {
                        print("❌ File read error: \(error)")
                        
                        // Fallback avec NSFileCoordinator
                        var coordinatorError: NSError?
                        var success = false
                        var readData: Data?
                        
                        NSFileCoordinator().coordinate(readingItemAt: sourceURL, options: [], error: &coordinatorError) { (url) in
                            do {
                                readData = try Data(contentsOf: url)
                                success = true
                                print("✅ Read successful with coordinator")
                            } catch {
                                print("❌ Coordinator error: \(error)")
                            }
                        }
                        
                        if let coordinatorError = coordinatorError {
                            print("❌ Coordinator error: \(coordinatorError)")
                        }
                        
                        guard success, let data = readData else {
                            await MainActor.run {
                                print("❌ Unable to read audio file")
                            }
                            return
                        }
                        
                        audioData = data
                    }
                    
                    let newFileName = "\(UUID().uuidString).\(sourceURL.pathExtension)"
                    let destinationURL = MediaStorageManager.shared.getAudioURL(fileName: newFileName)
                    
                    try audioData.write(to: destinationURL, options: .atomic)
                    print("✅ File copied to: \(destinationURL.path)")
                    
                    let asset = AVAsset(url: destinationURL)
                    let duration = try await asset.load(.duration)
                    let seconds = CMTimeGetSeconds(duration)
                    
                    // ✅ NOUVEAU : Vérification de la durée audio avec alerte SwiftUI
                    let premiumManager = PremiumManager.shared
                    if !premiumManager.isValidAudioDuration(seconds) {
                        await MainActor.run {
                            // Supprimer le fichier temporaire
                            try? FileManager.default.removeItem(at: destinationURL)
                            
                            // Afficher l'alerte SwiftUI
                            HapticFeedbackManager.shared.notification(type: .warning)
                            audioDurationAlertMessage = "Les fichiers audio sont limités à 30 secondes maximum."
                            showAudioDurationAlert = true
                        }
                        return
                    }
                    
                    await MainActor.run {
                        self.fileName = newFileName
                        self.audioDuration = seconds
                        self.onContentChange()
                        print("✅ Audio imported: \(newFileName), duration: \(seconds)s")
                    }
                    
                } catch {
                    print("❌ Audio processing error: \(error)")
                    await MainActor.run {
                        print("❌ Import failed")
                    }
                }
            }
            
        case .failure(let error):
            print("❌ File selection error: \(error)")
        }
    }
    
    // MARK: - Utilitaires
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Extensions

extension FlashcardContentType {
    var iconName: String {
        switch self {
        case .text: return "text.cursor"
        case .image: return "photo"
        case .audio: return "waveform"
        }
    }
}
