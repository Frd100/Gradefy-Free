//
//  EditProfileView.swift
//  PARALLAX
//
//  Created by  on 7/21/25.
//
import Combine
import CoreData
import Foundation
import Lottie
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WidgetKit

struct EditProfileView: View {
    var body: some View {
        Text(String(localized: "profile_editing"))
            .font(.title)
            .padding()
            .navigationTitle(String(localized: "nav_profile"))
    }
}

struct EditProfileSheet: View {
    // MARK: - Environment & Storage

    @Environment(\.dismiss) private var dismiss
    @AppStorage("username") private var username: String = ""
    @AppStorage("profileSubtitle") private var profileSubtitle: String = ""
    @AppStorage("showCreatorInShare") private var showCreatorInShare: Bool = true

    // MARK: - State Variables

    @State private var profileGradientStartHex: String = "90A4AE"
    @State private var profileGradientEndHex: String = "253137"
    @State private var tempUsername: String = ""
    @State private var tempSubtitle: String = ""
    @State private var selectedGradient: [Color] = []

    // MARK: - Constants

    private let availableGradients: [[Color]] = [
        // Gris bleu clair → Gris bleu foncé
        [Color(hex: "8B95A8"), Color(hex: "4A5568")],

        // Violet lavande clair → Violet lavande foncé
        [Color(hex: "B8A9DC"), Color(hex: "6B46C1")],

        // Bleu ciel clair → Bleu ciel foncé
        [Color(hex: "87CEEB"), Color(hex: "2563EB")],

        // Rose clair → Rose foncé
        [Color(hex: "F8BBD9"), Color(hex: "EC4899")],

        // Beige/Jaune clair → Beige/Jaune foncé
        [Color(hex: "F3E8A6"), Color(hex: "D69E2E")],

        // Vert menthe clair → Vert menthe foncé
        [Color(hex: "A7E6A3"), Color(hex: "16A085")],

        // Taupe/Marron clair → Taupe/Marron foncé
        [Color(hex: "C8A882"), Color(hex: "8B5A2B")],

        // Orange pêche clair → Orange pêche foncé
        [Color(hex: "FFB07A"), Color(hex: "E67E22")],

        // Lavande gris clair → Lavande gris foncé
        [Color(hex: "D1C4E9"), Color(hex: "7B1FA2")],

        // Bleu acier clair → Bleu acier foncé
        [Color(hex: "90A4AE"), Color(hex: "263238")],

        // Turquoise menthe clair → Turquoise menthe foncé
        [Color(hex: "A8E6CF"), Color(hex: "00695C")],

        // Violet magenta clair → Violet magenta foncé
        [Color(hex: "E1BEE7"), Color(hex: "8E24AA")],

        // Cyan aqua clair → Cyan aqua foncé
        [Color(hex: "81D4FA"), Color(hex: "0097A7")],

        // Vert lime clair → Vert lime foncé
        [Color(hex: "C8E6C9"), Color(hex: "388E3C")],
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                profilePreviewSection
                informationSection
                colorSection
            }
            .navigationTitle(String(localized: "profile_edit_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action_cancel")) {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action_save")) {
                        saveProfile()
                    }
                    .disabled(tempUsername.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                setupTempValues()
            }
        }
    }

    // MARK: - Private Methods

    func testColorSave() {
        print("🧪 [TEST] Test sauvegarde couleur...")

        UserDefaults.standard.set("FF0000", forKey: "profileGradientStartHex") // Rouge
        UserDefaults.standard.set("00FF00", forKey: "profileGradientEndHex") // Vert
        UserDefaults.standard.synchronize()

        let saved1 = UserDefaults.standard.string(forKey: "profileGradientStartHex")
        let saved2 = UserDefaults.standard.string(forKey: "profileGradientEndHex")

        print("🧪 [TEST] Sauvegardé: '\(saved1 ?? "nil")' → '\(saved2 ?? "nil")'")
    }

    private func setupTempValues() {
        // Charger depuis UserDefaults au lieu des @AppStorage
        tempUsername = username
        tempSubtitle = profileSubtitle

        // Charger les vraies couleurs sauvegardées
        let startHex = UserDefaults.standard.string(forKey: "profileGradientStartHex") ?? "90A4AE"
        let endHex = UserDefaults.standard.string(forKey: "profileGradientEndHex") ?? "253137"

        profileGradientStartHex = startHex
        profileGradientEndHex = endHex

        selectedGradient = [Color(hex: startHex), Color(hex: endHex)]

        print("📖 [EDIT_PROFILE] Couleurs chargées: '\(startHex)' → '\(endHex)'")
    }

    private func saveProfile() {
        print("💾 [EDIT_PROFILE] === DÉBUT SAUVEGARDE COULEURS ===")

        // Vérifier que selectedGradient a des valeurs
        guard selectedGradient.count >= 2 else {
            print("❌ [EDIT_PROFILE] selectedGradient invalide: \(selectedGradient.count) couleurs")
            return
        }

        // Convertir les couleurs
        let newStartHex = selectedGradient[0].toHex()
        let newEndHex = selectedGradient[1].toHex()

        print("💾 [EDIT_PROFILE] Nouvelles couleurs converties: '\(newStartHex)' → '\(newEndHex)'")

        // Sauvegarder le nom (fonctionne déjà)
        username = tempUsername.trimmingCharacters(in: .whitespaces)
        print("💾 [EDIT_PROFILE] Nom sauvegardé: '\(username)'")

        // Sauvegarder les couleurs DIRECTEMENT dans UserDefaults
        UserDefaults.standard.set(newStartHex, forKey: "profileGradientStartHex")
        UserDefaults.standard.set(newEndHex, forKey: "profileGradientEndHex")
        UserDefaults.standard.synchronize()

        print("💾 [EDIT_PROFILE] Couleurs écrites dans UserDefaults")

        // Vérification immédiate
        let savedStart = UserDefaults.standard.string(forKey: "profileGradientStartHex") ?? "nil"
        let savedEnd = UserDefaults.standard.string(forKey: "profileGradientEndHex") ?? "nil"

        print("✅ [EDIT_PROFILE] VÉRIFICATION: start='\(savedStart)', end='\(savedEnd)'")

        // Mettre à jour les @AppStorage si ils existent
        profileGradientStartHex = newStartHex
        profileGradientEndHex = newEndHex

        print("✅ [EDIT_PROFILE] === SAUVEGARDE TERMINÉE ===")

        HapticFeedbackManager.shared.notification(type: .success)
        dismiss()
    }

    // MARK: - View Components

    private var profilePreviewSection: some View {
        Group {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: selectedGradient),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: AppConstants.Animation.editProfileAvatarSize, height: AppConstants.Animation.editProfileAvatarSize)

                            Text(tempUsername.isEmpty ? "" : String(tempUsername.prefix(1).uppercased()))
                                .font(.largeTitle.weight(.bold))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 4) {
                            Text(tempUsername.isEmpty ? "" : tempUsername)
                                .font(.title2.weight(.semibold))
                        }
                    }
                    Spacer()
                }
                .padding(.vertical)
            }
        }
    }

    private var informationSection: some View {
        Section(String(localized: "section_information")) {
            ProfileTextField(
                title: String(localized: "profile_name_field"),
                text: $tempUsername,
                placeholder: String(localized: "field_optional")
            )
        }
    }

    private var colorSection: some View {
        Section(String(localized: "section_color")) {
            VStack(spacing: 12) {
                // Première ligne (0 à 6)
                HStack(spacing: 16) {
                    ForEach(0 ..< 7, id: \.self) { index in
                        MinimalGradientButton(
                            gradient: availableGradients[index],
                            isSelected: selectedGradient == availableGradients[index]
                        ) {
                            HapticFeedbackManager.shared.selection()
                            selectedGradient = availableGradients[index]
                        }
                    }
                }

                // Deuxième ligne (7 à 13)
                HStack(spacing: 16) {
                    ForEach(7 ..< 14, id: \.self) { index in
                        MinimalGradientButton(
                            gradient: availableGradients[index],
                            isSelected: selectedGradient == availableGradients[index]
                        ) {
                            HapticFeedbackManager.shared.selection()
                            selectedGradient = availableGradients[index]
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 40) {
            headerSection

            VStack(spacing: 20) {
                infoRow(
                    title: String(localized: "about_version"),
                    value: "1.0.0"
                )
                infoRow(
                    title: String(localized: "about_developer"),
                    value: String(localized: "about_developer_name")
                )
                infoRow(
                    title: String(localized: "about_compatibility"),
                    value: String(localized: "about_compatibility_value")
                )
                infoRow(
                    title: String(localized: "about_languages"),
                    value: String(localized: "about_languages_value")
                )
            }

            Spacer()

            Text(String(localized: "about_copyright"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle(String(localized: "nav_about"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "graduationcap.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text(String(localized: "about_app_name"))
                .font(.title.weight(.semibold))
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}
