import AppKit

/// Covers the menu bar clock on every display with an invisible panel, so clicking it can't open
/// Notification Center. Clicks show a "stay focused" toast instead.
///
/// Panels are never removed during a session: in full screen the menu bar hides, detection finds
/// nothing, and the last known frame is kept (see Spikes/RESULTS.md).
final class ClockBlocker: Enforcer {
    private var session: Session?
    private var panels: [CGDirectDisplayID: NSPanel] = [:]
    private var clockFrames: [CGDirectDisplayID: CGRect] = [:]
    private var relayoutTimer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private let toast = FocusToast()

    /// On-screen windows outlive their owner, so never let the overlays leak.
    isolated deinit {
        deactivate()
    }

    func activate(session: Session) {
        self.session = session
        guard relayoutTimer == nil else { return }

        relayout()
        // The clock's width changes with its text and the menu bar can move between displays,
        // so keep tracking it. A window-list query costs well under a millisecond.
        relayoutTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.relayout() }
        }
        relayoutTimer?.tolerance = 0.1

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            observe(workspace, name)
        }
        observe(.default, NSApplication.didChangeScreenParametersNotification)
    }

    func deactivate() {
        relayoutTimer?.invalidate()
        relayoutTimer = nil
        observers.forEach { center, token in center.removeObserver(token) }
        observers.removeAll()
        panels.values.forEach { $0.orderOut(nil) }
        panels.removeAll()
        toast.dismiss()
        session = nil
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.relayout() }
        }
        observers.append((center, token))
    }

    private func relayout() {
        let screens = NSScreen.screens
        guard let primaryHeight = screens.first?.frame.height else { return }
        let items = Self.menuBarItemFrames()

        var seen = Set<CGDirectDisplayID>()
        for screen in screens {
            guard let id = screen.displayID else { continue }
            seen.insert(id)
            if let clock = ClockGeometry.clockFrame(items: items, screen: screen.frame, primaryHeight: primaryHeight) {
                clockFrames[id] = clock
            }
            let clock = clockFrames[id] ?? ClockGeometry.fallbackFrame(screen: screen.frame)
            let frame = ClockGeometry.overlayFrame(for: clock)

            let panel = panels[id] ?? makePanel()
            panels[id] = panel
            if panel.frame != frame { panel.setFrame(frame, display: true) }
            panel.orderFrontRegardless()
        }

        // Display unplugged: drop its panel.
        for id in panels.keys where !seen.contains(id) {
            panels.removeValue(forKey: id)?.orderOut(nil)
            clockFrames.removeValue(forKey: id)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = BlockerView { [weak self, weak panel] in
            guard let self, let panel, let session = self.session else { return }
            self.toast.show(Countdown.focusMessage(remaining: session.remaining(at: Date())), below: panel.frame)
        }
        return panel
    }

    /// Frames of menu bar items, in CoreGraphics coords. On macOS 26 every menu bar item,
    /// including the clock, is a "Control Center" window at layer 25.
    private static func menuBarItemFrames() -> [CGRect] {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.compactMap { window in
            guard window[kCGWindowOwnerName as String] as? String == "Control Center",
                  window[kCGWindowLayer as String] as? Int == 25,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary
            else { return nil }
            return CGRect(dictionaryRepresentation: bounds)
        }
    }
}

/// Swallows every click. Painted at near-zero alpha: fully transparent pixels would let clicks through.
private final class BlockerView: NSView {
    private let onClick: () -> Void

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: .zero)
        autoresizingMask = [.width, .height]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick() }
    override func rightMouseDown(with event: NSEvent) { onClick() }
    override func otherMouseDown(with event: NSEvent) { onClick() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.004).setFill()
        dirtyRect.fill()
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
