import Foundation
import os
import Synchronization

/// The single source of truth for whether a session is active. Persists to a root-only file so
/// the session survives the app quitting and (from M8) reboots.
final class SessionAuthority: Sendable {
    private let state = Mutex<Session?>(nil)
    private let log = Logger(subsystem: MacLockID.daemon, category: "Session")

    init() {
        state.withLock { $0 = Self.load() }
        if let session = current() {
            log.info("Restored session ending \(session.end, privacy: .public)")
        }
    }

    /// The active session, or nil (an expired one is cleared).
    func current(now: Date = Date()) -> Session? {
        state.withLock { session in
            if let s = session, !s.isActive(at: now) {
                session = nil
                Self.save(nil)
            }
            return session
        }
    }

    /// Starts a session unless one is active; returns whichever is now in effect.
    func start(seconds: Int, now: Date = Date()) -> Session? {
        guard seconds > 0, seconds <= 24 * 3600 else { return current(now: now) }
        return state.withLock { session in
            if let s = session, s.isActive(at: now) { return s }   // can't replace or shorten
            let new = Session(start: now, duration: .seconds(seconds))
            session = new
            Self.save(new)
            log.info("Started \(seconds)s session")
            return new
        }
    }

    func end() {
        state.withLock { session in
            session = nil
            Self.save(nil)
        }
        log.info("Session ended early (debug)")
    }

    // MARK: Persistence

    private static func load() -> Session? {
        guard let data = try? Data(contentsOf: DaemonPaths.stateFile) else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    private static func save(_ session: Session?) {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: DaemonPaths.stateDirectory, withIntermediateDirectories: true,
                                   attributes: [.posixPermissions: 0o755])
            if let session {
                let data = try JSONEncoder().encode(session)
                try data.write(to: DaemonPaths.stateFile, options: .atomic)
                try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: DaemonPaths.stateFile.path)
            } else if fm.fileExists(atPath: DaemonPaths.stateFile.path) {
                try fm.removeItem(at: DaemonPaths.stateFile)
            }
        } catch {
            Logger(subsystem: MacLockID.daemon, category: "Session")
                .error("Couldn't save state: \(error.localizedDescription, privacy: .public)")
        }
    }
}
