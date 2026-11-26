import Foundation
import os
import Synchronization

/// The single source of truth for whether a session is active. Persists to a root-only file so
/// the session survives the app quitting and (from M8) reboots.
final class SessionAuthority: Sendable {
    private let state = Mutex<Session?>(nil)
    /// Debug builds: after "End session (debug only)", don't restart a schedule's session
    /// until this time (the end of the window that was running).
    private let schedulesSuppressedUntil = Mutex<Date>(.distantPast)
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

    /// Called about once a second. Undoes system-clock changes and clears the session once it
    /// expires (deleting the state file). Returns the session still in effect.
    func tick(wallElapsed: TimeInterval, monotonicElapsed: TimeInterval, now: Date = Date()) -> Session? {
        let jump = ClockGuard.jump(wallElapsed: wallElapsed, monotonicElapsed: monotonicElapsed)
        if jump != 0 {
            state.withLock { session in
                guard let s = session else { return }
                session = s.shifted(by: jump)
                Self.save(session)
            }
            log.notice("System clock moved by \(Int(jump))s; shifted the session to keep the time remaining")
        }
        return current(now: now)
    }

    /// Makes sure a session covers `until`: starts one if none is active, or extends the active
    /// one if it would end sooner. Used for schedules.
    func cover(until end: Date, source: Session.Source, now: Date = Date()) {
        guard now >= schedulesSuppressedUntil.withLock({ $0 }) else { return }
        state.withLock { session in
            if let s = session, s.isActive(at: now) {
                guard s.end < end else { return }
                session = s.extended(to: end)
                log.notice("Extended session to \(end, privacy: .public) for a schedule")
            } else {
                session = Session(start: now, duration: .seconds(Int(end.timeIntervalSince(now).rounded(.up))), source: source)
                log.notice("Started session until \(end, privacy: .public) for a schedule")
            }
            Self.save(session)
        }
    }

    /// Adds time to the active session. Returns it, or nil if there's none.
    func extend(bySeconds seconds: Int, now: Date = Date()) -> Session? {
        guard seconds > 0, seconds <= 12 * 3600 else { return current(now: now) }
        return state.withLock { session in
            guard let s = session, s.isActive(at: now) else { return nil }
            session = s.extended(to: s.end.addingTimeInterval(TimeInterval(seconds)))
            Self.save(session)
            log.info("Extended session by \(seconds)s")
            return session
        }
    }

    func end(suppressingSchedulesUntil suppressUntil: Date? = nil) {
        state.withLock { session in
            session = nil
            Self.save(nil)
        }
        if let suppressUntil { schedulesSuppressedUntil.withLock { $0 = suppressUntil } }
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
