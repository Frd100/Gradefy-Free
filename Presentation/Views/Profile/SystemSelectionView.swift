//
//  SystemModeSelectionView.swift
//  PARALLAX
//

import SwiftUI
import CoreData
import UIKit
import WidgetKit
import Lottie
import UniformTypeIdentifiers
import Combine
import Foundation

struct SystemModeSelectionView: View {
    @Binding var refreshID: UUID
    @AppStorage("GradingSystem") private var selectedGradingSystem: String = "france"
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showConfirmation = false
    @State private var pendingSystem: String?
    @State private var isChanging = false
    
    private var availableSystems: [GradingSystemDisplayItem] {
        [
            GradingSystemDisplayItem(
                id: "usa",
                displayName: String(localized: "country_usa")
            ),
            GradingSystemDisplayItem(
                id: "canada",
                displayName: String(localized: "country_canada")
            ),
            GradingSystemDisplayItem(
                id: "france",
                displayName: String(localized: "country_france")
            ),
            GradingSystemDisplayItem(
                id: "germany",
                displayName: String(localized: "country_germany")
            ),
            GradingSystemDisplayItem(
                id: "spain",
                displayName: String(localized: "country_spain")
            )
        ]
    }
    
    var body: some View {
        List {
            animationSection
            systemsSection
        }
        .navigationTitle(String(localized: "nav_grading_system"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "alert_change_grading_system"), isPresented: $showConfirmation) {
            Button(String(localized: "action_confirm"), role: .destructive) {
                confirmSystemChange()
            }
            Button(String(localized: "action_cancel"), role: .cancel) {
                cancelSystemChange()
            }
        } message: {
            Text(String(localized: "alert_system_change_message"))
        }
        .disabled(isChanging)
    }
    
    private var systemsSection: some View {
        Section(String(localized: "section_grading_systems")) {
            ForEach(availableSystems) { system in
                GradingSystemRow(
                    system: system,
                    isSelected: selectedGradingSystem == system.id,
                    isChanging: isChanging && pendingSystem == system.id
                ) {
                    handleSystemSelection(system.id)
                }
            }
        }
    }
    
    private var animationSection: some View {
        Section {
            VStack(spacing: 10) {
                LottieView(animation: .named("globe"))
                    .playing()
                    .frame(width: AppConstants.Animation.lottieSize, height: AppConstants.Animation.lottieSize)
                
                Text(String(localized: "grading_system_description"))
                    .font(.caption.weight(.regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 1)
            .padding(.bottom, 0)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }
    
    // MARK: - Private Methods
    private func handleSystemSelection(_ systemId: String) {
        guard systemId != selectedGradingSystem, !isChanging else { return }
        
        HapticFeedbackManager.shared.impact(style: .light)
        pendingSystem = systemId
        showConfirmation = true
    }
    
    private func confirmSystemChange() {
        guard let newSystem = pendingSystem, !isChanging else {
            print("❌ [SYSTEM_VIEW] Changement annulé - newSystem: '\(pendingSystem ?? "nil")' | isChanging: \(isChanging)")
            resetState()
            return
        }
        
        print("🎯 [SYSTEM_VIEW] DÉBUT changement: '\(selectedGradingSystem)' → '\(newSystem)'")
        changeGradingSystemOptimized(to: newSystem)
    }
    
    private func cancelSystemChange() {
        resetState()
    }
    
    private func resetState() {
        pendingSystem = nil
        showConfirmation = false
    }
    
    private func changeGradingSystemOptimized(to newSystemId: String) {
        print("🔄 [SYSTEM_CHANGE] Début optimisé: '\(newSystemId)'")
        print("🔄 [SYSTEM_CHANGE] selectedGradingSystem avant: '\(selectedGradingSystem)'")
        
        guard !isChanging else { return }
        isChanging = true
        HapticFeedbackManager.shared.impact(style: .medium)
        
        Task {
            do {
                try await performSystemChangeSimple(to: newSystemId)
                
                await MainActor.run {
                    let beforeChange = selectedGradingSystem
                    selectedGradingSystem = newSystemId
                    
                    print("✅ [SYSTEM_CHANGE] selectedGradingSystem changé: '\(beforeChange)' → '\(selectedGradingSystem)'")
                    print("✅ [SYSTEM_CHANGE] Vérification UserDefaults: '\(UserDefaults.standard.string(forKey: "GradingSystem") ?? "nil")'")
                    
                    GradingSystemRegistry.invalidateCache()
                    refreshID = UUID()
                    isChanging = false
                    
                    HapticFeedbackManager.shared.notification(type: .success)
                }
            } catch {
                await MainActor.run {
                    isChanging = false
                    HapticFeedbackManager.shared.notification(type: .error)
                    print("❌ [SYSTEM_CHANGE] Erreur: \(error)")
                }
            }
        }
    }

    private func performSystemChangeSimple(to newSystemId: String) async throws {
        try await viewContext.perform {
            do {
                print("🔍 Suppression ciblée des évaluations et matières...")
                
                let subjectsRequest: NSFetchRequest<Subject> = Subject.fetchRequest()
                let subjects = try self.viewContext.fetch(subjectsRequest)
                
                for subject in subjects {
                    let evaluations = (subject.evaluations as? Set<Evaluation>) ?? []
                    for evaluation in evaluations {
                        self.viewContext.delete(evaluation)
                    }
                    self.viewContext.delete(subject)
                }
                
                try self.viewContext.save()
                self.viewContext.refreshAllObjects()
                
                print("✅ Suppression ciblée terminée pour système : \(newSystemId)")
                
            } catch {
                self.viewContext.rollback()
                throw error
            }
        }
    }
}

// MARK: - Grading System Display Item
struct GradingSystemDisplayItem: Identifiable {
    let id: String
    let displayName: String
}

// MARK: - Grading System Row
struct GradingSystemRow: View {
    let system: GradingSystemDisplayItem
    let isSelected: Bool
    let isChanging: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            guard !isChanging else { return }
            HapticFeedbackManager.shared.impact(style: .light)
            action()
        }) {
            HStack(spacing: 16) {
                Text(system.displayName)
                    .font(.body)
                    .fontWeight(.regular)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Group {
                    if isChanging {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .font(.title3)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isChanging)
        .opacity(isChanging ? 0.7 : 1.0)
    }
}
