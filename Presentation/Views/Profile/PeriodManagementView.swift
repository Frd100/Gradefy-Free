//
//  PeriodManagementView.swift
//  PARALLAX
//
//  Created by  on 7/21/25.
//
import Combine
import CoreData
import Foundation
import Lottie
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WidgetKit

struct PeriodManagementView: View {
    @Binding var refreshID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: Period.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Period.startDate, ascending: true)]
    ) private var periods: FetchedResults<Period>

    @State private var showingAddPeriod = false
    @State private var periodToEdit: Period?
    @State private var showLastPeriodAlert = false
    @State private var periodToDelete: Period?
    @State private var showDeleteAlert = false

    var body: some View {
        List {
            if periods.isEmpty {
                emptyStateSection
            } else {
                periodsSection
            }
        }
        .navigationTitle(String(localized: "nav_periods"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String(localized: "action_add")) {
                    HapticFeedbackManager.shared.impact(style: .light)
                    showingAddPeriod = true
                }
            }
        }
        .sheet(isPresented: $showingAddPeriod) {
            AddPeriodSheet { name, startDate, endDate in
                addPeriod(name: name, startDate: startDate, endDate: endDate)
            }
        }
        .sheet(item: $periodToEdit) { period in
            EditPeriodSheet(period: period) {
                refreshID = UUID()
            }
        }
        .alert(String(localized: "alert_delete_impossible"), isPresented: $showLastPeriodAlert) {
            Button(String(localized: "alert_ok"), role: .cancel) {
                HapticFeedbackManager.shared.notification(type: .warning)
            }
        } message: {
            Text(String(localized: "alert_keep_one_period"))
        }
        .alert(String(localized: "alert_delete_period"), isPresented: $showDeleteAlert) {
            Button(String(localized: "action_delete"), role: .destructive) {
                if let period = periodToDelete {
                    deletePeriod(period)
                }
            }
            Button(String(localized: "action_cancel"), role: .cancel) {}
        } message: {
            if let period = periodToDelete {
                Text(String(localized: "alert_delete_period_message").replacingOccurrences(of: "%@", with: period.name ?? ""))
            }
        }
    }

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)

                Text(String(localized: "empty_no_periods"))
                    .font(.title2.weight(.semibold))

                Text(String(localized: "empty_periods_description"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        }
        .listRowBackground(Color.clear)
    }

    private var periodsSection: some View {
        Section(String(localized: "section_academic_periods")) {
            ForEach(periods, id: \.id) { period in
                PeriodRowView(
                    period: period,
                    onEdit: {
                        HapticFeedbackManager.shared.impact(style: .light)
                        periodToEdit = period
                    },
                    onDelete: {
                        HapticFeedbackManager.shared.impact(style: .medium)
                        periodToDelete = period
                        let currentPeriodsCount = periods.count
                        if currentPeriodsCount <= 1 {
                            showLastPeriodAlert = true
                        } else {
                            showDeleteAlert = true
                        }
                    }
                )
            }
        }
    }

    // ✅ CORRECTION : Opération Core Data async
    private func addPeriod(name: String, startDate: Date, endDate: Date) {
        Task {
            do {
                try await viewContext.perform {
                    let newPeriod = Period(context: self.viewContext)
                    newPeriod.id = UUID()
                    newPeriod.name = name
                    newPeriod.startDate = startDate
                    newPeriod.endDate = endDate

                    try self.viewContext.save()
                }

                await MainActor.run {
                    refreshID = UUID()
                    HapticFeedbackManager.shared.notification(type: .success)
                    print("Période créée : \(name)")
                }
            } catch {
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .error)
                    print("Erreur lors de la création de la période : \(error)")
                }
            }
        }
    }

    private func deletePeriod(_ period: Period) {
        let periodsCount = periods.count
        guard periodsCount > 1 else {
            showLastPeriodAlert = true
            return
        }

        // 🆕 NOUVEAU : Vérifier si c'est la période active qui va être supprimée
        let isActivePeriod = isCurrentlyActivePeriod(period)

        Task {
            do {
                try await viewContext.perform {
                    let subjects = (period.subjects as? Set<Subject>) ?? []
                    for subject in subjects {
                        let evaluations = (subject.evaluations as? Set<Evaluation>) ?? []
                        for evaluation in evaluations {
                            self.viewContext.delete(evaluation)
                        }
                        self.viewContext.delete(subject)
                    }

                    self.viewContext.delete(period)
                    try self.viewContext.save()
                }

                await MainActor.run {
                    // 🆕 NOUVEAU : Si c'était la période active, en sélectionner une autre
                    if isActivePeriod {
                        selectNewActivePeriod(excluding: period)
                    }

                    refreshID = UUID()
                    HapticFeedbackManager.shared.notification(type: .success)
                    print("Période supprimée : \(period.name ?? "")")
                }
            } catch {
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .error)
                    print("Erreur lors de la suppression de la période : \(error)")
                }
            }
        }
    }

    // 🆕 NOUVEAU : Fonction pour vérifier si c'est la période active
    private func isCurrentlyActivePeriod(_ period: Period) -> Bool {
        let currentActivePeriodID = UserDefaults.standard.string(forKey: "activePeriodID") ?? ""
        return period.id?.uuidString == currentActivePeriodID
    }

    // 🆕 NOUVEAU : Fonction pour sélectionner automatiquement une nouvelle période
    private func selectNewActivePeriod(excluding excludedPeriod: Period) {
        // Trouver la première période disponible (autre que celle supprimée)
        if let newActivePeriod = periods.first(where: { $0.id != excludedPeriod.id }) {
            // Mettre à jour la période active dans UserDefaults
            UserDefaults.standard.set(newActivePeriod.id?.uuidString ?? "", forKey: "activePeriodID")
            UserDefaults.standard.synchronize()

            // Envoyer une notification pour informer les autres vues
            NotificationCenter.default.post(
                name: .activePeriodChanged,
                object: nil,
                userInfo: ["newPeriodID": newActivePeriod.id?.uuidString ?? ""]
            )

            print("🔄 Nouvelle période active sélectionnée : \(newActivePeriod.name ?? "")")
        }
    }
}

// MARK: - Period Row Component

struct PeriodRowView: View {
    let period: Period
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(period.name ?? String(localized: "period_unnamed"))
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let startDate = period.startDate, let endDate = period.endDate {
                        Text("\(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onEdit) {
                Label(String(localized: "action_modify"), systemImage: "pencil")
            }
            .tint(.blue)

            Button(role: .destructive, action: onDelete) {
                Label(String(localized: "action_delete"), systemImage: "trash")
            }
            .tint(.red)
        }
    }
}

// MARK: - Add Period Sheet

struct AddPeriodSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, Date, Date) -> Void

    @State private var periodName = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var showValidationError = false
    @State private var errorMessage = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "section_information")) {
                    TextField(String(localized: "field_name"), text: $periodName)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .focused($isNameFieldFocused)
                }

                Section(String(localized: "section_duration")) {
                    DatePicker(String(localized: "field_start_date"), selection: $startDate, displayedComponents: .date)
                    DatePicker(String(localized: "field_end_date"), selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle(String(localized: "period_add_title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isNameFieldFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action_cancel")) {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action_create")) {
                        validateAndSave()
                    }
                    .disabled(periodName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: startDate) { _, newStartDate in
                if endDate <= newStartDate {
                    endDate = Calendar.current.date(byAdding: .month, value: 1, to: newStartDate) ?? newStartDate
                }
            }
            .alert(String(localized: "alert_error"), isPresented: $showValidationError) {
                Button(String(localized: "alert_ok"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func validateAndSave() {
        let trimmedName = periodName.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            errorMessage = String(localized: "error_period_name_required")
            showValidationError = true
            HapticFeedbackManager.shared.notification(type: .error)
            return
        }

        guard endDate > startDate else {
            errorMessage = String(localized: "error_end_date_after_start")
            showValidationError = true
            HapticFeedbackManager.shared.notification(type: .error)
            return
        }

        HapticFeedbackManager.shared.impact(style: .medium)
        onSave(trimmedName, startDate, endDate)
        dismiss()
    }
}

// MARK: - Edit Period Sheet

struct EditPeriodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var period: Period
    let onSave: () -> Void

    @State private var periodName: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var showValidationError = false
    @State private var errorMessage = ""
    @FocusState private var isNameFieldFocused: Bool

    init(period: Period, onSave: @escaping () -> Void) {
        self.period = period
        self.onSave = onSave

        _periodName = State(initialValue: period.name ?? "")
        _startDate = State(initialValue: period.startDate ?? Date())
        _endDate = State(initialValue: period.endDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "section_information")) {
                    TextField(String(localized: "field_name"), text: $periodName)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .focused($isNameFieldFocused)
                }

                Section(String(localized: "section_duration")) {
                    DatePicker(String(localized: "field_start_date"), selection: $startDate, displayedComponents: .date)
                    DatePicker(String(localized: "field_end_date"), selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle(String(localized: "period_edit_title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isNameFieldFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action_cancel")) {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action_save")) {
                        validateAndSave()
                    }
                    .disabled(periodName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: startDate) { _, newStartDate in
                if endDate <= newStartDate {
                    endDate = Calendar.current.date(byAdding: .month, value: 1, to: newStartDate) ?? newStartDate
                }
            }
            .alert(String(localized: "alert_error"), isPresented: $showValidationError) {
                Button(String(localized: "alert_ok"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func validateAndSave() {
        let trimmedName = periodName.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            errorMessage = String(localized: "error_period_name_required")
            showValidationError = true
            HapticFeedbackManager.shared.notification(type: .error)
            return
        }

        guard endDate > startDate else {
            errorMessage = String(localized: "error_end_date_after_start")
            showValidationError = true
            HapticFeedbackManager.shared.notification(type: .error)
            return
        }

        Task {
            do {
                try await viewContext.perform {
                    self.period.name = trimmedName
                    self.period.startDate = startDate
                    self.period.endDate = endDate

                    try self.viewContext.save()
                }

                await MainActor.run {
                    onSave()
                    HapticFeedbackManager.shared.notification(type: .success)
                    print("Période modifiée : \(trimmedName)")
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .error)
                    print("Erreur lors de la modification de la période : \(error)")
                    errorMessage = String(localized: "error_save_failed").replacingOccurrences(of: "%@", with: error.localizedDescription)
                    showValidationError = true
                }
            }
        }
    }
}
