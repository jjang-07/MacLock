import Foundation

/// XPC interface the root daemon exports to the app. Sessions cross the connection as
/// JSON-encoded `Session` data (nil = no active session), which keeps the interface to plain types.
@objc nonisolated protocol MacLockDaemonProtocol {
    /// Starts a session unless one is already active. Replies with the session now in effect.
    func startSession(seconds: Int, reply: @escaping @Sendable (Data?) -> Void)

    /// Replies with the active session, or nil.
    func currentSession(reply: @escaping @Sendable (Data?) -> Void)

    /// Debug builds only: ends the active session. Release daemons reply false.
    func debugEndSession(reply: @escaping @Sendable (Bool) -> Void)
}

nonisolated enum DaemonPaths {
    /// Root-owned, mode 600: a normal user can't read or edit the session.
    static let stateDirectory = URL(fileURLWithPath: "/Library/Application Support/MacLock", isDirectory: true)
    static let stateFile = stateDirectory.appendingPathComponent("state.json")
    static let plistName = "com.maclock.daemon.plist"
}
