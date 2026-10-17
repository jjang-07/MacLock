import AppKit
import os

/// Swallows the keyboard shortcut for Notification Center (Globe/fn + N) during a session, so the
/// panel never opens instead of opening and being closed by the watchdog.
/// Needs Accessibility permission; without it this does nothing and the watchdog is the only defense.
final class ShortcutBlocker: Enforcer {
    private static let log = Logger(subsystem: MacLockID.app, category: "ShortcutBlocker")
    private static let nKeyCode: Int64 = 45

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var retryTimer: Timer?

    isolated deinit {
        deactivate()
    }

    func activate(session: Session) {
        guard tap == nil, retryTimer == nil else { return }
        if !installTap() {
            // Permission may be granted mid-session; keep trying.
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.installTap() else { return }
                    self.retryTimer?.invalidate()
                    self.retryTimer = nil
                }
            }
        }
    }

    func deactivate() {
        retryTimer?.invalidate()
        retryTimer = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func installTap() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            // macOS disables slow taps; turn it straight back on.
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let refcon {
                    let blocker = Unmanaged<ShortcutBlocker>.fromOpaque(refcon).takeUnretainedValue()
                    MainActor.assumeIsolated { blocker.reenable() }
                }
                return Unmanaged.passUnretained(event)
            }
            let isShortcut = event.getIntegerValueField(.keyboardEventKeycode) == ShortcutBlocker.nKeyCode
                && event.flags.contains(.maskSecondaryFn)
            if isShortcut {
                ShortcutBlocker.log.info("Swallowed Notification Center shortcut (\(type == .keyDown ? "down" : "up", privacy: .public))")
                return nil
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask), callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Self.log.error("Couldn't create event tap")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        Self.log.info("Shortcut blocker active")
        return true
    }

    private func reenable() {
        Self.log.info("Event tap was disabled by the system; re-enabling")
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }
}
