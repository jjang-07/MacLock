import AppKit
import os

/// Closes blocklisted apps during a session.
/// - Already running at session start: asked to quit (so they can save), force-quit after 2s.
/// - Launched during the session: force-quit immediately, before a window can show.
final class AppBlocker: Enforcer {
    static let blocklistKey = "blockedApps"
    private static let log = Logger(subsystem: MacLockID.app, category: "AppBlocker")

    private var session: Session?
    private var launchObserver: NSObjectProtocol?
    private let toast = FocusToast()

    /// Bundle IDs to block. Editable in Settings from M10; defaults until then.
    private var blocklist: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.blocklistKey) ?? AppBlocklist.defaults)
    }

    isolated deinit {
        deactivate()
    }

    func activate(session: Session) {
        self.session = session
        guard launchObserver == nil else { return }

        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self, let app else { return }
                self.blockIfListed(app, graceful: false)
            }
        }

        // Sweep what's already open.
        for app in NSWorkspace.shared.runningApplications {
            blockIfListed(app, graceful: true)
        }
    }

    func deactivate() {
        if let launchObserver { NSWorkspace.shared.notificationCenter.removeObserver(launchObserver) }
        launchObserver = nil
        toast.dismiss()
        session = nil
    }

    private func blockIfListed(_ app: NSRunningApplication, graceful: Bool) {
        guard AppBlocklist.shouldBlock(app.bundleIdentifier, blocklist: blocklist) else { return }
        let name = app.localizedName ?? app.bundleIdentifier ?? "App"
        Self.log.info("Blocking \(name, privacy: .public) (\(graceful ? "quit" : "force quit", privacy: .public))")

        if graceful {
            app.terminate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if !app.isTerminated { app.forceTerminate() }
            }
        } else {
            app.forceTerminate()
            showToast(for: name)
        }
    }

    private func showToast(for name: String) {
        guard let session, let screen = NSScreen.main else { return }
        let remaining = Countdown.focusMessage(remaining: session.remaining(at: Date()))
            .replacingOccurrences(of: " — stay focused.", with: "")
        let anchor = ClockGeometry.fallbackFrame(screen: screen.frame)
        toast.show("\(name) is blocked — \(remaining)", below: anchor)
    }
}
