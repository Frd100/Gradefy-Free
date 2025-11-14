//
//  FlashcardLimitWidget.swift
//  PARALLAX
//
//  Created by Farid on 8/12/25.
//

//
//  FlashcardLimitWidget.swift
//  PARALLAX
//
//  Widget d'affichage des limites de flashcards
//

import CoreData
import SwiftUI

struct UnifiedLimitWidget: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var premiumManager = PremiumManager.shared
    @State private var refreshTrigger = UUID() // ✅ NOUVEAU : Trigger pour forcer les mises à jour

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête unifié
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Limites d'utilisation")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }

            // Section Flashcards
            VStack(alignment: .leading, spacing: 6) {
                let flashcardInfo = premiumManager.getTotalFlashcardInfo(context: viewContext)

                HStack {
                    Image(systemName: "rectangle.stack")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Flashcards")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(flashcardInfo.current)/\(flashcardInfo.max)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(flashcardInfo.remaining > 10 ? .primary : .orange)
                }

                ProgressView(value: Double(flashcardInfo.current), total: Double(flashcardInfo.max))
                    .tint(flashcardInfo.remaining > 10 ? .blue : .orange)
                    .scaleEffect(y: 0.6, anchor: .center)
            }

            // Section Médias
            VStack(alignment: .leading, spacing: 6) {
                let mediaInfo = premiumManager.getTotalMediaInfo(context: viewContext)

                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(.purple)
                        .font(.caption)
                    Text("Médias")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(mediaInfo.current)/\(mediaInfo.max)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(mediaInfo.remaining > 5 ? .primary : .orange)
                }

                ProgressView(value: Double(mediaInfo.current), total: Double(mediaInfo.max))
                    .tint(mediaInfo.remaining > 5 ? .purple : .orange)
                    .scaleEffect(y: 0.6, anchor: .center)
            }

            // Avertissement si limites proches
            if shouldShowWarning {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption2)
                    Text(warningMessage)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .id(refreshTrigger) // ✅ NOUVEAU : Forcer le refresh du widget
        // ✅ NOUVEAU : Écouter les changements de données
        .onReceive(NotificationCenter.default.publisher(for: .dataDidChange)) { _ in
            DispatchQueue.main.async {
                refreshTrigger = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { notification in
            // ✅ NOUVEAU : Réagir aux changements Core Data
            if let userInfo = notification.userInfo {
                let changedObjects = [
                    NSInsertedObjectsKey,
                    NSUpdatedObjectsKey,
                    NSDeletedObjectsKey,
                ].compactMap { key in
                    userInfo[key] as? Set<NSManagedObject>
                }.flatMap { $0 }

                let hasRelevantChanges = changedObjects.contains { object in
                    if object is Flashcard {
                        return true
                    }
                    return false
                }

                if hasRelevantChanges {
                    DispatchQueue.main.async {
                        refreshTrigger = UUID()
                    }
                }
            }
        }
    }

    // ✅ MODIFIÉ : Plus d'avertissement - Application entièrement gratuite
    private var shouldShowWarning: Bool {
        false // Plus de limites, plus d'avertissement
    }

    private var warningMessage: String {
        "" // Plus de message d'avertissement
    }
}

// ✅ ALIAS POUR COMPATIBILITÉ
typealias FlashcardLimitWidget = UnifiedLimitWidget

struct DeckLimitWidget: View {
    let currentDeckCount: Int
    @State private var premiumManager = PremiumManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let deckInfo = premiumManager.getDeckFlashcardInfo(currentDeckCount: currentDeckCount)

            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.green)
                Text("Flashcards dans ce deck")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(deckInfo.current)/\(deckInfo.max)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(deckInfo.remaining > 20 ? .primary : .orange)
            }

            ProgressView(value: Double(deckInfo.current), total: Double(deckInfo.max))
                .tint(deckInfo.remaining > 20 ? .green : .orange)
                .scaleEffect(y: 0.8, anchor: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
