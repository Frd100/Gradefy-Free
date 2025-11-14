//
//  HapticFeedbackManager.swift
//  PARALLAX
//
//  Created by  on 7/9/25.
//

import CoreData
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Haptic Feedback Manager

final class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()

    @AppStorage("enableHaptics") private var isEnabled: Bool = true

    // ✅ SOLUTION PARFAITE : Générateurs réutilisables pour éviter les erreurs
    private let softImpactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {
        // Préparer les générateurs une seule fois
        softImpactGenerator.prepare()
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }

    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }

        // ✅ SOLUTION : Utiliser les générateurs pré-préparés
        switch style {
        case .soft:
            softImpactGenerator.impactOccurred()
        case .light:
            lightImpactGenerator.impactOccurred()
        case .medium:
            mediumImpactGenerator.impactOccurred()
        case .heavy:
            heavyImpactGenerator.impactOccurred()
        @unknown default:
            softImpactGenerator.impactOccurred()
        }
    }

    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(type)
    }

    func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }
}
