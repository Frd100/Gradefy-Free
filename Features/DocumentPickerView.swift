//
// DocumentPickerView.swift
// PARALLAX
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Types de contenu supportés pour iOS 17 - VERSION SÉCURISÉE
        let contentTypes: [UTType] = [
            .json,
            UTType(filenameExtension: "gradefy") ?? .json,
        ]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.modalPresentationStyle = .formSheet

        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // CRITIQUE : Démarrer l'accès sécurisé aux ressources (iOS 17)
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Impossible d'accéder au fichier sélectionné")
                return
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            // Créer un bookmark de sécurité pour persistence
            do {
                let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmarkData, forKey: "importedFileBookmark_\(url.lastPathComponent)")
                print("✅ Bookmark créé pour : \(url.lastPathComponent)")
            } catch {
                print("⚠️ Impossible de créer le bookmark: \(error)")
            }

            parent.onDocumentPicked(url)
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            print("📱 Sélection de fichier annulée")
        }
    }
}
