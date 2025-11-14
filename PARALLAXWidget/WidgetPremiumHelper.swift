//
//  WidgetPremiumHelper.swift
//  PARALLAX
//
//  Created by vous on aujourd'hui.
//

import Foundation

struct WidgetPremiumHelper {
    private static let appGroupIdentifier = "group.com.Coefficient.PARALLAX2"
    
    static func isPremiumUser() -> Bool {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        return defaults?.bool(forKey: "isPremium") ?? false
    }
}
