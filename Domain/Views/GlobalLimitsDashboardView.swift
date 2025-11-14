import CoreData
import SwiftUI

struct GlobalLimitsDashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var featureManager = FeatureManager.shared
    @State private var refreshTrigger = UUID() // ✅ NOUVEAU : Trigger pour forcer les mises à jour

    private var flashcardInfo: (current: Int, max: Int, remaining: Int) {
        featureManager.getTotalFlashcardInfo(context: viewContext)
    }

    private var mediaInfo: (current: Int, max: Int, remaining: Int) {
        featureManager.getTotalMediaInfo(context: viewContext)
    }

    private var flashcardProgress: Double {
        guard flashcardInfo.max > 0 else { return 0 }
        let progress = Double(flashcardInfo.current) / Double(flashcardInfo.max)
        return min(progress, 1.0) // S'assurer que la valeur ne dépasse pas 1.0
    }

    private var mediaProgress: Double {
        guard mediaInfo.max > 0 else { return 0 }
        let progress = Double(mediaInfo.current) / Double(mediaInfo.max)
        return min(progress, 1.0) // S'assurer que la valeur ne dépasse pas 1.0
    }

    private var flashcardColor: Color {
        if flashcardInfo.remaining <= 10 {
            return .orange
        } else if flashcardProgress >= 0.8 {
            return .yellow
        } else {
            return .blue
        }
    }

    private var mediaColor: Color {
        if mediaInfo.remaining <= 5 {
            return .orange
        } else if mediaProgress >= 0.8 {
            return .yellow
        } else {
            return .purple
        }
    }

    var body: some View {
        HStack(spacing: 20) {
            // Flashcards
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(flashcardInfo.current)/\(flashcardInfo.max)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(flashcardColor)

                    Text("Cartes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: flashcardProgress, total: 1.0)
                    .tint(flashcardColor)
                    .scaleEffect(y: 0.8, anchor: .center)
            }

            Spacer()

            // Médias
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(mediaInfo.current)/\(mediaInfo.max)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(mediaColor)

                    Text("Médias")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: mediaProgress, total: 1.0)
                    .tint(mediaColor)
                    .scaleEffect(y: 0.8, anchor: .center)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
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
}
