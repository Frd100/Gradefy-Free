//
//  PaywallView.swift
//  PARALLAX
//
//  Created by  on 7/9/25.
//
import SwiftUI

struct PaywallView: View {
    let premiumManager: PremiumManager
    @State private var showingPremiumView = false
    
    var body: some View {
        if !premiumManager.isPremium {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "premium_unlimited_cards_title"))
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text(String(localized: "premium_create_50_plus"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Découvrir") {
                    showingPremiumView = true
                }
                .font(.caption.bold())
                .foregroundColor(.blue)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
            )
            .sheet(isPresented: $showingPremiumView) {
                // ✅ CORRECTION : Utiliser le bon nom de feature
                PremiumView(highlightedFeature: .unlimitedFlashcardsPerDeck)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    PaywallView(premiumManager: PremiumManager.shared)
        .padding()
}
