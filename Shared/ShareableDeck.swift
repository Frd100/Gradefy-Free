import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shareable Deck Models
struct ShareableDeck: Codable {
    let metadata: DeckMetadata
    let flashcards: [ShareableFlashcard]
    
    struct DeckMetadata: Codable {
        let id: String
        let name: String
        let totalCards: Int
        let createdAt: Date
        let creatorName: String?
        let appVersion: String
        let shareVersion: String
        
        init(id: String, name: String, totalCards: Int, createdAt: Date, creatorName: String?, appVersion: String, shareVersion: String = "1.0") {
            self.id = id
            self.name = name
            self.totalCards = totalCards
            self.createdAt = createdAt
            self.creatorName = creatorName
            self.appVersion = appVersion
            self.shareVersion = shareVersion
        }
    }
    
    struct ShareableFlashcard: Codable {
        let question: String
        let answer: String
        let createdAt: Date
    }
}

// MARK: - Gradefy Deck Document for File Export
struct GradefyDeckDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(url: URL) throws {
        self.data = try Data(contentsOf: url)
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
