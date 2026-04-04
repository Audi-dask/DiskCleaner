import SwiftUI

@main
struct DiskCleanerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 600)
                .tint(AppTheme.accent)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
