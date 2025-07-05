import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - WIDGETBUNDLE PRINCIPAL
@main
struct LiveActivitiesBundle: WidgetBundle {
    var body: some Widget {
        RevisionLiveActivity()       // ✅ Votre Live Activity existante
    }
}
