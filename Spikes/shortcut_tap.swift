// M4 spike: can an event tap swallow Globe/fn+N before Notification Center opens?
import AppKit

func log(_ s: String) { print("[\(String(format: "%.2f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 100)))] \(s)"); fflush(stdout) }

let nKey: Int64 = 45
let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { log("tap disabled: \(type.rawValue)"); return Unmanaged.passUnretained(event) }
    let code = event.getIntegerValueField(.keyboardEventKeycode)
    let fn = event.flags.contains(.maskSecondaryFn)
    if type == .flagsChanged {
        if code == 63 || code == 179 { log("flagsChanged keycode \(code) fn=\(fn)") }   // fn / Globe
        return Unmanaged.passUnretained(event)
    }
    if code == nKey && fn {
        log("SWALLOWED \(type == .keyDown ? "keyDown" : "keyUp") fn+N")
        return nil
    }
    return Unmanaged.passUnretained(event)
}

guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                  eventsOfInterest: CGEventMask(mask), callback: callback, userInfo: nil) else {
    log("FAILED to create event tap (no Accessibility/Input Monitoring permission)"); exit(1)
}
CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

// Also report whether Notification Center actually opened.
var wasOpen = false
Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    let open = list.contains { ($0[kCGWindowOwnerName as String] as? String) == "Notification Center" && ($0[kCGWindowLayer as String] as? Int) == 21 }
    if open != wasOpen { log(open ? "NC OPENED" : "NC closed"); wasOpen = open }
}
let seconds = Double(CommandLine.arguments.dropFirst().first ?? "90") ?? 90
Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in log("done"); exit(0) }
log("tap active for \(seconds)s")
CFRunLoopRun()
