//
// DebugPremiumButton.swift
// PARALLAX
//
// Created by  on 7/9/25.
//

import SwiftUI

struct DebugPremiumButton: View {
    @State private var premiumManager = PremiumManager.shared
    @State private var isPremium: Bool = false
    @State private var isToggling: Bool = false

    var body: some View {
        #if DEBUG
            VStack(spacing: 16) {
                // ✅ BOUTON PRINCIPAL AMÉLIORÉ
                Button {
                    togglePremiumForTesting()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(isPremium ? Color.yellow : Color.gray.opacity(0.3))
                                .frame(width: 32, height: 32)

                            if isToggling {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: isPremium ? "crown.fill" : "crown")
                                    .foregroundColor(isPremium ? .white : .gray)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(isPremium ? "Mode Premium" : "Mode Gratuit")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text(isPremium ? "Toutes les fonctionnalités" : "Fonctionnalités limitées")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // ✅ SWITCH VISUEL
                        Toggle("", isOn: Binding(
                            get: { isPremium },
                            set: { _ in togglePremiumForTesting() }
                        ))
                        .labelsHidden()
                        .tint(.yellow)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isPremium ? Color.yellow.opacity(0.1) : Color.gray.opacity(0.05))
                            .stroke(isPremium ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                .disabled(isToggling)

                // ✅ INFORMATIONS DE DEBUG AMÉLIORÉES
                VStack(spacing: 8) {
                    HStack {
                        Label("Debug Override", systemImage: "ant.fill")
                            .font(.caption)
                            .foregroundColor(.orange)

                        Spacer()

                        Text(premiumManager.debugOverride ? "ACTIF" : "INACTIF")
                            .font(.caption.weight(.bold))
                            .foregroundColor(premiumManager.debugOverride ? .green : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(premiumManager.debugOverride ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            )
                    }

                    HStack {
                        Label("Fonctionnalités", systemImage: "list.bullet")
                            .font(.caption)
                            .foregroundColor(.blue)

                        Spacer()

                        Text("\(premiumManager.features.count) disponibles")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.blue)
                    }

                    // ✅ BOUTON DE RESET
                    Button("Reset Complet") {
                        resetPremiumState()
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.red.opacity(0.1))
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )

                    // ✅ BOUTON DE GÉNÉRATION DE CARTES DE TEST
                    Button("Générer 30 cartes de test") {
                        generateTestCards()
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green.opacity(0.1))
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
            .onAppear {
                updatePremiumStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: .premiumStatusChanged)) { _ in
                print("🔔 Notification reçue: premiumStatusChanged")
                DispatchQueue.main.async {
                    updatePremiumStatus()
                }
            }
        #endif
    }

    private func togglePremiumForTesting() {
        print("🔧 Toggle Premium - État actuel: \(isPremium)")
        print("🔧 Debug Override actuel: \(premiumManager.debugOverride)")

        // ✅ ANIMATION DE FEEDBACK
        withAnimation(.easeInOut(duration: 0.2)) {
            isToggling = true
        }

        // ✅ HAPTIC FEEDBACK
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        if isPremium {
            premiumManager.disableDebugPremium()
            print("🔧 Désactivation du mode Premium")
        } else {
            premiumManager.enableDebugPremium()
            print("🔧 Activation du mode Premium")
        }

        // ✅ DÉLAI PLUS LONG POUR ÉVITER LA RÉACTIVATION AUTOMATIQUE
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.2)) {
                updatePremiumStatus()
                isToggling = false
            }
        }
    }

    private func resetPremiumState() {
        print("🔄 Reset complet du statut Premium")

        // ✅ HAPTIC FEEDBACK
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()

        withAnimation(.easeInOut(duration: 0.3)) {
            isToggling = true
        }

        // ✅ RESET COMPLET
        premiumManager.debugOverride = false
        premiumManager.deactivatePremium()

        // ✅ CLEAR USERDEFAULTS
        UserDefaults.standard.removeObject(forKey: "isPremium")
        UserDefaults.standard.synchronize()

        // ✅ CLEAR APP GROUP
        let appGroupDefaults = UserDefaults(suiteName: "group.com.Coefficient.PARALLAX2")
        appGroupDefaults?.removeObject(forKey: "isPremium")
        appGroupDefaults?.synchronize()

        print("🧹 Reset complet effectué - tous les paramètres premium supprimés")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                updatePremiumStatus()
                isToggling = false
            }
        }
    }

    private func updatePremiumStatus() {
        let newStatus = premiumManager.isPremium
        print("🔄 Mise à jour statut: \(isPremium) -> \(newStatus)")

        withAnimation(.easeInOut(duration: 0.2)) {
            isPremium = newStatus
        }
    }

    // ✅ NOUVELLE FONCTION : Génération de cartes de test avec différents statuts
    private func generateTestCards() {
        print("🎴 Génération de 30 cartes de test avec différents statuts")

        // ✅ HAPTIC FEEDBACK
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // ✅ CONTEXTE PERSISTENCE
        let context = PersistenceController.shared.container.viewContext

        // ✅ CRÉATION D'UN DECK DE TEST
        let testDeck = FlashcardDeck(context: context)
        testDeck.id = UUID()
        testDeck.name = "Deck de Test - \(Date().formatted(date: .abbreviated, time: .shortened))"
        testDeck.createdAt = Date()
        // testDeck.updatedAt = Date() // Supprimé car pas de propriété updatedAt

        // ✅ GÉNÉRATION DE 30 CARTES AVEC DIFFÉRENTS STATUTS
        let cardConfigs = [
            // 6 cartes nouvelles (jamais étudiées)
            (count: 6, type: "nouvelle", interval: 0.0, reviewCount: 0, correctCount: 0, daysOffset: 0),

            // 8 cartes à réviser (intervalle < 7 jours)
            (count: 8, type: "à réviser", interval: 3.0, reviewCount: 2, correctCount: 1, daysOffset: -1),

            // 8 cartes acquises (intervalle >= 7 jours mais < 21 jours)
            (count: 8, type: "acquise", interval: 12.0, reviewCount: 4, correctCount: 3, daysOffset: 5),

            // 6 cartes maîtrisées (intervalle >= 21 jours)
            (count: 6, type: "maîtrisée", interval: 30.0, reviewCount: 8, correctCount: 7, daysOffset: 15),

            // 2 cartes en retard (date dépassée)
            (count: 2, type: "en retard", interval: 5.0, reviewCount: 3, correctCount: 2, daysOffset: -5),
        ]

        var cardIndex = 1

        for config in cardConfigs {
            for _ in 1 ... config.count {
                let card = Flashcard(context: context)
                card.id = UUID()
                card.question = "Question \(cardIndex) (\(config.type))"
                card.answer = "Réponse \(cardIndex) - Carte \(config.type)"
                card.createdAt = Date()
                // card.updatedAt = Date() // Supprimé car pas de propriété updatedAt
                card.deck = testDeck

                // ✅ CONFIGURATION SRS
                card.interval = config.interval
                card.reviewCount = Int32(config.reviewCount)
                card.correctCount = Int16(config.correctCount)
                card.easeFactor = 2.3

                // ✅ DATE DE PROCHAINE RÉVISION
                let nextReviewDate = Calendar.current.date(byAdding: .day, value: config.daysOffset, to: Date())
                card.nextReviewDate = nextReviewDate

                cardIndex += 1
            }
        }

        // ✅ SAUVEGARDE
        do {
            try context.save()
            print("✅ 30 cartes de test créées avec succès dans le deck '\(testDeck.name ?? "Deck de Test")'")
            print("📊 Répartition : 6 nouvelles, 8 à réviser, 8 acquises, 6 maîtrisées, 2 en retard")

            // ✅ NOTIFICATION DE SUCCÈS
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

        } catch {
            print("❌ Erreur lors de la création des cartes de test: \(error.localizedDescription)")

            // ✅ NOTIFICATION D'ERREUR
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

#Preview {
    DebugPremiumButton()
}
