//
// UserPreferencesView.swift
// PARALLAX
//
// Created by  on 7/21/25.
//

import Combine
import CoreData
import Foundation
import Lottie
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WidgetKit

struct UserPreferencesView: View {
    @AppStorage("enableHaptics") private var enableHaptics: Bool = true
    @AppStorage("showCreatorInShare") private var showCreatorInShare: Bool = true

    var body: some View {
        List {
            animationSection
            preferencesSection
        }
        .navigationTitle(String(localized: "nav_preferences"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Animation Section

    private var animationSection: some View {
        Section {
            VStack(spacing: 10) {
                AdaptiveLottieView(
                    animationName: "preference",
                    isAnimated: true
                )
                .frame(width: AppConstants.Animation.lottieSize, height: AppConstants.Animation.lottieSize)

                Text(String(localized: "preferences_description"))
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

    // MARK: - Preferences Section

    // ✅ NOUVEAU - Sans icônes
    private var preferencesSection: some View {
        Section(String(localized: "section_preferences")) {
            // Retour haptique
            Toggle(String(localized: "setting_haptic_feedback"), isOn: $enableHaptics)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .onChange(of: enableHaptics) { _, newValue in
                    if newValue {
                        HapticFeedbackManager.shared.impact(style: .medium)
                    }
                }

            // Afficher le créateur
            Toggle(String(localized: "setting_sign_shares"), isOn: $showCreatorInShare)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .onChange(of: showCreatorInShare) { _, _ in
                    HapticFeedbackManager.shared.selection()
                }
        }
    }
}
