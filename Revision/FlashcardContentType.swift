//
//  FlashcardContentType.swift
//  PARALLAX
//
//  Created by Farid on 7/27/25.
//

// Nouveau fichier : FlashcardContentType.swift
import Foundation

enum FlashcardContentType: String, CaseIterable, Codable {
    case text
    case image
    case audio

    var displayName: String {
        switch self {
        case .text: return "Texte"
        case .image: return "Image"
        case .audio: return "Audio"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .audio: return "waveform"
        }
    }
}
