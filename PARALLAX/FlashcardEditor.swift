//
//  FlashcardEditor.swift
//  PARALLAX
//
//  Created by Farid on 6/25/25.
//

import SwiftUI
import UIKit
import Foundation
import CoreData
import ActivityKit

// MARK: - Flashcard Editor View
struct FlashcardEditorView: View {
    @State private var flashcardToEdit: Flashcard?
    @ObservedObject var subject: Subject
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest var flashcards: FetchedResults<Flashcard>
    
    @State private var searchText = ""
    @State private var showingAddFlashcard = false
    @State private var showingDeleteAlert = false
    @State private var flashcardToDelete: Flashcard?
    @State private var isLoading = false
    @State private var newQuestion = ""
    @State private var newAnswer = ""
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case question, answer
    }
    
    private var filteredFlashcards: [Flashcard] {
        let allCards = Array(flashcards).sorted {
            ($0.createdAt ?? Date()) > ($1.createdAt ?? Date())
        }
        
        if searchText.isEmpty {
            return allCards
        } else {
            return allCards.filter { flashcard in
                let question = flashcard.question?.lowercased() ?? ""
                let answer = flashcard.answer?.lowercased() ?? ""
                let search = searchText.lowercased()
                return question.contains(search) || answer.contains(search)
            }
        }
    }
    
    private var flashcardCount: Int {
        flashcards.count
    }
    
    private var canAddFlashcard: Bool {
        !newQuestion.isEmpty && !newAnswer.isEmpty
    }
    
    init(subject: Subject) {
        self.subject = subject
        
        self._flashcards = FetchRequest<Flashcard>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Flashcard.createdAt, ascending: false)],
            predicate: NSPredicate(format: "subject == %@", subject)
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                searchSection
                contentSection
            }
            .background(backgroundColor)
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddFlashcard = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .sheet(item: $flashcardToEdit) { flashcard in
            EditFlashcardView(flashcard: flashcard)
        }
        .sheet(isPresented: $showingAddFlashcard) {
            AddFlashcardFormView(
                subject: subject,
                newQuestion: $newQuestion,
                newAnswer: $newAnswer,
                onSave: { question, answer in
                    addFlashcard(question: question, answer: answer)
                }
            )
        }
        .alert("Supprimer la flashcard", isPresented: $showingDeleteAlert) {
            Button("Supprimer", role: .destructive) {
                if let flashcard = flashcardToDelete {
                    deleteFlashcard(flashcard)
                }
            }
            Button("Annuler", role: .cancel) {
                flashcardToDelete = nil
            }
        } message: {
            Text("Êtes-vous sûr de vouloir supprimer cette flashcard ?")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(subject.name ?? "Matière")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text("Gestion des flashcards")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    VStack(spacing: 4) {
                        Text("\(flashcardCount)")
                            .font(.title.bold())
                            .foregroundColor(.accentColor)
                        Text(flashcardCount <= 1 ? "carte" : "cartes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    let status = flashcardStatus
                    Text(status.text)
                        .font(.caption2.bold())
                        .foregroundColor(status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(status.color.opacity(0.15))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Divider()
                .padding(.horizontal, 20)
        }
        .background(cardBackground)
    }
    
    private var searchSection: some View {
        Group {
            if flashcardCount > 0 {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Rechercher dans les flashcards...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
    
    private var contentSection: some View {
        Group {
            if filteredFlashcards.isEmpty && !searchText.isEmpty {
                searchEmptyView
            } else if filteredFlashcards.isEmpty {
                emptyStateView
            } else {
                flashcardsListView
            }
        }
    }
    
    private var flashcardsListView: some View {
        List {
            if searchText.isEmpty {
                quickAddSection
            }
            
            Section {
                ForEach(filteredFlashcards, id: \.id) { flashcard in
                    FlashcardRowView(
                        flashcard: flashcard,
                        onEdit: {
                            flashcardToEdit = flashcard
                        }
                    )
                }
                .onDelete(perform: deleteFlashcards)
            } header: {
                if !searchText.isEmpty {
                    Text("Résultats de recherche")
                        .font(.subheadline.weight(.medium))
                } else {
                    Text("Vos flashcards")
                        .font(.subheadline.weight(.medium))
                }
            }
            .listRowBackground(cardBackground)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var quickAddSection: some View {
        Section {
            VStack(spacing: 16) {
                Text("Ajouter une flashcard")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Question")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Entrez la question", text: $newQuestion, axis: .vertical)
                            .focused($focusedField, equals: .question)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                            .lineLimit(2...4)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Réponse")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Entrez la réponse", text: $newAnswer, axis: .vertical)
                            .focused($focusedField, equals: .answer)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                            .lineLimit(2...4)
                    }
                }
                
                Button {
                    addFlashcard(question: newQuestion, answer: newAnswer)
                    newQuestion = ""
                    newAnswer = ""
                    focusedField = .question
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Ajouter")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(canAddFlashcard ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(canAddFlashcard ? Color.accentColor : Color(.systemGray4))
                    )
                }
                .disabled(!canAddFlashcard)
                .scaleEffect(canAddFlashcard ? 1.0 : 0.95)
                .animation(.easeInOut(duration: 0.2), value: canAddFlashcard)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Ajout rapide")
                .font(.subheadline.weight(.medium))
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .symbolEffect(.bounce, value: showingAddFlashcard)
            
            VStack(spacing: 8) {
                Text("Aucune flashcard")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Créez vos premières flashcards pour commencer à réviser cette matière.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                showingAddFlashcard = true
            } label: {
                Label("Créer une flashcard", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.accentColor)
                    )
            }
            .scaleEffect(showingAddFlashcard ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: showingAddFlashcard)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var searchEmptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Aucun résultat")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            Text("Aucune flashcard ne correspond à votre recherche.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .light ? Color(.systemGroupedBackground) : Color(.systemBackground)
    }
    
    private var cardBackground: Color {
        colorScheme == .light ? Color.white : Color(.secondarySystemBackground)
    }
    
    private var flashcardStatus: (text: String, color: Color) {
        switch flashcardCount {
        case 0:
            return ("Vide", .secondary)
        case 1...4:
            return ("Débutant", .orange)
        case 5...19:
            return ("En cours", .blue)
        default:
            return ("Complet", .green)
        }
    }
    
    private func addFlashcard(question: String, answer: String) {
        let success = viewContext.createFlashcard(
            question: question,
            answer: answer,
            subjectObjectID: subject.objectID
        )
        
        if success {
            HapticFeedbackManager.shared.notification(type: .success)
            print("✅ Flashcard ajoutée avec succès")
        } else {
            HapticFeedbackManager.shared.notification(type: .error)
            print("❌ Erreur ajout flashcard")
        }
    }
    
    private func deleteFlashcard(_ flashcard: Flashcard) {
        withAnimation(.easeInOut(duration: 0.3)) {
            viewContext.performAndWait {
                do {
                    viewContext.delete(flashcard)
                    try viewContext.save()
                    flashcardToDelete = nil
                    print("✅ Flashcard supprimée avec succès")
                } catch {
                    print("❌ Erreur suppression flashcard: \(error)")
                    viewContext.rollback()
                }
            }
        }
    }
    
    private func deleteFlashcards(offsets: IndexSet) {
        withAnimation(.easeInOut(duration: 0.3)) {
            viewContext.performAndWait {
                do {
                    let cardsToDelete = offsets.map { filteredFlashcards[$0] }
                    for card in cardsToDelete {
                        viewContext.delete(card)
                    }
                    try viewContext.save()
                    print("✅ Flashcard(s) supprimée(s) avec succès")
                } catch {
                    print("❌ Erreur suppression flashcards: \(error)")
                    viewContext.rollback()
                }
            }
        }
    }
}

// MARK: - AddFlashcardFormView
struct AddFlashcardFormView: View {
    let subject: Subject
    @Binding var newQuestion: String
    @Binding var newAnswer: String
    let onSave: (String, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FlashcardEditorView.Field?
    @State private var showAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Matière") {
                    Text(subject.name ?? "Matière")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                
                Section("Question") {
                    TextField("Entrez la question", text: $newQuestion, axis: .vertical)
                        .focused($focusedField, equals: .question)
                        .lineLimit(3...8)
                }
                
                Section("Réponse") {
                    TextField("Entrez la réponse", text: $newAnswer, axis: .vertical)
                        .focused($focusedField, equals: .answer)
                        .lineLimit(3...8)
                }
                
                Section {
                    Text("Créez des flashcards pour réviser efficacement cette matière.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Nouvelle flashcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        saveFlashcard()
                    }
                    .disabled(newQuestion.isEmpty || newAnswer.isEmpty)
                }
            }
            .alert("Erreur", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                focusedField = .question
            }
        }
    }
    
    private func saveFlashcard() {
        guard !newQuestion.isEmpty && !newAnswer.isEmpty else {
            errorMessage = "Question et réponse requises"
            showAlert = true
            return
        }
        
        let context = PersistenceController.shared.container.viewContext
        
        context.performAndWait {
            do {
                // ✅ Récupérer le subject dans le bon contexte
                let subjectID = subject.objectID
                guard let contextSubject = try? context.existingObject(with: subjectID) as? Subject else {
                    errorMessage = "Erreur: Impossible de récupérer la matière"
                    showAlert = true
                    return
                }
                
                let newFlashcard = Flashcard(context: context)
                newFlashcard.id = UUID()
                newFlashcard.question = newQuestion    // ✅ Utilise newQuestion (qui existe)
                newFlashcard.answer = newAnswer        // ✅ Utilise newAnswer (qui existe)
                newFlashcard.createdAt = Date()
                newFlashcard.subject = contextSubject   // ✅ Utilise subject (qui existe)
                // Pas de deck dans cette vue, c'est normal !
                
                try context.save()
                
                // ✅ Appeler la fonction de callback
                onSave(newQuestion, newAnswer)
                dismiss()
                
                print("✅ Flashcard sauvegardée")
            } catch {
                errorMessage = "Erreur sauvegarde: \(error.localizedDescription)"
                showAlert = true
                print("❌ Erreur: \(error)")
            }
        }
    }
}

// MARK: - Flashcard Editor ViewModel
@MainActor
class FlashcardEditorViewModel: ObservableObject {
    @Published var newQuestion: String = ""
    @Published var newAnswer: String = ""
    @Published var errorMessage: String?
    
    private let dataService: DataServiceProtocol
    private let subject: Subject
    
    init(subject: Subject, dataService: DataServiceProtocol) {
        self.subject = subject
        self.dataService = dataService
    }
    
    var canAddFlashcard: Bool {
        !newQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !newAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func addFlashcard() {
        guard canAddFlashcard else {
            errorMessage = "Question et réponse requises"
            return
        }
        
        _ = dataService.createFlashcard(
            question: newQuestion.trimmingCharacters(in: .whitespacesAndNewlines),
            answer: newAnswer.trimmingCharacters(in: .whitespacesAndNewlines),
            subject: subject
        )
        
        do {
            try dataService.save()
            clearFields()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteFlashcard(_ flashcard: Flashcard) {
        do {
            try dataService.delete(flashcard)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func clearFields() {
        newQuestion = ""
        newAnswer = ""
        errorMessage = nil
    }
}

// MARK: - Data Service Protocol
protocol DataServiceProtocol {
    func save() throws
    func delete(_ object: NSManagedObject) throws
    func createFlashcard(question: String, answer: String, subject: Subject) -> Flashcard
}

