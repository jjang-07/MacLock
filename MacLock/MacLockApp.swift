import SwiftUI

@main
struct MacLockApp: App {
    var body: some Scene {
        MenuBarExtra("MacLock", systemImage: "lock") {
            MenuContent()
        }
        .menuBarExtraStyle(.window)

        // A plain Window instead of a Settings scene: SettingsLink is unreliable in LSUIElement apps.
        Window("MacLock Settings", id: WindowID.settings) {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

enum WindowID {
    static let settings = "settings"
}
