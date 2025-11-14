//
//  RevisionModeSelectionView.swift
//  PARALLAX
//
//  Created by  on 7/21/25.
//
import CoreData
import Foundation
import SwiftUI
import UIKit

struct RevisionModeSelectionView: View {
    let deck: FlashcardDeck
    @Binding var showRevisionSession: Bool
    @Binding var showQuizSession: Bool
    @Binding var showAssociationSession: Bool // ✅ RETOUR À showAssociationSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var flashcardCount: Int {
        (deck.flashcards as? Set<Flashcard>)?.count ?? 0
    }

    // ✅ NOUVEAU : Compter uniquement les cartes disponibles (non révisées aujourd'hui)
    private var availableFlashcardCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return (deck.flashcards as? Set<Flashcard>)?.filter { card in
            card.lastReviewDate == nil || card.lastReviewDate! < today
        }.count ?? 0
    }

    private var canStartQuiz: Bool {
        availableFlashcardCount >= 4
    }

    private var canStartAssociation: Bool {
        availableFlashcardCount >= 3
    }

    var body: some View {
        VStack(spacing: 24) {
            // ✅ Bouton X en haut à droite
            HStack {
                Spacer()
                Button {
                    HapticFeedbackManager.shared.impact(style: .light)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 18)

            VStack(spacing: 16) {
                // ✅ FLASHCARDS BUTTON
                RevisionModeButton(
                    icon: "rectangle.on.rectangle.angled.fill",
                    title: String(localized: "flashcard_mode_title"),
                    description: String(localized: "flashcard_mode_description"),
                    color: .blue,
                    isEnabled: true,
                    showChevron: true
                ) {
                    HapticFeedbackManager.shared.impact(style: .light)
                    dismiss()
                    showRevisionSession = true
                }

                // ✅ QUIZ BUTTON
                RevisionModeButton(
                    icon: "questionmark.app.fill",
                    title: String(localized: "quiz_mode_title"),
                    description: canStartQuiz ? String(localized: "quiz_mode_description") : String(localized: "quiz_minimum_required"),
                    color: canStartQuiz ? .orange : .gray,
                    isEnabled: canStartQuiz,
                    showChevron: canStartQuiz,
                    rightContent: {
                        if !canStartQuiz {
                            Text("\(availableFlashcardCount)/4")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.orange.opacity(0.2)))
                        }
                    }
                ) {
                    if canStartQuiz {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                        showQuizSession = true
                    } else {
                        HapticFeedbackManager.shared.notification(type: .warning)
                    }
                }

                // ✅ BOUTON ASSOCIATION SIMPLIFIÉ
                RevisionModeButton(
                    icon: "arrow.triangle.2.circlepath",
                    title: String(localized: "association_mode_title"),
                    description: canStartAssociation ? String(localized: "association_mode_description") : String(localized: "association_minimum_required"),
                    color: canStartAssociation ? .purple : .gray,
                    isEnabled: canStartAssociation,
                    showChevron: canStartAssociation,
                    rightContent: {
                        if !canStartAssociation {
                            Text("\(availableFlashcardCount)/3")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.purple.opacity(0.2)))
                        }
                    }
                ) {
                    if canStartAssociation {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                        showAssociationSession = true
                    } else {
                        HapticFeedbackManager.shared.notification(type: .warning)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .presentationDetents([.fraction(0.50)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(25)
    }
}

struct RevisionModeButton<RightContent: View>: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let isEnabled: Bool
    let showChevron: Bool
    let rightContent: () -> RightContent
    let action: () -> Void

    init(
        icon: String,
        title: String,
        description: String,
        color: Color,
        isEnabled: Bool,
        showChevron: Bool,
        @ViewBuilder rightContent: @escaping () -> RightContent = { EmptyView() },
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.color = color
        self.isEnabled = isEnabled
        self.showChevron = showChevron
        self.rightContent = rightContent
        self.action = action
    }

    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isEnabled ? .primary : .secondary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Group {
                    if showChevron {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        rightContent()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(borderColor, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 30))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.7)
    }

    private var backgroundColor: Color {
        Color(.secondarySystemGroupedBackground)
    }

    private var borderColor: Color {
        Color(.separator).opacity(0.3)
    }
}

// MARK: - Flashcard Row View (au niveau du fichier)

struct InstantFocusTextFieldforedit: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onReturn: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = ""
        textField.delegate = context.coordinator

        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = UIFont.systemFont(ofSize: 18)
        textField.textAlignment = .center
        textField.returnKeyType = .done

        textField.adjustsFontSizeToFitWidth = false
        textField.clipsToBounds = true
        textField.contentHorizontalAlignment = .center
        // ✅ SOLUTION PARFAITE : Configuration Auto Layout robuste
        textField.translatesAutoresizingMaskIntoConstraints = false

        // Délai pour éviter les conflits de contraintes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textField.becomeFirstResponder()
        }

        return textField
    }

    func updateUIView(_ uiView: UITextField, context _: Context) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: InstantFocusTextFieldforedit // ✅ CORRIGÉ ICI

        init(_ parent: InstantFocusTextFieldforedit) { // ✅ ET ICI
            self.parent = parent
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let newText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? string

            DispatchQueue.main.async {
                self.parent.text = newText // ✅ SOLUTION
            }

            return true
        }

        func textFieldShouldReturn(_: UITextField) -> Bool {
            parent.onReturn()
            return true
        }
    }
}

struct InstantFocusTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onReturn: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = ""
        textField.delegate = context.coordinator

        // ✅ Configuration pour texte plus grand
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = UIFont.systemFont(ofSize: 18)
        textField.textAlignment = .center
        textField.returnKeyType = .done

        // ✅ Propriétés pour contrôler la taille et le défilement
        textField.adjustsFontSizeToFitWidth = false
        textField.clipsToBounds = true
        textField.contentHorizontalAlignment = .center

        // ✅ SOLUTION PARFAITE : Configuration Auto Layout robuste
        textField.translatesAutoresizingMaskIntoConstraints = false

        // Délai pour éviter les conflits de contraintes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textField.becomeFirstResponder()
        }

        return textField
    }

    func updateUIView(_ uiView: UITextField, context _: Context) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: InstantFocusTextField

        init(_ parent: InstantFocusTextField) {
            self.parent = parent
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let newText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? string

            // ✅ SOLUTION : Différer la modification d'état
            DispatchQueue.main.async {
                self.parent.text = newText
            }

            return true
        }

        func textFieldShouldReturn(_: UITextField) -> Bool {
            parent.onReturn()
            return true
        }
    }
}
