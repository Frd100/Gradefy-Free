import SwiftUI
import UIKit

// MARK: - Activity View Controller

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        print("🎯 ActivityViewController makeUIViewController appelé")
        print("📋 ActivityItems: \(activityItems)")

        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        // Configuration plus robuste
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks,
            .postToVimeo,
            .postToFlickr,
            .postToTencentWeibo,
            .postToWeibo,
        ]

        // Callback pour diagnostiquer
        controller.completionWithItemsHandler = { _, success, _, error in
            print("🔄 Partage terminé: \(success)")
            if let error = error {
                print("❌ Erreur partage: \(error)")
            }
        }

        print("✅ UIActivityViewController créé")
        return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {
        print("🔄 ActivityViewController updateUIViewController appelé")
    }
}
