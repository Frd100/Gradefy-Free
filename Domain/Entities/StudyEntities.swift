import Foundation
import SwiftUI
import CoreData

// Constantes métier
let NO_GRADE: Double = -999.0
let MIN_COEFF: Double = 0.5
let MAX_COEFF: Double = 10.0

struct GradingConstants {
    static let noGrade: Double = -999.0
    static let minCoefficient: Double = 0.5
    static let maxCoefficient: Double = 10.0
}

// Enums métier
enum GradeColor {
    static let excellent = Color.green
    static let veryGood = Color.mint
    static let good = Color.blue
    static let average = Color.orange
    static let failure = Color.red
    static let noGrade = Color.secondary
}

// Modèles de données
struct DummyEvaluation {
    let grade: Double
    let coefficient: Double
}

struct SubjectData: Hashable {
    let code: String
    let name: String
    let grade: Double
    let coefficient: Double
    let creditHours: Double  // ✅ AJOUTEZ
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
    case alphabetical = "alphabetical"
    case grade = "grade"
    
    var localizedTitle: String {
        switch self {
        case .alphabetical:
            return String(localized: "sort_alphabetical")
        case .grade:
            return String(localized: "sort_grade")
        }
    }
}
extension Subject {
    /// SEULE source de vérité pour le calcul de moyenne
    var currentGrade: Double {
        let validEvaluations = evaluations?.allObjects as? [Evaluation] ?? []
        let graded = validEvaluations.filter { $0.grade != NO_GRADE }
        guard !graded.isEmpty else { return NO_GRADE }
        
        // Utilise le système actif pour le calcul
        let system = GradingSystemRegistry.active
        let dummyEvals = graded.map { DummyEvaluation(grade: $0.grade, coefficient: $0.coefficient) }
        return system.weightedAverage(dummyEvals)
    }
    
    /// Alias pour compatibilité
    var finalGradeForGPA: Double { currentGrade }
    
    /// Vérifie si la matière est valide pour le calcul GPA
    var isValidForGPA: Bool {
        return currentGrade != NO_GRADE && creditHours > 0
    }
    
    /// Méthode de recalcul avec cache et logs (version complète)
    func recalculateAverageOptimized(context: NSManagedObjectContext, autoSave: Bool = false) {
        // ✅ Utilise la computed property comme source de vérité
        self.grade = currentGrade
        
        // ✅ Invalidation du cache pour performance
        let objectIDString = self.objectID.uriRepresentation().absoluteString
        SmartAverageCache.shared.invalidateIfNeeded(changedObjectID: objectIDString)
        
        // ✅ Logs pour debugging
        if self.grade == NO_GRADE {
            print("🔍 Aucune évaluation avec note → Moyenne: NO_GRADE")
        } else {
            let system = GradingSystemRegistry.active
            print("🔍 Nouvelle moyenne calculée: \(system.format(self.grade))")
        }
        
        // ✅ Sauvegarde avec gestion d'erreur
        if autoSave {
            do {
                try context.save()
                print("✅ Sauvegarde automatique réussie")
            } catch {
                print("❌ Erreur sauvegarde: \(error)")
            }
        }
    }
}

// MARK: - SRS Data (Moteur pur)
struct SRSData {
    let interval: Double
    let nextReviewDate: Date?
    let reviewCount: Int32
    let correctCount: Int16
    let easeFactor: Double
    let isOverdue: Bool
    let isDueToday: Bool
    let daysUntilNext: Int
    let daysOverdue: Int
    
    init(from card: Flashcard, calendar: Calendar = SRSConfiguration.reviewCalendar, now: Date = Date()) {
        self.interval = card.interval
        self.nextReviewDate = card.nextReviewDate
        self.reviewCount = card.reviewCount
        self.correctCount = card.correctCount
        self.easeFactor = card.easeFactor

        // ✅ OPTION 2 : Logique par jour sans chevauchement avec Calendar configuré
        var workingCalendar = calendar
        workingCalendar.timeZone = SRSConfiguration.timeZonePolicy.timeZone

        if let nextReview = card.nextReviewDate {
            let today = workingCalendar.startOfDay(for: now)
            let reviewDay = workingCalendar.startOfDay(for: nextReview)

            // Logique robuste par jour
            self.isOverdue = reviewDay < today       // En retard : jour de révision < aujourd'hui
            self.isDueToday = reviewDay == today     // Due aujourd'hui : jour de révision = aujourd'hui

            // Calcul des jours pour l'affichage
            let daysDiff = workingCalendar.dateComponents([.day], from: now, to: nextReview).day ?? 0
            self.daysUntilNext = max(0, daysDiff)
            self.daysOverdue = max(0, -daysDiff)
        } else {
            self.isOverdue = false
            self.isDueToday = false
            self.daysUntilNext = 0
            self.daysOverdue = 0
        }
    }
}



// MARK: - SRS Configuration (Centralisée)
struct SRSConfiguration {
    // ✅ NOUVELLE RÈGLE À 3 NIVEAUX : Progression motivante
    static let acquiredIntervalThreshold: Double = 7.0   // ⭐ Acquis : 7 jours minimum
    static let masteryIntervalThreshold: Double = 21.0   // 👑 Maîtrisé : 21 jours minimum
    
    // Seuils de statut simplifiés
    static let overdueDaysThreshold: Int = 30
    
    // Configuration lapse buffer
    static let maxLapsesPerCard: Int = 3
    static let spacerBetweenLapses: Int = 3
    
    // ✅ AJUSTEMENT 2 : Phase early plus tonique
    static let defaultEaseFactor: Double = 2.3  // Changé de 2.0 à 2.3
    static let minEaseFactor: Double = 1.3
    static let maxEaseFactor: Double = 3.0
    
    // Configuration interval
    static let minInterval: Double = 1.0
    static let resetInterval: Double = 1.0
    static let softCapThreshold: Double = 365 * 3  // 3 ans
    
    // ✅ AJUSTEMENT 2 : Graduating silencieux pour phase early
    static let earlyGraduatingMaxReviews: Int = 2  // Maximum 2 révisions en phase early
    
    // ✅ CORRECTION 1 : Utiliser la stratégie configurée
    static var earlyGraduatingIntervals: [Double] {
        return earlyPhaseStrategy.intervals
    }
    
    // ✅ CORRECTION 3 : Configuration phase early flexible pour v2
    enum EarlyPhaseStrategy {
        case conservative    // [3.0, 7.0] - actuel
        case moderate       // [2.0, 5.0] - plus rapide
        case aggressive     // [1.0, 4.0] - très rapide
        case adaptive       // Basé sur performance utilisateur (futur)
        
        var intervals: [Double] {
            switch self {
            case .conservative: return [3.0, 7.0]
            case .moderate: return [2.0, 5.0]
            case .aggressive: return [1.0, 4.0]
            case .adaptive: return [3.0, 7.0]  // Fallback pour l'instant
            }
        }
    }
    static let earlyPhaseStrategy: EarlyPhaseStrategy = .conservative  // Configurable pour v2
    
    // Configuration timezone
    enum TimeZonePolicy {
        case current
        case fixed(String)
        
        var timeZone: TimeZone {
            switch self {
            case .current:
                return TimeZone.current
            case .fixed(let identifier):
                return TimeZone(identifier: identifier) ?? TimeZone.current
            }
        }
    }
    static let timeZonePolicy: TimeZonePolicy = .current

    static var reviewCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZonePolicy.timeZone
        return calendar
    }
    
    // Configuration qualité SM-2 binaire
    static let confidentAnswerQuality: Int = 2      // ✅ Bon
    static let hesitantAnswerQuality: Int = 1       // ❌ Faux
    static let incorrectAnswerQuality: Int = 1      // ❌ Faux
    
    // Configuration ease factor binaire
    static let confidentEaseFactorIncrease: Double = 0.12   // ✅ +0.12
    static let hesitantEaseFactorIncrease: Double = 0.0     // ❌ +0.0 (inchangé)
    static let incorrectEaseFactorDecrease: Double = 0.15   // ✅ AJUSTEMENT 1 : -0.15 au lieu de -0.18
    
    // Configuration interval binaire
    static let hesitantIntervalMultiplier: Double = 1.35    // ❌ ×1.35 (progression modérée)
    static let incorrectIntervalMultiplier: Double = 0.4    // ❌ ×0.4 (inchangé)
    static let incorrectIntervalMin: Double = 1.0           // ❌ Clamp minimum
    static let incorrectIntervalMax: Double = 7.0           // ❌ Clamp maximum
    
    // ✅ AJUSTEMENT 1 : Lapse moins brutal pour les cartes avec streak
    static let streakThresholdForGentleLapse: Int = 6       // Streak ≥6 = lapse plus clément
    static let gentleLapseIntervalMultiplier: Double = 0.6  // ×0.6 au lieu de ×0.4 pour les streaks
    
    // ✅ AJUSTEMENT 3 : Réinjection contrôlée
    static let reinjectOnlyIncorrect: Bool = true           // Réinjecter seulement les incorrectes
    static let maxReinjectionQuota: Double = 0.4            // 40% max de réinjections par session
    
    // Configuration idempotence
    static let idempotenceCheckEnabled: Bool = true
    static let maxOperationCacheSize: Int = 1000 // Limite pour éviter accumulation infinie
    
    // ✅ CORRECTION 9 : Monitoring conditionnel pour éviter impact production
    static let enablePerformanceMonitoring: Bool = false  // Désactivé en production
    static let enableDetailedLogging: Bool = false        // Désactivé en production
    static let enableSM2Cache: Bool = true               // Activé (impact positif)
    static let enableCoreDataOptimization: Bool = true   // Activé (impact positif)
    
    // ✅ CORRECTION 1 : Soft cap constants pour éviter magic numbers
    static let softCapTaperingBase: Double = 1.1
    static let softCapTaperingRate: Double = 0.1  // Réduction par année
    static let softCapTaperingPeriod: Double = 365.0  // Période de référence (1 an)
    
    // ✅ CORRECTION 2 : Lapse constants pour cohérence
    static let gentleLapseThreshold: Int = 6  // Seuil pour lapse clément
    static let gentleLapseMultiplier: Double = 0.6  // Multiplicateur clément
    static let standardLapseMultiplier: Double = 0.4  // Multiplicateur standard
    static let lapseIntervalMin: Double = 1.0  // Intervalle minimum après lapse
    static let lapseIntervalMax: Double = 7.0  // Intervalle maximum après lapse
}
