import Foundation
import SwiftUI
import WidgetKit

// MARK: - Evaluation Data Manager

class EvaluationDataManager {
    static let shared = EvaluationDataManager()

    func getNextEvaluation() -> (hasEvaluation: Bool, title: String, timeRemaining: String) {
        let userDefaults = UserDefaults(suiteName: "group.com.Coefficient.PARALLAX2")

        let hasEvaluation = userDefaults?.bool(forKey: "hasNextEvaluation") ?? false
        let title = userDefaults?.string(forKey: "nextEvaluationTitle") ?? ""
        let timeRemaining = userDefaults?.string(forKey: "nextEvaluationTime") ?? ""

        return (hasEvaluation, title, timeRemaining)
    }

    func updateNextEvaluation(hasEvaluation: Bool, title: String, timeRemaining: String) {
        let userDefaults = UserDefaults(suiteName: "group.com.Coefficient.PARALLAX2")
        userDefaults?.set(hasEvaluation, forKey: "hasNextEvaluation")
        userDefaults?.set(title, forKey: "nextEvaluationTitle")
        userDefaults?.set(timeRemaining, forKey: "nextEvaluationTime")
    }
}

// MARK: - Entry Structure

struct EvaluationEntry: TimelineEntry {
    let date: Date
    let hasEvaluation: Bool
    let title: String
    let timeRemaining: String
}

// MARK: - Extension pour formater les données

extension EvaluationEntry {
    var displayTime: String {
        guard hasEvaluation && !timeRemaining.isEmpty else { return "" }
        return timeRemaining
    }

    var displayTitle: String {
        return hasEvaluation && !title.isEmpty ? title : String(localized: "widget_no_evaluations")
    }

    var emptyStateText: String {
        return "Aucune évaluation à venir"
    }
}

// MARK: - Provider

struct EvaluationProvider: TimelineProvider {
    func placeholder(in _: Context) -> EvaluationEntry {
        EvaluationEntry(
            date: Date(),
            hasEvaluation: true,
            title: "Contrôle Mathématiques",
            timeRemaining: "2 jours"
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (EvaluationEntry) -> Void) {
        let entry = EvaluationEntry(
            date: Date(),
            hasEvaluation: true,
            title: "Contrôle Mathématiques",
            timeRemaining: "2 jours"
        )
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<EvaluationEntry>) -> Void) {
        let evaluationData = EvaluationDataManager.shared.getNextEvaluation()
        let entry = EvaluationEntry(
            date: Date(),
            hasEvaluation: evaluationData.hasEvaluation,
            title: evaluationData.title,
            timeRemaining: evaluationData.timeRemaining
        )

        // Mise à jour toutes les heures
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ??
            Calendar.current.date(byAdding: .minute, value: 15, to: Date())!

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Vue Router Principale

// ✅ MODIFIÉ : Toujours afficher les widgets - Application entièrement gratuite
struct EvaluationWidgetView: View {
    var entry: EvaluationEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        // Toujours afficher le widget - pas de vérification premium
        switch family {
        case .systemSmall:
            SmallEvaluationView(entry: entry)
        case .systemMedium:
            MediumEvaluationView(entry: entry)
        case .systemLarge:
            LargeEvaluationView(entry: entry)
        case .accessoryCircular:
            CircularEvaluationView(entry: entry)
        case .accessoryRectangular:
            RectangularEvaluationView(entry: entry)
        case .accessoryInline:
            InlineEvaluationView(entry: entry)
        default:
            SmallEvaluationView(entry: entry)
        }
    }
}

// MARK: - Toutes vos vues originales INCHANGÉES

struct LargeEvaluationView: View {
    let entry: EvaluationEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            // Icône calendar en haut à droite
            HStack {
                Spacer()
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 50, weight: .regular))
                    .foregroundColor(.indigo)
            }
            .padding(.top, 10)
            .padding(.trailing, 10)

            Spacer()

            if entry.hasEvaluation {
                // Nom de l'évaluation et temps restant en bas à gauche
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.displayTitle)
                            .font(.title3.weight(.medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        Text(entry.displayTime)
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.leading, 1)
                    .padding(.bottom, 1)
                    Spacer()
                }
            } else {
                // Empty state
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.emptyStateText)
                            .font(.title3.weight(.medium))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.leading, 10)
                    .padding(.bottom, 10)
                    Spacer()
                }
            }
        }
        .containerBackground(for: .widget) {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .black.opacity(0.3) : .gray.opacity(0.15),
                    radius: 2,
                    x: 0,
                    y: 1
                )
        }
        .widgetURL(URL(string: "parallax://evaluations"))
    }
}

struct StandByEvaluationView: View {
    let entry: EvaluationEntry

    var body: some View {
        VStack(spacing: 4) {
            // Icône en haut
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 25, weight: .regular))
                .foregroundColor(.indigo)

            Spacer()

            if entry.hasEvaluation {
                // Temps restant au centre
                Text(entry.displayTime)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                // Nom de l'évaluation en bas
                Text(entry.displayTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                // Empty state
                Text(entry.emptyStateText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct SmallEvaluationView: View {
    let entry: EvaluationEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    var body: some View {
        if showsBackground {
            // Mode normal (écran d'accueil)
            normalWidgetView
        } else {
            // Mode StandBy
            StandByEvaluationView(entry: entry)
        }
    }

    private var normalWidgetView: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(.indigo)
                    .padding(.top, 1)
                    .padding(.trailing, 1)
            }

            Spacer()

            if entry.hasEvaluation {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.displayTitle)
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(entry.displayTime)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.leading, 1)
                    .padding(.bottom, 1)
                    Spacer()
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.emptyStateText)
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.leading, 5)
                    .padding(.bottom, 5)
                    Spacer()
                }
            }
        }
        .containerBackground(for: .widget) {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .black.opacity(0.3) : .gray.opacity(0.15),
                    radius: 2,
                    x: 0,
                    y: 1
                )
        }
        .widgetURL(URL(string: "parallax://evaluations"))
    }
}

struct MediumEvaluationView: View {
    let entry: EvaluationEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            // Icône calendar en haut à droite
            HStack {
                Spacer()
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(.indigo)
            }
            .padding(.top, 1)
            .padding(.trailing, 1)

            Spacer()

            if entry.hasEvaluation {
                // Nom de l'évaluation et temps restant en bas à gauche
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.displayTitle)
                            .font(.headline.weight(.medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(entry.displayTime)
                            .font(.title.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.leading, 1)
                    .padding(.bottom, 1)
                    Spacer()
                }
            } else {
                // Empty state
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.emptyStateText)
                            .font(.headline.weight(.medium))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.leading, 16)
                    .padding(.bottom, 16)
                    Spacer()
                }
            }
        }
        .containerBackground(for: .widget) {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .black.opacity(0.3) : .gray.opacity(0.15),
                    radius: 2,
                    x: 0,
                    y: 1
                )
        }
        .widgetURL(URL(string: "parallax://evaluations"))
    }
}

struct CircularEvaluationView: View {
    let entry: EvaluationEntry

    var body: some View {
        GeometryReader { geometry in
            if entry.hasEvaluation {
                evaluationContentView
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                emptyStateView
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .background(
            Circle()
                .fill(Color(.systemBackground))
        )
        .clipShape(Circle())
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private var evaluationContentView: some View {
        VStack(spacing: 2) {
            Text(entry.displayTime)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            Text(entry.displayTitle)
                .font(.system(size: 6, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
    }

    private var emptyStateView: some View {
        Text(String(localized: "widget_no_evaluations_compact")) // 🔄 MODIFIÉ
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 4)
    }
}

struct RectangularEvaluationView: View {
    let entry: EvaluationEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(.mint)
                .font(.system(size: 12, weight: .medium))

            if entry.hasEvaluation {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.displayTime)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(entry.displayTitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text(String(localized: "widget_no_evaluations")) // 🔄 MODIFIÉ
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()
        }
        .padding(13)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct InlineEvaluationView: View {
    let entry: EvaluationEntry

    var body: some View {
        if entry.hasEvaluation {
            Text("\(entry.displayTime) \(entry.displayTitle)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        } else {
            Text(entry.emptyStateText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
