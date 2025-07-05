import ActivityKit
import Foundation

struct RevisionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var cardsCompleted: Int
        var totalCards: Int
        var currentCardQuestion: String
        var cardsKnown: Int
        var cardsToReview: Int
        var isActive: Bool
        var lastUpdate: Date
        
        var sessionDuration: TimeInterval {
            Date().timeIntervalSince(startDate)
        }
        
        var progress: Double {
            guard totalCards > 0 else { return 0 }
            return Double(cardsCompleted) / Double(totalCards)
        }
        
        var cardsRemaining: Int {
            totalCards - cardsCompleted
        }
    }
    
    var sessionID: UUID
    var subjectName: String
    var deckName: String
}

struct AIGenerationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var progress: Double
        var currentStep: String
        var isActive: Bool
    }
    
    var sessionID: UUID
    var deckName: String
    var numberOfCards: Int
}
