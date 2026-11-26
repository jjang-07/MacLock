import AppKit
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list {
    let r = CGRect(dictionaryRepresentation: w[kCGWindowBounds as String] as! NSDictionary)!
    guard r.minY < 40, r.maxX > 1500, r.height < 60 else { continue }
    print("\(w[kCGWindowOwnerName as String] ?? "?") layer \(w[kCGWindowLayer as String]!)  x \(Int(r.minX))…\(Int(r.maxX)) w \(Int(r.width)) h \(Int(r.height))")
}
