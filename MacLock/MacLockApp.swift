import os
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
        // `--args -extend-seconds 900`: extends the running session (the "+15 min" button).
        let extendBy = UserDefaults.standard.integer(forKey: "extend-seconds")
        if extendBy > 0 {
            Task {
                try? await Task.sleep(for: .seconds(3))
                store.extend(by: .seconds(extendBy))
            }
        }
        // `--args -test-schedule-in 2 -test-schedule-length 3`: adds a schedule for today starting
        // in 2 minutes and lasting 3. `--args -remove-schedules YES`: tries to delete all schedules.
        let defaults = UserDefaults.standard
        let startIn = defaults.integer(forKey: "test-schedule-in")
        let removeAll = defaults.bool(forKey: "remove-schedules")
        if startIn > 0 || removeAll {
            Task {
                // Wait for the first sync so we edit the daemon's real config.
                try? await Task.sleep(for: .seconds(2))
                var config = store.config
                if removeAll {
                    config.schedules = []
                } else {
                    let now = Calendar.current.dateComponents([.hour, .minute, .weekday], from: .now)
                    let start = ((now.hour ?? 0) * 60 + (now.minute ?? 0) + startIn) % (24 * 60)
                    let length = max(1, defaults.integer(forKey: "test-schedule-length"))
                    config.schedules.append(Schedule(name: "Test", weekdays: [now.weekday ?? 1],
                                                     start: start, end: (start + length) % (24 * 60)))
                }
                let refusal = await store.updateConfig(config)
                Logger(subsystem: MacLockID.app, category: "Debug")
                    .notice("Test config change: \(refusal ?? "accepted", privacy: .public)")
            }
        }
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
