import SwiftUI

@main
struct PARALLAXWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        WeeklyStreakWidget()
    }
}
