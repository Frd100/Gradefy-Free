//
//  SubjectsAndGrading.swift
//  PARALLAX
//
//  Created by Farid on 6/28/25.
//

import Foundation
import SwiftUI
import CoreData

// MARK: - Constants and Utilities

let NO_GRADE: Double = -999.0

enum GradeColor {
    static let excellent = Color.green
    static let good = Color.blue
    static let average = Color.orange
    static let failure = Color.red
    static let noGrade = Color.secondary
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
    let formatter = NumberFormatter()
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    formatter.numberStyle = .decimal
    formatter.locale = Locale.current
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
}

func formatCoefficientClean(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    formatter.numberStyle = .decimal
    formatter.locale = Locale.current
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
}

func formatGradeClean(_ value: Double, system: GradingSystemPlugin) -> String {
    guard value != NO_GRADE else { return "—" }
    
    let formatter = NumberFormatter()
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = system.decimalPlaces
    formatter.numberStyle = .decimal
    formatter.locale = Locale.current
    
    let baseNumber = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    return baseNumber + system.suffix
}

// MARK: - Extensions

extension Subject {
    func recalculateAverageOptimized(context: NSManagedObjectContext, autoSave: Bool = false) {
        print("🔍 === DÉBUT recalculateAverageOptimized pour: \(self.name ?? "Sujet inconnu") ===")
        
        let system = GradingSystemRegistry.active
        let request: NSFetchRequest<Evaluation> = Evaluation.fetchRequest()
        
        // ✅ NOUVELLE LOGIQUE : Toutes les évaluations avec notes comptent
        request.predicate = NSPredicate(
            format: "subject == %@ AND grade != %f",
            self,
            NO_GRADE
        )
        request.sortDescriptors = []
        
        do {
            let evaluations = try context.fetch(request)
            print("🔍 Nombre d'évaluations trouvées: \(evaluations.count)")
            
            // Debug détaillé de chaque évaluation
            let allEvaluations = (self.evaluations as? Set<Evaluation>) ?? []
            print("🔍 Toutes les évaluations de ce sujet: \(allEvaluations.count)")
            
            for eval in allEvaluations {
                let dateStr = eval.date != nil ? "\(eval.date!)" : "nil"
                let gradeStr = eval.grade == NO_GRADE ? "NO_GRADE" : "\(eval.grade)"
                let isValidGrade = eval.grade != NO_GRADE
                
                print("🔍 Éval: '\(eval.title ?? "Sans titre")'")
                print("    📅 Date: \(dateStr)")
                print("    📊 Note: \(gradeStr) (valide: \(isValidGrade))")
                print("    ✅ Incluse: \(isValidGrade)")  // ✅ Seule la note compte maintenant
                print("    ---")
            }
            
            let ancienneMoyenne = self.grade
            
            if evaluations.isEmpty {
                self.grade = NO_GRADE
                print("🔍 Aucune évaluation avec note → Moyenne: NO_GRADE")
            } else {
                let dummyEvals = evaluations.map { DummyEvaluation(grade: $0.grade, coefficient: $0.coefficient) }
                self.grade = system.weightedAverage(dummyEvals)
                print("🔍 Nouvelle moyenne calculée: \(system.format(self.grade))")
            }
            
            print("🔍 Moyenne AVANT: \(ancienneMoyenne == NO_GRADE ? "NO_GRADE" : system.format(ancienneMoyenne))")
            print("🔍 Moyenne APRÈS: \(self.grade == NO_GRADE ? "NO_GRADE" : system.format(self.grade))")
            
            if autoSave {
                try context.save()
                print("🔍 Context sauvegardé avec succès")
            }
            
        } catch {
            print("❌ Erreur calcul moyenne optimisé: \(error)")
            self.grade = NO_GRADE
            
            if autoSave {
                do {
                    try context.save()
                    print("🔍 Context sauvegardé après erreur")
                } catch {
                    print("❌ Erreur save après erreur calcul: \(error)")
                }
            }
        }
        
        print("🔍 === FIN recalculateAverageOptimized ===\n")
    }
}


// MARK: - Data Models

struct DummyEvaluation {
    let grade: Double
    let coefficient: Double
}

struct SubjectData: Hashable {
    let code: String
    let name: String
    let grade: Double
    let coefficient: Double
    let periodName: String
}

struct EvaluationData: Identifiable {
    let id: String
    let title: String
    let date: String
    let grade: Double
    let coefficient: Double
}

enum SortOption: String, CaseIterable {
    case alphabetical = "Alphabétique"
    case grade = "Note"
}

struct GradingSystemDisplayItem: Identifiable {
    let id: String
    let displayName: String
    let description: String
    let flag: String
    
    var supportedSortOptions: [SortOption] {
        return [.alphabetical, .grade]
    }
}

// MARK: - Grading System Protocol

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
    var gradeInputHelp: String { get }
    var coefficientHelp: String { get }
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
    func appreciation(for grade: Double) -> String
    func gradeColor(for grade: Double) -> Color
    func validationErrorMessage(for input: String) -> String
    func coefficientErrorMessage(for input: String) -> String
    func displayGrade(_ grade: Double, compact: Bool) -> String
}

// MARK: - Grading Systems Implementation

struct FrenchSystem: GradingSystemPlugin {
    let id = "french"
    let label = "France (/20)"
    let description = "Système français traditionnel de 0 à 20"
    let min: Double = 0
    let max: Double = 20
    let suffix = "/20"
    let coefLabel = "Coefficient"
    let placeholder = "ex: 15.5"
    let passingGrade: Double = 10
    let gradeInputHelp = "Saisissez une note entre 0 et 20"
    let coefficientHelp = "Coefficient de pondération (généralement 1-5)"
    let averageLabel = "Moyenne générale"
    let gradeUnit = "/20"
    let systemName = "Notation française"
    let decimalPlaces = 2
    let usesLetterGrades = false
    let isInverted = false
    
    func format(_ grade: Double) -> String {
        guard grade != NO_GRADE else { return "—" }
        
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        
        let number = formatter.string(from: NSNumber(value: grade)) ?? String(format: "%.2f", grade)
        return "\(number)/20"
    }
    
    func weightedAverage(_ evaluations: [DummyEvaluation]) -> Double {
        let validEvaluations = evaluations.filter { $0.grade != NO_GRADE }
        guard !validEvaluations.isEmpty else { return NO_GRADE }
        
        let totalWeightedGrades = validEvaluations.reduce(0.0) { $0 + ($1.grade * $1.coefficient) }
        let totalCoefficients = validEvaluations.reduce(0.0) { $0 + $1.coefficient }
        
        guard totalCoefficients > 0 else { return NO_GRADE }
        return totalWeightedGrades / totalCoefficients
    }
    
    func validate(_ grade: Double) -> Bool {
        return grade >= min && grade <= max
    }
    
    func validateCoefficient(_ coeff: Double) -> Bool {
        return coeff >= 0.5 && coeff <= 10.0
    }
    
    func parse(_ input: String) -> Double? {
        let cleaned = input.replacingOccurrences(of: "/20", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let value = Double(cleaned) else { return nil }
        return validate(value) ? value : nil
    }
    
    func appreciation(for grade: Double) -> String {
        guard grade != NO_GRADE else { return "Pas de note" }
        
        switch grade {
        case 16...20: return "Excellent"
        case 12...15.99: return "Bien"
        case 10...11.99: return "Passable"
        default: return "Insuffisant"
        }
    }
    
    func gradeColor(for grade: Double) -> Color {
        guard grade != NO_GRADE else { return GradeColor.noGrade }
        
        switch grade {
        case 16...20: return GradeColor.excellent
        case 12...15.99: return GradeColor.good
        case 10...11.99: return GradeColor.average
        default: return GradeColor.failure
        }
    }
    
    func validationErrorMessage(for input: String) -> String {
        if input.isEmpty {
            return "Veuillez saisir une note"
        }
        return "La note doit être comprise entre 0 et 20"
    }
    
    func coefficientErrorMessage(for input: String) -> String {
        if input.isEmpty {
            return "Veuillez saisir un coefficient"
        }
        return "Le coefficient doit être entre 0.5 et 10.0"
    }
    
    func displayGrade(_ grade: Double, compact: Bool) -> String {
        guard grade != NO_GRADE else { return "—" }
        
        if compact {
            return String(format: "%.1f", grade)
        }
        return format(grade)
    }
}

struct USASystem: GradingSystemPlugin {
    let id = "usa"
    let label = "États-Unis (GPA)"
    let description = "Système GPA américain de 0.0 à 4.0 avec équivalences lettres"
    let min: Double = 0
    let max: Double = 4
    let suffix = ""
    let coefLabel = "Crédits"
    let placeholder = "ex: A, B+, 3.7"
    let passingGrade: Double = 2.0
    let gradeInputHelp = "Saisissez une lettre (A, B+, C-, etc.) ou un GPA (0.0-4.0)"
    let coefficientHelp = "Nombre de crédits pour ce cours"
    let averageLabel = "GPA moyen"
    let gradeUnit = "GPA"
    let systemName = "GPA 4.0"
    let decimalPlaces = 1
    let usesLetterGrades = true
    let isInverted = false
    
    private let letterToGPA: [String: Double] = [
        "A+": 4.0, "A": 4.0, "A-": 3.7,
        "B+": 3.3, "B": 3.0, "B-": 2.7,
        "C+": 2.3, "C": 2.0, "C-": 1.7,
        "D+": 1.3, "D": 1.0, "D-": 0.7,
        "F": 0.0
    ]
    
    private let gpaToLetter: [Double: String] = [
        4.0: "A", 3.7: "A-", 3.3: "B+", 3.0: "B", 2.7: "B-",
        2.3: "C+", 2.0: "C", 1.7: "C-", 1.3: "D+", 1.0: "D", 0.7: "D-", 0.0: "F"
    ]
    
    func format(_ grade: Double) -> String {
        guard grade != NO_GRADE else { return "—" }
        
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        
        return formatter.string(from: NSNumber(value: grade)) ?? String(format: "%.1f", grade)
    }
    
    func weightedAverage(_ evaluations: [DummyEvaluation]) -> Double {
        let validEvaluations = evaluations.filter { $0.grade != NO_GRADE }
        guard !validEvaluations.isEmpty else { return NO_GRADE }
        
        let totalWeightedGrades = validEvaluations.reduce(0.0) { $0 + ($1.grade * $1.coefficient) }
        let totalCoefficients = validEvaluations.reduce(0.0) { $0 + $1.coefficient }
        
        guard totalCoefficients > 0 else { return NO_GRADE }
        return totalWeightedGrades / totalCoefficients
    }
    
    func validate(_ grade: Double) -> Bool {
        return grade >= min && grade <= max
    }
    
    func validateCoefficient(_ coeff: Double) -> Bool {
        return coeff >= 0.5 && coeff <= 8.0
    }
    
    func parse(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return nil }
        
        if let gpaValue = letterToGPA[trimmed] {
            return gpaValue
        }
        
        if let direct = Double(trimmed) {
            let rounded = round(direct * 10) / 10
            return validate(rounded) ? rounded : nil
        }
        
        return nil
    }
    
    func appreciation(for grade: Double) -> String {
        guard grade != NO_GRADE else { return "Pas de note" }
        
        switch grade {
        case 3.5...4.0: return "Excellent"
        case 2.5...3.4: return "Bien"
        case 2.0...2.4: return "Passable"
        default: return "Insuffisant"
        }
    }
    
    func gradeColor(for grade: Double) -> Color {
        guard grade != NO_GRADE else { return GradeColor.noGrade }
        
        switch grade {
        case 3.5...4.0: return GradeColor.excellent
        case 2.5...3.4: return GradeColor.good
        case 2.0...2.4: return GradeColor.average
        default: return GradeColor.failure
        }
    }
    
    func validationErrorMessage(for input: String) -> String {
        if input.isEmpty {
            return "Veuillez saisir une note"
        }
        return "Note invalide. Utilisez une lettre (A, B+, C-) ou un GPA (0.0-4.0)"
    }
    
    func coefficientErrorMessage(for input: String) -> String {
        if input.isEmpty {
            return "Veuillez saisir un nombre de crédits"
        }
        return "Les crédits doivent être entre 0.5 et 8.0"
    }
    
    func displayGrade(_ grade: Double, compact: Bool) -> String {
        guard grade != NO_GRADE else { return "—" }
        
        if compact {
            if let letter = gpaToLetter[grade] {
                return letter
            }
        }
        return format(grade)
    }
}

struct UKSystem: GradingSystemPlugin {
    let id = "uk"
    let label = "Royaume-Uni (%)"
    let description = "Système britannique en pourcentages de 0% à 100%"
    let min: Double = 0
    let max: Double = 100
    let suffix = "%"
    let coefLabel = "Credits"
    let placeholder = "ex: 75"
    let passingGrade: Double = 40
    let gradeInputHelp = "Saisissez un pourcentage entre 0 et 100"
    let coefficientHelp = "Number of credits for this module (typically 10-60)"
    let averageLabel = "Moyenne"
    let gradeUnit = "%"
    let systemName = "Pourcentage UK"
    let decimalPlaces = 1
    let usesLetterGrades = false
    let isInverted = false
    
    func format(_ grade: Double) -> String {
        guard grade != NO_GRADE else { return "—" }
        
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        
        let number = formatter.string(from: NSNumber(value: grade)) ?? String(format: "%.1f", grade)
        return "\(number)%"
    }
    
    func weightedAverage(_ evaluations: [DummyEvaluation]) -> Double {
        let validEvaluations = evaluations.filter { $0.grade != NO_GRADE }
        guard !validEvaluations.isEmpty else { return NO_GRADE }
        
        let totalWeightedGrades = validEvaluations.reduce(0.0) { $0 + ($1.grade * $1.coefficient) }
        let totalCoefficients = validEvaluations.reduce(0.0) { $0 + $1.coefficient }
        
        guard totalCoefficients > 0 else { return NO_GRADE }
        return totalWeightedGrades / totalCoefficients
    }
    
    func validate(_ grade: Double) -> Bool {
        return grade >= min && grade <= max
    }
    
    func validateCoefficient(_ coeff: Double) -> Bool {
        return coeff >= 0.5 && coeff <= 10.0
    }
    
    func parse(_ input: String) -> Double? {
        let cleaned = input.replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let value = Double(cleaned) else { return nil }
        return validate(value) ? value : nil
    }
    
    func appreciation(for grade: Double) -> String {
        guard grade != NO_GRADE else { return "Pas de note" }
        
        switch grade {
        case 70...100: return "Excellent"
        case 50...69: return "Bien"
        case 40...49: return "Passable"
        default: return "Insuffisant"
        }
    }
    
    func gradeColor(for grade: Double) -> Color {
        guard grade != NO_GRADE else { return GradeColor.noGrade }
        
        switch grade {
        case 70...100: return GradeColor.excellent
        case 50...69: return GradeColor.good
        case 40...49: return GradeColor.average
        default: return GradeColor.failure
        }
    }
    
    func validationErrorMessage(for input: String) -> String {
        if input.isEmpty {
            return "Veuillez saisir une note"
        }
        return "La note doit être un pourcentage entre 0 et 100"
    }
    
    func coefficientErrorMessage(for input: String) -> String {
        if input.isEmpty {
            return "Veuillez saisir un coefficient"
        }
        return "Le coefficient doit être entre 0.5 et 10.0"
    }
    
    func displayGrade(_ grade: Double, compact: Bool) -> String {
        guard grade != NO_GRADE else { return "—" }
        
        if compact {
            return String(format: "%.0f%%", grade)
        }
        return format(grade)
    }
}

struct GermanSystem: GradingSystemPlugin {
    let id = "germany"
    let label = "Allemagne (1-6)"
    let description = "Système allemand inversé de 1.0 (excellent) à 6.0 (insuffisant)"
    let min: Double = 1.0
    let max: Double = 6.0
    let suffix = ""
    let coefLabel = "Gewichtung"
    let placeholder = "ex: 1.7 ou Gut"
    let passingGrade: Double = 4.0
    let gradeInputHelp = "Saisissez une note (1.0-6.0) ou un mot (Sehr gut, Gut, etc.)"
    let coefficientHelp = "Pondération du cours (généralement 1-8)"
    let averageLabel = "Durchschnitt"
    let gradeUnit = ""
    let systemName = "Notes allemandes"
    let decimalPlaces = 1
    let usesLetterGrades = true
    let isInverted = true
    
    private let wordToGrade: [String: Double] = [
        "SEHR GUT": 1.0, "SEHRGUT": 1.0,
        "GUT": 2.0,
        "BEFRIEDIGEND": 3.0,
        "AUSREICHEND": 4.0,
        "MANGELHAFT": 5.0,
        "UNGENÜGEND": 6.0, "UNGENUGEND": 6.0
    ]
    
    private let gradeToWord: [Double: String] = [
        1.0: "Sehr gut", 1.3: "Sehr gut", 1.7: "Gut",
        2.0: "Gut", 2.3: "Gut", 2.7: "Befriedigend",
        3.0: "Befriedigend", 3.3: "Befriedigend", 3.7: "Ausreichend",
        4.0: "Ausreichend", 5.0: "Mangelhaft", 6.0: "Ungenügend"
    ]
    
    func format(_ grade: Double) -> String {
        guard grade != NO_GRADE else { return "—" }
        
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        
        return formatter.string(from: NSNumber(value: grade)) ?? String(format: "%.1f", grade)
    }
    
    func weightedAverage(_ evaluations: [DummyEvaluation]) -> Double {
        let validEvaluations = evaluations.filter { $0.grade != NO_GRADE }
        guard !validEvaluations.isEmpty else { return NO_GRADE }
        
        let totalWeightedGrades = validEvaluations.reduce(0.0) { $0 + ($1.grade * $1.coefficient) }
        let totalCoefficients = validEvaluations.reduce(0.0) { $0 + $1.coefficient }
        
        guard totalCoefficients > 0 else { return NO_GRADE }
        let average = totalWeightedGrades / totalCoefficients
        
        let rounded = round(average * 10) / 10
        let decimal = rounded.truncatingRemainder(dividingBy: 1)
        
        if abs(decimal - 0.0) < 0.05 { return floor(rounded) }
        if abs(decimal - 0.3) < 0.05 { return floor(rounded) + 0.3 }
        if abs(decimal - 0.7) < 0.05 { return floor(rounded) + 0.7 }
        
        if decimal < 0.15 { return floor(rounded) }
        if decimal < 0.5 { return floor(rounded) + 0.3 }
        return floor(rounded) + 0.7
    }
    
    func validate(_ grade: Double) -> Bool {
        return grade >= min && grade <= max
    }
    
    func validateCoefficient(_ coeff: Double) -> Bool {
        return coeff >= 0.5 && coeff <= 8.0
    }
    
    func parse(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return nil }
        
        if let gradeValue = wordToGrade[trimmed] {
            return gradeValue
        }
        
        if let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
            guard validate(value) else { return nil }
            
            let decimal = value.truncatingRemainder(dividingBy: 1)
            let validDecimals: [Double] = [0.0, 0.3, 0.7]
            
            for validDecimal in validDecimals {
                if abs(decimal - validDecimal) < 0.01 {
                    return value
                }
            }
            return nil
        }
        
        return nil
    }
    
    func appreciation(for grade: Double) -> String {
        guard grade != NO_GRADE else { return "Pas de note" }
        
        switch grade {
        case 1.0...2.5: return "Excellent"
        case 2.6...3.5: return "Bien"
        case 3.6...4.0: return "Passable"
        default: return "Insuffisant"
        }
    }
    
    func gradeColor(for grade: Double) -> Color {
        guard grade != NO_GRADE else { return GradeColor.noGrade }
        
        switch grade {
        case 1.0...2.5: return GradeColor.excellent
        case 2.6...3.5: return GradeColor.good
        case 3.6...4.0: return GradeColor.average
        default: return GradeColor.failure
        }
    }
    
    func validationErrorMessage(for input: String) -> String {
        if input.isEmpty {
            return "Veuillez saisir une note"
        }
        return "Note invalide. Utilisez 1.0-6.0 avec décimales .0, .3, .7 ou un mot allemand"
    }
    
    func coefficientErrorMessage(for input: String) -> String {
        if input.isEmpty {
            return "Veuillez saisir une pondération"
        }
        return "La pondération doit être entre 0.5 et 8.0"
    }
    
    func displayGrade(_ grade: Double, compact: Bool) -> String {
        guard grade != NO_GRADE else { return "—" }
        
        if compact {
            if let word = gradeToWord[grade] {
                return word
            }
        }
        return format(grade)
    }
}

// MARK: - Grading System Registry

final class GradingSystemRegistry {
    private static let queue = DispatchQueue(label: "grading.system.queue", qos: .userInitiated)
    private static var _cachedActiveSystem: GradingSystemPlugin?
    private static var _lastSystemId: String?
    
    private static let _available: [GradingSystemPlugin] = [
        FrenchSystem(), USASystem(), GermanSystem(), UKSystem()
    ]
    
    static var available: [GradingSystemPlugin] {
        queue.sync { _available }
    }
    
    static var active: GradingSystemPlugin {
        queue.sync {
            let currentId = UserDefaults.standard.string(forKey: "GradingSystem") ?? "france"
            
            if _lastSystemId == currentId, let cached = _cachedActiveSystem {
                return cached
            }
            
            let system = _available.first { $0.id == currentId } ?? FrenchSystem()
            _cachedActiveSystem = system
            _lastSystemId = currentId
            
            return system
        }
    }
    
    static func setActiveSystem(id: String) {
        queue.async {
            UserDefaults.standard.set(id, forKey: "GradingSystem")
            _cachedActiveSystem = nil
            _lastSystemId = nil
        }
    }
    
    static func system(for id: String) -> GradingSystemPlugin {
        queue.sync {
            _available.first { $0.id == id } ?? FrenchSystem()
        }
    }
    
    static func invalidateCache() {
        queue.async {
            _cachedActiveSystem = nil
            _lastSystemId = nil
        }
    }
}

// MARK: - Subject Row Component

struct SubjectRow: View {
    let subject: Subject
    let showAppreciations: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(subject.name ?? "")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primary)
                
                HStack {
                    Text("\(gradingSystem.coefLabel) \(formatCoefficientClean(subject.coefficient))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if showAppreciations && subject.grade != NO_GRADE && gradingSystem.validate(subject.grade) {
                        Text("• \(gradingSystem.appreciation(for: subject.grade))")
                            .font(.caption.weight(.medium))
                            .foregroundColor(gradingSystem.gradeColor(for: subject.grade))
                    }
                }
            }
            
            Spacer()
            
            if subject.grade == NO_GRADE {
                Text("--")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.secondary)
            } else if gradingSystem.validate(subject.grade) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(gradingSystem.format(subject.grade))
                        .font(.title3.weight(.semibold))
                        .foregroundColor(gradingSystem.gradeColor(for: subject.grade))
                }
            } else {
                Text(gradingSystem.format(subject.grade))
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 0)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .tint(.blue)
            
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .tint(.red)
        }
    }
}


// MARK: - Subject Detail View

struct SubjectDetailView: View {
    @ObservedObject var subjectObject: Subject
    @Binding var showingProfileSheet: Bool
    @Environment(\.managedObjectContext) private var viewContext
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    private var sortedEvaluations: [Evaluation] {
        let set = subjectObject.evaluations as? Set<Evaluation> ?? []
        return set.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
    }
    
    @State private var showingAddEvaluation = false
    @State private var evaluationToEdit: Evaluation?
    
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()
    
    private var now: Date { Date() }
    private var pastEvaluations: [Evaluation] {
        let now = Date()
        return sortedEvaluations.filter { ($0.date ?? now) < now }
    }
    private var upcomingEvaluations: [Evaluation] {
        let now = Date()
        return sortedEvaluations.filter { ($0.date ?? now) >= now }
    }
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(subjectObject.name ?? "")
                                .font(.title.bold())
                            Text("\(gradingSystem.coefLabel) \(upToTwoDecimals(subjectObject.coefficient))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack {
                            if subjectObject.grade != NO_GRADE {
                                Text(gradingSystem.format(subjectObject.grade))
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(gradingSystem.gradeColor(for: subjectObject.grade))
                                HStack(spacing: 4) {
                                    Text(gradingSystem.suffix)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if gradingSystem.validate(subjectObject.grade) {
                                        Text("•")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(gradingSystem.appreciation(for: subjectObject.grade))
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(gradingSystem.gradeColor(for: subjectObject.grade))
                                    }
                                }
                            } else {
                                Text("--")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text("Pas de note")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            
            Section("Évaluations passées") {
                if pastEvaluations.isEmpty {
                    Text("Aucune évaluation passée")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(pastEvaluations, id: \.id) { evaluation in
                        evaluationRow(evaluation)
                    }
                    .onDelete { offsets in
                        deleteEvaluationsOptimized(offsets: offsets, in: pastEvaluations)
                    }
                }
            }
            
            Section("Évaluations à venir") {
                if upcomingEvaluations.isEmpty {
                    Text("Aucune évaluation à venir")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(upcomingEvaluations, id: \.id) { evaluation in
                        evaluationRow(evaluation)
                    }
                    .onDelete { offsets in
                        deleteEvaluationsOptimized(offsets: offsets, in: upcomingEvaluations)
                    }
                }
            }
        }
        .navigationTitle(subjectObject.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Ajouter") {
                    showingAddEvaluation = true
                }
            }
        }
        .sheet(isPresented: $showingAddEvaluation) {
            AddEvaluationView(subject: subjectObject)
        }
        .sheet(item: $evaluationToEdit) { evaluation in
            EditEvaluationView(evaluation: evaluation)
        }
    }
    
    @ViewBuilder
    private func evaluationRow(_ evaluation: Evaluation) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(evaluation.title ?? "")
                    .font(.headline)
                if let date = evaluation.date {
                    Text(SubjectDetailView.dateFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Date inconnue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if evaluation.grade != NO_GRADE && gradingSystem.validate(evaluation.grade) {
                    Text(gradingSystem.format(evaluation.grade))
                        .font(.title3.bold())
                        .foregroundColor(gradingSystem.gradeColor(for: evaluation.grade))
                    Text(gradingSystem.appreciation(for: evaluation.grade))
                        .font(.caption2)
                        .foregroundColor(gradingSystem.gradeColor(for: evaluation.grade))
                } else {
                    Text("--")
                        .font(.title3.bold())
                        .foregroundColor(.secondary)
                }
                Text("\(gradingSystem.coefLabel) \(formatCoefficientClean(evaluation.coefficient))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                evaluationToEdit = evaluation
            } label: {
                Image(systemName: "pencil")
            }
            .tint(.blue)
            
            Button(role: .destructive) {
                deleteEvaluation(evaluation)
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
        }
    }
    
    private func deleteEvaluation(_ evaluation: Evaluation) {
        viewContext.performAndWait {
            do {
                let subject = evaluation.subject
                viewContext.delete(evaluation)
                subject?.recalculateAverageOptimized(context: viewContext)
                try viewContext.save()
            } catch {
                viewContext.rollback()
                print("❌ Erreur suppression évaluation: \(error)")
            }
        }
    }
    
    private func deleteEvaluationsOptimized(offsets: IndexSet, in evaluations: [Evaluation]) {
        viewContext.performAndWait {
            do {
                let toDelete = offsets.map { evaluations[$0] }
                let subject = toDelete.first?.subject
                
                toDelete.forEach(viewContext.delete)
                subject?.recalculateAverageOptimized(context: viewContext)
                try viewContext.save()
            } catch {
                viewContext.rollback()
                print("❌ Erreur suppression évaluations: \(error)")
            }
        }
    }
}

// MARK: - Add/Edit Evaluation Views

struct AddEvaluationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subject: Subject
    @State private var title = ""
    @State private var gradeInput = ""
    @State private var coefficientInput = ""
    @State private var date = Date()
    @State private var errorMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var createWithoutGrade = false
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    private var isFutureEvaluation: Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }
    
    private var isFormValid: Bool {
        let titleValid = !title.trimmingCharacters(in: .whitespaces).isEmpty
        let coefficientValid = !coefficientInput.isEmpty
        
        if isFutureEvaluation {
            return titleValid && coefficientValid
        } else {
            return titleValid && coefficientValid && !gradeInput.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                titleSection
                dateSection
                
                if isFutureEvaluation {
                    futureGradeSection
                } else {
                    presentGradeSection
                }
                
                coefficientSection
                
                if isFutureEvaluation {
                    futureEvaluationInfo
                }
            }
            .navigationTitle("Nouvelle évaluation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        saveEvaluation()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Erreur"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onChange(of: date) { _, _ in
                if isFutureEvaluation && !gradeInput.isEmpty {
                    gradeInput = ""
                    createWithoutGrade = false
                }
            }
        }
    }
    
    private var titleSection: some View {
        Section("Titre") {
            TextField("Nom du devoir/examen", text: $title)
        }
    }
    
    private var dateSection: some View {
        Section("Date") {
            DatePicker("Date", selection: $date, displayedComponents: .date)
        }
    }
    
    private var futureGradeSection: some View {
        Section("Note (optionnelle)") {
            if createWithoutGrade {
                HStack {
                    Text("Évaluation programmée sans note")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Ajouter une note") {
                        createWithoutGrade = false
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(gradingSystem.placeholder, text: $gradeInput)
                        .keyboardType(.decimalPad)
                    
                    HStack {
                        Text(gradingSystem.gradeInputHelp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Programmer sans note") {
                            gradeInput = ""
                            createWithoutGrade = true
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                }
            }
        }
    }
    
    private var presentGradeSection: some View {
        Section("Note") {
            TextField(gradingSystem.placeholder, text: $gradeInput)
                .keyboardType(.decimalPad)
            Text(gradingSystem.gradeInputHelp)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var coefficientSection: some View {
        Section(gradingSystem.coefLabel) {
            TextField("ex: 2", text: $coefficientInput)
                .keyboardType(.decimalPad)
            Text(gradingSystem.coefficientHelp)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var futureEvaluationInfo: some View {
        Section {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Évaluation future")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.primary)
                    Text("Cette évaluation apparaîtra dans vos échéances. Vous pourrez ajouter la note plus tard.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func saveEvaluation() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else {
            errorMessage = "Le titre ne peut pas être vide"
            showAlert = true
            return
        }
        
        var finalGrade: Double = NO_GRADE
        
        if !gradeInput.isEmpty && !createWithoutGrade {
            guard let grade = gradingSystem.parse(gradeInput) else {
                errorMessage = gradingSystem.validationErrorMessage(for: gradeInput)
                showAlert = true
                return
            }
            
            guard gradingSystem.validate(grade) && isGradeValidForSystem(grade, system: gradingSystem) else {
                errorMessage = "Cette note n'est pas valide pour le système \(gradingSystem.systemName)"
                showAlert = true
                return
            }
            
            finalGrade = grade
        } else if !isFutureEvaluation && gradeInput.isEmpty {
            errorMessage = "Une note est requise pour les évaluations passées"
            showAlert = true
            return
        }
        
        guard let coefficient = Double(coefficientInput.replacingOccurrences(of: ",", with: ".")),
              gradingSystem.validateCoefficient(coefficient) else {
            errorMessage = gradingSystem.coefficientErrorMessage(for: coefficientInput)
            showAlert = true
            return
        }
        
        viewContext.performAndWait {
            do {
                let newEvaluation = Evaluation(context: viewContext)
                newEvaluation.id = UUID()
                newEvaluation.title = cleanTitle
                newEvaluation.grade = finalGrade
                newEvaluation.coefficient = coefficient
                newEvaluation.date = date
                newEvaluation.subject = subject
                
                try viewContext.save()
                
                if finalGrade != NO_GRADE {
                    subject.recalculateAverageOptimized(context: viewContext, autoSave: true)
                }
                
                dismiss()
            } catch {
                viewContext.rollback()
                errorMessage = "Erreur lors de la sauvegarde : \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func isGradeValidForSystem(_ grade: Double, system: GradingSystemPlugin) -> Bool {
        switch system.id {
        case "germany":
            let decimal = grade.truncatingRemainder(dividingBy: 1)
            let validDecimals: [Double] = [0.0, 0.3, 0.7]
            return validDecimals.contains { abs(decimal - $0) < 0.01 }
        case "usa":
            return grade >= 0.0 && grade <= 4.0
        default:
            return system.validate(grade)
        }
    }
}

struct EditEvaluationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var evaluation: Evaluation
    @State private var title = ""
    @State private var gradeInput = ""
    @State private var coefficientInput = ""
    @State private var date = Date()
    @State private var errorMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var createWithoutGrade = false
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    private var isFutureEvaluation: Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }
    
    private var isFormValid: Bool {
        let titleValid = !title.trimmingCharacters(in: .whitespaces).isEmpty
        let coefficientValid = !coefficientInput.isEmpty
        
        if isFutureEvaluation {
            return titleValid && coefficientValid
        } else {
            return titleValid && coefficientValid && !gradeInput.isEmpty
        }
    }

    init(evaluation: Evaluation) {
        self.evaluation = evaluation
        let system = GradingSystemRegistry.active
        
        _title = State(initialValue: evaluation.title ?? "")
        _date = State(initialValue: evaluation.date ?? Date())
        _coefficientInput = State(initialValue: formatCoefficientClean(evaluation.coefficient))
        
        _gradeInput = State(initialValue: {
            if evaluation.grade == NO_GRADE {
                return ""
            } else {
                let formatter = NumberFormatter()
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = system.decimalPlaces
                formatter.numberStyle = .decimal
                formatter.locale = Locale.current
                return formatter.string(from: NSNumber(value: evaluation.grade)) ?? String(format: "%.2f", evaluation.grade)
            }
        }())
        
        _createWithoutGrade = State(initialValue: evaluation.grade == NO_GRADE)
    }

    var body: some View {
        NavigationStack {
            Form {
                titleSection
                dateSection
                
                if isFutureEvaluation {
                    futureGradeSection
                } else {
                    presentGradeSection
                }
                
                coefficientSection
                
                if isFutureEvaluation {
                    futureEvaluationInfo
                }
            }
            .navigationTitle("Modifier l'évaluation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        saveEvaluation()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Erreur"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onChange(of: date) { _, _ in
                if isFutureEvaluation && !gradeInput.isEmpty {
                    gradeInput = ""
                    createWithoutGrade = false
                }
            }
        }
    }
    
    private var titleSection: some View {
        Section("Titre") {
            TextField("Nom du devoir/examen", text: $title)
        }
    }
    
    private var dateSection: some View {
        Section("Date") {
            DatePicker("Date", selection: $date, displayedComponents: .date)
        }
    }
    
    private var futureGradeSection: some View {
        Section("Note (optionnelle)") {
            TextField(gradingSystem.placeholder, text: $gradeInput)
                .keyboardType(.decimalPad)
            Text(gradingSystem.gradeInputHelp)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var presentGradeSection: some View {
        Section("Note") {
            TextField(gradingSystem.placeholder, text: $gradeInput)
                .keyboardType(.decimalPad)
            Text(gradingSystem.gradeInputHelp)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var coefficientSection: some View {
        Section(gradingSystem.coefLabel) {
            TextField("ex: 2", text: $coefficientInput)
                .keyboardType(.decimalPad)
            Text(gradingSystem.coefficientHelp)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var futureEvaluationInfo: some View {
        Section {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Évaluation future")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.primary)
                    Text("Cette évaluation apparaîtra dans vos échéances. Vous pourrez ajouter la note plus tard.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func saveEvaluation() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else {
            errorMessage = "Le titre ne peut pas être vide"
            showAlert = true
            return
        }
        
        var finalGrade: Double = NO_GRADE
        
        if !gradeInput.isEmpty {
            guard let grade = gradingSystem.parse(gradeInput) else {
                errorMessage = gradingSystem.validationErrorMessage(for: gradeInput)
                showAlert = true
                return
            }
            
            guard gradingSystem.validate(grade) && isGradeValidForSystem(grade, system: gradingSystem) else {
                errorMessage = "Cette note n'est pas valide pour le système \(gradingSystem.systemName)"
                showAlert = true
                return
            }
            
            finalGrade = grade
        } else if !isFutureEvaluation {
            errorMessage = "Une note est requise pour les évaluations passées"
            showAlert = true
            return
        }
        
        guard let coefficient = Double(coefficientInput.replacingOccurrences(of: ",", with: ".")),
              gradingSystem.validateCoefficient(coefficient) else {
            errorMessage = gradingSystem.coefficientErrorMessage(for: coefficientInput)
            showAlert = true
            return
        }
        
        viewContext.performAndWait {
            do {
                evaluation.title = cleanTitle
                evaluation.grade = finalGrade
                evaluation.coefficient = coefficient
                evaluation.date = date
                
                try viewContext.save()
                
                // ✅ TOUJOURS RECALCULER (même si finalGrade == NO_GRADE)
                evaluation.subject?.recalculateAverageOptimized(context: viewContext, autoSave: true)
                
                dismiss()
            } catch {
                viewContext.rollback()
                errorMessage = "Erreur lors de la sauvegarde : \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func isGradeValidForSystem(_ grade: Double, system: GradingSystemPlugin) -> Bool {
        switch system.id {
        case "germany":
            let decimal = grade.truncatingRemainder(dividingBy: 1)
            let validDecimals: [Double] = [0.0, 0.3, 0.7]
            return validDecimals.contains { abs(decimal - $0) < 0.01 }
        case "usa":
            return grade >= 0.0 && grade <= 4.0
        default:
            return system.validate(grade)
        }
    }
}

struct AddSubjectView: View {
    let selectedPeriod: String
    let onAdd: (SubjectData) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var subjectName = ""
    @State private var weight: Double? = nil
    @FocusState private var isNameFieldFocused: Bool // ✅ Ajouté FocusState
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    HStack {
                        Text("Nom")
                        Spacer()
                        TextField("Requis", text: $subjectName)
                            .multilineTextAlignment(.trailing)
                            .focused($isNameFieldFocused) // ✅ Liaison avec FocusState
                    }
                    
                    HStack {
                        Text(gradingSystem.coefLabel)
                         Spacer()
                        TextField("Requis", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Période") {
                    Text(selectedPeriod)
                }
            }
            .navigationTitle("Ajouter une matière")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // ✅ Focus automatique dès l'apparition
                DispatchQueue.main.async {
                    isNameFieldFocused = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        let subjectData = SubjectData(
                            code: "",
                            name: subjectName.trimmingCharacters(in: .whitespaces),
                            grade: 0.0,
                            coefficient: weight!,
                            periodName: selectedPeriod
                        )
                        onAdd(subjectData)
                        dismiss()
                    }
                    .disabled(subjectName.trimmingCharacters(in: .whitespaces).isEmpty ||
                             weight == nil)
                }
            }
        }
    }
}


struct EditSubjectView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subject: Subject
    @State private var name: String
    @State private var coefficientText: String
    @State private var errorMessage = ""
    @State private var showAlert = false

    private var system: GradingSystemPlugin {
        GradingSystemRegistry.active
    }

    init(subject: Subject) {
        self.subject = subject
        _name = State(initialValue: subject.name ?? "")
        _coefficientText = State(initialValue: "\(subject.coefficient)")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom de la matière") {
                    TextField("ex : Mathématiques", text: $name)
                }
                Section(system.coefLabel) {
                    TextField(system.placeholder, text: $coefficientText)
                        .keyboardType(.decimalPad)
                    Text(system.coefficientHelp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Modifier la matière")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || coefficientText.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Erreur"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func save() {
        let cleaned = coefficientText.replacingOccurrences(of: ",", with: ".")
        guard let coefficient = Double(cleaned), system.validateCoefficient(coefficient) else {
            errorMessage = system.coefficientErrorMessage(for: coefficientText)
            showAlert = true
            return
        }

        subject.name = name.trimmingCharacters(in: .whitespaces)
        subject.coefficient = coefficient

        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Erreur lors de la sauvegarde : \(error.localizedDescription)"
            showAlert = true
            viewContext.rollback()
        }
    }
}

// MARK: - System Selection Components

struct SystemModeSelectionView: View {
    @Binding var refreshID: UUID
    @AppStorage("GradingSystem") private var selectedGradingSystem: String = "france"
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showConfirmation = false
    @State private var pendingSystem: String?
    @State private var isChanging = false
    
    private let availableSystems: [GradingSystemDisplayItem] = [
        GradingSystemDisplayItem(
            id: "france",
            displayName: "France",
            description: "0–20 points",
            flag: "🇫🇷"
        ),
        GradingSystemDisplayItem(
            id: "usa",
            displayName: "États-Unis",
            description: "GPA 4.0",
            flag: "🇺🇸"
        ),
        GradingSystemDisplayItem(
            id: "germany",
            displayName: "Allemagne",
            description: "1.0–6.0",
            flag: "🇩🇪"
        ),
        GradingSystemDisplayItem(
            id: "uk",
            displayName: "Royaume-Uni",
            description: "Percentages",
            flag: "🇬🇧"
        )
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Système de notation")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 30)
                
                VStack(spacing: 16) {
                    ForEach(availableSystems) { system in
                        SystemButton(
                            system: system,
                            isSelected: selectedGradingSystem == system.id,
                            isChanging: isChanging && pendingSystem == system.id
                        ) {
                            handleSystemSelection(system.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(450), .fraction(0.60)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(25)
        .alert("Changer de système de notation", isPresented: $showConfirmation) {
            Button("Confirmer", role: .destructive) {
                confirmSystemChange()
            }
            Button("Annuler", role: .cancel) {
                cancelSystemChange()
            }
        } message: {
            Text("Toutes vos matières et évaluations seront supprimées. Vos périodes seront conservées. Au moins une période restera disponible.")
        }
        .disabled(isChanging)
    }
    
    // MARK: - Actions (logique corrigée conservée)
    
    private func handleSystemSelection(_ systemId: String) {
        guard systemId != selectedGradingSystem, !isChanging else { return }
        
        HapticFeedbackManager.shared.impact(style: .light)
        pendingSystem = systemId
        showConfirmation = true
    }
    
    private func confirmSystemChange() {
        guard let newSystem = pendingSystem, !isChanging else {
            resetState()
            return
        }
        
        changeGradingSystemOptimized(to: newSystem)
    }
    
    private func cancelSystemChange() {
        resetState()
    }
    
    private func resetState() {
        pendingSystem = nil
        showConfirmation = false
    }
    
    private func changeGradingSystemOptimized(to newSystemId: String) {
        guard !isChanging else { return }
        
        isChanging = true
        HapticFeedbackManager.shared.impact(style: .medium)
        
        Task {
            do {
                try await performSystemChangeSimple(to: newSystemId)
                
                await MainActor.run {
                    // Mettre à jour UserDefaults
                    UserDefaults.standard.set(newSystemId, forKey: "GradingSystem")
                    UserDefaults.standard.synchronize()
                    
                    selectedGradingSystem = newSystemId
                    refreshID = UUID()
                    isChanging = false
                    
                    // ✅ NOTIFICATION SPÉCIALE avec flag de préservation
                    NotificationCenter.default.post(
                        name: .systemChanged,
                        object: nil,
                        userInfo: ["preservePeriod": true]
                    )
                    
                    HapticFeedbackManager.shared.notification(type: .success)
                    print("✅ Système changé avec demande de préservation : \(newSystemId)")
                }
                
            } catch {
                await MainActor.run {
                    isChanging = false
                    HapticFeedbackManager.shared.notification(type: .error)
                    print("❌ Erreur changement système : \(error)")
                }
            }
        }
    }

    // ✅ NOUVELLE APPROCHE : Éviter les conflits de merge
    private func performSystemChangeSimple(to newSystemId: String) async throws {
        try await viewContext.perform {
            do {
                // ✅ ÉTAPE 1 : Vider le cache AVANT les suppressions
                self.viewContext.refreshAllObjects()
                self.viewContext.reset() // Purge complète du cache
                
                // ✅ ÉTAPE 2 : Suppressions par batch SANS merge (évite les conflits)
                let evaluationRequest: NSFetchRequest<NSFetchRequestResult> = Evaluation.fetchRequest()
                let deleteEvaluations = NSBatchDeleteRequest(fetchRequest: evaluationRequest)
                try self.viewContext.execute(deleteEvaluations)
                
                let subjectRequest: NSFetchRequest<NSFetchRequestResult> = Subject.fetchRequest()
                let deleteSubjects = NSBatchDeleteRequest(fetchRequest: subjectRequest)
                try self.viewContext.execute(deleteSubjects)
                
                // ✅ ÉTAPE 3 : Sauvegarde simple
                try self.viewContext.save()
                
                // ✅ ÉTAPE 4 : Reset final pour être sûr
                self.viewContext.refreshAllObjects()
                
                print("✅ Données supprimées sans conflits pour système : \(newSystemId)")
                
            } catch {
                self.viewContext.rollback()
                throw error
            }
        }
    }
    
    private func resetAllStates() {
        isChanging = false
    }
    
    private func performSystemChange(to newSystemId: String) async throws {
        try await viewContext.perform {
            do {
                let evaluationRequest: NSFetchRequest<NSFetchRequestResult> = Evaluation.fetchRequest()
                let deleteEvaluationsRequest = NSBatchDeleteRequest(fetchRequest: evaluationRequest)
                deleteEvaluationsRequest.resultType = .resultTypeObjectIDs
                
                let evaluationResult = try self.viewContext.execute(deleteEvaluationsRequest) as? NSBatchDeleteResult
                
                let subjectRequest: NSFetchRequest<NSFetchRequestResult> = Subject.fetchRequest()
                let deleteSubjectsRequest = NSBatchDeleteRequest(fetchRequest: subjectRequest)
                deleteSubjectsRequest.resultType = .resultTypeObjectIDs
                
                let subjectResult = try self.viewContext.execute(deleteSubjectsRequest) as? NSBatchDeleteResult
                
                if let evaluationObjectIDs = evaluationResult?.result as? [NSManagedObjectID] {
                    let evaluationChanges = [NSDeletedObjectsKey: evaluationObjectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: evaluationChanges, into: [self.viewContext])
                }
                
                if let subjectObjectIDs = subjectResult?.result as? [NSManagedObjectID] {
                    let subjectChanges = [NSDeletedObjectsKey: subjectObjectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: subjectChanges, into: [self.viewContext])
                }
                
                try self.viewContext.save()
                self.viewContext.refreshAllObjects()
                
                let periodRequest: NSFetchRequest<Period> = Period.fetchRequest()
                let remainingPeriods = try self.viewContext.fetch(periodRequest)
                
                if remainingPeriods.isEmpty {
                    let defaultPeriod = Period(context: self.viewContext)
                    defaultPeriod.id = UUID()
                    defaultPeriod.name = "Nouvelle période"
                    defaultPeriod.startDate = Date()
                    defaultPeriod.endDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
                    
                    try self.viewContext.save()
                }
                
            } catch {
                self.viewContext.rollback()
                throw error
            }
        }
    }
}

// MARK: - System Button (Style original exact - carte)

struct SystemButton: View {
    let system: GradingSystemDisplayItem
    let isSelected: Bool
    let isChanging: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            guard !isChanging else { return }
            HapticFeedbackManager.shared.selection()
            action()
        }) {
            HStack(spacing: 16) {
                // Flag
                Text(system.flag)
                    .font(.title2)
                
                // Infos système
                VStack(alignment: .leading, spacing: 4) {
                    Text(system.displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("\(system.description)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Indicateur
                Group {
                    if isChanging {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .font(.title3)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isChanging)
        .opacity(isChanging ? 0.7 : 1.0)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isChanging)
    }
    
    // ✅ CORRECTION : Pas de background bleu, seulement stroke
    private var backgroundColor: Color {
        Color(.secondarySystemGroupedBackground) // Toujours le même background
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.blue // ✅ Stroke bleu pour sélection
        } else {
            return Color(.separator).opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        isSelected ? 2 : 1 // ✅ Stroke plus épais pour sélection
    }
}


// MARK: - GPA Calculator Views

struct GPACalculatorView: View {
    @State private var courses: [GPACourse] = []
    @State private var showingAddCourse = false
    @Environment(\.dismiss) private var dismiss
    
    private var totalGPA: Double {
        let totalPoints = courses.reduce(0.0) { $0 + ($1.grade * $1.credits) }
        let totalCredits = courses.reduce(0.0) { $0 + $1.credits }
        return totalCredits > 0 ? totalPoints / totalCredits : 0.0
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Text("GPA Calculé")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text(String(format: "%.2f", totalGPA))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Text("sur 4.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                Section("Vos cours") {
                    if courses.isEmpty {
                        ContentUnavailableView(
                            "Aucun cours ajouté",
                            systemImage: "graduationcap",
                            description: Text("Ajoutez vos cours pour calculer votre GPA")
                        )
                    } else {
                        ForEach(courses.indices, id: \.self) { index in
                            GPACourseRow(course: $courses[index])
                        }
                        .onDelete(perform: deleteCourses)
                    }
                }
            }
            .navigationTitle("Calculateur GPA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ajouter") { showingAddCourse = true }
                }
            }
            .sheet(isPresented: $showingAddCourse) {
                AddGPACourseView { course in
                    courses.append(course)
                }
            }
        }
    }
    
    private func deleteCourses(offsets: IndexSet) {
        courses.remove(atOffsets: offsets)
    }
}

struct GPACourse: Identifiable {
    let id = UUID()
    var name: String
    var grade: Double
    var credits: Double
}

struct GPACourseRow: View {
    @Binding var course: GPACourse
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.headline)
                Text("\(Int(course.credits)) crédits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.1f", course.grade))
                .font(.title3.weight(.semibold))
                .foregroundStyle(gradeColor(course.grade))
        }
    }
    
    private func gradeColor(_ grade: Double) -> Color {
        switch grade {
        case 3.7...4.0: return .green
        case 3.0..<3.7: return .blue
        case 2.0..<3.0: return .orange
        default: return .red
        }
    }
}

struct AddGPACourseView: View {
    @State private var courseName = ""
    @State private var selectedGrade = 4.0
    @State private var credits = 3.0
    @Environment(\.dismiss) private var dismiss
    
    let onAdd: (GPACourse) -> Void
    
    private let gradeOptions: [(String, Double)] = [
        ("A", 4.0), ("A-", 3.7), ("B+", 3.3), ("B", 3.0),
        ("B-", 2.7), ("C+", 2.3), ("C", 2.0), ("C-", 1.7),
        ("D+", 1.3), ("D", 1.0), ("F", 0.0)
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations du cours") {
                    TextField("Nom du cours", text: $courseName)
                }
                
                Section("Note") {
                    Picker("Note", selection: $selectedGrade) {
                        ForEach(gradeOptions, id: \.1) { letter, points in
                            Text("\(letter) (\(String(format: "%.1f", points)))")
                                .tag(points)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                
                Section("Crédits") {
                    Stepper("Crédits: \(Int(credits))", value: $credits, in: 1...6, step: 1)
                }
            }
            .navigationTitle("Nouveau cours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        let course = GPACourse(
                            name: courseName,
                            grade: selectedGrade,
                            credits: credits
                        )
                        onAdd(course)
                        dismiss()
                    }
                    .disabled(courseName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Conversion Table View

struct ConversionTableView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let conversions: [GradeConversion] = [
        GradeConversion(french: "18-20", american: "A", german: "1.0-1.4", percentage: "90-100%"),
        GradeConversion(french: "16-17", american: "A-", german: "1.5-1.9", percentage: "85-89%"),
        GradeConversion(french: "14-15", american: "B+", german: "2.0-2.4", percentage: "80-84%"),
        GradeConversion(french: "12-13", american: "B", german: "2.5-2.9", percentage: "75-79%"),
        GradeConversion(french: "10-11", american: "B-", german: "3.0-3.4", percentage: "70-74%"),
        GradeConversion(french: "8-9", american: "C+", german: "3.5-3.9", percentage: "65-69%"),
        GradeConversion(french: "6-7", american: "C", german: "4.0", percentage: "60-64%"),
        GradeConversion(french: "0-5", american: "F", german: "5.0-6.0", percentage: "0-59%")
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Équivalences indicatives entre les principaux systèmes de notation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Table de conversion")
                }
                
                Section {
                    ForEach(conversions, id: \.french) { conversion in
                        ConversionRow(conversion: conversion)
                    }
                }
            }
            .navigationTitle("Conversions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}

struct GradeConversion {
    let french: String
    let american: String
    let german: String
    let percentage: String
}

struct ConversionRow: View {
    let conversion: GradeConversion
    
    var body: some View {
        Grid(alignment: .leading, verticalSpacing: 8) {
            GridRow {
                Text(conversion.french)
                    .font(.system(.body, design: .monospaced).weight(.medium))

                Text(conversion.american.isEmpty ? "—" : conversion.american)
                    .font(.system(.body, design: .monospaced).weight(.medium))

                Text(conversion.german.isEmpty ? "—" : conversion.german)
                    .font(.system(.body, design: .monospaced).weight(.medium))

                Text(conversion.percentage.isEmpty ? "—" : conversion.percentage)
                    .font(.system(.body, design: .monospaced).weight(.medium))
            }
        }
        .padding(.vertical, 4)
    }
}
