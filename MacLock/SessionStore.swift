import Foundation
import Observation

/// Mirrors the daemon's session and runs the enforcers while one is active. The daemon is the
/// source of truth: quitting or killing the app ends nothing, and on relaunch the app picks the
/// session back up.
@Observable
final class SessionStore {
    /// The one instance for the app. Creating it has no side effects; `connect()` starts the work.
    static let shared = SessionStore()

    private(set) var session: Session?
    /// Updated once a second while a session runs, so views re-render the countdown.
    private(set) var now = Date()
    private(set) var helperStatus: DaemonClient.Status = .unavailable("Not checked yet")
    private(set) var isStarting = false

    private var ticker: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private let daemon: DaemonClient
    private let enforcers: [any Enforcer]

    init(
        daemon: DaemonClient = DaemonClient(),
        enforcers: [any Enforcer] = [ClockBlocker(), ShortcutBlocker(), NotificationCenterWatchdog(), AppBlocker(), FocusController()]
    ) {
        self.daemon = daemon
        self.enforcers = enforcers
    }

    var isActive: Bool { session?.isActive(at: now) ?? false }
    var remaining: TimeInterval { session?.remaining(at: now) ?? 0 }
    var progress: Double { session?.progress(at: now) ?? 0 }

    /// Call once at launch: registers the daemon and resumes any session it holds.
    func connect() {
        checkHelper()
        // Keep in step with the daemon (e.g. a session started by a schedule, or after approval).
        syncTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sync()
                try? await Task.sleep(for: .seconds(5), tolerance: .seconds(1))
            }
        }
    }

    func checkHelper() {
        helperStatus = daemon.ensureRegistered()
    }

    func openHelperSettings() {
        daemon.openLoginItemsSettings()
    }

    func start(duration: Duration) {
        guard !isActive, !isStarting, helperStatus == .ready else { return }
        isStarting = true
        Task {
            let seconds = Int(duration.components.seconds)
            apply(await daemon.startSession(seconds: seconds))
            isStarting = false
        }
    }

    #if DEBUG
    /// Development escape hatch. Not compiled into Release builds.
    func debugEnd() {
        Task {
            if await daemon.debugEndSession() { apply(nil) }
        }
    }
    #endif

    private func sync() async {
        if helperStatus != .ready { checkHelper() }
        guard helperStatus == .ready else { return }
        // nil = daemon unreachable: keep enforcing whatever we last knew.
        if let current = await daemon.currentSession() {
            apply(current)
        }
    }

    private func apply(_ newSession: Session?) {
        now = Date()
        guard let newSession, newSession.isActive(at: now) else {
            if session != nil { finish() }
            return
        }
        guard newSession != session else { return }
        let wasActive = session != nil
        session = newSession
        // Also on changes (e.g. the daemon shifted the session after a clock change), so
        // enforcers that show the time left stay right. Activation is idempotent.
        enforcers.forEach { $0.activate(session: newSession) }
        if !wasActive { startTicking() }
    }

    private func startTicking() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1), tolerance: .milliseconds(100))
                guard let self else { return }
                self.now = Date()
                if !self.isActive {
                    // Confirm with the daemon rather than trusting the local clock alone.
                    await self.sync()
                    if self.session.map({ !$0.isActive(at: Date()) }) ?? false { self.finish() }
                }
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
