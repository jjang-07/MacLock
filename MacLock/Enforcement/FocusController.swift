import Foundation
import os

/// Turns Do Not Disturb on for the session through the user's Shortcuts "MacLock Focus On/Off"
/// (macOS has no public API for Focus). DND state can't be read back without Full Disk Access,
/// so success is judged by the shortcut's exit status.
final class FocusController: Enforcer {
    nonisolated static let onShortcut = "MacLock Focus On"
    nonisolated static let offShortcut = "MacLock Focus Off"
    nonisolated private static let log = Logger(subsystem: MacLockID.app, category: "Focus")

    private var turnedOn = false

    func activate(session: Session) {
        guard !turnedOn else { return }
        turnedOn = true
        Self.run(Self.onShortcut)
    }

    func deactivate() {
        // Only undo what we did; never turn off a DND the user set themselves outside a session.
        guard turnedOn else { return }
        turnedOn = false
        Self.run(Self.offShortcut)
    }

    /// Whether both shortcuts exist in the Shortcuts app.
    nonisolated static func shortcutsInstalled() async -> Bool {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return false }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let names = Set(String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init))
            return names.contains(onShortcut) && names.contains(offShortcut)
        }.value
    }

    /// Runs off the main thread: launching Shortcuts can take a second or two.
    nonisolated private static func run(_ shortcut: String) {
        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", shortcut]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    log.info("Ran shortcut \"\(shortcut, privacy: .public)\"")
                } else {
                    log.error("Shortcut \"\(shortcut, privacy: .public)\" failed (status \(process.terminationStatus)); is it set up in Shortcuts?")
                }
            } catch {
                log.error("Couldn't run shortcuts: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
