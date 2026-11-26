import AppKit
let primaryH = NSScreen.screens[0].frame.height
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
let items = list.filter { ($0[kCGWindowOwnerName as String] as? String) == "Control Center" && ($0[kCGWindowLayer as String] as? Int) == 25 }
    .map { CGRect(dictionaryRepresentation: $0[kCGWindowBounds as String] as! NSDictionary)! }
for s in NSScreen.screens {
    let f = s.frame, cgTop = primaryH - f.maxY
    let onScreen = items.filter { abs($0.minY - cgTop) < 2 && $0.minX >= f.minX - 1 && $0.maxX <= f.maxX + 1 }.sorted { $0.maxX < $1.maxX }
    print("\(s.localizedName): x \(Int(f.minX))…\(Int(f.maxX)), menu bar items (rightmost 3):")
    for r in onScreen.suffix(3) { print("   x \(Int(r.minX))…\(Int(r.maxX)) w \(Int(r.width)) h \(Int(r.height))") }
}
