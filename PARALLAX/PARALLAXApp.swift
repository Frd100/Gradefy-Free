import SwiftUI

@MainActor
@main
struct PARALLAXApp: App {
    let persistenceController = PersistenceController.shared
    @AppStorage("darkModeEnabled") private var darkModeEnabled: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(darkModeEnabled ? .dark : nil)
        }
    }
}
