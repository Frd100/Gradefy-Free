//
//  WidgetPremiumHelper.swift
//  PARALLAX
//
//  Created by vous on aujourd'hui.
//

import Foundation

enum WidgetPremiumHelper {
    private static let appGroupIdentifier = "group.com.Coefficient.PARALLAX2"

    // ✅ MODIFIÉ : Toujours retourner true - Application entièrement gratuite
    static func isPremiumUser() -> Bool {
        return true // Toujours gratuit
    }
}
