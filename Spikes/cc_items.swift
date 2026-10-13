import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
let items = list.filter { ($0[kCGWindowOwnerName as String] as? String) == "Control Center" && ($0[kCGWindowLayer as String] as? Int) == 25 }
for w in items { let b = w[kCGWindowBounds as String] as! [String: Any]; print("x", b["X"]!, "y", b["Y"]!, "w", b["Width"]!, "on", w[kCGWindowIsOnscreen as String] ?? 0) }
