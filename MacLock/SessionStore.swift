import Foundation
import Observation

/// Owns the current session. App-only for now; in M7 this becomes a client of the daemon.
@Observable
final class SessionStore {
    private(set) var session: Session?
    /// Updated once a second while a session runs, so views re-render the countdown.
    private(set) var now = Date()

    private var ticker: Task<Void, Never>?
    private let enforcers: [any Enforcer]

    init(enforcers: [any Enforcer] = [ClockBlocker(), ShortcutBlocker(), NotificationCenterWatchdog(), AppBlocker(), FocusController()]) {
        self.enforcers = enforcers
    }

    var isActive: Bool { session?.isActive(at: now) ?? false }
    var remaining: TimeInterval { session?.remaining(at: now) ?? 0 }
    var progress: Double { session?.progress(at: now) ?? 0 }

    func start(duration: Duration) {
        guard !isActive else { return }   // can't replace or shorten a running session
        now = Date()
        let session = Session(start: now, duration: duration)
        self.session = session
        enforcers.forEach { $0.activate(session: session) }
        startTicking()
    }

    #if DEBUG
    /// Development escape hatch. Not compiled into Release builds.
    func debugEnd() { finish() }
    #endif

    private func startTicking() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1), tolerance: .milliseconds(100))
                guard let self else { return }
                self.now = Date()
                if !self.isActive { self.finish() }
            }
        }
    }

    private func finish() {
        ticker?.cancel()
        ticker = nil
        enforcers.forEach { $0.deactivate() }
        session = nil
        now = Date()
    }
}
