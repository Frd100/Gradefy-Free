//
//  AppConstants.swift
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

enum AppConstants {
    enum Animation {
        static let lottieSize: CGFloat = 110
        static let iconPreviewSize: CGFloat = 28
        static let profileAvatarSize: CGFloat = 60
        static let editProfileAvatarSize: CGFloat = 100
        static let gradientButtonSize: CGFloat = 30
    }

    enum Limits {
        static let minimumPeriods = 1
        static let maxPeriodNameLength = 50
        static let minimumPeriodDurationDays = 1
        static let maximumPeriodDurationDays = 730 // 2 ans
    }
}

enum DataImportError: LocalizedError {
    case contextNotConfigured
    case invalidJSONFormat
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .contextNotConfigured:
            return "Context Core Data non configuré"
        case .invalidJSONFormat:
            return "Format JSON invalide"
        case .exportFailed:
            return "Échec de l'export des données"
        }
    }
}

// MARK: - Error Handling (Correction : Gestion d'erreurs spécifiques)

enum PeriodError: LocalizedError {
    case invalidName
    case duplicateName(String)
    case invalidDateRange
    case periodTooShort
    case periodTooLong
    case overlappingDates
    case coreDataError(Error)
    case cannotDeleteLastPeriod

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Le nom de la période n'est pas valide."
        case let .duplicateName(name):
            return "Une période nommée \"\(name)\" existe déjà."
        case .invalidDateRange:
            return "La date de fin doit être postérieure à la date de début."
        case .periodTooShort:
            return "La période doit durer au moins 1 jour."
        case .periodTooLong:
            return "La période ne peut pas dépasser 2 ans."
        case .overlappingDates:
            return "Cette période chevauche avec une période existante."
        case let .coreDataError(error):
            return "Erreur de base de données : \(error.localizedDescription)"
        case .cannotDeleteLastPeriod:
            return "Impossible de supprimer la dernière période."
        }
    }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes = [UTType.json]
    static var writableContentTypes = [UTType.json]

    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(configuration _: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnknown)
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct ZIPDocument: FileDocument {
    static var readableContentTypes = [UTType.zip]
    static var writableContentTypes = [UTType.zip]

    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(configuration _: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnknown)
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Extension pour la notification

extension Notification.Name {
    static let resetToOnboarding = Notification.Name("resetToOnboarding")
}

extension NSNotification.Name {
    static let activePeriodChanged = NSNotification.Name("activePeriodChanged")
}
