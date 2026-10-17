// Clicks the built-in display's clock N times (to stress-test the toast).
import CoreGraphics
import Foundation
let n = Int(CommandLine.arguments.dropFirst().first ?? "15") ?? 15
let point = CGPoint(x: 1630, y: 18)   // built-in display clock, CG coords
for _ in 0..<n {
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(150_000)
}
