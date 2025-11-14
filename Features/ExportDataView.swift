
//
// ImportExportViews.swift
// PARALLAX
//
// Created by  on 7/14/25.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export Data View
struct ExportDataView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: DataImportExportManager
    @State private var showingShareSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 12) {
                        Text(String(localized: "export_data_title"))
                            .font(.title2.weight(.bold))
                            .foregroundColor(.primary)
                        
                        Text(String(localized: "export_data_description"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        exportData()
                    }) {
                        HStack {
                            if manager.isExporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.headline.weight(.semibold))
                            }
                            
                            Text(manager.isExporting ? String(localized: "action_export_in_progress") : String(localized: "action_export_my_data"))
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue)
                        )
                    }
                    .disabled(manager.isExporting)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .navigationTitle(String(localized: "nav_export"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "action_close")) {
                        print("📤 [EXPORT_VIEW] Bouton fermer cliqué")
                        dismiss()
                        print("📤 [EXPORT_VIEW] Vue fermée")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = manager.lastExportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert(String(localized: "alert_error"), isPresented: $showingError) {
                Button(String(localized: "alert_ok"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func exportData() {
        Task {
            do {
                HapticFeedbackManager.shared.impact(style: .heavy)
                _ = try await manager.exportAllData()

                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .success)
                    showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .error)
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}
struct ImportDataView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: DataImportExportManager
    let onImportComplete: () -> Void
    
    @State private var showingDocumentPicker = false
    @State private var showingConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedFileURL: URL?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    VStack(spacing: 12) {
                        Text(String(localized: "import_data_title"))
                            .font(.title2.weight(.bold))
                            .foregroundColor(.primary)
                        
                        Text(String(localized: "import_data_description"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        showingDocumentPicker = true
                    }) {
                        HStack {
                            if manager.isImporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "folder")
                                    .font(.headline.weight(.semibold))
                            }
                            
                            Text(manager.isImporting ? String(localized: "action_import_in_progress") : String(localized: "action_choose_file"))
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green)
                        )
                    }
                    .disabled(manager.isImporting)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .navigationTitle(String(localized: "nav_import"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "action_close")) {
                        print("📤 [EXPORT_VIEW] Bouton fermer cliqué")
                        dismiss()
                        print("📤 [EXPORT_VIEW] Vue fermée")
                    }
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView { url in
                    selectedFileURL = url
                    showingConfirmation = true
                }
            }
            .alert(String(localized: "alert_confirm_import"), isPresented: $showingConfirmation) {
                Button(String(localized: "action_import"), role: .destructive) {
                    if let url = selectedFileURL {
                        importData(from: url)
                    }
                }
                Button(String(localized: "action_cancel"), role: .cancel) { }
            } message: {
                Text(String(localized: "alert_import_warning"))
            }
            .alert(String(localized: "alert_error"), isPresented: $showingError) {
                Button(String(localized: "alert_ok"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func importData(from url: URL) {
        Task {
            do {
                HapticFeedbackManager.shared.impact(style: .heavy)
                try await manager.importData(from: url)
                
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .success)
                    
                    // ✅ AJOUT : Message informatif
                    print("🎉 Import terminé - Période active mise à jour automatiquement")
                    
                    onImportComplete()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    HapticFeedbackManager.shared.notification(type: .error)
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}
