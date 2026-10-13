import AppKit
for s in NSScreen.screens { print("screen", s.localizedName, s.frame, "visible", s.visibleFrame) }
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list {
  let owner = w[kCGWindowOwnerName as String] as? String ?? ""
  let b = w[kCGWindowBounds as String] as! [String: Any]
  let layer = w[kCGWindowLayer as String] as! Int
  if layer >= 20 || owner.contains("Notification") {
    print(owner, "pid", w[kCGWindowOwnerPID as String]!, "layer", layer, "x", b["X"]!, "y", b["Y"]!, "w", b["Width"]!, "h", b["Height"]!)
  }
}
