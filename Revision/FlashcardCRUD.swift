//
//  FlashcardRowView.swift
//  PARALLAX
//
//  Created by  on 7/21/25.
//
import SwiftUI
import UIKit
import Foundation
import CoreData
import PhotosUI      // Pour les photos
import AVFoundation  // Pour l'audio
import UniformTypeIdentifiers
import AVFAudio



@available(iOS 17.0, *)
struct AddFlashcardView: View {
    @ObservedObject var deck: FlashcardDeck
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - États pour le contenu
    @State private var questionText = ""
    @State private var answerText = ""
    
    // MARK: - États médias Question
    @State private var questionImageData: Data?
    @State private var questionImageFileName: String?
    @State private var questionAudioFileName: String?
    @State private var questionAudioDuration: TimeInterval?
    
    // MARK: - États médias Answer
    @State private var answerImageData: Data?
    @State private var answerImageFileName: String?
    @State private var answerAudioFileName: String?
    @State private var answerAudioDuration: TimeInterval?
    
    // MARK: - États UI pour les présentations
    @State private var showingQuestionImagePicker = false
    @State private var showingAnswerImagePicker = false
    @State private var showingQuestionAudioMenu = false
    @State private var showingAnswerAudioMenu = false
    @State private var showingAudioFilePicker = false
    @State private var isQuestionAudioImport = false
    @State private var showQuestionAudioMenu: Bool = false
    @State private var showAnswerAudioMenu: Bool = false
    @State private var questionAudioImportContext: AudioImportContext = .question

    @State private var selectedQuestionImage: PhotosPickerItem?
    @State private var selectedAnswerImage: PhotosPickerItem?
    
    @ObservedObject private var audioManager = AudioManager.shared
    @State private var currentRecordingContext: RecordingContext?
    @State private var isProcessingAudio = false
    
    // ✅ NOUVEAU : États pour l'alerte audio
    @State private var showAudioDurationAlert = false
    @State private var audioDurationAlertMessage = ""
    
    private enum RecordingContext {
        case question
        case answer
    }
    
    private func handleAudioButtonTap(forQuestion: Bool) {
        if forQuestion {
            showQuestionAudioMenu = true
        } else {
            showAnswerAudioMenu = true
        }
    }
    
    private enum AudioImportContext {
        case question
        case answer
    }
    
    // MARK: - Computed properties pour interface conditionnelle
    private var hasQuestionMedia: Bool {
        questionImageFileName != nil || questionAudioFileName != nil
    }
    
    private var hasAnswerMedia: Bool {
        answerImageFileName != nil || answerAudioFileName != nil
    }
    
    // MARK: - Body principal
    var body: some View {
        NavigationStack {
            mainForm
                .navigationTitle("Ajouter une carte")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarContent
                }
                .onDisappear {
                    handleViewDisappear()
                }
        }
        .photosPicker(
            isPresented: $showingQuestionImagePicker,
            selection: $selectedQuestionImage,
            matching: .images
        )
        .photosPicker(
            isPresented: $showingAnswerImagePicker,
            selection: $selectedAnswerImage,
            matching: .images
        )
        .confirmationDialog("Options audio", isPresented: $showQuestionAudioMenu) {
            Button("Enregistrer un audio") {
                startInstantRecording(forQuestion: true)  // ✅ Enregistrement instantané
            }
            Button("Importer un fichier") {
                questionAudioImportContext = .question
                showingAudioFilePicker = true
            }
            Button("Annuler", role: .cancel) { }
        }

        // Pour le menu réponse :
        .confirmationDialog("Options audio", isPresented: $showAnswerAudioMenu) {
            Button("Enregistrer un audio") {
                startInstantRecording(forQuestion: false)  // ✅ Enregistrement instantané
            }
            Button("Importer un fichier") {
                questionAudioImportContext = .answer
                showingAudioFilePicker = true
            }
            Button("Annuler", role: .cancel) { }
        }
        .fileImporter(
            isPresented: $showingAudioFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            handleAudioImport(result: result)
        }
        .onChange(of: selectedQuestionImage) {
            handleQuestionImageSelection()
        }
        .onChange(of: selectedAnswerImage) {
            handleAnswerImageSelection()
        }
        // ✅ NOUVEAU : Alerte SwiftUI pour la durée audio
        .alert("Durée audio limitée", isPresented: $showAudioDurationAlert) {
            Button("OK") { }
        } message: {
            Text(audioDurationAlertMessage)
        }
    }
    @ViewBuilder
    private var questionSection: some View {
        Section("QUESTION") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // TextField toujours visible
                    TextField("Question (optionnel)", text: $questionText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...3)
                    
                    Spacer()
                    
                    // Boutons d'action
                    questionActionButtons
                }
                
                // Indicateurs médias
                questionMediaIndicators
            }
        }
    }
    
    // MARK: - ✅ CORRIGÉ : Section Answer avec header natif
    @ViewBuilder
    private var answerSection: some View {
        Section("RÉPONSE") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // TextField toujours visible
                    TextField("Réponse (optionnel)", text: $answerText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...3)
                    
                    Spacer()
                    
                    // Boutons d'action
                    answerActionButtons
                }
                // Indicateurs médias
                answerMediaIndicators
            }
        }
    }
    // MARK: - Form principal séparé
    @ViewBuilder
    private var mainForm: some View {
        Form {
            questionSection
            answerSection
        }
    }
    
    // MARK: - Toolbar séparé
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Annuler") {
                handleCancel()
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Sauvegarder") {
                saveFlashcard()
            }
            .disabled(!canSave || audioManager.isRecording)
        }
    }
    
    @ViewBuilder
    private func imagePreview(imageFileName: String?, imageData: Data?) -> some View {
        if let imageData = imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else if let imageFileName = imageFileName {
            // ✅ SOLUTION : Utiliser une fonction helper
            let debugInfo = getImageDebugInfo(fileName: imageFileName)
            
            if let imageURL = MediaStorageManager.shared.getImageURL(fileName: imageFileName),
               let uiImage = UIImage(contentsOfFile: imageURL.path) {
                
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onAppear {
                        print("✅ PREVIEW: Image chargée - \(debugInfo)")
                    }
            } else {
                errorPlaceholder("Image non trouvée")
            }
        } else {
            Image(systemName: "photo")
                .frame(width: 40, height: 40)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // ✅ FONCTION HELPER : Logique do-catch extraite
    private func getImageDebugInfo(fileName: String) -> String {
        guard let imageURL = MediaStorageManager.shared.getImageURL(fileName: fileName) else {
            return "URL non trouvée"
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: imageURL.path)
            let fileSize = attributes[.size] as? Int ?? 0
            return "Taille: \(fileSize) bytes"
        } catch {
            return "Erreur: \(error.localizedDescription)"
        }
    }


    @ViewBuilder
    private func errorPlaceholder(_ message: String) -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
            Text(message)
                .font(.caption2)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
        .frame(width: 40, height: 40)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // ✅ Fonction helper pour récupérer l'URL du fichier
    private func getImageURL(fileName: String) -> URL? {
        // ✅ SOLUTION : Utiliser MediaStorageManager au lieu de construire le chemin
        return MediaStorageManager.shared.getImageURL(fileName: fileName)
    }
    
    // MARK: - Boutons d'action Question CORRIGÉS
    @ViewBuilder
    private var questionActionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                showingQuestionImagePicker = true
            }) {
                Image(systemName: questionImageFileName != nil ? "photo.badge.checkmark" : "photo.badge.plus")
                    .foregroundColor(questionImageFileName != nil ? .green : .blue)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            // ✅ BOUTON AUDIO AVEC ACTION CONDITIONNELLE
            Button(action: {
                let isCurrentlyRecording = audioManager.isRecording &&
                                          currentRecordingContext == .question
                
                if isCurrentlyRecording {
                    // ✅ Si en cours d'enregistrement → ARRÊTER
                    finishInstantRecording()
                } else {
                    // ✅ Si pas d'enregistrement → OUVRIR MENU
                    handleAudioButtonTap(forQuestion: true)
                }
            }) {
                audioButtonIcon(forQuestion: true)
            }
            .buttonStyle(.plain)
            .disabled(isProcessingAudio)
        }
    }

    // MARK: - Boutons d'action Answer CORRIGÉS
    @ViewBuilder
    private var answerActionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                showingAnswerImagePicker = true
            }) {
                Image(systemName: answerImageFileName != nil ? "photo.badge.checkmark" : "photo.badge.plus")
                    .foregroundColor(answerImageFileName != nil ? .green : .blue)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            // ✅ BOUTON AUDIO AVEC ACTION CONDITIONNELLE
            Button(action: {
                let isCurrentlyRecording = audioManager.isRecording &&
                                          currentRecordingContext == .answer
                
                if isCurrentlyRecording {
                    // ✅ Si en cours d'enregistrement → ARRÊTER
                    finishInstantRecording()
                } else {
                    // ✅ Si pas d'enregistrement → OUVRIR MENU
                    handleAudioButtonTap(forQuestion: false)
                }
            }) {
                audioButtonIcon(forQuestion: false)
            }
            .buttonStyle(.plain)
            .disabled(isProcessingAudio)
        }
    }

    
    // MARK: - Indicateurs médias séparés
    @ViewBuilder
    private var questionMediaIndicators: some View {
        mediaIndicatorsView(
            imageFileName: questionImageFileName,
            imageData: questionImageData,
            audioFileName: questionAudioFileName,
            audioDuration: questionAudioDuration,
            onRemoveImage: {
                removeQuestionImage()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    // Le TextField réapparaîtra avec l'animation
                }
            },
            onRemoveAudio: {
                // ✅ Utiliser la méthode optimisée au lieu de stopAudio()
                if audioManager.isPlaying && audioManager.playingFileName == questionAudioFileName {
                    audioManager.stopAudioSilently()  // ✅ Évite les conflits d'animation
                }
                removeQuestionAudio()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    // Le TextField réapparaît
                }
            }
        )
    }
    
    @ViewBuilder
    private var answerMediaIndicators: some View {
        mediaIndicatorsView(
            imageFileName: answerImageFileName,
            imageData: answerImageData,
            audioFileName: answerAudioFileName,
            audioDuration: answerAudioDuration,
            onRemoveImage: {
                removeAnswerImage()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    // Le TextField réapparaîtra avec l'animation
                }
            },
            onRemoveAudio: {
                if audioManager.isPlaying && audioManager.playingFileName == answerAudioFileName {
                    audioManager.stopAudio()
                }
                removeAnswerAudio()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    // Le TextField réapparaît
                }
            }
        )
    }
    
    // MARK: - Actions
    private func handleCancel() {
        if audioManager.isRecording {
            audioManager.forceStopRecording()
        }
        if audioManager.isPlaying {
            audioManager.stopAudio()
        }
        dismiss()
    }
    
    private func handleViewDisappear() {
        // ✅ Arrêt optimisé sans animation d'icône
        if audioManager.isPlaying {
            audioManager.stopAudioSilently()
            print("🔇 Audio arrêté silencieusement à la fermeture")
        }
        
        // ✅ Nettoyage complet si enregistrement en cours
        if audioManager.isRecording {
            audioManager.forceCleanState()
        }
    }
    
    @ViewBuilder
    private func audioButtonIcon(forQuestion: Bool) -> some View {
        let isCurrentlyRecording = audioManager.isRecording &&
                                  currentRecordingContext == (forQuestion ? .question : .answer)
        let hasAudio = forQuestion ? questionAudioFileName != nil : answerAudioFileName != nil
        
        if isCurrentlyRecording {
            ZStack {
                // Cercle extérieur rouge avec 50% d'opacité
                Image(systemName: "circle.fill")
                    .foregroundColor(.red)
                    .opacity(0.25)
                    .font(.title2)
                
                // ✅ CHANGEMENT : Seulement le point central, pas de cercle
                Image(systemName: "circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 8)) // ✅ Taille plus petite pour le point
            }
            .scaleEffect(1.1)
            .animation(.easeInOut(duration: 0.2), value: isCurrentlyRecording)
            
        } else if hasAudio {
            Image(systemName: "waveform.badge.checkmark")
                .foregroundColor(.green)
                .font(.title2)
        } else {
            Image(systemName: "waveform")
                .foregroundColor(.blue)
                .font(.title2)
        }
    }
    
    // MARK: - Indicateurs Médias
    @ViewBuilder
    private func mediaIndicatorsView(
        imageFileName: String?,
        imageData: Data?,
        audioFileName: String?,
        audioDuration: TimeInterval?,
        onRemoveImage: @escaping () -> Void,
        onRemoveAudio: @escaping () -> Void
    ) -> some View {
        if imageFileName != nil || audioFileName != nil {
            VStack(alignment: .leading, spacing: 6) {
                

                if let imageFileName = imageFileName {
                    HStack(spacing: 8) {
                        // ✅ CORRECTION : Utiliser la nouvelle fonction robuste
                        imagePreview(imageFileName: imageFileName, imageData: imageData)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            // Texte "Image ajoutée" supprimé
                        }
                        
                        Spacer()
                        
                        Button(action: onRemoveImage) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                
                // Indicateur d'audio
                if let audioFileName = audioFileName {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if let duration = audioDuration {
                                Text(formatDuration(duration))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Spacer()
                        
                        // Bouton play/pause
                        Button(action: {
                            if audioManager.isPlaying && audioManager.playingFileName == audioFileName {
                                audioManager.stopAudio()
                            } else {
                                audioManager.playAudio(fileName: audioFileName)
                            }
                        }) {
                            Image(systemName: audioManager.isPlaying && audioManager.playingFileName == audioFileName ? "pause.circle" : "play.circle")
                                .foregroundColor(.blue)
                                .contentTransition(.identity)  // ✅ Empêche le morphing SF Symbols
                                .transaction { $0.animation = nil }  // ✅ Supprime toute animation
                                .animation(nil, value: audioManager.isPlaying)  // ✅ Force aucune animation
                        }
                        .buttonStyle(.plain)
                        .transaction { $0.animation = nil }
                        
                        Button(action: onRemoveAudio) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var canSave: Bool {
        let hasQuestionContent = !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                questionImageFileName != nil ||
                                questionAudioFileName != nil
        
        let hasAnswerContent = !answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              answerImageFileName != nil ||
                              answerAudioFileName != nil
        
        return hasQuestionContent && hasAnswerContent
    }
    
    // MARK: - Gestion Images
    private func handleQuestionImageSelection() {
        guard let selectedQuestionImage = selectedQuestionImage else { return }
        
        Task {
            do {
                if let data = try await selectedQuestionImage.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    
                    // ✅ COMPRESSION pour éviter les problèmes de taille
                    let compressedImage = compressImageForPreview(image)
                    
                    if let result = MediaStorageManager.shared.storeImage(compressedImage) {
                        await MainActor.run {
                            // Supprimer l'audio existant
                            if let existingAudioFileName = self.questionAudioFileName {
                                MediaStorageManager.shared.deleteAudio(fileName: existingAudioFileName)
                                self.questionAudioFileName = nil
                                self.questionAudioDuration = nil
                            }
                            
                            // ✅ FORCER : Toujours garder en mémoire pour AddFlashcard
                            self.questionImageData = data
                            self.questionImageFileName = result.fileName
                            self.selectedQuestionImage = nil
                            print("✅ Image caméra forcée en mémoire pour preview")
                        }
                    }
                }
            } catch {
                print("❌ Error loading camera image: \(error)")
            }
        }
    }

    // ✅ Fonction de compression pour les previews
    private func compressImageForPreview(_ image: UIImage) -> UIImage {
        let maxSize: CGFloat = 1024 // Taille max pour éviter les problèmes
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)
        
        if ratio >= 1 { return image }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let compressedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return compressedImage ?? image
    }

    private func handleAnswerImageSelection() {
        guard let selectedAnswerImage = selectedAnswerImage else { return }
        
        Task {
            do {
                if let data = try await selectedAnswerImage.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let result = MediaStorageManager.shared.storeImage(image) {
                    
                    await MainActor.run {
                        // Supprimer l'audio existant avant d'ajouter l'image
                        if let existingAudioFileName = self.answerAudioFileName {
                            MediaStorageManager.shared.deleteAudio(fileName: existingAudioFileName)
                            self.answerAudioFileName = nil
                            self.answerAudioDuration = nil
                            print("🗑️ Audio réponse supprimé au profit de l'image")
                        }
                        
                        self.answerImageData = result.shouldStoreInFileManager ? nil : result.data
                        self.answerImageFileName = result.fileName
                        self.selectedAnswerImage = nil
                        print("✅ Answer image stored: \(result.fileName)")
                    }
                }
            } catch {
                print("❌ Error loading answer image: \(error)")
                await MainActor.run {
                    self.selectedAnswerImage = nil
                }
            }
        }
    }
    
    // MARK: - Suppression Médias
    private func removeQuestionImage() {
        if let fileName = questionImageFileName {
            MediaStorageManager.shared.deleteImage(fileName: fileName, hasFileManagerData: questionImageData == nil)
        }
        questionImageData = nil
        questionImageFileName = nil
    }
    
    private func removeAnswerImage() {
        if let fileName = answerImageFileName {
            MediaStorageManager.shared.deleteImage(fileName: fileName, hasFileManagerData: answerImageData == nil)
        }
        answerImageData = nil
        answerImageFileName = nil
    }
    
    private func removeQuestionAudio() {
        if let fileName = questionAudioFileName {
            MediaStorageManager.shared.deleteAudio(fileName: fileName)
        }
        questionAudioFileName = nil
        questionAudioDuration = nil
    }
    
    private func removeAnswerAudio() {
        if let fileName = answerAudioFileName {
            MediaStorageManager.shared.deleteAudio(fileName: fileName)
        }
        answerAudioFileName = nil
        answerAudioDuration = nil
    }
    
    private func startRecording(forQuestion: Bool) {
        print("🎙️ Starting recording for \(forQuestion ? "question" : "answer")")
        
        guard !audioManager.isRecording && !isProcessingAudio else {
            print("❌ Recording already in progress or processing")
            return
        }
        
        // ✅ CORRECTION 1 : Déclarer observer comme optionnelle
        var observer: NSObjectProtocol?
        
        // ✅ CORRECTION 2 : Capturer observer de manière faible pour éviter la mutation
        observer = NotificationCenter.default.addObserver(
            forName: .init("RecordingFinishedAutomatically"),
            object: nil,
            queue: .main
        ) { [weak observer] notification in  // ✅ [weak observer] évite la mutation
            if let fileName = notification.object as? String {
                print("🎯 Arrêt automatique détecté - fichier: \(fileName)")
                
                let duration = audioManager.recordingDuration > 0 ? audioManager.recordingDuration : 30.0
                
                if currentRecordingContext == .question {
                    questionAudioFileName = fileName
                    questionAudioDuration = duration
                } else {
                    answerAudioFileName = fileName
                    answerAudioDuration = duration
                }
                
                currentRecordingContext = nil
                isProcessingAudio = false
                
                print("✅ Fichier de 30s automatiquement assigné: \(fileName)")
            }
            
            // ✅ CORRECTION 3 : Unwrapping sécurisé pour éviter la coercion à Any
            if let obs = observer {
                NotificationCenter.default.removeObserver(obs)
            }
        }
        
        Task {
            await MainActor.run {
                audioManager.forceCleanState()
                
                isProcessingAudio = true
                currentRecordingContext = forQuestion ? .question : .answer
            }
            
            if let _ = await audioManager.toggleRecording() {
                await MainActor.run {
                    // Suppression image existante avant audio
                    if forQuestion {
                        if let existingImageFileName = questionImageFileName {
                            MediaStorageManager.shared.deleteImage(fileName: existingImageFileName, hasFileManagerData: questionImageData == nil)
                            questionImageData = nil
                            questionImageFileName = nil
                            print("🗑️ Image question supprimée au profit de l'audio")
                        }
                    } else {
                        if let existingImageFileName = answerImageFileName {
                            MediaStorageManager.shared.deleteImage(fileName: existingImageFileName, hasFileManagerData: answerImageData == nil)
                            answerImageData = nil
                            answerImageFileName = nil
                            print("🗑️ Image réponse supprimée au profit de l'audio")
                        }
                    }
                    
                    isProcessingAudio = false
                    print("✅ Recording started (no file assigned yet)")
                }
            } else {
                await MainActor.run {
                    print("❌ Failed to start recording")
                    currentRecordingContext = nil
                    isProcessingAudio = false
                }
                
                // ✅ CORRECTION 4 : Nettoyage sécurisé de l'observer en cas d'échec
                if let obs = observer {
                    NotificationCenter.default.removeObserver(obs)
                }
            }
        }
    }

    
    private func finishRecording() {
        print("✅ Finishing recording")
        
        guard audioManager.isRecording && !isProcessingAudio else {
            print("❌ No recording in progress or already processing")
            return
        }
        
        isProcessingAudio = true
        
        Task { @MainActor in
            // ✅ VERSION CORRIGÉE : Suppression du do-catch inutile
            if let finalFileName = await audioManager.toggleRecording() {
                let duration = audioManager.recordingDuration > 0 ? audioManager.recordingDuration : 1.0
                
                if self.currentRecordingContext == .question {
                    self.questionAudioFileName = finalFileName
                    self.questionAudioDuration = duration
                } else {
                    self.answerAudioFileName = finalFileName
                    self.answerAudioDuration = duration
                }
                
                self.currentRecordingContext = nil
                self.isProcessingAudio = false
                
                print("✅ Recording finished and saved: \(finalFileName), duration: \(duration)s")
            } else {
                print("❌ Failed to finalize recording")
                // ✅ Nettoyage en cas d'échec (sans catch)
                audioManager.forceCleanState()
                self.isProcessingAudio = false
                self.cancelRecording()
            }
        }
    }

    private func cancelRecording() {
        print("❌ Cancelling recording")
        
        audioManager.forceStopRecording()
        
        Task { @MainActor in
            if let context = currentRecordingContext {
                let fileName = context == .question ? questionAudioFileName : answerAudioFileName
                if let fileName = fileName {
                    MediaStorageManager.shared.deleteAudio(fileName: fileName)
                }
                
                if context == .question {
                    self.questionAudioFileName = nil
                    self.questionAudioDuration = nil
                } else {
                    self.answerAudioFileName = nil
                    self.answerAudioDuration = nil
                }
            }
            
            self.currentRecordingContext = nil
            self.isProcessingAudio = false
        }
    }
    
    private func startInstantRecording(forQuestion: Bool) {
        guard !audioManager.isRecording && !isProcessingAudio else { return }
        
        print("🎙️ Démarrage INSTANTANÉ - \(forQuestion ? "question" : "réponse")")
        
        // ✅ INSTANTANÉ : Démarrer l'enregistrement IMMÉDIATEMENT
        currentRecordingContext = forQuestion ? .question : .answer
        
        // ✅ APPEL DIRECT sans Task asynchrone
        audioManager.startRecordingInstantly()
        
        // ✅ NETTOYAGE EN ARRIÈRE-PLAN (après le démarrage)
        Task.detached(priority: .background) {
            await MainActor.run {
                self.isProcessingAudio = true
                
                // Supprimer les anciens fichiers EN ARRIÈRE-PLAN
                if forQuestion {
                    if let fileName = self.questionAudioFileName {
                        MediaStorageManager.shared.deleteAudio(fileName: fileName)
                        self.questionAudioFileName = nil
                        self.questionAudioDuration = 0
                    }
                    if let existingImageFileName = self.questionImageFileName {
                        MediaStorageManager.shared.deleteImage(fileName: existingImageFileName, hasFileManagerData: self.questionImageData == nil)
                        self.questionImageData = nil
                        self.questionImageFileName = nil
                    }
                } else {
                    if let fileName = self.answerAudioFileName {
                        MediaStorageManager.shared.deleteAudio(fileName: fileName)
                        self.answerAudioFileName = nil
                        self.answerAudioDuration = 0
                    }
                    if let existingImageFileName = self.answerImageFileName {
                        MediaStorageManager.shared.deleteImage(fileName: existingImageFileName, hasFileManagerData: self.answerImageData == nil)
                        self.answerImageData = nil
                        self.answerImageFileName = nil
                    }
                }
                
                self.isProcessingAudio = false
            }
        }
        
        HapticFeedbackManager.shared.impact(style: .medium)
    }


    private func finishInstantRecording() {
        guard audioManager.isRecording else { return }
        
        print("✅ Arrêt enregistrement instantané")
        finishRecording() // Utilise votre méthode existante
        HapticFeedbackManager.shared.impact(style: .light)
    }
    
    // MARK: - Import Audio
    private func handleAudioImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let sourceURL = urls.first else { return }
            
            Task {
                let shouldStopAccessing = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopAccessing {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                do {
                    let audioData = try Data(contentsOf: sourceURL)
                    let newFileName = "\(UUID().uuidString).\(sourceURL.pathExtension)"
                    let destinationURL = MediaStorageManager.shared.getAudioURL(fileName: newFileName)
                    
                    try audioData.write(to: destinationURL, options: .atomic)
                    
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
                        // Supprimer l'image existante avant d'ajouter l'audio
                        if self.questionAudioImportContext == .question {
                            if let existingImageFileName = self.questionImageFileName {
                                MediaStorageManager.shared.deleteImage(fileName: existingImageFileName, hasFileManagerData: self.questionImageData == nil)
                                self.questionImageData = nil
                                self.questionImageFileName = nil
                                print("🗑️ Image question supprimée au profit de l'audio importé")
                            }
                            self.questionAudioFileName = newFileName
                            self.questionAudioDuration = seconds
                        } else {
                            if let existingImageFileName = self.answerImageFileName {
                                MediaStorageManager.shared.deleteImage(fileName: existingImageFileName, hasFileManagerData: self.answerImageData == nil)
                                self.answerImageData = nil
                                self.answerImageFileName = nil
                                print("🗑️ Image réponse supprimée au profit de l'audio importé")
                            }
                            self.answerAudioFileName = newFileName
                            self.answerAudioDuration = seconds
                        }
                        print("✅ Audio imported: \(newFileName), duration: \(seconds)s")
                    }
                    
                } catch {
                    print("❌ Audio import error: \(error)")
                }
            }
            
        case .failure(let error):
            print("❌ File selection error: \(error)")
        }
    }
    
    // MARK: - Sauvegarde optimisée
    private func saveFlashcard() {
        // ✅ VÉRIFICATION DES LIMITES MÉDIAS
        let premiumManager = PremiumManager.shared
        
        // Compter les médias qu'on va ajouter
        var mediaToAdd = 0
        if questionAudioFileName != nil || questionImageFileName != nil { mediaToAdd += 1 }
        if answerAudioFileName != nil || answerImageFileName != nil { mediaToAdd += 1 }
        
        // Vérifier si on peut ajouter ces médias
        if mediaToAdd > 0 && !premiumManager.canAddMedia(deck: deck, context: viewContext) {
            print("❌ Limite médias atteinte - Impossible d'ajouter la flashcard")
            HapticFeedbackManager.shared.notification(type: .warning)
            return
        }
        
        // ✅ OPTIMISATION : Utiliser perform pour éviter le blocage
        viewContext.perform {
            let newFlashcard = Flashcard(context: viewContext)
            newFlashcard.id = UUID()
            newFlashcard.createdAt = Date()
            newFlashcard.deck = deck
            
            // Question - Sauvegarder le texte et déterminer le type principal
            newFlashcard.question = questionText
            if let questionAudioFileName = questionAudioFileName {
                newFlashcard.questionContentType = .audio
                newFlashcard.questionAudioFileName = questionAudioFileName
                newFlashcard.questionAudioDuration = questionAudioDuration ?? 0
            } else if let questionImageFileName = questionImageFileName {
                newFlashcard.questionContentType = .image
                newFlashcard.questionImageData = questionImageData
                newFlashcard.questionImageFileName = questionImageFileName
            } else {
                newFlashcard.questionContentType = .text
            }
            
            // Answer - Sauvegarder le texte et déterminer le type principal
            newFlashcard.answer = answerText
            if let answerAudioFileName = answerAudioFileName {
                newFlashcard.answerContentType = .audio
                newFlashcard.answerAudioFileName = answerAudioFileName
                newFlashcard.answerAudioDuration = answerAudioDuration ?? 0
            } else if let answerImageFileName = answerImageFileName {
                newFlashcard.answerContentType = .image
                newFlashcard.answerImageData = answerImageData
                newFlashcard.answerImageFileName = answerImageFileName
            } else {
                newFlashcard.answerContentType = .text
            }
            
            do {
                try viewContext.save()
                print("✅ Flashcard saved")
                
                // ✅ OPTIMISATION : Invalider seulement le cache du deck actuel
                SM2OptimizationCache.shared.clearDeckCache(deck: deck)
                
                // ✅ OPTIMISATION : Dismiss sur le thread principal
                DispatchQueue.main.async {
                    dismiss()
                }
            } catch {
                print("❌ Save error: \(error)")
                DispatchQueue.main.async {
                    HapticFeedbackManager.shared.notification(type: .error)
                }
            }
        }
    }
    
    // MARK: - Utilitaires
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SubjectPickerSheet: View {
    let subjects: [Subject]
    @Binding var selectedSubject: Subject?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // ✅ BACKGROUND ADAPTATIF : F6F7FB seulement en mode clair
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                adaptiveBackground.ignoresSafeArea()
                
                List {
                    Button(action: {
                        HapticFeedbackManager.shared.selection()
                        selectedSubject = nil
                        dismiss()
                    }) {
                        HStack {
                            Text(String(localized: "subject_none"))
                            Spacer()
                            if selectedSubject == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    ForEach(subjects, id: \.id) { subject in
                        Button(action: {
                            HapticFeedbackManager.shared.selection()
                            selectedSubject = subject
                            dismiss()
                        }) {
                            HStack {
                                Text(subject.name ?? String(localized: "subject_fallback"))
                                Spacer()
                                if selectedSubject == subject {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle(String(localized: "subject_choose_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action_close")) {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                }
            }
        }
    }
}
