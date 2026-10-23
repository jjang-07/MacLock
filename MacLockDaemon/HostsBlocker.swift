import Foundation
import os

/// Keeps /etc/hosts in the state the session calls for: the MacLock block present during a
/// session, absent otherwise. Re-applying every tick also undoes manual edits mid-session.
final class HostsBlocker: @unchecked Sendable {   // used only from the supervisor's queue
    private static let hostsURL = URL(fileURLWithPath: "/etc/hosts")
    private static let backupURL = DaemonPaths.stateDirectory.appendingPathComponent("hosts.backup")
    private let log = Logger(subsystem: MacLockID.daemon, category: "Hosts")

    /// Domains to block. Configurable from Settings in M10.
    var domains: [String] = WebsiteBlocklist.defaults.compactMap(HostsFile.normalize)

    func reconcile(sessionActive: Bool) {
        guard let current = try? String(contentsOf: Self.hostsURL, encoding: .utf8) else {
            log.error("Couldn't read /etc/hosts")
            return
        }
        let wanted = HostsFile.applying(domains: sessionActive ? domains : [], to: current)
        guard wanted != current else { return }

        backUpOriginal(current)
        do {
            try Data(wanted.utf8).write(to: Self.hostsURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: Self.hostsURL.path)
            flushDNS()
            log.notice("\(sessionActive ? "Applied" : "Removed", privacy: .public) website block (\(self.domains.count) sites)")
        } catch {
            log.error("Couldn't write /etc/hosts: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Keep one copy of the user's own hosts file (without any MacLock block), just in case.
    private func backUpOriginal(_ contents: String) {
        guard !FileManager.default.fileExists(atPath: Self.backupURL.path) else { return }
        try? FileManager.default.createDirectory(at: DaemonPaths.stateDirectory, withIntermediateDirectories: true)
        try? Data(HostsFile.removingBlock(from: contents).utf8).write(to: Self.backupURL, options: .atomic)
    }

    private func flushDNS() {
        for (tool, args) in [("/usr/bin/dscacheutil", ["-flushcache"]), ("/usr/bin/killall", ["-HUP", "mDNSResponder"])] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = args
            try? process.run()
            process.waitUntilExit()
        }
    }
}
