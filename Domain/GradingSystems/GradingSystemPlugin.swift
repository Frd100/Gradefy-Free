//
//  GradingSystemPlugin.swift
//  PARALLAX
//
//  Created by  on 7/21/25.
//

import Foundation
import SwiftUI
import CoreData

// Protocole principal
protocol GradingSystemPlugin {
    var id: String { get }
    var label: String { get }
    var description: String { get }
    var min: Double { get }
    var max: Double { get }
    var suffix: String { get }
    var coefLabel: String { get }
    var placeholder: String { get }
    var passingGrade: Double { get }
    var averageLabel: String { get }
    var gradeUnit: String { get }
    var systemName: String { get }
    var decimalPlaces: Int { get }
    var usesLetterGrades: Bool { get }
    var isInverted: Bool { get }
    
    func format(_ grade: Double) -> String
    func weightedAverage(_ evaluations: [DummyEvaluation]) -> Double
    func validate(_ grade: Double) -> Bool
    func validateCoefficient(_ coeff: Double) -> Bool
    func parse(_ input: String) -> Double?
    func gradeColor(for grade: Double) -> Color
    func validationErrorMessage(for input: String) -> String
    func coefficientErrorMessage(for input: String) -> String
    func displayGrade(_ grade: Double, compact: Bool) -> String
}

// Extensions du protocole
extension GradingSystemPlugin {
    /// Comparaison intelligente selon le système (gère l'inversion)
    func isGradeBetter(_ grade1: Double, than grade2: Double) -> Bool {
        guard grade1 != NO_GRADE && grade2 != NO_GRADE else { return false }
        guard validate(grade1) && validate(grade2) else { return false }
        
        if self.isInverted {
            return grade1 < grade2 // Plus petit = meilleur (Allemagne)
        } else {
            return grade1 > grade2 // Plus grand = meilleur (France, USA, etc.)
        }
    }
    
    /// Tri intelligent des matières par performance
    func sortSubjectsByPerformance(_ subjects: [Subject]) -> [Subject] {
        let validSubjects = subjects.filter { $0.grade != NO_GRADE && validate($0.grade) }
        let invalidSubjects = subjects.filter { $0.grade == NO_GRADE || !validate($0.grade) }
        
        let sortedValid = validSubjects.sorted { subject1, subject2 in
            isGradeBetter(subject1.grade, than: subject2.grade)
        }
        
        return sortedValid + invalidSubjects
    }
    
    /// Pourcentage de performance unifié pour les anneaux
    func performancePercentage(for grade: Double) -> Double {
        guard grade != NO_GRADE && validate(grade) else { return 0 }
        
        let normalizedGrade = Swift.max(self.min, Swift.min(grade, self.max))
        
        if isInverted {
            return (self.max - normalizedGrade) / (self.max - self.min)
        } else {
            return (normalizedGrade - self.min) / (self.max - self.min)
        }
    }

    func findBestGrade(in grades: [Double]) -> Double {
        let validGrades = grades.filter { validate($0) }
        guard !validGrades.isEmpty else { return NO_GRADE }
        
        if isInverted {
            return validGrades.min() ?? NO_GRADE // Plus petit = meilleur
        } else {
            return validGrades.max() ?? NO_GRADE // Plus grand = meilleur
        }
    }
}

