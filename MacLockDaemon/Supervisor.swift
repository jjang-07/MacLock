import Darwin
import Foundation
import os
import SystemConfiguration

/// Runs once a second in the daemon: keeps the session honest against clock changes, ends it on
/// time, and relaunches the app for the logged-in user if it's not running during a session.
final class Supervisor: @unchecked Sendable {   // all state is confined to `queue`
    private let authority: SessionAuthority
    private let queue = DispatchQueue(label: "com.maclock.daemon.supervisor")
    private let log = Logger(subsystem: MacLockID.daemon, category: "Supervisor")
    private var timer: DispatchSourceTimer?

    private var lastWall = Date()
    private var lastMonotonic = ContinuousClock.now
    private var lastLaunchAttempt = Date.distantPast
    private var tickCount = 0

    /// The app bundle this daemon is embedded in: …/MacLock.app/Contents/MacOS/MacLockDaemon.
    private let appURL: URL
    private let executableURL: URL
    private let executableInode: ino_t?

    init(authority: SessionAuthority) {
        self.authority = authority
        // Not argv[0]: launchd starts the daemon with a path relative to the app bundle.
        executableURL = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
            .resolvingSymlinksInPath()
        appURL = executableURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        executableInode = Self.inode(of: executableURL)
        log.info("Daemon binary \(self.executableURL.path, privacy: .public), app \(self.appURL.path, privacy: .public)")
    }

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    private func tick() {
        let wall = Date(), monotonic = ContinuousClock.now
        let wallElapsed = wall.timeIntervalSince(lastWall)
        let monotonicElapsed = TimeInterval((monotonic - lastMonotonic).components.seconds)
            + TimeInterval((monotonic - lastMonotonic).components.attoseconds) / 1e18
        lastWall = wall
        lastMonotonic = monotonic

        let session = authority.tick(wallElapsed: wallElapsed, monotonicElapsed: monotonicElapsed, now: wall)
        if session != nil { ensureAppRunning() }

        tickCount += 1
        if tickCount % 5 == 0 { exitIfReplaced() }
    }

    // MARK: Keeping the app running

    private func ensureAppRunning() {
        guard let user = Self.consoleUser() else { return }   // nobody logged in yet
        guard !Self.isProcessRunning(named: "MacLock", uid: user.uid) else { return }
        guard Date().timeIntervalSince(lastLaunchAttempt) > 3 else { return }
        lastLaunchAttempt = Date()

        log.notice("MacLock isn't running during a session; relaunching it for uid \(user.uid)")
        // `open` goes through LaunchServices, so there's never a second copy of the app. It must
        // run as the user (not root) inside the user's session, or LaunchServices refuses.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["asuser", String(user.uid), "/usr/bin/sudo", "-u", user.name, "/usr/bin/open", "-g", appURL.path]
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        process.terminationHandler = { [log] process in
            guard process.terminationStatus != 0 else { return }
            let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            log.error("Relaunch failed (status \(process.terminationStatus)): \(message, privacy: .public)")
        }
        do {
            try process.run()
        } catch {
            log.error("Relaunch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The user at the login window/desktop, if any.
    private static func consoleUser() -> (name: String, uid: uid_t)? {
        var uid: uid_t = 0
        guard let name = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) as String?,
              name != "loginwindow", uid != 0
        else { return nil }
        return (name, uid)
    }

    private static func isProcessRunning(named name: String, uid: uid_t) -> Bool {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_UID, Int32(uid)]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return false }
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / MemoryLayout<kinfo_proc>.stride + 8)
        size = procs.count * MemoryLayout<kinfo_proc>.stride
        guard sysctl(&mib, UInt32(mib.count), &procs, &size, nil, 0) == 0 else { return false }
        let count = size / MemoryLayout<kinfo_proc>.stride
        return procs.prefix(count).contains { proc in
            var comm = proc.kp_proc.p_comm
            let processName = withUnsafeBytes(of: &comm) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
            return processName == name
        }
    }

    // MARK: Updates

    /// When the app is reinstalled, launchd keeps running the old daemon. Exit so launchd
    /// (KeepAlive) starts the new binary. The session is on disk, so nothing is lost.
    private func exitIfReplaced() {
        guard let executableInode, Self.inode(of: executableURL) != executableInode else { return }
        log.notice("Daemon binary was replaced; exiting so launchd starts the new one")
        exit(0)
    }

    private static func inode(of url: URL) -> ino_t? {
        var info = stat()
        return stat(url.path, &info) == 0 ? info.st_ino : nil
    }
}
