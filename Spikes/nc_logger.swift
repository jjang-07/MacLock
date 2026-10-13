// M0 spike: log every on-screen window that appears/disappears (to find NC's "open" signature).
import AppKit
func snapshot() -> Set<String> {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return Set(list.map { w in
        let b = CGRect(dictionaryRepresentation: w[kCGWindowBounds as String] as! NSDictionary)!
        return "\(w[kCGWindowOwnerName as String] ?? "?") pid\(w[kCGWindowOwnerPID as String]!) L\(w[kCGWindowLayer as String]!) \(Int(b.minX)),\(Int(b.minY)) \(Int(b.width))x\(Int(b.height))"
    })
}
var last = snapshot()
let start = Date()
while Date().timeIntervalSince(start) < 75 {
    usleep(150_000)
    let now = snapshot()
    let t = String(format: "%5.1f", Date().timeIntervalSince(start))
    for s in now.subtracting(last).sorted() { print("[\(t)] + \(s)") }
    for s in last.subtracting(now).sorted() { print("[\(t)] - \(s)") }
    fflush(stdout); last = now
}
print("done")
