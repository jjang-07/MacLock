import SwiftUI

@main
struct MacLockApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environment(appDelegate.store)
        } label: {
            MenuBarLabel(store: appDelegate.store)
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

/// Owns app-lifetime state. SwiftUI may call `App.init` more than once, so nothing with side
/// effects (like the session store and its on-screen overlays) may be created there.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = SessionStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // `open MacLock.app --args -start-seconds 60` starts a session at launch, for testing.
        let seconds = UserDefaults.standard.integer(forKey: "start-seconds")
        if seconds > 0 { store.start(duration: .seconds(seconds)) }
        #endif
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
