// Bug hunt: why can a double-click on the clock get Notification Center open?
// Logs 20×/s: MacLock overlay frames, the clock's frame, NC open state, mouse position and button.
// Prints a line only when something changes, plus every mouse press.
import AppKit

func t() -> String { String(format: "%.2f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000)) }
func r(_ b: CGRect) -> String { "\(Int(b.minX))…\(Int(b.maxX))×\(Int(b.minY))…\(Int(b.maxY))" }

var last = ""
var wasDown = false
let end = Date().addingTimeInterval(Double(CommandLine.arguments.dropFirst().first ?? "150") ?? 150)
while Date() < end {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    func frames(_ owner: String, _ layer: Int) -> [CGRect] {
        list.filter { ($0[kCGWindowOwnerName as String] as? String) == owner && ($0[kCGWindowLayer as String] as? Int) == layer }
            .compactMap { CGRect(dictionaryRepresentation: $0[kCGWindowBounds as String] as! NSDictionary) }
    }
    let overlays = frames("MacLock", 26).map(r).sorted().joined(separator: ", ")
    let clocks = frames("Control Center", 25).filter { $0.width > 80 && $0.width < 260 }.map(r).sorted().joined(separator: ", ")
    let ncOpen = !frames("Notification Center", 21).isEmpty
    // Front-to-back index of each MacLock overlay vs. the clock (lower = in front).
    let order = list.enumerated().compactMap { i, w -> String? in
        let o = w[kCGWindowOwnerName as String] as? String ?? ""
        let b = CGRect(dictionaryRepresentation: w[kCGWindowBounds as String] as! NSDictionary)!
        if o == "MacLock" && (w[kCGWindowLayer as String] as? Int) == 26 { return "overlay@\(i)" }
        if o == "Control Center" && b.width > 80 && b.width < 260 { return "clock@\(i)" }
        return nil
    }.joined(separator: " ")
    let state = "overlays[\(overlays)] clock[\(clocks)] order[\(order)] NC=\(ncOpen ? "OPEN" : "closed")"
    if state != last { print("[\(t())] \(state)"); fflush(stdout); last = state }

    let down = CGEventSource.buttonState(.combinedSessionState, button: .left)
    if down && !wasDown {
        let m = CGEvent(source: nil)?.location ?? .zero
        print("[\(t())] CLICK at \(Int(m.x)),\(Int(m.y))"); fflush(stdout)
    }
    wasDown = down
    usleep(50_000)
}
print("[\(t())] done")
