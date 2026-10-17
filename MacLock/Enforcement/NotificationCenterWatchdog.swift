import AppKit
import ApplicationServices
import os

/// Backup for routes the clock overlay can't cover (Globe+N, hot corners, trackpad gestures):
/// if Notification Center opens during a session, close it immediately.
///
/// With Accessibility permission, macOS notifies us when Notification Center creates a window,
/// so there's no polling (≈0% CPU). Without it, we poll the window list 10×/s (≈1.5% CPU).
final class NotificationCenterWatchdog: Enforcer {
    private static let bundleID = "com.apple.notificationcenterui"
    private static let log = Logger(subsystem: MacLockID.app, category: "NCWatchdog")
    /// Fires as the panel starts opening, slightly before it's on screen (it slides in).
    private static let axEvents = [kAXWindowCreatedNotification, kAXCreatedNotification]

    private var pollTimer: Timer?
    private var burstTimer: Timer?
    private var burstEnd = Date.distantPast
    private var observer: AXObserver?
    private var observedPID: pid_t?
    private var lastKill = Date.distantPast

    isolated deinit {
        deactivate()
    }

    func activate(session: Session) {
        guard pollTimer == nil else { return }
        if !AXIsProcessTrusted() {
            // Shows the system prompt pointing at Privacy & Security → Accessibility.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        attachObserver()
        startPolling()
    }

    func deactivate() {
        pollTimer?.invalidate()
        pollTimer = nil
        burstTimer?.invalidate()
        burstTimer = nil
        detachObserver()
    }

    // MARK: Polling

    /// Fast while we have no event observer; otherwise a slow safety net that also re-attaches
    /// to Notification Center after it restarts (it gets a new process ID).
    private func startPolling() {
        pollTimer?.invalidate()
        let interval = observer == nil ? 0.1 : 2.0
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        pollTimer?.tolerance = interval / 5
    }

    private func poll() {
        let hadObserver = observer != nil
        if observedPID != Self.notificationCenterPID() { attachObserver() }
        if (observer != nil) != hadObserver { startPolling() }   // switch speed
        closeIfOpen()
    }

    // MARK: Accessibility events

    private func attachObserver() {
        detachObserver()
        guard AXIsProcessTrusted(), let pid = Self.notificationCenterPID() else { return }

        var newObserver: AXObserver?
        let callback: AXObserverCallback = { _, _, event, refcon in
            guard let refcon else { return }
            let watchdog = Unmanaged<NotificationCenterWatchdog>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated {
                NotificationCenterWatchdog.log.debug("AX event: \(event as String, privacy: .public)")
                watchdog.startBurst()
            }
        }
        guard AXObserverCreate(pid, callback, &newObserver) == .success, let newObserver else { return }

        let app = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let added = Self.axEvents.filter { AXObserverAddNotification(newObserver, app, $0 as CFString, refcon) == .success }
        guard !added.isEmpty else { return }

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .defaultMode)
        observer = newObserver
        observedPID = pid
        Self.log.info("Observing Notification Center (pid \(pid)): \(added.joined(separator: ", "), privacy: .public)")
    }

    private func detachObserver() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        observedPID = nil
    }

    /// A window is being created but the panel isn't on screen yet, so watch closely for a moment.
    private func startBurst() {
        burstEnd = Date().addingTimeInterval(1.5)
        closeIfOpen()
        guard burstTimer == nil else { return }
        burstTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.burstTick() }
        }
    }

    private func burstTick() {
        closeIfOpen()
        if Date() > burstEnd {
            burstTimer?.invalidate()
            burstTimer = nil
        }
    }

    // MARK: Closing

    private func closeIfOpen() {
        guard NotificationCenterDetector.isOpen(Self.panelLayerWindows()) else { return }
        // Give a just-killed process a moment to go away before trying again.
        guard Date().timeIntervalSince(lastKill) > 0.3 else { return }
        lastKill = Date()
        Self.log.info("Notification Center opened during a session; closing it")

        // Quitting the process closes the panel; launchd restarts it right away and nothing is lost.
        if let pid = Self.notificationCenterPID() { kill(pid, SIGKILL) }

        // Re-attach to the restarted process soon, rather than waiting for the next slow poll.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.poll() }
    }

    private static func notificationCenterPID() -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.processIdentifier
    }

    /// Avoids bridging the whole window list into Swift dictionaries: reads each window's layer
    /// straight from CoreFoundation and only fetches the owner name at the panel's layer.
    private static func panelLayerWindows() -> [NotificationCenterDetector.WindowInfo] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) else { return [] }
        var result: [NotificationCenterDetector.WindowInfo] = []
        for index in 0..<CFArrayGetCount(list) {
            let window = unsafeBitCast(CFArrayGetValueAtIndex(list, index), to: CFDictionary.self)
            var layer = 0
            guard let layerValue = CFDictionaryGetValue(window, layerKey),
                  CFNumberGetValue(unsafeBitCast(layerValue, to: CFNumber.self), .intType, &layer),
                  layer == NotificationCenterDetector.panelLayer,
                  let ownerValue = CFDictionaryGetValue(window, ownerKey)
            else { continue }
            result.append(.init(owner: unsafeBitCast(ownerValue, to: CFString.self) as String, layer: layer))
        }
        return result
    }

    private static let layerKey = Unmanaged.passUnretained(kCGWindowLayer).toOpaque()
    private static let ownerKey = Unmanaged.passUnretained(kCGWindowOwnerName).toOpaque()
}
