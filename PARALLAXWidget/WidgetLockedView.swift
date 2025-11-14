//
//  WidgetLockedView.swift
//  PARALLAX
//
//  Mise à jour iOS 17+
//

import SwiftUI

struct WidgetLockedView: View {
    let widgetTitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.blue)
            
            Text("Gradefy Pro")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
        }
        .padding()
        .containerBackground(.thinMaterial, for: .widget)
        .widgetURL(URL(string: "parallax://premium"))
    }
}

struct WidgetLockedAccessoryView: View {
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "lock.fill")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.blue)
            
            Text("Pro")
                .font(.system(size: 6, weight: .medium))
                .foregroundColor(.secondary)
        }
        .containerBackground(.clear, for: .widget)  // ✅ CORRECTION
    }
}
