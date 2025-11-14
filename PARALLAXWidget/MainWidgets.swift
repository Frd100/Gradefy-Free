import Foundation
import SwiftUI
import WidgetKit

// MARK: - Widget Data Manager pour Semaines Consécutives

class WidgetDataManager {
    static let shared = WidgetDataManager()
    private let defaults = UserDefaults(suiteName: "group.com.Coefficient.PARALLAX2")
    private let consecutiveWeeksKey = "consecutiveWeeks"
    private let lastActiveWeekKey = "lastActiveWeekIdentifier"

    func getConsecutiveWeeks() -> Int {
        let storedStreak = defaults?.integer(forKey: consecutiveWeeksKey) ?? 0
        guard storedStreak > 0 else { return 0 }
        guard let lastIdentifier = defaults?.string(forKey: lastActiveWeekKey),
              let lastDate = Self.date(fromWeekIdentifier: lastIdentifier)
        else {
            return storedStreak
        }

        let calendar = Calendar.current
        let currentStart = calendar.startOfWeek(for: Date())
        let lastStart = calendar.startOfWeek(for: lastDate)

        guard let weeksApart = calendar.dateComponents([.weekOfYear], from: lastStart, to: currentStart).weekOfYear else {
            return storedStreak
        }

        if weeksApart > 1 {
            defaults?.set(0, forKey: consecutiveWeeksKey)
            return 0
        }

        return storedStreak
    }

    private static func date(fromWeekIdentifier identifier: String) -> Date? {
        let components = identifier.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let week = Int(components[1]) else { return nil }

        var dateComponents = DateComponents()
        dateComponents.weekOfYear = week
        dateComponents.yearForWeekOfYear = year
        dateComponents.weekday = 2 // Lundi

        return Calendar.current.date(from: dateComponents)
    }
}

// MARK: - Entry Structure pour Semaines

struct WeeklyStreakEntry: TimelineEntry {
    let date: Date
    let consecutiveWeeks: Int
}

// MARK: - Extension pour le formatage

extension WeeklyStreakEntry {
    var formattedStreak: String {
        return "\(consecutiveWeeks)"
    }

    var streakLabel: String {
        if consecutiveWeeks <= 1 {
            return String(localized: "widget_week_singular") // "semaine"
        } else {
            return String(localized: "widget_weeks_plural") // "semaines"
        }
    }
}

// MARK: - Provider pour Semaines

struct WeeklyStreakProvider: TimelineProvider {
    func placeholder(in _: Context) -> WeeklyStreakEntry {
        WeeklyStreakEntry(date: Date(), consecutiveWeeks: 3)
    }

    func getSnapshot(in _: Context, completion: @escaping (WeeklyStreakEntry) -> Void) {
        completion(WeeklyStreakEntry(date: Date(), consecutiveWeeks: 3))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<WeeklyStreakEntry>) -> Void) {
        let consecutiveWeeks = WidgetDataManager.shared.getConsecutiveWeeks()
        let entry = WeeklyStreakEntry(date: Date(), consecutiveWeeks: consecutiveWeeks)

        // Mise à jour quotidienne
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Vue Widget Simplifiée

// ✅ MODIFIÉ : Toujours afficher le widget - Application entièrement gratuite
struct WeeklyStreakWidgetView: View {
    var entry: WeeklyStreakEntry

    var body: some View {
        SmallStreakWidgetView(entry: entry) // Toujours accessible
    }
}

struct SmallStreakWidgetView: View {
    let entry: WeeklyStreakEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // ✅ Gros cercle blanc à gauche qui contient le contenu
            HStack {
                Circle()
                    .fill(Color(.systemBackground)) // ✅ Cercle blanc/adaptatif
                    .frame(width: 190, height: 190)
                    .overlay(
                        // ✅ Contenu texte centré dans le cercle
                        VStack(spacing: 4) {
                            Text(entry.formattedStreak)
                                .font(
                                    .system(size: 45, weight: .black, design: .default)
                                )
                                .foregroundStyle(Color(.label)) // ✅ CORRIGÉ : Adaptatif (noir/blanc)

                            Text(entry.streakLabel)
                                .font(.footnote.weight(.regular))
                                .foregroundColor(Color(.secondaryLabel)) // ✅ CORRIGÉ : Adaptatif avec opacité
                        }
                        .offset(x: 35) // ✅ Décalage vers la droite
                    )
                    .offset(x: -55) // ✅ Légèrement décalé vers la gauche

                Spacer()
            }
        }
        .containerBackground(for: .widget) {
            // ✅ Fond bleu uniforme
            Color.blue
        }
        .widgetURL(URL(string: "parallax://streak-stats"))
    }
}

// MARK: - Widget Configuration (Seulement systemSmall)

struct WeeklyStreakWidget: Widget {
    let kind: String = "WeeklyStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WeeklyStreakProvider(),
            content: { entry in
                WeeklyStreakWidgetView(entry: entry)
            }
        )
        .configurationDisplayName(String(localized: "widget_streak_title"))
        .description(String(localized: "widget_streak_description"))
        .supportedFamilies([.systemSmall]) // ✅ Seulement systemSmall
        .contentMarginsDisabled()
    }
}

// MARK: - Bundle Principal

struct MainWidgets: WidgetBundle {
    var body: some Widget {
        WeeklyStreakWidget()
    }
}

// MARK: - Previews

struct WeeklyStreakWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview avec 0 semaine
            SmallStreakWidgetView(entry: WeeklyStreakEntry(date: Date(), consecutiveWeeks: 0))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("0 semaine")

            // Preview avec 1 semaine
            SmallStreakWidgetView(entry: WeeklyStreakEntry(date: Date(), consecutiveWeeks: 1))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("1 semaine")

            // Preview avec 3 semaines
            SmallStreakWidgetView(entry: WeeklyStreakEntry(date: Date(), consecutiveWeeks: 3))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("3 semaines")

            // Preview avec 7 semaines
            SmallStreakWidgetView(entry: WeeklyStreakEntry(date: Date(), consecutiveWeeks: 7))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("7 semaines")

            // Preview avec 15 semaines
            SmallStreakWidgetView(entry: WeeklyStreakEntry(date: Date(), consecutiveWeeks: 15))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("15 semaines")

            // Preview avec 25 semaines
            SmallStreakWidgetView(entry: WeeklyStreakEntry(date: Date(), consecutiveWeeks: 25))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("25 semaines")
        }
    }
}

// MARK: - Calendar Helpers

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        var startComponents = DateComponents()
        startComponents.weekOfYear = components.weekOfYear
        startComponents.yearForWeekOfYear = components.yearForWeekOfYear
        startComponents.weekday = 2 // Lundi
        return self.date(from: startComponents) ?? date
    }
}

// Preview pour tester en mode sombre
struct WeeklyStreakWidgetDark_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SmallStreakWidgetView(entry: WeeklyStreakEntry(date: Date(), consecutiveWeeks: 5))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .preferredColorScheme(.dark)
                .previewDisplayName("Mode sombre - 5 semaines")

            SmallStreakWidgetView(entry: WeeklyStreakEntry(date: Date(), consecutiveWeeks: 12))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .preferredColorScheme(.dark)
                .previewDisplayName("Mode sombre - 12 semaines")
        }
    }
}
