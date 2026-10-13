// M0 spike: clock overlay + Notification Center watchdog logger.
import AppKit

func log(_ s: String) { print("[\(String(format: "%.1f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000)))] \(s)"); fflush(stdout) }

func windows() -> [[String: Any]] {
    CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
}

/// One rect per screen (Cocoa coords) hugging the clock exactly. The last good detection per screen is
/// cached, so the overlay never shrinks or disappears while the menu bar is hidden (full screen).
var cached: [CGDirectDisplayID: CGRect] = [:]
func displayID(_ s: NSScreen) -> CGDirectDisplayID { s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID }
func clockRects() -> [CGRect] {
    let primaryH = NSScreen.screens[0].frame.height
    let items = windows().filter { ($0[kCGWindowOwnerName as String] as? String) == "Control Center" && ($0[kCGWindowLayer as String] as? Int) == 25 }
        .compactMap { w -> CGRect? in
            guard let b = w[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: b)
        }
    return NSScreen.screens.map { screen in
        let f = screen.frame, id = displayID(screen)
        let cgTop = primaryH - f.maxY
        // Clock = rightmost item touching this screen's top edge and ending at its right edge.
        if let c = items.filter({ abs($0.minY - cgTop) < 2 && abs($0.maxX - f.maxX) < 6 && (80...260).contains($0.width) }).first {
            cached[id] = CGRect(x: c.minX, y: primaryH - c.maxY, width: c.width, height: c.height)
        }
        // Fallback before first detection: typical clock size at the right edge.
        return cached[id] ?? CGRect(x: f.maxX - 150, y: f.maxY - 39, width: 150, height: 39)
    }
}

final class BlockerView: NSView {
    override func mouseDown(with event: NSEvent) { log("BLOCKED click on clock overlay") }
    override func rightMouseDown(with event: NSEvent) { log("BLOCKED right click") }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemRed.withAlphaComponent(CommandLine.arguments.contains("--debug") ? 0.35 : 0.004).setFill()
        dirtyRect.fill()
    }
}

var panels: [NSPanel] = []
func makePanel(_ rect: CGRect) -> NSPanel {
    let p = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
    p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    p.isOpaque = false
    p.backgroundColor = .clear
    p.hasShadow = false
    p.hidesOnDeactivate = false
    p.contentView = BlockerView(frame: NSRect(origin: .zero, size: rect.size))
    p.orderFrontRegardless()
    return p
}
func layoutPanels() {
    let rects = clockRects()
    while panels.count < rects.count { panels.append(makePanel(rects[panels.count])) }
    for (p, r) in zip(panels, rects) where p.frame != r {
        p.setFrame(r, display: true); p.contentView?.frame = NSRect(origin: .zero, size: r.size)
        log("overlay at \(r)")
    }
    for p in panels { p.orderFrontRegardless() }   // stay on top, never removed
}

var closing = false
func ncOpen() -> Bool {
    windows().contains { ($0[kCGWindowOwnerName as String] as? String) == "Notification Center" && ($0[kCGWindowLayer as String] as? Int) == 21 }
}
func pollNC() {
    guard !closing, ncOpen() else { return }
    closing = true
    log("NC OPEN detected -> Escape + kill")
    let src = CGEventSource(stateID: .hidSystemState)
    CGEvent(keyboardEventSource: src, virtualKey: 53, keyDown: true)?.post(tap: .cghidEventTap)
    CGEvent(keyboardEventSource: src, virtualKey: 53, keyDown: false)?.post(tap: .cghidEventTap)
    do {
        let t = Process(); t.executableURL = URL(fileURLWithPath: "/usr/bin/killall"); t.arguments = ["NotificationCenter"]
        try? t.run(); t.waitUntilExit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { log(ncOpen() ? "STILL OPEN" : "closed"); closing = false }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
layoutPanels()
Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in pollNC() }
Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in layoutPanels() }
for n in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
    NSWorkspace.shared.notificationCenter.addObserver(forName: n, object: nil, queue: .main) { _ in layoutPanels() }
}
NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in layoutPanels() }
let seconds = Double(CommandLine.arguments.dropFirst().first ?? "90") ?? 90
Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in log("done"); exit(0) }
log("running for \(seconds)s")
app.run()
