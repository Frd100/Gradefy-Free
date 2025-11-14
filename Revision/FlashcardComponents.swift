//
//  ProgressBar.swift
//  PARALLAX
//
//  Created by  on 7/21/25.
//


import SwiftUI
import UIKit
import Foundation
import CoreData

// MARK: - Progress Bar Component

struct ProgressBar: View {
    let progress: Double
    let height: CGFloat = 10
    
    private var progressWidth: CGFloat {
        return min(CGFloat(progress), 1.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: height)
                    .cornerRadius(height / 2)
                
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: progressWidth * geometry.size.width, height: height)
                    .cornerRadius(height / 2)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Stat Column Component

struct StatColumn: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                Capsule()
                    .fill(Color.accentColor)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
    }
}

