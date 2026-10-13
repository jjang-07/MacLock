import Foundation
import Observation

/// Owns the current session. App-only for now; in M7 this becomes a client of the daemon.
@Observable
final class SessionStore {
    private(set) var session: Session?
    /// Updated once a second while a session runs, so views re-render the countdown.
    private(set) var now = Date()

    private var ticker: Task<Void, Never>?

    var isActive: Bool { session?.isActive(at: now) ?? false }
    var remaining: TimeInterval { session?.remaining(at: now) ?? 0 }
    var progress: Double { session?.progress(at: now) ?? 0 }

    func start(duration: Duration) {
        guard !isActive else { return }   // can't replace or shorten a running session
        now = Date()
        session = Session(start: now, duration: duration)
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
        session = nil
        now = Date()
    }
}
