import SwiftUI

@main
struct MacLockApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    /// The menu bar label only refreshes reliably for state SwiftUI owns, so hand it the store
    /// through @State. `App.init` can run more than once, but `.shared` is always the same instance.
    @State private var store = SessionStore.shared

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

/// Starts app-lifetime work. SwiftUI may call `App.init` more than once, so nothing with side
/// effects (like connecting to the daemon or showing overlays) may happen there.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: SessionStore { .shared }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.connect()
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
