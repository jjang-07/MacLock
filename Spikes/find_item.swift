import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
for w in list where (w[kCGWindowOwnerName as String] as? String) == "MacLock" {
  print("layer", w[kCGWindowLayer as String]!, "onscreen", w[kCGWindowIsOnscreen as String] ?? false, w[kCGWindowBounds as String]!)
}
