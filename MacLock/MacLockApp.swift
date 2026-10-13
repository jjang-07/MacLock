import SwiftUI

@main
struct MacLockApp: App {
    @State private var store = SessionStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environment(store)
        } label: {
            MenuBarLabel(store: store)
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

/// Lock icon when idle; filled lock plus countdown during a session.
private struct MenuBarLabel: View {
    let store: SessionStore

    var body: some View {
        if store.isActive {
            Image(systemName: "lock.fill")
            Text(Countdown.format(store.remaining))
                .monospacedDigit()
        } else {
            Image(systemName: "lock.open")
        }
    }
}
