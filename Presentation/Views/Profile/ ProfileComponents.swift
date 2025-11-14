//
//   ProfileComponents.swift
// PARALLAX
//
// Created by  on 6/28/25.
//

import Combine
import CoreData
import Foundation
import Lottie
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WidgetKit

// MARK: - AdaptiveImage Component

struct AdaptiveImage: View {
    let lightImageName: String
    let darkImageName: String
    let size: CGSize

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Group {
            if colorScheme == .light {
                Image(lightImageName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(darkImageName)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size.width, height: size.height)
        .id(colorScheme)
    }
}

enum ProfileDestination: Hashable {
    case editProfile
    case premium
    case debug
    case about
    case appIconSelection
    case dataOptions
    case dataManagement
    case periodManagement
    case systemSelection
    case userPreferences // ✅ NOUVEAU
    case modelSelection // ✅ NOUVEAU
}

struct DebugView: View {
    var body: some View {
        Text("Outils de debug")
            .font(.title)
            .padding()
            .navigationTitle("Debug")
    }
}

// MARK: - Premium Feature Row

struct FeatureRow: View {
    let feature: Feature
    let hasAccess: Bool
    let featureManager: FeatureManager

    var body: some View {
        HStack {
            Image(systemName: featureIcon)
                .foregroundColor(hasAccess ? .green : .gray)

            Text(featureTitle)
                .foregroundColor(.primary)

            Spacer()

            if hasAccess {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "lock.circle.fill")
                    .foregroundColor(.gray)
            }
        }
    }

    private var featureIcon: String {
        switch feature {
        case .unlimitedFlashcardsPerDeck: return "rectangle.stack.fill"
        case .unlimitedDecks: return "folder.badge.plus"
        case .customThemes: return "paintbrush.fill"
        case .premiumWidgets: return "app.badge.fill"
        case .advancedStats: return "chart.bar.fill"
        case .exportData: return "square.and.arrow.up.fill"
        case .prioritySupport: return "headphones"
        }
    }

    private var featureTitle: String {
        switch feature {
        case .unlimitedFlashcardsPerDeck: return "2000 cartes vs 300 gratuites"
        case .unlimitedDecks: return "Listes illimitées"
        case .customThemes: return "Thèmes personnalisés"
        case .premiumWidgets: return "Widgets Premium"
        case .advancedStats: return "Statistiques avancées"
        case .exportData: return "Export des données"
        case .prioritySupport: return "Support prioritaire"
        }
    }
}

// MARK: - Profile Text Field

struct ProfileTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 80, alignment: .leading)
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

struct MinimalGradientButton: View {
    let gradient: [Color]
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: gradient),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: AppConstants.Animation.gradientButtonSize, height: AppConstants.Animation.gradientButtonSize)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model Selection View

struct ModelSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var modelManager = ModelManager.shared
    @State private var showingDeleteConfirmation = false
    @State private var modelToDelete: AIModel?

    var body: some View {
        List {
            Section {
                ForEach(modelManager.availableModels) { model in
                    ModelRowView(
                        model: model,
                        onDownload: {
                            modelManager.downloadModel(model)
                        },
                        onDelete: {
                            modelToDelete = model
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
        }
        .navigationTitle("Modèle")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Supprimer le modèle",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let model = modelToDelete {
                    modelManager.deleteModel(model)
                    modelToDelete = nil
                }
            }
            Button("Annuler", role: .cancel) {
                modelToDelete = nil
            }
        } message: {
            Text("Cette action supprimera définitivement le modèle de votre appareil. Vous devrez le retélécharger pour l'utiliser à nouveau.")
        }
    }
}

// MARK: - Model Row View

struct ModelRowView: View {
    let model: AIModel
    let onDownload: () -> Void
    let onDelete: () -> Void

    @StateObject private var modelManager = ModelManager.shared

    // ✅ NOUVEAU : Vérification de compatibilité RAM
    private var isCompatible: Bool {
        modelManager.isDeviceCompatibleForAI()
    }

    var body: some View {
        HStack(spacing: 12) {
            // Bouton de téléchargement/progression
            if modelManager.isModelDownloaded(model) {
                // Checkmark de succès (non interactif - juste indicateur)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.blue)
            } else {
                Button(action: {
                    if !modelManager.isDownloading(model), isCompatible {
                        onDownload()
                    }
                }) {
                    if modelManager.isDownloading(model) {
                        // Cercle de progression bleu unifié
                        ZStack {
                            Circle()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                                .frame(width: 24, height: 24)

                            Circle()
                                .trim(from: 0, to: modelManager.downloadProgress(for: model))
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 24, height: 24)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.3), value: modelManager.downloadProgress(for: model))
                        }
                    } else {
                        // Bouton download sans fond
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(isCompatible ? .blue : .gray)
                    }
                }
                .buttonStyle(.plain)
                .disabled(modelManager.isDownloading(model) || !isCompatible)
            }

            // Informations du modèle
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                // ✅ NOUVEAU : Message de compatibilité
                if !isCompatible {
                    Text("Non compatible")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.6))
                }

                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            // Bouton ellipses pour menu de suppression quand téléchargé
            if modelManager.isModelDownloaded(model) {
                Menu {
                    Button("Supprimer le modèle", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
