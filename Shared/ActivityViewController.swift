import SwiftUI
import UIKit

// MARK: - Activity View Controller
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
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
            .postToWeibo
        ]
        
        // Callback pour diagnostiquer
        controller.completionWithItemsHandler = { activity, success, items, error in
            print("🔄 Partage terminé: \(success)")
            if let error = error {
                print("❌ Erreur partage: \(error)")
            }
        }
        
        print("✅ UIActivityViewController créé")
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        print("🔄 ActivityViewController updateUIViewController appelé")
    }
}
