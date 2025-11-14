//
//  AppIconSelectionView.swift
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

struct AppIconSelectionView: View {
    @StateObject private var iconManager = AppIconManager.shared
    @State private var premiumManager = PremiumManager.shared
    @State private var showingPremiumView = false
    @Environment(\.colorScheme) private var colorScheme
    
    // ✅ PARAMÈTRES D'APPARENCE intégrés
    @AppStorage("darkModeEnabled") private var darkModeEnabled: Bool = false
    
    // ✅ COMPUTED PROPERTY au lieu de let statique
    private var availableIcons: [AppIconDisplayItem] {
        [
            AppIconDisplayItem(
                name: "AppIcon",
                displayName: String(localized: "icon_default"),
                color: .blue,
                previewImageName: "AppIconPreview",
                isPremium: false
            ),
            AppIconDisplayItem(
                name: "AppIconDark",
                displayName: String(localized: "icon_dark"),
                color: .black,
                previewImageName: "iconDarkPreview",
                isPremium: true
            ),
            AppIconDisplayItem(
                name: "AppIconColorful",
                displayName: String(localized: "icon_colorful"),
                color: .purple,
                previewImageName: "iconColorfulPreview",
                isPremium: true
            ),
            AppIconDisplayItem(
                name: "AppIconMinimal",
                displayName: String(localized: "icon_minimal"),
                color: .gray,
                previewImageName: "iconMinimalPreview",
                isPremium: true
            )
        ]
    }
    
    var body: some View {
        List {
            // ✅ SECTION ANIMATION LOTTIE
            animationSection
            
            // ✅ SECTION APPARENCE
            appearanceSection
            
            // ✅ SECTION ICÔNES
            iconSection
        }
        .navigationTitle(String(localized: "nav_appearance"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            iconManager.syncCurrentIcon()
        }
        .sheet(isPresented: $showingPremiumView) {
            PremiumView(highlightedFeature: .customThemes)
        }
    }
    
    private var animationSection: some View {
        Section {
            VStack(spacing: 10) {
                AdaptiveLottieView(
                    animationName: "palette",
                    isAnimated: true
                )
                .frame(width: AppConstants.Animation.lottieSize, height: AppConstants.Animation.lottieSize)
                
                Text(String(localized: "appearance_description"))
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

    // MARK: - Section Apparence
    private var appearanceSection: some View {
        Section(String(localized: "section_display")) {
            // Mode sombre
            HStack(spacing: 16) {
                
                Toggle(String(localized: "setting_dark_mode"), isOn: $darkModeEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: darkModeEnabled) { _, newValue in
                        HapticFeedbackManager.shared.selection()
                    }
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Section Icônes
    private var iconSection: some View {
        Section(String(localized: "section_app_icon")) {
            ForEach(availableIcons) { icon in
                AppIconRow(
                    icon: icon,
                    isSelected: iconManager.currentIcon == icon.name,
                    isChanging: iconManager.isChanging && iconManager.currentIcon == icon.name,
                    isPremium: premiumManager.isPremium
                ) {
                    selectIcon(icon)
                }
            }
        }
    }
    
    private func selectIcon(_ icon: AppIconDisplayItem) {
        // ✅ NOUVEAU : Toujours permettre la sélection de l'icône par défaut
        if icon.name == "AppIcon" {
            iconManager.changeIcon(to: icon.name)
            return
        }
        
        // ✅ NOUVEAU : Vérifier d'abord si l'icône est premium et l'utilisateur gratuit
        if icon.isPremium && !premiumManager.isPremium {
            showingPremiumView = true
            return
        }
        
        // ✅ NOUVEAU : Permettre le changement si l'icône est différente
        if icon.name != iconManager.currentIcon {
            iconManager.changeIcon(to: icon.name)
        }
    }
}

// MARK: - App Icon Row Component

struct AppIconRow: View {
    let icon: AppIconDisplayItem
    let isSelected: Bool
    let isChanging: Bool
    let isPremium: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            guard !isChanging else { return }
            HapticFeedbackManager.shared.impact(style: .light)
            action()
        }) {
            HStack(spacing: 16) {
                // 🖼️ IMAGE PETITE À GAUCHE
                if let uiImage = UIImage(named: icon.previewImageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: AppConstants.Animation.iconPreviewSize, height: AppConstants.Animation.iconPreviewSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 0.2)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(icon.color)
                        .frame(width: AppConstants.Animation.iconPreviewSize, height: AppConstants.Animation.iconPreviewSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                
                // 📝 TITRE AU MILIEU
                Text(icon.displayName)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // ✅ INDICATEUR À DROITE
                Group {
                    if isChanging {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    } else if icon.isPremium && !isPremium {
                        // 🔒 CADENAS DORÉ aligné
                        Image(systemName: "lock.fill")
                            .font(.title3)  // ✅ MÊME TAILLE QUE LE CHECKMARK
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "circle")
                            .font(.title3)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .frame(width: 24, height: 24)  // ✅ FRAME FIXE POUR ALIGNEMENT
                .frame(maxWidth: 24, alignment: .center)  // ✅ CENTRAGE PARFAIT

            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isChanging)
        .opacity(isChanging ? 0.7 : 1.0)
    }
}

// MARK: - App Icon Display Item

struct AppIconDisplayItem: Identifiable {
    let id = UUID()
    let name: String
    let displayName: String
    let color: Color
    let previewImageName: String
    let isPremium: Bool
}

// MARK: - App Icon Manager

@MainActor
final class AppIconManager: ObservableObject {
    static let shared = AppIconManager()
    private init() {}
    
    @Published private(set) var currentIcon: String = "AppIcon"
    @Published private(set) var isChanging: Bool = false
    
    func syncCurrentIcon() {
        currentIcon = UIApplication.shared.alternateIconName ?? "AppIcon"
    }
    
    func changeIcon(to iconName: String) {
        guard !isChanging else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            print("Icônes alternatives non supportées")
            return
        }
        
        isChanging = true
        let newIconName = iconName == "AppIcon" ? nil : iconName
        
        HapticFeedbackManager.shared.impact(style: .medium)
        
        UIApplication.shared.setAlternateIconName(newIconName) { [weak self] error in
            DispatchQueue.main.async {
                self?.isChanging = false
                if let error = error {
                    HapticFeedbackManager.shared.notification(type: .error)
                    print("Erreur lors du changement d'icône : \(error)")
                } else {
                    self?.currentIcon = iconName
                    HapticFeedbackManager.shared.notification(type: .success)
                    print("Icône changée : \(iconName)")
                }
            }
        }
    }
}
