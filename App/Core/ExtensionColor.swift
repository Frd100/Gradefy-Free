import SwiftUI
import UIKit

extension Color {
    // MARK: - Hex Initialization (Optimized)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128) // Couleur par défaut améliorée
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // MARK: - Hex Conversion (Optimized)

    func toHex() -> String {
        guard let components = cgColor?.components, components.count >= 3 else {
            return "000000"
        }

        let red = Int(components[0] * 255)
        let green = Int(components[1] * 255)
        let blue = Int(components[2] * 255)

        return String(format: "%02X%02X%02X", red, green, blue)
    }

    func toHexWithAlpha() -> String {
        guard let components = cgColor?.components else {
            return "00000000"
        }

        let red = Int(components[0] * 255)
        let green = Int(components[1] * 255)
        let blue = Int(components[2] * 255)
        let alpha = components.count > 3 ? Int(components[3] * 255) : 255

        return String(format: "%02X%02X%02X%02X", red, green, blue, alpha)
    }

    // MARK: - App Theme Colors (Gradefy Specific)

    static var appBackground: Color {
        Color(hex: "F6F7FB")
    }

    // ✅ NOUVEAU : Couleurs pour les cartes home refactorisées
    static var cardBackground: Color {
        Color(.systemBackground)
    }

    static var cardBackgroundSecondary: Color {
        Color(.secondarySystemBackground)
    }

    static var cardShadow: Color {
        Color.black.opacity(0.04)
    }

    // ✅ NOUVEAU : Couleurs Activity Ring
    static var activityRingPrimary: Color {
        Color(hex: "5AC8FA")
    }

    static var activityRingBackground: Color {
        Color(hex: "5AC8FA").opacity(0.2)
    }

    // Couleurs existantes optimisées
    static var gradeBluePrimary: Color {
        Color(hex: "5AC8FA")
    }

    static var gradeGreenSecondary: Color {
        Color(hex: "2ECC40")
    }

    // ✅ NOUVEAU : Couleurs pour les différents types de cartes
    static var listesCardColor: Color {
        Color.blue
    }

    static var subjectsCardColor: Color {
        Color.blue
    }

    static var deadlineCardColor: Color {
        Color.orange
    }

    static var periodsCardColor: Color {
        Color.green
    }

    static var systemCardColor: Color {
        Color.gray
    }

    // ✅ NOUVEAU : Couleurs de statut
    static var successColor: Color {
        Color.green
    }

    static var warningColor: Color {
        Color.orange
    }

    static var errorColor: Color {
        Color.red
    }

    static var infoColor: Color {
        Color.blue
    }

    static var profileGradientStart: Color {
        Color(hex: "90A4AE") // Au lieu de "9BE8F6"
    }

    static var profileGradientEnd: Color {
        Color(hex: "253137") // Au lieu de "5DD5F4"
    }

    // ✅ NOUVEAU : Gradient premium pour la carte Gradefy Pro
    static var premiumGradientStart: Color {
        Color.blue
    }

    static var premiumGradientEnd: Color {
        Color.blue.opacity(0.8)
    }

    // MARK: - Color Utilities (Optimized)

    var isDark: Bool {
        guard let components = cgColor?.components, components.count >= 3 else {
            return false
        }

        let red = components[0]
        let green = components[1]
        let blue = components[2]

        // Calcul de la luminance selon les standards WCAG
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance < 0.5
    }

    var contrastingColor: Color {
        isDark ? .white : .black
    }

    // ✅ NOUVEAU : Fonction pour obtenir une couleur avec opacité adaptative selon le thème
    func adaptiveOpacity(light: Double, dark _: Double) -> Color {
        // Cette fonction sera utilisée avec @Environment(\.colorScheme)
        // Pour l'instant, on retourne la version de base
        return opacity(light)
    }

    // ✅ NOUVEAU : Fonction pour créer des variantes de couleur
    func lighter(by percentage: Double = 0.2) -> Color {
        guard let components = cgColor?.components, components.count >= 3 else {
            return self
        }

        let red = min(1.0, components[0] + percentage)
        let green = min(1.0, components[1] + percentage)
        let blue = min(1.0, components[2] + percentage)
        let alpha = components.count > 3 ? components[3] : 1.0

        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    func darker(by percentage: Double = 0.2) -> Color {
        guard let components = cgColor?.components, components.count >= 3 else {
            return self
        }

        let red = max(0.0, components[0] - percentage)
        let green = max(0.0, components[1] - percentage)
        let blue = max(0.0, components[2] - percentage)
        let alpha = components.count > 3 ? components[3] : 1.0

        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    // ✅ NOUVEAU : Fonction pour vérifier le contraste WCAG
    func contrastRatio(with other: Color) -> Double {
        let luminance1 = relativeLuminance
        let luminance2 = other.relativeLuminance

        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)

        return (lighter + 0.05) / (darker + 0.05)
    }

    private var relativeLuminance: Double {
        guard let components = cgColor?.components, components.count >= 3 else {
            return 0
        }

        let red = gammaCorrect(components[0])
        let green = gammaCorrect(components[1])
        let blue = gammaCorrect(components[2])

        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    private func gammaCorrect(_ value: CGFloat) -> Double {
        let val = Double(value)
        return val <= 0.03928 ? val / 12.92 : pow((val + 0.055) / 1.055, 2.4)
    }

    // ✅ NOUVEAU : Couleurs adaptatives pour le thème système
    static func adaptive(light: Color, dark: Color) -> Color {
        // Cette fonction nécessite iOS 13+ pour Color(UIColor.init)
        return Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    // ✅ NOUVEAU : Palette de couleurs pour les icônes de matières
    static var subjectColors: [Color] {
        [
            Color(hex: "FF6B6B"), // Rouge corail
            Color(hex: "4ECDC4"), // Turquoise
            Color(hex: "45B7D1"), // Bleu ciel
            Color(hex: "96CEB4"), // Vert menthe
            Color(hex: "FFEAA7"), // Jaune pastel
            Color(hex: "DDA0DD"), // Prune
            Color(hex: "FFB347"), // Orange pêche
            Color(hex: "87CEEB"), // Bleu ciel clair
            Color(hex: "98FB98"), // Vert pâle
            Color(hex: "F0E68C"), // Kaki clair
        ]
    }

    // ✅ NOUVEAU : Fonction pour obtenir une couleur de matière par index
    static func subjectColor(for index: Int) -> Color {
        subjectColors[index % subjectColors.count]
    }
}

// MARK: - Color Extension pour les vues adaptatives

extension Color {
    // ✅ NOUVEAU : Fonctions spécifiques pour les cartes Gradefy
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? .white : Color(.secondarySystemBackground)
    }

    static func cardShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.04) : .clear
    }

    static func adaptiveText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? .black : .white
    }

    static func adaptiveSecondaryText(for _: ColorScheme) -> Color {
        Color(.secondaryLabel)
    }
}
