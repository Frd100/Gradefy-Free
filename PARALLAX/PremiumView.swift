//
//  PremiumView.swift
//  PARALLAX
//
//  Created by Farid on 6/29/25.
//

import SwiftUI

// MARK: - Premium View Sheet avec Navigation Bar Bas
struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSuccess = false
    @State private var animateGlare = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationView {
            ZStack {
                // ✅ FOND adaptatif selon le thème
                (colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        GeometryReader { geometry in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self,
                                          value: geometry.frame(in: .named("scroll")).minY)
                        }
                        .frame(height: 0)
                        
                        VStack(spacing: 0) {
                            heroSection
                            pricingSection
                            featuresSection
                            
                            Spacer().frame(height: 100)
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .scrollIndicators(.hidden)
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                    }
                    
                    nativeBottomBar
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ✅ SUPPRESSION du titre inline
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            animateGlare = true
        }
        .sheet(isPresented: $showSuccess) {
            successView
        }
    }
    
    // ✅ HERO SECTION sans effet shiny - VERSION CORRIGÉE
    private var heroSection: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)
            
            // ✅ PHRASE SIMPLE sans parenthèse en trop
            (Text("Libérez tout votre potentiel avec ")
                .font(.title.weight(.bold))
                .foregroundColor(colorScheme == .dark ? .white : .black) +
            Text("Gradefy Pro")
                .font(.title.weight(.bold))
                .foregroundColor(.blue))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            
            // ✅ SOUS-TITRE adaptatif
            VStack(spacing: 12) {
                Text("Allez au-delà des limites et débloquez des dizaines de fonctions exclusives en vous abonnant à Gradefy Pro.")
                    .font(.footnote)
                    .foregroundColor(colorScheme == .dark ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
            }
            
            Spacer().frame(height: 20)
        }
    }

    private var nativeBottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(height: 0.5)
            
            HStack {
                Button(action: {
                    HapticFeedbackManager.shared.notification(type: .success)
                    showSuccess = true
                }) {
                    Text("S'abonner pour 5,99 € / mois")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            ZStack {
                                Color.blue
                                
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.cyan.opacity(0.2),
                                                Color.cyan.opacity(0.4),
                                                Color.cyan.opacity(0.6),
                                                Color.cyan.opacity(0.4),
                                                Color.cyan.opacity(0.2)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 200)
                                    .blur(radius: 10)
                                    .offset(x: animateGlare ? 2500 : -500)
                                    .blendMode(.screen)
                                    .animation(
                                        Animation.linear(duration: 3)
                                            .repeatForever(autoreverses: false),
                                        value: animateGlare
                                    )
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                colorScheme == .dark
                ? Color(.systemBackground)
                : Color(.systemBackground)
            )
        }
    }
    
    // MARK: - Section Prix adaptative
    private var pricingSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white : Color.blue)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                }
                
                Text("Mensuel")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
                
                Text("5,99 €/mois")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.secondary) // ✅ Couleur secondaire
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color.white)
                    )
            .padding(.horizontal, 20)
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CE QUI EST INCLUS")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 6)
            
            VStack(spacing: 0) {
                featureRow(
                    icon: "rectangle.portrait.on.rectangle.portrait.angled.fill",
                    iconColor: .orange,
                    title: "Cartes et liste illimitées",
                    subtitle: "Créez autant de cartes que vous voulez, organisez vos révisions sans limites."
                )
                
                // ✅ DIVIDER CORRIGÉ
                Divider()
                    .background(Color(UIColor.separator))
                    .padding(.leading, 65)

                featureRow(
                    icon: "icloud.fill",
                    iconColor: .blue,
                    title: "Sauvegarde iCloud",
                    subtitle: "Vos données synchronisées automatiquement sur tous vos appareils Apple."
                )
                
                Divider()
                    .background(Color(UIColor.separator))
                    .padding(.leading, 65)

                featureRow(
                    icon: "calendar",
                    iconColor: .green,
                    title: "Intégration Calendrier",
                    subtitle: "Vos échéances et révisions directement dans votre calendrier."
                )
                
                Divider()
                    .background(Color(UIColor.separator))
                    .padding(.leading, 65)

                featureRow(
                    icon: "app.badge.fill",
                    iconColor: .purple,
                    title: "Widgets Avancés",
                    subtitle: "Suivez vos statistiques directement depuis l'écran d'accueil."
                )
                
                Divider()
                    .background(Color(UIColor.separator))
                    .padding(.leading, 65)
                
                featureRow(
                    icon: "doc.fill",
                    iconColor: .red,
                    title: "Export PDF",
                    subtitle: "Exportez vos révisions en PDF professionnel pour impression ou partage."
                )
                
                Divider()
                    .background(Color(UIColor.separator))
                    .padding(.leading, 65)
                
                featureRow(
                    icon: "paintbrush.fill",
                    iconColor: .pink,
                    title: "Icônes Personnalisées",
                    subtitle: "Personnalisez l'apparence de Gradefy avec des icônes exclusives."
                )
            }
            .background(
                // ✅ BACKGROUND CORRIGÉ
                colorScheme == .dark
                ? Color(.systemGray5)  // Plus sombre pour le contraste
                : Color(.systemBackground)
            )
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    
    private func featureRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(iconColor)
                    .frame(width: 30, height: 30)
                
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
            }
            .offset(y: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.regular))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? .secondary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private var successView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(colorScheme == .dark ? 0.2 : 0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 16) {
                Text("Bienvenue dans Gradefy PRO !")
                    .font(.title.bold())
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text("Votre abonnement pro a été activé avec succès. Découvrez toutes les fonctionnalités exclusives.")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .secondary : .secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button("Commencer") {
                HapticFeedbackManager.shared.impact(style: .medium)
                showSuccess = false
                dismiss()
            }
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(
            colorScheme == .dark
            ? Color(.systemBackground)
            : Color.white
        )
    }
}

// ✅ PREFERENCE KEY pour tracker le scroll
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    PremiumView()
}
