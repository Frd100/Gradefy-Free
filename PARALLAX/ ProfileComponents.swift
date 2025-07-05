//
//  ProfileComponents.swift
//  PARALLAX
//
//  Created by Farid on 6/28/25.
//

import SwiftUI
import CoreData
import UIKit

// MARK: - Haptic Feedback Manager

final class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    @AppStorage("enableHaptics") private var isEnabled: Bool = true
    
    private init() {}
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

// MARK: - AdaptiveImage Component

struct AdaptiveImage: View {
    let lightImageName: String
    let darkImageName: String
    let size: CGSize
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if colorScheme == .light {
                Image(lightImageName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(darkImageName)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size.width, height: size.height)
        .id(colorScheme)
    }
}

// MARK: - Period Management View

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
    
    private var currentCount: Int {
        periods.count
    }
    
    var body: some View {
        NavigationStack {
            List {
                if periods.isEmpty {
                    emptyStateSection
                } else {
                    periodsSection
                }
            }
            .navigationTitle("Périodes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ajouter") {
                        HapticFeedbackManager.shared.impact(style: .light)
                        showingAddPeriod = true
                    }
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
        .alert("Suppression impossible", isPresented: $showLastPeriodAlert) {
            Button("OK", role: .cancel) {
                HapticFeedbackManager.shared.notification(type: .warning)
            }
        } message: {
            Text("Au moins une période doit être conservée.")
        }
        .alert("Supprimer cette période", isPresented: $showDeleteAlert) {
            Button("Supprimer", role: .destructive) {
                if let period = periodToDelete {
                    deletePeriod(period)
                }
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            if let period = periodToDelete {
                Text("La période « \(period.name ?? "") » et toutes ses données associées seront définitivement supprimées.")
            }
        }
    }
    
    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Aucune période")
                    .font(.title2.weight(.semibold))
                
                Text("Organisez vos matières par trimestre ou semestre en créant des périodes.")
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
        Section("Périodes académiques") {
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
                        if currentCount <= 1 {
                            showLastPeriodAlert = true
                        } else {
                            showDeleteAlert = true
                        }
                    }
                )
            }
        }
    }
    
    private func addPeriod(name: String, startDate: Date, endDate: Date) {
        viewContext.performAndWait {
            do {
                let newPeriod = Period(context: viewContext)
                newPeriod.id = UUID()
                newPeriod.name = name
                newPeriod.startDate = startDate
                newPeriod.endDate = endDate
                
                try viewContext.save()
                refreshID = UUID()
                
                HapticFeedbackManager.shared.notification(type: .success)
                print("Période créée : \(name)")
            } catch {
                HapticFeedbackManager.shared.notification(type: .error)
                print("Erreur lors de la création de la période : \(error)")
                viewContext.rollback()
            }
        }
    }
    
    private func deletePeriod(_ period: Period) {
        guard currentCount > 1 else {
            showLastPeriodAlert = true
            return
        }
        
        viewContext.performAndWait {
            do {
                let subjects = (period.subjects as? Set<Subject>) ?? []
                for subject in subjects {
                    let evaluations = (subject.evaluations as? Set<Evaluation>) ?? []
                    for evaluation in evaluations {
                        viewContext.delete(evaluation)
                    }
                    viewContext.delete(subject)
                }
                
                viewContext.delete(period)
                try viewContext.save()
                
                refreshID = UUID()
                HapticFeedbackManager.shared.notification(type: .success)
                
                print("Période supprimée : \(period.name ?? "")")
            } catch {
                HapticFeedbackManager.shared.notification(type: .error)
                print("Erreur lors de la suppression de la période : \(error)")
                viewContext.rollback()
            }
        }
    }
}

// MARK: - ADD PERIOD VIEW

struct AddPeriodView: View {
    let onSave: (String, Date, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var showAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom de la période", text: $name)
                        .textInputAutocapitalization(.words)
                }
                
                Section("Dates") {
                    DatePicker("Date de début", selection: $startDate, displayedComponents: .date)
                    DatePicker("Date de fin", selection: $endDate, displayedComponents: .date)
                }
                
                Section {
                    Text("Les périodes sont triées automatiquement par ordre chronologique.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Nouvelle période")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        savePeriod()
                    }
                    .disabled(name.isEmpty || startDate >= endDate)
                }
            }
            .alert("Erreur", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func savePeriod() {
        guard !name.isEmpty else {
            errorMessage = "Le nom de la période ne peut pas être vide."
            showAlert = true
            return
        }
        
        guard startDate < endDate else {
            errorMessage = "La date de début doit être antérieure à la date de fin."
            showAlert = true
            return
        }
        
        onSave(name, startDate, endDate)
        dismiss()
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
                    Text(period.name ?? "Sans nom")
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
                Label("Modifier", systemImage: "pencil")
            }
            .tint(.blue)
            
            Button(role: .destructive, action: onDelete) {
                Label("Supprimer", systemImage: "trash")
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom de la période", text: $periodName)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                }
                
                Section("Durée") {
                    DatePicker("Date de début", selection: $startDate, displayedComponents: .date)
                    DatePicker("Date de fin", selection: $endDate, displayedComponents: .date)
                }
                
                Section {
                    Text("Exemples : Trimestre 1, Semestre d'automne, Année académique 2024-2025")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Nouvelle période")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { validateAndSave() }
                        .disabled(periodName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: startDate) { _, newStartDate in
                if endDate <= newStartDate {
                    endDate = Calendar.current.date(byAdding: .month, value: 1, to: newStartDate) ?? newStartDate
                }
            }
        }
        .alert("Erreur", isPresented: $showValidationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func validateAndSave() {
        let trimmedName = periodName.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Le nom de la période est requis."
            showValidationError = true
            HapticFeedbackManager.shared.notification(type: .error)
            return
        }
        
        guard endDate > startDate else {
            errorMessage = "La date de fin doit être postérieure à la date de début."
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
    
    init(period: Period, onSave: @escaping () -> Void) {
        self.period = period
        self.onSave = onSave
        self._periodName = State(initialValue: period.name ?? "")
        self._startDate = State(initialValue: period.startDate ?? Date())
        self._endDate = State(initialValue: period.endDate ?? Date())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom de la période", text: $periodName)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                }
                
                Section("Durée") {
                    DatePicker("Date de début", selection: $startDate, displayedComponents: .date)
                    DatePicker("Date de fin", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Modifier la période")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { validateAndSave() }
                        .disabled(periodName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: startDate) { _, newStartDate in
                if endDate <= newStartDate {
                    endDate = Calendar.current.date(byAdding: .month, value: 1, to: newStartDate) ?? newStartDate
                }
            }
        }
        .alert("Erreur", isPresented: $showValidationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func validateAndSave() {
        let trimmedName = periodName.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Le nom de la période est requis."
            showValidationError = true
            HapticFeedbackManager.shared.notification(type: .error)
            return
        }
        
        guard endDate > startDate else {
            errorMessage = "La date de fin doit être postérieure à la date de début."
            showValidationError = true
            HapticFeedbackManager.shared.notification(type: .error)
            return
        }
        
        viewContext.performAndWait {
            do {
                period.name = trimmedName
                period.startDate = startDate
                period.endDate = endDate
                
                try viewContext.save()
                onSave()
                
                HapticFeedbackManager.shared.notification(type: .success)
                print("Période modifiée : \(trimmedName)")
            } catch {
                HapticFeedbackManager.shared.notification(type: .error)
                print("Erreur lors de la modification de la période : \(error)")
                errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
                showValidationError = true
                viewContext.rollback()
            }
        }
        
        dismiss()
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("username") private var username: String = ""
    @AppStorage("profileSubtitle") private var profileSubtitle: String = ""
    @AppStorage("profileGradientStartHex") private var profileGradientStartHex: String = "9BE8F6"
    @AppStorage("profileGradientEndHex") private var profileGradientEndHex: String = "5DD5F4"
    @AppStorage("showAppreciations") private var showAppreciations: Bool = true
    @AppStorage("enableHaptics") private var enableHaptics: Bool = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled: Bool = false
    @AppStorage("GradingSystem") private var selectedGradingSystem: String = "french"
    
    @State private var showingEditProfile = false
    @State private var showingDataManagement = false
    @State private var showingPeriodManagement = false
    @State private var showingSystemSelection = false
    @State private var showingAppIconSelection = false
    @State private var showingShareSheet = false
    @State private var showingAbout = false
    @State private var refreshID = UUID()
    @State private var exportedURL: URL?
    
    private var profileGradient: [Color] {
        [Color(hex: profileGradientStartHex), Color(hex: profileGradientEndHex)]
    }
    
    var body: some View {
        NavigationStack {
            List {
                profileSection
                appearanceSection
                preferencesSection
                systemSection
                dataSection
                aboutSection
            }
            .listSectionSpacing(35)
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.inline)
            .id(refreshID)
            .preferredColorScheme(darkModeEnabled ? .dark : nil)
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileSheet()
        }
        .sheet(isPresented: $showingDataManagement) {
            DataManagementView()
        }
        .sheet(isPresented: $showingPeriodManagement) {
            PeriodManagementView(refreshID: $refreshID)
        }
        .sheet(isPresented: $showingSystemSelection) {
            SystemModeSelectionView(refreshID: $refreshID)
        }
        .sheet(isPresented: $showingAppIconSelection) {
            AppIconSelectionView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportedURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    private var profileSection: some View {
        Section {
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                showingEditProfile = true
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: profileGradient),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 60, height: 60)
                        
                        Text(username.isEmpty ? "" : String(username.prefix(1).uppercased()))
                            .font(.title.weight(.semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(username.isEmpty ? "Configurer le profil" : username)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(profileSubtitle.isEmpty ? "Ajouter une description" : profileSubtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var appearanceSection: some View {
        Section {
            HStack(spacing: 16) { // ← Augmenté de 12 à 16
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.indigo)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "moon.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                    )
                
                Toggle("Mode sombre", isOn: $darkModeEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: darkModeEnabled) { _, newValue in
                        HapticFeedbackManager.shared.selection()
                    }
            }
            .padding(.vertical, 2)
        }
    }
    
    private var preferencesSection: some View {
        Section {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                    )
                
                Toggle("Retour haptique", isOn: $enableHaptics)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: enableHaptics) { _, newValue in
                        if newValue {
                            HapticFeedbackManager.shared.impact(style: .medium)
                        }
                    }
            }
            .padding(.vertical, 2)
        }
    }
    
    private var systemSection: some View {
        Section {
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                showingSystemSelection = true
            }) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "globe")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                        )
                    
                    Text("Système de notation")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                showingAppIconSelection = true
            }) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.cyan)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                        )
                    
                    Text("Icône de l'application")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var dataSection: some View {
        Section {
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                showingPeriodManagement = true
            }) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                        )
                    
                    Text("Gérer les périodes")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Button(action: exportDataDirectly) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.teal)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                        )
                    
                    Text("Exporter les données")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .medium)
                showingDataManagement = true
            }) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                        )
                    
                    Text("Réinitialiser")
                        .font(.body)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var aboutSection: some View {
        Section {
            Button(action: {
                HapticFeedbackManager.shared.impact(style: .light)
                showingAbout = true
            }) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "info.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                        )
                    
                    Text("À propos de Gradefy")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private func exportDataDirectly() {
        HapticFeedbackManager.shared.impact(style: .medium)
        
        Task {
            do {
                let subjects = try await fetchSubjects()
                let evaluations = try await fetchEvaluations()
                let periods = try await fetchPeriods()
                
                let exportData = createExportData(subjects: subjects, evaluations: evaluations, periods: periods)
                let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
                
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileName = "gradefy_export_\(Int(Date().timeIntervalSince1970)).json"
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                try jsonData.write(to: fileURL)
                
                await MainActor.run {
                    exportedURL = fileURL
                    showingShareSheet = true
                    HapticFeedbackManager.shared.notification(type: .success)
                }
            } catch {
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .error)
                    print("Erreur lors de l'exportation : \(error)")
                }
            }
        }
    }
    
    private func fetchSubjects() async throws -> [Subject] {
        return try await viewContext.perform {
            try self.viewContext.fetch(Subject.fetchRequest()) as [Subject]
        }
    }
    
    private func fetchEvaluations() async throws -> [Evaluation] {
        return try await viewContext.perform {
            try self.viewContext.fetch(Evaluation.fetchRequest()) as [Evaluation]
        }
    }
    
    private func fetchPeriods() async throws -> [Period] {
        return try await viewContext.perform {
            try self.viewContext.fetch(Period.fetchRequest()) as [Period]
        }
    }
    
    private func createExportData(subjects: [Subject], evaluations: [Evaluation], periods: [Period]) -> [String: Any] {
        let exportDate = ISO8601DateFormatter().string(from: Date())
        let appVersion = "1.0.0"
        
        let periodsData = periods.map { period -> [String: Any] in
            [
                "id": period.id?.uuidString ?? "",
                "name": period.name ?? "",
                "start_date": ISO8601DateFormatter().string(from: period.startDate ?? Date()),
                "end_date": ISO8601DateFormatter().string(from: period.endDate ?? Date())
            ]
        }
        
        let subjectsData = subjects.map { subject -> [String: Any] in
            [
                "id": subject.id?.uuidString ?? "",
                "name": subject.name ?? "",
                "coefficient": subject.coefficient,
                "grade": subject.grade,
                "period_id": subject.period?.id?.uuidString ?? ""
            ]
        }
        
        let evaluationsData = evaluations.map { evaluation -> [String: Any] in
            [
                "id": evaluation.id?.uuidString ?? "",
                "title": evaluation.title ?? "",
                "grade": evaluation.grade,
                "coefficient": evaluation.coefficient,
                "date": ISO8601DateFormatter().string(from: evaluation.date ?? Date()),
                "subject_id": evaluation.subject?.id?.uuidString ?? ""
            ]
        }
        
        return [
            "export_date": exportDate,
            "app_version": appVersion,
            "periods": periodsData,
            "subjects": subjectsData,
            "evaluations": evaluationsData
        ]
    }
}


// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("username") private var username: String = ""
    @AppStorage("profileSubtitle") private var profileSubtitle: String = ""
    @AppStorage("profileGradientStartHex") private var profileGradientStartHex: String = "9BE8F6"
    @AppStorage("profileGradientEndHex") private var profileGradientEndHex: String = "5DD5F4"
    
    @State private var tempUsername: String = ""
    @State private var tempSubtitle: String = ""
    @State private var selectedGradient: [Color] = []
    
    private let availableGradients: [[Color]] = [
        [Color(hex: "9BE8F6"), Color(hex: "5DD5F4")],
        [Color(hex: "B0F4B6"), Color(hex: "78E089")],
        [Color(hex: "FBB3C7"), Color(hex: "F68EB2")],
        [Color(hex: "DBC7F9"), Color(hex: "C6A8EF")],
        [Color(hex: "F8C79B"), Color(hex: "F5A26A")]
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                profilePreviewSection
                informationSection
                colorSection
            }
            .navigationTitle("Modifier le profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { saveProfile() }
                }
            }
        }
        .onAppear {
            setupTempValues()
        }
    }
    
    private var profilePreviewSection: some View {
        Section {
            HStack {
                Spacer()
                
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: selectedGradient),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 100, height: 100)
                        
                        Text(tempUsername.isEmpty ? "" : String(tempUsername.prefix(1).uppercased()))
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 4) {
                        Text(tempUsername.isEmpty ? "Nom d'utilisateur" : tempUsername)
                            .font(.title2.weight(.semibold))
                        
                        Text(tempSubtitle.isEmpty ? "Description" : tempSubtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
    }
    
    private var informationSection: some View {
        Section("Informations") {
            ProfileTextField(title: "Nom", text: $tempUsername, placeholder: "Votre nom")
            ProfileTextField(title: "Description", text: $tempSubtitle, placeholder: "Étudiant, Lycéen...")
        }
    }
    
    private var colorSection: some View {
        Section("Couleur") {
            HStack(spacing: 20) {
                ForEach(0..<availableGradients.count, id: \.self) { index in
                    MinimalGradientButton(
                        gradient: availableGradients[index],
                        isSelected: selectedGradient == availableGradients[index]
                    ) {
                        selectedGradient = availableGradients[index]
                        HapticFeedbackManager.shared.selection()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
    
    private func setupTempValues() {
        tempUsername = username
        tempSubtitle = profileSubtitle
        selectedGradient = [Color(hex: profileGradientStartHex), Color(hex: profileGradientEndHex)]
    }
    
    private func saveProfile() {
        username = tempUsername
        profileSubtitle = tempSubtitle
        
        if selectedGradient.count >= 2 {
            profileGradientStartHex = selectedGradient[0].toHex()
            profileGradientEndHex = selectedGradient[1].toHex()
        }
        
        HapticFeedbackManager.shared.notification(type: .success)
        dismiss()
    }
}

// MARK: - Profile Components

struct ProfileTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Text(title)
                .frame(width: 80, alignment: .leading)
            
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct MinimalGradientButton: View {
    let gradient: [Color]
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: gradient),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 50, height: 50)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var showResetAlert = false
    @State private var isResetting = false
    
    private var adaptiveBackground: Color {
        colorScheme == .light ? Color.appBackground : Color(.systemBackground)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                adaptiveBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 12) {
                        Text("Réinitialisation complète")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.primary)
                        
                        Text("Cette action supprimera définitivement toutes vos données et vous ramènera à l'écran d'accueil de l'application.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Button(action: {
                            HapticFeedbackManager.shared.impact(style: .heavy)
                            showResetAlert = true
                        }) {
                            HStack {
                                if isResetting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.headline.weight(.semibold))
                                }
                                
                                Text(isResetting ? "Réinitialisation..." : "Réinitialiser l'application")
                                    .font(.headline.weight(.semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red)
                            )
                        }
                        .disabled(isResetting)
                        .padding(.horizontal, 20)
                        
                        Button("Annuler") {
                            HapticFeedbackManager.shared.impact(style: .light)
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Réinitialiser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        HapticFeedbackManager.shared.impact(style: .light)
                        dismiss()
                    }
                }
            }
        }
        .alert("Réinitialisation complète", isPresented: $showResetAlert) {
            Button("Réinitialiser", role: .destructive) {
                performCompleteReset()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Êtes-vous sûr de vouloir supprimer toutes vos données ? Cette action est irréversible et vous ramènera à l'écran d'accueil.")
        }
    }
    
    private func performCompleteReset() {
        isResetting = true
        HapticFeedbackManager.shared.impact(style: .heavy)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completeApplicationReset()
        }
    }
    
    private func completeApplicationReset() {
        viewContext.performAndWait {
            do {
                print("🗑️ Début suppression données Core Data...")
                
                let entities: [NSFetchRequest<NSFetchRequestResult>] = [
                    Flashcard.fetchRequest(),
                    FlashcardDeck.fetchRequest(),
                    Evaluation.fetchRequest(),
                    Subject.fetchRequest(),
                    Period.fetchRequest()
                ]
                
                for entityRequest in entities {
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: entityRequest)
                    deleteRequest.resultType = .resultTypeObjectIDs
                    
                    let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
                    
                    if let objectIDs = result?.result as? [NSManagedObjectID] {
                        let changes = [NSDeletedObjectsKey: objectIDs]
                        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
                    }
                    
                    print("✅ \(entityRequest.entityName ?? "Entity") supprimée")
                }
                
                try viewContext.save()
                viewContext.refreshAllObjects()
                
                print("✅ Toutes les données Core Data supprimées avec succès")
                
            } catch {
                print("❌ Erreur suppression Core Data: \(error)")
                viewContext.rollback()
            }
        }
        
        DispatchQueue.main.async {
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
            }
            
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(false, forKey: "onboardingPeriodProcessed")
            UserDefaults.standard.set("france", forKey: "GradingSystem")
            UserDefaults.standard.set(false, forKey: "darkModeEnabled")
            UserDefaults.standard.set(true, forKey: "showAppreciations")
            UserDefaults.standard.set(true, forKey: "enableHaptics")
            
            UserDefaults.standard.synchronize()
            
            self.isResetting = false
            self.showConfirmationAlert()
        }
    }
    
    private func showConfirmationAlert() {
        let alert = UIAlertController(
            title: "Réinitialisation terminée",
            message: "L'application va maintenant redémarrer pour appliquer les changements. Appuyez sur OK pour continuer.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            print("🚀 Utilisateur a confirmé - Fermeture de l'app")
            
            HapticFeedbackManager.shared.notification(type: .success)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("🚀 exit(0) exécuté")
                exit(0)
            }
        })
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                
                var topController = window.rootViewController
                while let presentedController = topController?.presentedViewController {
                    topController = presentedController
                }
                
                topController?.present(alert, animated: true) {
                    print("✅ Alerte de confirmation affichée")
                }
            }
        }
    }
}

// MARK: - App Icon Selection

struct AppIconSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var iconManager = AppIconManager()
    
    private let availableIcons: [AppIconDisplayItem] = [
        AppIconDisplayItem(
            name: "AppIcon",
            displayName: "Par défaut",
            description: "Icône standard de Gradefy",
            color: .blue,
            previewImageName: "AppIconPreview" // ✅ Nom de l'image preview
        ),
        AppIconDisplayItem(
            name: "AppIconDark",
            displayName: "Sombre",
            description: "Version adaptée au mode sombre",
            color: .black,
            previewImageName: "iconDarkPreview"
        ),
        AppIconDisplayItem(
            name: "AppIconColorful",
            displayName: "Colorée",
            description: "Version avec accent coloré",
            color: .purple,
            previewImageName: "iconColorfulPreview"
        ),
        AppIconDisplayItem(
            name: "AppIconMinimal",
            displayName: "Minimaliste",
            description: "Design épuré et moderne",
            color: .gray,
            previewImageName: "iconMinimalPreview"
        )
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Icône de l'application")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 30)
                
                VStack(spacing: 16) {
                    ForEach(availableIcons) { icon in
                        AppIconButton(
                            icon: icon,
                            isSelected: iconManager.currentIcon == icon.name,
                            isChanging: iconManager.isChanging && iconManager.currentIcon == icon.name
                        ) {
                            if icon.name != iconManager.currentIcon {
                                iconManager.changeIcon(to: icon.name)
                            }
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
        .onAppear {
            iconManager.syncCurrentIcon()
        }
    }
}

struct AppIconDisplayItem: Identifiable {
    let id = UUID()
    let name: String
    let displayName: String
    let description: String
    let color: Color
    let previewImageName: String // ✅ Nouveau champ
}

struct AppIconButton: View {
    let icon: AppIconDisplayItem
    let isSelected: Bool
    let isChanging: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            guard !isChanging else { return }
            HapticFeedbackManager.shared.impact(style: .light)
            action()
        }) {
            HStack(spacing: 12) {
                // ✅ Affichage de la vraie icône
                if let uiImage = UIImage(named: icon.previewImageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(width: 30, height: 30)
                } else {
                    // Fallback vers le rectangle coloré si l'image n'existe pas
                    RoundedRectangle(cornerRadius: 8)
                        .fill(icon.color)
                        .frame(width: 30, height: 30)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(icon.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(icon.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Indicateur de sélection
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
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: 30))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(isChanging)
        .opacity(isChanging ? 0.7 : 1.0)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isChanging)
    }
    
    private var backgroundColor: Color {
        Color(.secondarySystemGroupedBackground)
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.blue
        } else {
            return Color(.separator).opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        isSelected ? 4 : 2  // ✅ CHANGEZ 2 → 3 (ou plus selon votre préférence)
    }
}

@MainActor
final class AppIconManager: ObservableObject {
    @Published private(set) var currentIcon: String = "AppIcon"
    @Published private(set) var isChanging: Bool = false
    
    func syncCurrentIcon() {
        currentIcon = UIApplication.shared.alternateIconName ?? "AppIcon"
    }
    
    func changeIcon(to iconName: String) {
        guard !isChanging else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            print("Icônes alternatives non supportées")
            return
        }
        
        isChanging = true
        let newIconName = iconName == "AppIcon" ? nil : iconName
        
        HapticFeedbackManager.shared.impact(style: .medium)
        
        UIApplication.shared.setAlternateIconName(newIconName) { [weak self] error in
            DispatchQueue.main.async {
                self?.isChanging = false
                if let error = error {
                    HapticFeedbackManager.shared.notification(type: .error)
                    print("Erreur lors du changement d'icône : \(error)")
                } else {
                    self?.currentIcon = iconName
                    HapticFeedbackManager.shared.notification(type: .success)
                    print("Icône changée : \(iconName)")
                }
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                headerSection
                
                VStack(spacing: 20) {
                    infoRow(title: "Version", value: "1.0.0")
                    infoRow(title: "Développeur", value: "Gradefy Team")
                    infoRow(title: "Compatibilité", value: "iOS 16.0+")
                    infoRow(title: "Langues", value: "Français")
                }
                
                Spacer()
                
                Text("© 2025 Gradefy. Tous droits réservés.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("À propos")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "graduationcap.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Gradefy")
                .font(.title.weight(.semibold))
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }

// MARK: - Color Extension

