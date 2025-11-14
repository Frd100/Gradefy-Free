//
//  File.swift
//  PARALLAX
//
//  Created by  on 7/21/25.
//
import Foundation
import SwiftUI
import CoreData


// Extensions utilitaires
extension Double {
    /// Arrondi à *places* chiffres après la virgule
    func rounded(toPlaces places: Int) -> Double {
        let factor = Foundation.pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

/// Formatage des nombres avec locale
func formatNumber(_ value: Double, places: Int) -> String {
    let nf = NumberFormatter()
    nf.minimumFractionDigits = 0
    nf.maximumFractionDigits = places
    nf.numberStyle = .decimal
    nf.locale = Locale.current
    return nf.string(for: value) ?? String(value)
}

/// Parsing unifié des entrées décimales avec conversion virgule → point
func parseDecimalInput(_ input: String) -> Double? {
    Double(input.replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines))
}

/// Type de clavier adaptatif selon le système
func keyboardType(for system: GradingSystemPlugin) -> UIKeyboardType {
    system.usesLetterGrades ? .default : .decimalPad
}

func calculateFraction(grade: Double, system: GradingSystemPlugin) -> Double {
    guard grade != NO_GRADE && system.validate(grade) else { return 0 }
    
    if system.isInverted {
        let normalizedGrade = max(system.min, min(grade, system.max))
        return (system.max - normalizedGrade) / (system.max - system.min)
    } else {
        let normalizedGrade = max(system.min, min(grade, system.max))
        return (normalizedGrade - system.min) / (system.max - system.min)
    }
}

func upToTwoDecimals(_ value: Double) -> String {
    formatNumber(value, places: 2)
}

func formatCoefficientClean(_ value: Double) -> String {
    formatNumber(value, places: 2)
}

func formatGradeClean(_ value: Double, system: GradingSystemPlugin) -> String {
    guard value != NO_GRADE else { return "—" }
    return formatNumber(value, places: system.decimalPlaces) + system.suffix
}
