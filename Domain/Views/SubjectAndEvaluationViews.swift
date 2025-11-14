//
// SubjectsAndGrading.swift
// PARALLAX
//
// Created by on 6/28/25.
//

import Foundation
import SwiftUI
import CoreData

struct SubjectRow: View {
    let subject: Subject
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
                    if gradingSystem.id == "usa" || gradingSystem.id == "canada" {
                        Text("Credit Hours \(formatCoefficientClean(subject.creditHours))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(gradingSystem.coefLabel) \(formatCoefficientClean(subject.coefficient))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if subject.currentGrade == NO_GRADE {  // ✅ Utilise subject.currentGrade
                Text("--")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.secondary)
            } else if gradingSystem.validate(subject.currentGrade) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(gradingSystem.format(subject.currentGrade))
                        .font(.title3.weight(.semibold))
                        .foregroundColor(gradingSystem.gradeColor(for: subject.currentGrade))
                }
            } else {
                Text(gradingSystem.format(subject.currentGrade))
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.red)
            }
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onEdit()
            } label: {
                Label(String(localized: "action_modify"), systemImage: "pencil")
            }
            .tint(.blue)
            
            Button(role: .none) {
                withAnimation(.none) {
                    onDelete()
                }
            } label: {
                Label(String(localized: "action_delete"), systemImage: "trash")
                    .foregroundColor(.red)
            }
            .tint(.red)
        }
    }
}

struct SubjectDetailView: View {
    @ObservedObject var subjectObject: Subject
    @Binding var showingProfileSheet: Bool
    @Environment(\.managedObjectContext) private var viewContext
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    private var evaluations: [Evaluation] {
        let set = subjectObject.evaluations as? Set<Evaluation> ?? []
        return set.sorted {
            ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast)
        }
    }
    
    @State private var showingAddEvaluation = false
    @State private var evaluationToEdit: Evaluation?
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(subjectObject.name ?? "")
                                .font(.title.bold())
                            
                            if gradingSystem.id == "usa" || gradingSystem.id == "canada" {
                                Text("Credit Hours \(upToTwoDecimals(subjectObject.creditHours))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(gradingSystem.coefLabel) \(upToTwoDecimals(subjectObject.coefficient))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack {
                            if subjectObject.currentGrade != NO_GRADE {  // ✅ Utilise subjectObject.currentGrade
                                Text(gradingSystem.format(subjectObject.currentGrade))
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(gradingSystem.gradeColor(for: subjectObject.currentGrade))
                            } else {
                                Text("--")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            
            Section(String(localized: "section_evaluations")) {
                if evaluations.isEmpty {
                    Text(String(localized: "no_evaluations"))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(evaluations, id: \.id) { evaluation in
                        evaluationRow(evaluation)
                    }
                    .onDelete { offsets in
                        deleteEvaluationsOptimized(offsets: offsets, in: evaluations)
                    }
                }
            }
        }
        .navigationTitle(subjectObject.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "action_add")) {
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
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if evaluation.grade != NO_GRADE && gradingSystem.validate(evaluation.grade) {
                    Text(gradingSystem.format(evaluation.grade))
                        .font(.title3.bold())
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
                
                // ✅ Vérifier s'il reste des évaluations valides
                let remainingEvaluations = subject?.evaluations?.allObjects as? [Evaluation] ?? []
                let validEvaluations = remainingEvaluations.filter { $0.grade != NO_GRADE }
                
                if validEvaluations.isEmpty {
                    // ✅ Plus d'évaluations → remettre la note à NO_GRADE
                    subject?.grade = NO_GRADE
                } else {
                    // ✅ Recalculer la moyenne normalement
                    subject?.recalculateAverageOptimized(context: viewContext)
                }
                
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
                
                // ✅ Vérifier s'il reste des évaluations valides
                let remainingEvaluations = subject?.evaluations?.allObjects as? [Evaluation] ?? []
                let validEvaluations = remainingEvaluations.filter { $0.grade != NO_GRADE }
                
                if validEvaluations.isEmpty {
                    // ✅ Plus d'évaluations → remettre la note à NO_GRADE
                    subject?.grade = NO_GRADE
                } else {
                    // ✅ Recalculer la moyenne normalement
                    subject?.recalculateAverageOptimized(context: viewContext)
                }
                
                try viewContext.save()
            } catch {
                viewContext.rollback()
                print("❌ Erreur suppression évaluations: \(error)")
            }
        }
    }
}

// MARK: - Vues d'ajout/modification
struct AddEvaluationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subject: Subject
    @State private var title = ""
    @State private var gradeInput = ""
    @State private var coefficientInput = ""
    @State private var errorMessage: String = ""
    @State private var showAlert: Bool = false
    
    @FocusState private var isTitleFocused: Bool
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    private func isDuplicateEvaluationTitle(_ title: String) -> Bool {
        let existingTitles = subject.evaluations?.compactMap { ($0 as? Evaluation)?.title?.lowercased() } ?? []
        return existingTitles.contains(title.lowercased())
    }
    
    private var isFormValid: Bool {
        let titleValid = !title.trimmingCharacters(in: .whitespaces).isEmpty
        let coefficientValid = !coefficientInput.isEmpty
        return titleValid && coefficientValid && !gradeInput.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                titleSection
                gradeSection
                coefficientSection
            }
            .navigationTitle(String(localized: "nav_add_evaluation"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isTitleFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action_cancel")) { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action_save")) {
                        saveEvaluation()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(String(localized: "alert_error")),
                    message: Text(errorMessage),
                    dismissButton: .default(Text(String(localized: "alert_ok")))
                )
            }
        }
    }
    
    private var titleSection: some View {
        Section(String(localized: "field_name")) {
            TextField(String(localized: "field_required"), text: $title)
                .focused($isTitleFocused)
        }
    }
    
    private var gradeSection: some View {
        Section(String(localized: "field_grade")) {
            TextField(String(localized: "field_required"), text: $gradeInput)
                .keyboardType(PARALLAX.keyboardType(for: gradingSystem))
        }
    }
    
    private var coefficientSection: some View {
        Section(gradingSystem.coefLabel) {
            TextField(String(localized: "field_required"), text: $coefficientInput)
                .keyboardType(.decimalPad)
        }
    }
    
    private func saveEvaluation() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else {
            errorMessage = String(localized: "error_empty_name")
            showAlert = true
            return
        }
        
        guard !isDuplicateEvaluationTitle(cleanTitle) else {
            errorMessage = String(localized: "error_evaluation_duplicate")
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
                errorMessage = String(localized: "error_invalid_grade_system").replacingOccurrences(of: "%@", with: gradingSystem.systemName)
                showAlert = true
                return
            }
            
            finalGrade = grade
        } else {
            errorMessage = String(localized: "error_grade_required_past")
            showAlert = true
            return
        }
        
        guard let coefficient = parseDecimalInput(coefficientInput),
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
                newEvaluation.date = Date() // ✅ AJOUTER cette ligne
                newEvaluation.subject = subject
                
                try viewContext.save()
                
                if finalGrade != NO_GRADE {
                    subject.recalculateAverageOptimized(context: viewContext, autoSave: true)
                }
                
                dismiss()
            } catch {
                viewContext.rollback()
                errorMessage = String(localized: "error_save").replacingOccurrences(of: "%@", with: error.localizedDescription)
                showAlert = true
            }
        }
    }
    
    private func isGradeValidForSystem(_ grade: Double, system: GradingSystemPlugin) -> Bool {
        switch system.id {
        case "germany":
            return grade >= 1.0 && grade <= 5.0
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
    @State private var errorMessage: String = ""
    @State private var showAlert: Bool = false
    
    @FocusState private var isTitleFocused: Bool
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    private func isDuplicateEvaluationTitle(_ title: String) -> Bool {
        let currentEvaluationID = evaluation.id
        let existingTitles = evaluation.subject?.evaluations?.compactMap { evalObj -> String? in
            guard let eval = evalObj as? Evaluation,
                  eval.id != currentEvaluationID,  // ✅ Compare par ID au lieu de l'objet
                  let evalTitle = eval.title else { return nil }
            return evalTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        } ?? []
        
        let cleanTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return existingTitles.contains(cleanTitle)
    }
    
    private var isFormValid: Bool {
        let titleValid = !title.trimmingCharacters(in: .whitespaces).isEmpty
        let coefficientValid = !coefficientInput.isEmpty
        return titleValid && coefficientValid && !gradeInput.isEmpty
    }
    
    init(evaluation: Evaluation) {
        self.evaluation = evaluation
        let system = GradingSystemRegistry.active
        
        _title = State(initialValue: evaluation.title ?? "")
        _coefficientInput = State(initialValue: formatCoefficientClean(evaluation.coefficient))
        _gradeInput = State(initialValue: {
            if evaluation.grade == NO_GRADE {
                return ""
            } else {
                return formatNumber(evaluation.grade, places: system.decimalPlaces)
            }
        }())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                titleSection
                gradeSection
                coefficientSection
            }
            .navigationTitle(String(localized: "nav_edit_evaluation"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isTitleFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action_cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action_save")) {
                        saveEvaluation()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(String(localized: "alert_error")),
                    message: Text(errorMessage),
                    dismissButton: .default(Text(String(localized: "alert_ok")))
                )
            }
        }
    }
    
    private var titleSection: some View {
        Section(String(localized: "field_name")) {
            TextField(String(localized: "field_required"), text: $title)
                .focused($isTitleFocused)
        }
    }
    
    private var gradeSection: some View {
        Section(String(localized: "field_grade")) {
            TextField(String(localized: "field_required"), text: $gradeInput)
                .keyboardType(PARALLAX.keyboardType(for: gradingSystem))
        }
    }
    
    private var coefficientSection: some View {
        Section(gradingSystem.coefLabel) {
            TextField(String(localized: "field_required"), text: $coefficientInput)
                .keyboardType(.decimalPad)
        }
    }
    
    private func saveEvaluation() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else {
            errorMessage = String(localized: "error_empty_name")
            showAlert = true
            return
        }
        
        guard !isDuplicateEvaluationTitle(cleanTitle) else {
            errorMessage = String(localized: "error_evaluation_duplicate")
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
                errorMessage = String(localized: "error_invalid_grade_system").replacingOccurrences(of: "%@", with: gradingSystem.systemName)
                showAlert = true
                return
            }
            
            finalGrade = grade
        } else {
            errorMessage = String(localized: "error_grade_required_past")
            showAlert = true
            return
        }
        
        guard let coefficient = parseDecimalInput(coefficientInput),
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
                
                try viewContext.save()
                evaluation.subject?.recalculateAverageOptimized(context: viewContext, autoSave: true)
                dismiss()
            } catch {
                viewContext.rollback()
                errorMessage = String(localized: "error_save").replacingOccurrences(of: "%@", with: error.localizedDescription)
                showAlert = true
            }
        }
    }
    
    private func isGradeValidForSystem(_ grade: Double, system: GradingSystemPlugin) -> Bool {
        switch system.id {
        case "germany":
            return grade >= 1.0 && grade <= 5.0
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
    @State private var weightInput = "1"
    @State private var creditHoursInput = "3"
    @FocusState private var isNameFieldFocused: Bool
    @State private var errorMessage: String = ""
    @State private var showAlert: Bool = false
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "section_information")) {
                    HStack {
                        Text(String(localized: "field_name"))
                        Spacer()
                        TextField(String(localized: "field_required"), text: $subjectName)
                            .multilineTextAlignment(.trailing)
                            .focused($isNameFieldFocused)
                    }
                    
                    if gradingSystem.id == "usa" || gradingSystem.id == "canada" {
                        HStack {
                            Text("Credit Hours")
                            Spacer()
                            TextField(String(localized: "field_required"), text: $creditHoursInput)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    } else {
                        HStack {
                            Text(gradingSystem.coefLabel)
                            Spacer()
                            TextField(String(localized: "field_required"), text: $weightInput)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                Section(String(localized: "section_period")) {
                    Text(selectedPeriod)
                }
            }
            .navigationTitle(String(localized: "nav_add_subject"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                DispatchQueue.main.async {
                    isNameFieldFocused = true
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(String(localized: "alert_error")),
                    message: Text(errorMessage),
                    dismissButton: .default(Text(String(localized: "alert_ok")))
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action_cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action_add")) {
                        addSubject()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        let nameValid = !subjectName.trimmingCharacters(in: .whitespaces).isEmpty
        if gradingSystem.id == "usa" || gradingSystem.id == "canada" {
            return nameValid && !creditHoursInput.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return nameValid && !weightInput.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
    
    private func addSubject() {
        let cleanName = subjectName.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else {
            errorMessage = String(localized: "error_empty_name")
            showAlert = true
            return
        }
        
        let finalWeight: Double
        let finalCreditHours: Double
        
        if gradingSystem.id == "usa" || gradingSystem.id == "canada" {
            guard let creditHours = parseDecimalInput(creditHoursInput) else {
                errorMessage = String(localized: "error_enter_credits")
                showAlert = true
                return
            }
            
            guard creditHours >= MIN_COEFF && creditHours <= 8.0 else {
                errorMessage = String(localized: "error_credits_range_05_8")
                showAlert = true
                return
            }
            
            finalWeight = 1.0
            finalCreditHours = creditHours
        } else {
            guard let weight = parseDecimalInput(weightInput) else {
                errorMessage = gradingSystem.coefficientErrorMessage(for: weightInput)
                showAlert = true
                return
            }
            
            guard gradingSystem.validateCoefficient(weight) else {
                errorMessage = gradingSystem.coefficientErrorMessage(for: weightInput)
                showAlert = true
                return
            }
            
            finalWeight = weight
            finalCreditHours = 3.0
        }
        
        let subjectData = SubjectData(
            code: "",
            name: cleanName,
            grade: 0.0,
            coefficient: finalWeight,
            creditHours: finalCreditHours,
            periodName: selectedPeriod
        )
        
        onAdd(subjectData)
        dismiss()
    }
}

struct EditSubjectView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subject: Subject
    
    @State private var subjectName: String
    @State private var weightInput: String
    @State private var creditHoursInput: String
    @FocusState private var isNameFieldFocused: Bool
    @State private var errorMessage = ""
    @State private var showAlert = false
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    init(subject: Subject) {
        self.subject = subject
        _subjectName = State(initialValue: subject.name ?? "")
        _weightInput = State(initialValue: {
            if subject.coefficient <= 0 {
                return "1"
            } else {
                return formatCoefficientClean(subject.coefficient)
            }
        }())
        _creditHoursInput = State(initialValue: {
            if subject.creditHours <= 0 {
                return "3"
            } else {
                return formatCoefficientClean(subject.creditHours)
            }
        }())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "section_information")) {
                    HStack {
                        Text(String(localized: "field_name"))
                        Spacer()
                        TextField(String(localized: "field_required"), text: $subjectName)
                            .multilineTextAlignment(.trailing)
                            .focused($isNameFieldFocused)
                    }
                    
                    if gradingSystem.id == "usa" || gradingSystem.id == "canada" {
                        HStack {
                            Text("Credit Hours")
                            Spacer()
                            TextField(String(localized: "field_required"), text: $creditHoursInput)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    } else {
                        HStack {
                            Text(gradingSystem.coefLabel)
                            Spacer()
                            TextField(String(localized: "field_required"), text: $weightInput)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "nav_edit_subject"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                DispatchQueue.main.async {
                    isNameFieldFocused = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action_cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action_save")) {
                        save()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert(String(localized: "alert_error"), isPresented: $showAlert, actions: {}) {
                Text(errorMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        let nameValid = !subjectName.trimmingCharacters(in: .whitespaces).isEmpty
        if gradingSystem.id == "usa" || gradingSystem.id == "canada" {
            return nameValid && !creditHoursInput.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return nameValid && !weightInput.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
    
    private func save() {
        let cleanName = subjectName.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else {
            errorMessage = String(localized: "error_empty_name")
            showAlert = true
            return
        }
        
        subject.name = cleanName
        
        if gradingSystem.id == "usa" || gradingSystem.id == "canada" {
            guard let creditHours = parseDecimalInput(creditHoursInput),
                  creditHours > 0 else {
                showAlert = true
                return
            }
            
            subject.creditHours = creditHours
        } else {
            guard let weight = parseDecimalInput(weightInput),
                  weight > 0 && gradingSystem.validateCoefficient(weight) else {
                errorMessage = gradingSystem.coefficientErrorMessage(for: weightInput)
                showAlert = true
                return
            }
            
            subject.coefficient = weight
        }
        
        subject.lastModified = Date()
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            viewContext.rollback()
            errorMessage = String(localized: "error_save").replacingOccurrences(of: "%@", with: error.localizedDescription)
            showAlert = true
        }
    }
}
