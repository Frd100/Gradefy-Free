// Fichier corrigé : Flashcard+Extensions.swift
import Foundation
import UIKit

extension Flashcard {
    // MARK: - Question Content

    var questionContentType: FlashcardContentType {
        get {
            FlashcardContentType(rawValue: questionType ?? "text") ?? .text
        }
        set {
            questionType = newValue.rawValue
        }
    }

    var hasQuestionMedia: Bool {
        questionContentType != .text
    }

    var questionDisplayContent: String {
        switch questionContentType {
        case .text:
            return question ?? "—"
        case .image:
            return "📷 Image"
        case .audio:
            return "🎵 Audio (\(String(format: "%.1fs", questionAudioDuration)))"
        }
    }

    // MARK: - Answer Content

    var answerContentType: FlashcardContentType {
        get {
            FlashcardContentType(rawValue: answerType ?? "text") ?? .text
        }
        set {
            answerType = newValue.rawValue
        }
    }

    var hasAnswerMedia: Bool {
        answerContentType != .text
    }

    var answerDisplayContent: String {
        switch answerContentType {
        case .text:
            return answer ?? "—"
        case .image:
            return "📷 Image"
        case .audio:
            return "🎵 Audio (\(String(format: "%.1fs", answerAudioDuration)))"
        }
    }

    // MARK: - Validation

    var hasValidQuestionContent: Bool {
        switch questionContentType {
        case .text:
            return !(question?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        case .image:
            return questionImageFileName != nil
        case .audio:
            return questionAudioFileName != nil
        }
    }

    var hasValidAnswerContent: Bool {
        switch answerContentType {
        case .text:
            return !(answer?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        case .image:
            return answerImageFileName != nil
        case .audio:
            return answerAudioFileName != nil
        }
    }

    var isReadyForReview: Bool {
        hasValidQuestionContent && hasValidAnswerContent
    }

    // MARK: - Image Helpers (MainActor isolés)

    @MainActor
    func getQuestionImage() -> UIImage? {
        guard questionContentType == .image,
              let fileName = questionImageFileName else { return nil }

        return MediaStorageManager.shared.loadImage(
            fileName: fileName,
            data: questionImageData
        )
    }

    @MainActor
    func getAnswerImage() -> UIImage? {
        guard answerContentType == .image,
              let fileName = answerImageFileName else { return nil }

        return MediaStorageManager.shared.loadImage(
            fileName: fileName,
            data: answerImageData
        )
    }

    // MARK: - Audio Helpers (MainActor isolés)

    @MainActor
    func getQuestionAudioURL() -> URL? {
        guard questionContentType == .audio,
              let fileName = questionAudioFileName else { return nil }

        return MediaStorageManager.shared.getAudioURL(fileName: fileName)
    }

    @MainActor
    func getAnswerAudioURL() -> URL? {
        guard answerContentType == .audio,
              let fileName = answerAudioFileName else { return nil }

        return MediaStorageManager.shared.getAudioURL(fileName: fileName)
    }

    // MARK: - Nettoyage (MainActor isolés)

    // ✅ Fonction manquante ajoutée - cleanupQuestionMedia
    @MainActor
    func cleanupQuestionMedia() {
        if let fileName = questionImageFileName {
            MediaStorageManager.shared.deleteImage(
                fileName: fileName,
                hasFileManagerData: questionImageData == nil
            )
        }

        if let fileName = questionAudioFileName {
            MediaStorageManager.shared.deleteAudio(fileName: fileName)
        }

        questionContentType = .text
        questionImageData = nil
        questionImageFileName = nil
        questionAudioFileName = nil
        questionAudioDuration = 0
    }

    // ✅ Une seule version de cleanupAnswerMedia (duplication supprimée)
    @MainActor
    func cleanupAnswerMedia() {
        if let fileName = answerImageFileName {
            MediaStorageManager.shared.deleteImage(
                fileName: fileName,
                hasFileManagerData: answerImageData == nil
            )
        }

        if let fileName = answerAudioFileName {
            MediaStorageManager.shared.deleteAudio(fileName: fileName)
        }

        answerContentType = .text
        answerImageData = nil
        answerImageFileName = nil
        answerAudioFileName = nil
        answerAudioDuration = 0
    }

    @MainActor
    func cleanupAllMedia() {
        cleanupQuestionMedia() // ✅ Maintenant définie
        cleanupAnswerMedia()
    }
}

// MARK: - Async versions pour les contextes non-MainActor

extension Flashcard {
    func getQuestionImageAsync() async -> UIImage? {
        await MainActor.run {
            getQuestionImage()
        }
    }

    func getAnswerImageAsync() async -> UIImage? {
        await MainActor.run {
            getAnswerImage()
        }
    }

    func getQuestionAudioURLAsync() async -> URL? {
        await MainActor.run {
            getQuestionAudioURL()
        }
    }

    func getAnswerAudioURLAsync() async -> URL? {
        await MainActor.run {
            getAnswerAudioURL()
        }
    }

    func cleanupAllMediaAsync() async {
        await MainActor.run {
            cleanupAllMedia()
        }
    }
}
