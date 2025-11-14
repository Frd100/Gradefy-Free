//
//  ProfileView.swift
//  PARALLAX
//
//  Created by  on 7/21/25.
//
import SwiftUI
import CoreData
import UIKit
import WidgetKit
import Lottie
import UniformTypeIdentifiers
import Combine
import Foundation

struct ProfileView: View {
    // MARK: - Environment
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - App Storage
    @AppStorage("showCreatorInShare") private var showCreatorInShare: Bool = true
    @AppStorage("username") private var username: String = ""
    @AppStorage("profileSubtitle") private var profileSubtitle: String = ""
    @AppStorage("profileGradientStartHex") private var profileGradientStartHex: String = "90A4AE"
    @AppStorage("profileGradientEndHex") private var profileGradientEndHex: String = "253137"
    @AppStorage("enableHaptics") private var enableHaptics: Bool = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled: Bool = false
    @AppStorage("GradingSystem") private var selectedGradingSystem: String = "france"
    @State private var premiumManager = PremiumManager.shared
    // MARK: - State Variables
    @State private var showingEditProfile = false
    @State private var showingShareSheet = false
    @State private var showingPremiumView = false
    @State private var refreshID = UUID()
    @State private var exportedURL: URL?
    @State private var navigationPath = NavigationPath()
    
    // Variables pour import/export

    @StateObject private var importExportManager = DataImportExportManager()
    
    // MARK: - Computed Properties
    private var profileGradient: [Color] {
        [Color(hex: profileGradientStartHex), Color(hex: profileGradientEndHex)]
    }
    
    // MARK: - Main Body
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                profileSection
                settingsSection
                dataSection
                premiumSection
                debugSection
                aboutSection
            }
            .listSectionSpacing(25)
            .scrollIndicators(.hidden)
            .navigationTitle(String(localized: "nav_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .id(refreshID)
            .safeAreaInset(edge: .bottom) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 60)
            }
            .navigationDestination(for: ProfileDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        
        .sheet(isPresented: $showingEditProfile) {
            EditProfileSheet()
        }
        .sheet(isPresented: $showingPremiumView) {
            PremiumView()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportedURL {
                ShareSheet(activityItems: [url])
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            let savedSystem = UserDefaults.standard.string(forKey: "GradingSystem") ?? "france"
            if selectedGradingSystem != savedSystem {
                selectedGradingSystem = savedSystem
            }
        }
        .onAppear {
            print("🔍 Configuration contexte import/export")
            importExportManager.setContext(viewContext)
            updateProfileFromUserDefaults()
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: ProfileDestination) -> some View {
        switch destination {
        case .editProfile:
            EditProfileView()
        case .premium:
            PremiumView()
        case .debug:
            DebugView()
        case .about:
            AboutView()
        case .appIconSelection:
            AppIconSelectionView()
        case .dataOptions:
            DataOptionsView(navigationPath: $navigationPath)
        case .dataManagement:
            DataManagementView()
        case .periodManagement:
            PeriodManagementView(refreshID: $refreshID)
        case .systemSelection:
            SystemModeSelectionView(refreshID: $refreshID)
        case .userPreferences: // ✅ NOUVEAU
            UserPreferencesView()
        case .modelSelection: // ✅ NOUVEAU
            ModelSelectionView()
        }
    }
    
    private func updateProfileFromUserDefaults() {
        importExportManager.setContext(viewContext)
        print("✅ Contexte reconfiguré dans updateProfileFromUserDefaults")
    }
}

// MARK: - Profile Sections
extension ProfileView {
    
    // MARK: - Profile Section
    private var profileSection: some View {
        Section {
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                showingEditProfile = true
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: profileGradient),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: AppConstants.Animation.profileAvatarSize, height: AppConstants.Animation.profileAvatarSize)
                        
                        Text(username.isEmpty ? "" : String(username.prefix(1).uppercased()))
                            .font(.title.weight(.semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(username.isEmpty ? String(localized: "profile_username_placeholder") : username)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 1)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Premium Section (à déplacer dans une section séparée)
    private var premiumSection: some View {
        Section {
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                showingPremiumView = true
            }) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange)
                        .frame(width: AppConstants.Animation.iconPreviewSize, height: AppConstants.Animation.iconPreviewSize)
                        .overlay(
                            Image(systemName: "crown.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: AppConstants.Animation.iconPreviewSize, height: AppConstants.Animation.iconPreviewSize)
                        )
                    
                    Text(String(localized: "premium_gradefy_pro"))
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Badge conditionnel pour les utilisateurs premium
                    if premiumManager.isPremium {
                        Text(String(localized: "premium_active_badge"))
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green)
                            )
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    // ✅ NOUVELLE section unifiée
    private var settingsSection: some View {
        Section{
            // Système de notation
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                navigationPath.append(ProfileDestination.systemSelection)
            }) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green)
                        .frame(width: AppConstants.Animation.iconPreviewSize, height: AppConstants.Animation.iconPreviewSize)
                        .overlay(
                            Image(systemName: "chart.bar")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        )
                    
                    Text(String(localized: "settings_grading_system"))
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Apparence
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                navigationPath.append(ProfileDestination.appIconSelection)
            }) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                        .frame(width: AppConstants.Animation.iconPreviewSize, height: AppConstants.Animation.iconPreviewSize)
                        .overlay(
                            Image(systemName: "app.badge")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        )
                    
                    Text(String(localized: "nav_appearance"))
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Préférences
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                navigationPath.append(ProfileDestination.userPreferences)
            }) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple)
                        .frame(width: AppConstants.Animation.iconPreviewSize, height: AppConstants.Animation.iconPreviewSize)
                        .overlay(
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        )
                    
                    Text(String(localized: "settings_preferences"))
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Model
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                navigationPath.append(ProfileDestination.modelSelection)
            }) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.indigo)
                        .frame(width: AppConstants.Animation.iconPreviewSize, height: AppConstants.Animation.iconPreviewSize)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        )
                    
                    Text("Modèle")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }


    
    // MARK: - Data Section (MODIFIÉE)
    private var dataSection: some View {
        Section {
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                navigationPath.append(ProfileDestination.periodManagement)
            }) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green)
                        .frame(width: AppConstants.Animation.iconPreviewSize, height: AppConstants.Animation.iconPreviewSize)
                        .overlay(
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: AppConstants.Animation.iconPreviewSize, height: AppConstants.Animation.iconPreviewSize)
                        )
                    
                    Text(String(localized: "settings_manage_periods"))
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // AJOUTÉ : Nouveau bouton unifié pour la gestion des données
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                navigationPath.append(ProfileDestination.dataOptions)
            }) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                        .frame(width: AppConstants.Animation.iconPreviewSize, height: AppConstants.Animation.iconPreviewSize)
                        .overlay(
                            Image(systemName: "cylinder.split.1x2")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        )
                    
                    Text(String(localized: "settings_data_backup"))
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Debug Section
    private var debugSection: some View {
        Section {
            DebugPremiumButton()
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        Section {
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                navigationPath.append(ProfileDestination.about)
            }) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray)
                        .frame(width: AppConstants.Animation.iconPreviewSize, height: AppConstants.Animation.iconPreviewSize)
                        .overlay(
                            Image(systemName: "info.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: AppConstants.Animation.iconPreviewSize, height: AppConstants.Animation.iconPreviewSize)
                        )
                    
                    Text(String(localized: "about_gradefy"))
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
