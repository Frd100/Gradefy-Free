//
//  FrenchSystem.swift
//  PARALLAX
//
//  Created by  on 7/21/25.
//
import CoreData
import Foundation
import SwiftUI

// Tous les systèmes de notation
struct FrenchSystem: GradingSystemPlugin {
    let id = "france"

    var label: String { String(localized: "grading_france_label") }
    var description: String { String(localized: "grading_france_description") }
    var coefLabel: String { String(localized: "field_coefficient") }
    var placeholder: String { String(localized: "field_optional") }
    var averageLabel: String { String(localized: "grading_france_average") }
    var systemName: String { String(localized: "grading_france_system_name") }

    let min: Double = 0
    let max: Double = 20
    let suffix = ""
    let passingGrade: Double = 10
    let gradeUnit = "/20"
    let decimalPlaces = 2
    let usesLetterGrades = false
    let isInverted = false

    func format(_ grade: Double) -> String {
        guard grade != NO_GRADE else { return "—" }
        return "\(formatNumber(grade, places: decimalPlaces))\(suffix)"
    }

    func weightedAverage(_ evaluations: [DummyEvaluation]) -> Double {
        let validEvaluations = evaluations.filter { $0.grade != NO_GRADE }
        guard !validEvaluations.isEmpty else { return NO_GRADE }

        let totalWeightedGrades = validEvaluations.reduce(0.0) { $0 + ($1.grade * $1.coefficient) }
        let totalCoefficients = validEvaluations.reduce(0.0) { $0 + $1.coefficient }

        guard totalCoefficients > 0 else { return NO_GRADE }
        return (totalWeightedGrades / totalCoefficients).rounded(toPlaces: decimalPlaces)
    }

    func validate(_ grade: Double) -> Bool {
        return grade >= min && grade <= max
    }

    func validateCoefficient(_ coeff: Double) -> Bool {
        return coeff >= MIN_COEFF && coeff <= MAX_COEFF
    }

    func parse(_ input: String) -> Double? {
        guard let val = parseDecimalInput(input.replacingOccurrences(of: suffix, with: "")) else { return nil }
        return validate(val) ? val.rounded(toPlaces: decimalPlaces) : nil
    }

    func gradeColor(for grade: Double) -> Color {
        guard grade != NO_GRADE else { return GradeColor.noGrade }

        switch grade {
        case 16 ... 20: return GradeColor.excellent
        case 14 ..< 16: return GradeColor.veryGood
        case 12 ..< 14: return GradeColor.good
        case passingGrade ..< 12: return GradeColor.average
        default: return GradeColor.failure
        }
    }

    func validationErrorMessage(for input: String) -> String {
        input.isEmpty ? String(localized: "error_enter_grade") :
            String(localized: "error_grade_range_0_20")
    }

    func coefficientErrorMessage(for input: String) -> String {
        input.isEmpty ? String(localized: "error_enter_coefficient") :
            String(localized: "error_coefficient_range")
    }

    func displayGrade(_ grade: Double, compact _: Bool) -> String {
        format(grade)
    }
}

struct SpanishSystem: GradingSystemPlugin {
    let id = "spain"

    var label: String { String(localized: "grading_spain_label") }
    var description: String { String(localized: "grading_spain_description") }
    var coefLabel: String { String(localized: "field_coefficient") }
    var placeholder: String { String(localized: "field_optional") }
    var averageLabel: String { String(localized: "grading_france_average") }
    var systemName: String { String(localized: "grading_spain_system_name") }

    let min: Double = 0
    let max: Double = 10
    let suffix = ""
    let passingGrade: Double = 5.0
    let gradeUnit = "/10"
    let decimalPlaces = 1
    let usesLetterGrades = false
    let isInverted = false

    func format(_ grade: Double) -> String {
        guard grade != NO_GRADE else { return "—" }
        return "\(formatNumber(grade, places: decimalPlaces))\(suffix)"
    }

    func weightedAverage(_ evaluations: [DummyEvaluation]) -> Double {
        let validEvaluations = evaluations.filter { $0.grade != NO_GRADE }
        guard !validEvaluations.isEmpty else { return NO_GRADE }

        let totalWeightedGrades = validEvaluations.reduce(0.0) { $0 + ($1.grade * $1.coefficient) }
        let totalCoefficients = validEvaluations.reduce(0.0) { $0 + $1.coefficient }

        guard totalCoefficients > 0 else { return NO_GRADE }
        return (totalWeightedGrades / totalCoefficients).rounded(toPlaces: decimalPlaces)
    }

    func validate(_ grade: Double) -> Bool {
        return grade >= min && grade <= max
    }

    func validateCoefficient(_ coeff: Double) -> Bool {
        return coeff >= MIN_COEFF && coeff <= MAX_COEFF
    }

    func parse(_ input: String) -> Double? {
        guard let val = parseDecimalInput(input.replacingOccurrences(of: suffix, with: "")) else { return nil }
        return validate(val) ? val.rounded(toPlaces: decimalPlaces) : nil
    }

    func gradeColor(for grade: Double) -> Color {
        guard grade != NO_GRADE else { return GradeColor.noGrade }

        switch grade {
        case 9 ... 10: return GradeColor.excellent
        case 7 ..< 9: return GradeColor.veryGood
        case 6 ..< 7: return GradeColor.good
        case 5 ..< 6: return GradeColor.average
        default: return GradeColor.failure
        }
    }

    func validationErrorMessage(for input: String) -> String {
        input.isEmpty ? String(localized: "error_enter_grade") :
            String(localized: "error_grade_range_0_10")
    }

    func coefficientErrorMessage(for input: String) -> String {
        input.isEmpty ? String(localized: "error_enter_coefficient") :
            String(localized: "error_coefficient_range")
    }

    func displayGrade(_ grade: Double, compact _: Bool) -> String {
        format(grade)
    }
}

struct CanadianSystem: GradingSystemPlugin {
    let id = "canada"

    var label: String { String(localized: "grading_canada_label") }
    var description: String { String(localized: "grading_canada_description") }
    var coefLabel: String { String(localized: "field_credits") }
    var placeholder: String { String(localized: "field_optional") }
    var averageLabel: String { String(localized: "grading_canada_average") }
    var systemName: String { String(localized: "grading_canada_system_name") }

    let min: Double = 0.0
    let max: Double = 4.0
    let suffix = ""
    let passingGrade: Double = 2.0
    let gradeUnit = " GPA"
    let decimalPlaces = 2
    let usesLetterGrades = false
    let isInverted = false

    func format(_ grade: Double) -> String {
        guard grade != NO_GRADE else { return "—" }
        return "\(formatNumber(grade, places: decimalPlaces))\(suffix)"
    }

    func weightedAverage(_ evaluations: [DummyEvaluation]) -> Double {
        let validEvaluations = evaluations.filter { $0.grade != NO_GRADE }
        guard !validEvaluations.isEmpty else { return NO_GRADE }

        let totalWeightedGrades = validEvaluations.reduce(0.0) { $0 + ($1.grade * $1.coefficient) }
        let totalCoefficients = validEvaluations.reduce(0.0) { $0 + $1.coefficient }

        guard totalCoefficients > 0 else { return NO_GRADE }
        return (totalWeightedGrades / totalCoefficients).rounded(toPlaces: decimalPlaces)
    }

    func validate(_ grade: Double) -> Bool {
        return grade >= min && grade <= max
    }

    func validateCoefficient(_ coeff: Double) -> Bool {
        return coeff >= MIN_COEFF && coeff <= MAX_COEFF
    }

    func parse(_ input: String) -> Double? {
        guard let val = parseDecimalInput(input.replacingOccurrences(of: suffix, with: "")) else { return nil }
        return validate(val) ? val.rounded(toPlaces: decimalPlaces) : nil
    }

    func gradeColor(for grade: Double) -> Color {
        guard grade != NO_GRADE else { return GradeColor.noGrade }

        switch grade {
        case 3.7 ... 4.0: return GradeColor.excellent
        case 3.0 ..< 3.7: return GradeColor.veryGood
        case 2.3 ..< 3.0: return GradeColor.good
        case 2.0 ..< 2.3: return GradeColor.average
        case 1.0 ..< 2.0: return GradeColor.failure
        default: return GradeColor.failure
        }
    }

    func validationErrorMessage(for input: String) -> String {
        input.isEmpty ? String(localized: "error_enter_gpa") :
            String(localized: "error_gpa_range_0_4")
    }

    func coefficientErrorMessage(for input: String) -> String {
        input.isEmpty ? String(localized: "error_enter_coefficient") :
            String(localized: "error_coefficient_range")
    }

    func displayGrade(_ grade: Double, compact _: Bool) -> String {
        format(grade)
    }
}

struct GermanSystem: GradingSystemPlugin {
    let id = "germany"

    var label: String { String(localized: "grading_germany_label") }
    var description: String { String(localized: "grading_germany_description") }
    var coefLabel: String { String(localized: "field_ects_points") }
    var placeholder: String { String(localized: "field_optional") }
    var averageLabel: String { String(localized: "grading_germany_average") }
    var systemName: String { String(localized: "grading_germany_system_name") }

    let min: Double = 1.0
    let max: Double = 5.0
    let suffix = ""
    let passingGrade: Double = 4.0
    let gradeUnit = ""
    let decimalPlaces = 1
    let usesLetterGrades = false
    let isInverted = true

    func format(_ grade: Double) -> String {
        guard grade != NO_GRADE else { return "—" }
        return formatNumber(grade, places: decimalPlaces)
    }

    func weightedAverage(_ evaluations: [DummyEvaluation]) -> Double {
        let validEvaluations = evaluations.filter { $0.grade != NO_GRADE }
        guard !validEvaluations.isEmpty else { return NO_GRADE }

        let totalWeightedGrades = validEvaluations.reduce(0.0) { $0 + ($1.grade * $1.coefficient) }
        let totalCoefficients = validEvaluations.reduce(0.0) { $0 + $1.coefficient }

        guard totalCoefficients > 0 else { return NO_GRADE }
        return (totalWeightedGrades / totalCoefficients).rounded(toPlaces: decimalPlaces)
    }

    func validate(_ grade: Double) -> Bool {
        return grade >= min && grade <= max
    }

    func validateCoefficient(_ coeff: Double) -> Bool {
        return coeff >= MIN_COEFF && coeff <= 8.0
    }

    func parse(_ input: String) -> Double? {
        guard let val = parseDecimalInput(input) else { return nil }
        return validate(val) ? val : nil
    }

    func gradeColor(for grade: Double) -> Color {
        guard grade != NO_GRADE else { return GradeColor.noGrade }

        switch grade {
        case 1.0 ... 1.5: return GradeColor.excellent
        case 1.6 ... 2.5: return GradeColor.veryGood
        case 2.6 ... 3.5: return GradeColor.good
        case 3.6 ... 4.0: return GradeColor.average
        default: return GradeColor.failure
        }
    }

    func validationErrorMessage(for input: String) -> String {
        input.isEmpty ? String(localized: "error_enter_grade") :
            String(localized: "error_german_grades")
    }

    func coefficientErrorMessage(for input: String) -> String {
        input.isEmpty ? String(localized: "error_enter_coefficient") :
            String(localized: "error_ects_range")
    }

    func displayGrade(_ grade: Double, compact _: Bool) -> String {
        format(grade)
    }
}

struct USASystem: GradingSystemPlugin {
    let id = "usa"

    var label: String { String(localized: "grading_usa_label") }
    var description: String { String(localized: "grading_usa_description") }
    var coefLabel: String { String(localized: "field_credits") }
    var placeholder: String { String(localized: "field_optional") }
    var averageLabel: String { String(localized: "grading_canada_average") }
    var systemName: String { String(localized: "grading_usa_system_name") }

    let min: Double = 0
    let max: Double = 4
    let suffix = ""
    let passingGrade: Double = 2.0
    let gradeUnit = "GPA"
    let decimalPlaces = 2
    let usesLetterGrades = false
    let isInverted = false

    func format(_ grade: Double) -> String {
        guard grade != NO_GRADE else { return "—" }
        return formatNumber(grade, places: decimalPlaces)
    }

    func weightedAverage(_ evaluations: [DummyEvaluation]) -> Double {
        let validEvaluations = evaluations.filter { $0.grade != NO_GRADE }
        guard !validEvaluations.isEmpty else { return NO_GRADE }

        let totalWeightedGrades = validEvaluations.reduce(0.0) { $0 + ($1.grade * $1.coefficient) }
        let totalCoefficients = validEvaluations.reduce(0.0) { $0 + $1.coefficient }

        guard totalCoefficients > 0 else { return NO_GRADE }
        return (totalWeightedGrades / totalCoefficients).rounded(toPlaces: decimalPlaces)
    }

    func validate(_ grade: Double) -> Bool {
        return grade >= min && grade <= max
    }

    func validateCoefficient(_ coeff: Double) -> Bool {
        return coeff >= MIN_COEFF && coeff <= 8.0
    }

    func parse(_ input: String) -> Double? {
        guard let val = parseDecimalInput(input) else { return nil }
        let rounded = val.rounded(toPlaces: decimalPlaces)
        return validate(rounded) ? rounded : nil
    }

    func gradeColor(for grade: Double) -> Color {
        guard grade != NO_GRADE else { return GradeColor.noGrade }

        switch grade {
        case 3.7 ... 4.0: return GradeColor.excellent
        case 3.0 ..< 3.7: return GradeColor.veryGood
        case 2.3 ..< 3.0: return GradeColor.good
        case 2.0 ..< 2.3: return GradeColor.average
        default: return GradeColor.failure
        }
    }

    func validationErrorMessage(for input: String) -> String {
        input.isEmpty ? String(localized: "error_enter_grade") :
            String(localized: "error_gpa_range_0_4")
    }

    func coefficientErrorMessage(for input: String) -> String {
        input.isEmpty ? String(localized: "error_enter_credits") :
            String(localized: "error_credits_range_05_8")
    }

    func displayGrade(_ grade: Double, compact _: Bool) -> String {
        format(grade)
    }
}

// Registre des systèmes
enum GradingSystemRegistry {
    private static let queue = DispatchQueue(label: "grading.system.queue", qos: .userInitiated)
    private static var _cachedActiveSystem: GradingSystemPlugin?
    private static var _lastSystemId: String?

    private static let _available: [GradingSystemPlugin] = [
        FrenchSystem(), USASystem(), GermanSystem(), SpanishSystem(), CanadianSystem(),
    ]

    static var available: [GradingSystemPlugin] {
        queue.sync { _available }
    }

    static var active: GradingSystemPlugin {
        let currentId = UserDefaults.standard.string(forKey: "GradingSystem") ?? "france"
        print("🔍 [REGISTRY] Lecture UserDefaults: '\(currentId)'")

        if _lastSystemId != currentId {
            print("🔄 [REGISTRY] Changement détecté: '\(_lastSystemId ?? "nil")' → '\(currentId)'")
            _cachedActiveSystem = nil
            _lastSystemId = currentId
        }

        if let cached = _cachedActiveSystem {
            print("💾 [REGISTRY] Utilisation cache: '\(cached.id)'")
            return cached
        }

        let system = _available.first { $0.id == currentId } ?? _available.first!
        print("✅ [REGISTRY] Système actif final: '\(system.id)'")
        _cachedActiveSystem = system
        return system
    }

    static func setActiveSystem(id: String) {
        print("🎯 [REGISTRY] ⚠️ APPEL setActiveSystem avec: '\(id)'")

        print("🎯 [REGISTRY] Stack trace:")
        for symbol in Thread.callStackSymbols.prefix(8) {
            if symbol.contains("PARALLAX") || symbol.contains("Gradefy") {
                print("    📍 \(symbol)")
            }
        }

        queue.async {
            let oldValue = UserDefaults.standard.string(forKey: "GradingSystem") ?? "nil"
            print("📝 [REGISTRY] UserDefaults AVANT setActiveSystem: '\(oldValue)'")

            UserDefaults.standard.set(id, forKey: "GradingSystem")

            let newValue = UserDefaults.standard.string(forKey: "GradingSystem") ?? "nil"
            print("✅ [REGISTRY] UserDefaults APRÈS setActiveSystem: '\(newValue)'")

            _cachedActiveSystem = nil
            _lastSystemId = nil
        }
    }

    static func invalidateCache() {
        queue.async {
            _cachedActiveSystem = nil
            _lastSystemId = nil
        }
    }
}
