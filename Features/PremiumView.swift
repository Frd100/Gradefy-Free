//
//  PremiumView.swift
//  PARALLAX
//
//  Created by  on 7/9/25.
//

import StoreKit
import SwiftUI

struct PremiumView: View {
    @StateObject private var storeKit = StoreKitHelper.shared
    @State private var premiumManager = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedPlan: String = ProductIDs.yearly
    @State private var selectedDetent: PresentationDetent = .fraction(0.55)

    @State private var isProcessing = false
    @State private var selectedProduct: Product?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var scrollOffset: CGFloat = 0
    @State private var animateGlare = false
    @State private var animate = false

    // ✅ MODIFIÉ : Navigation interne au lieu de sheets
    @State private var navigationPath = NavigationPath()

    let highlightedFeature: PremiumFeature?

    init(highlightedFeature: PremiumFeature? = nil) {
        self.highlightedFeature = highlightedFeature
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                (colorScheme == .dark ? Color(.systemBackground) : Color(.systemGray6))
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "premium_close")) {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "terms":
                    TermsOfServiceSimpleView()
                case "privacy":
                    PrivacyPolicySimpleView()
                default:
                    EmptyView()
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            startGlareAnimation()

            Task {
                await loadInitialData()
            }
        }
        .onDisappear {
            animateGlare = false
        }
        .sheet(isPresented: $showSuccess) {
            successView
                .presentationDetents([.fraction(0.55)], selection: $selectedDetent)
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(55)
                .presentationCompactAdaptation(.sheet)
                .presentationBackground(.regularMaterial)
                .onAppear {
                    selectedDetent = .fraction(0.55)
                }
        }
        .alert(String(localized: "premium_error"), isPresented: $showingError) {
            Button(String(localized: "premium_ok")) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func restorePurchases() async {
        guard !isProcessing else { return }
        isProcessing = true

        do {
            try await storeKit.restorePurchases()

            // Vérifier si des achats ont été restaurés
            if premiumManager.isPremium {
                HapticFeedbackManager.shared.notification(type: .success)
                showSuccess = true
            } else {
                showError(String(localized: "premium_error_no_restore"))
            }

        } catch StoreKitHelper.StoreKitHelperError.noActiveAccount {
            showError(String(localized: "premium_error_no_account"))
        } catch {
            showError(String(localized: "premium_error_restore_failed").replacingOccurrences(of: "%@", with: error.localizedDescription))
        }

        isProcessing = false
    }

    // MARK: - Legal Links

    private func openTermsOfService() {
        navigationPath.append("terms")
    }

    private func openPrivacyPolicy() {
        navigationPath.append("privacy")
    }

    private var heroSection: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            Text("Gradefy Pro")
                .font(.system(size: 40, weight: .bold, design: .default))
                .foregroundColor(.blue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                Text(String(localized: "premium_hero_subtitle"))
                    .font(.footnote)
                    .foregroundColor(colorScheme == .dark ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
            }

            Spacer().frame(height: 20)
        }
    }

    // MARK: - Native Bottom Bar

    private var nativeBottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(height: 0.5)

            VStack(spacing: 12) {
                // ✅ Bouton principal d'abonnement (existant)
                Button(action: {
                    guard !isProcessing else { return }
                    if let product = storeKit.products.first(where: { $0.id == selectedPlan }) {
                        Task {
                            await purchaseProduct(product)
                        }
                    } else {
                        // Si les produits ne sont pas chargés, on montre une erreur appropriée
                        showError(String(localized: "price_unavailable"))
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }

                        Text(selectedPlan == ProductIDs.yearly ?
                            String(localized: "premium_subscribe_yearly").replacingOccurrences(of: "%@", with: yearlyDisplayPrice) :
                            String(localized: "premium_subscribe_monthly").replacingOccurrences(of: "%@", with: monthlyDisplayPrice))
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue.opacity(0.9),
                                            Color.blue.opacity(0.7),
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.0),
                                            Color.white.opacity(0.0),
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.0),
                                            Color.white.opacity(0.0),
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 370)
                                .blur(radius: 1)
                                .offset(x: animateGlare ? 400 : -1300)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    )
                }
                .disabled(isProcessing)

                Button(String(localized: "premium_restore_purchases")) {
                    Task {
                        await restorePurchases()
                    }
                }
                .font(.footnote)
                .foregroundColor(.blue)
                .disabled(isProcessing)

                // Liens légaux
                HStack(spacing: 16) {
                    Button(String(localized: "premium_terms")) {
                        openTermsOfService()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(String(localized: "premium_privacy")) {
                        openPrivacyPolicy()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }

    // MARK: - Pricing Section

    // MARK: - Pricing Section (SIMPLIFIÉ)

    private var pricingSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                // Plan Annuel
                Button(action: {
                    selectedPlan = ProductIDs.yearly
                    HapticFeedbackManager.shared.impact(style: .light)
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(selectedPlan == ProductIDs.yearly ? Color.blue : Color.clear)
                                .frame(width: 24, height: 24)
                            Circle()
                                .stroke(selectedPlan == ProductIDs.yearly ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            if selectedPlan == ProductIDs.yearly {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "premium_plan_yearly"))
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }

                        Spacer()

                        Text(yearlyDisplayPrice)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())

                Divider()
                    .background(Color(UIColor.separator))
                    .padding(.leading, 60)

                // Plan Mensuel
                Button(action: {
                    selectedPlan = ProductIDs.monthly
                    HapticFeedbackManager.shared.impact(style: .light)
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(selectedPlan == ProductIDs.monthly ? Color.blue : Color.clear)
                                .frame(width: 24, height: 24)
                            Circle()
                                .stroke(selectedPlan == ProductIDs.monthly ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            if selectedPlan == ProductIDs.monthly {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        Text(String(localized: "premium_plan_monthly"))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white : .black)

                        Spacer()

                        Text(monthlyDisplayPrice)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground))
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "premium_features_title"))
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                featureRow(
                    icon: "rectangle.stack.fill",
                    iconColor: .orange,
                    title: String(localized: "premium_feature_unlimited_title"),
                    subtitle: String(localized: "premium_feature_unlimited_subtitle")
                )

                Divider()
                    .background(Color(UIColor.separator))
                    .padding(.leading, 65)

                featureRow(
                    icon: "app.badge.fill",
                    iconColor: .purple,
                    title: String(localized: "premium_feature_widgets_title"),
                    subtitle: String(localized: "premium_feature_widgets_subtitle")
                )

                Divider()
                    .background(Color(UIColor.separator))
                    .padding(.leading, 65)

                featureRow(
                    icon: "icloud.and.arrow.up.fill",
                    iconColor: .green,
                    title: String(localized: "premium_feature_backup_title"),
                    subtitle: String(localized: "premium_feature_backup_subtitle")
                )

                Divider()
                    .background(Color(UIColor.separator))
                    .padding(.leading, 65)

                featureRow(
                    icon: "paintbrush.fill",
                    iconColor: .pink,
                    title: String(localized: "premium_feature_icons_title"),
                    subtitle: String(localized: "premium_feature_icons_subtitle")
                )
            }
            .background(
                colorScheme == .dark
                    ? Color(.systemGray5)
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
            AdaptiveLottieView(
                animationName: "confetti",
                isAnimated: true
            )
            .frame(width: 130, height: 130)
            .padding(.top, 8)

            VStack(spacing: 16) {
                Text(String(localized: "premium_success_title"))
                    .font(.title.bold())
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                Text(String(localized: "premium_success_subtitle"))
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .secondary : .secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Button(String(localized: "premium_success_button")) {
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
            .padding(.horizontal, 25)
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(
                    colorScheme == .dark
                        ? Color(.systemBackground)
                        : Color.white
                )
                .ignoresSafeArea()
        )
    }

    private var yearlyProduct: Product? {
        storeKit.products.first { $0.id == ProductIDs.yearly }
    }

    private var monthlyProduct: Product? {
        storeKit.products.first { $0.id == ProductIDs.monthly }
    }

    private var yearlyDisplayPrice: String {
        yearlyProduct?.displayPrice ?? String(localized: "price_loading")
    }

    private var monthlyDisplayPrice: String {
        monthlyProduct?.displayPrice ?? String(localized: "price_loading")
    }

    // MARK: - Methods

    private func startGlareAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                animateGlare = true
            }
        }
    }

    private func loadInitialData() async {
        do {
            try await storeKit.loadProducts()
        } catch {
            showError(String(localized: "premium_error_load_products").replacingOccurrences(of: "%@", with: error.localizedDescription))
        }
    }

    private func purchaseProduct(_ product: Product) async {
        guard !isProcessing else { return }

        isProcessing = true

        do {
            let transaction = try await storeKit.purchase(product)
            if transaction != nil {
                HapticFeedbackManager.shared.impact(style: .heavy)
                showSuccess = true
            }
        } catch StoreKitError.paymentPending {
            showError(String(localized: "premium_error_payment_pending"))
        } catch {
            let nsError = error as NSError

            if nsError.domain == SKErrorDomain {
                switch SKError.Code(rawValue: nsError.code) {
                case .paymentCancelled:
                    // Ne pas afficher d'erreur pour une annulation utilisateur
                    break
                case .cloudServiceNetworkConnectionFailed:
                    showError(String(localized: "premium_error_connection"))
                default:
                    showError(String(localized: "premium_error_purchase").replacingOccurrences(of: "%@", with: nsError.localizedDescription))
                }
            } else {
                showError(String(localized: "premium_error_purchase").replacingOccurrences(of: "%@", with: nsError.localizedDescription))
            }
        }

        isProcessing = false
    }

    @MainActor
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true

        HapticFeedbackManager.shared.notification(type: .error)
    }
}

// ✅ NOUVELLES VUES : Sans NavigationView pour éviter les conflits
struct TermsOfServiceSimpleView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "terms_title"))
                        .font(.title.bold())

                    Text(String(localized: "terms_last_updated"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "terms_intro"))
                        .font(.body)
                        .padding(.bottom, 8)

                    Text(String(localized: "terms_subscription_title"))
                        .font(.headline)

                    Text(String(localized: "terms_subscription_text"))
                        .font(.body)

                    Text(String(localized: "terms_usage_title"))
                        .font(.headline)
                        .padding(.top, 8)

                    Text(String(localized: "terms_usage_text"))
                        .font(.body)

                    Text(String(localized: "terms_modifications_title"))
                        .font(.headline)
                        .padding(.top, 8)

                    Text(String(localized: "terms_modifications_text"))
                        .font(.body)

                    Text(String(localized: "terms_contact_title"))
                        .font(.headline)
                        .padding(.top, 8)

                    Text(String(localized: "terms_contact_text"))
                        .font(.body)

                    Text(String(localized: "terms_effective_date"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 16)
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: "terms_nav_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicySimpleView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "privacy_title"))
                        .font(.title.bold())

                    Text(String(localized: "terms_last_updated")) // Réutilise la même date
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "privacy_intro"))
                        .font(.body)
                        .padding(.bottom, 8)

                    Text(String(localized: "privacy_data_collection_title"))
                        .font(.headline)

                    Text(String(localized: "privacy_data_collection_text"))
                        .font(.body)

                    Text(String(localized: "privacy_storage_title"))
                        .font(.headline)
                        .padding(.top, 8)

                    Text(String(localized: "privacy_storage_text"))
                        .font(.body)

                    Text(String(localized: "privacy_rights_title"))
                        .font(.headline)
                        .padding(.top, 8)

                    Text(String(localized: "privacy_rights_text"))
                        .font(.body)

                    Text(String(localized: "terms_contact_title")) // Réutilise
                        .font(.headline)
                        .padding(.top, 8)

                    Text(String(localized: "privacy_contact_text"))
                        .font(.body)

                    Text(String(localized: "privacy_effective_date"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 16)
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: "privacy_nav_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ScrollOffsetPreferenceKey

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview {
    PremiumView()
}
