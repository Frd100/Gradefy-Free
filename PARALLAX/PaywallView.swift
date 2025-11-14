//
//  PaywallView.swift
//  PARALLAX
//
//  Created by  on 7/9/25.
//
import SwiftUI

// ✅ MODIFIÉ : PaywallView n'est plus nécessaire - Application entièrement gratuite
struct PaywallView: View {
    let featureManager: FeatureManager
    @State private var showingPremiumView = false

    var body: some View {
        // Plus de paywall - Application entièrement gratuite
        EmptyView()
    }
}

// MARK: - Preview

#Preview {
    PaywallView(featureManager: FeatureManager.shared)
        .padding()
}
