import CoreGraphics
import Foundation
let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
for w in list {
  let owner = w[kCGWindowOwnerName as String] as? String ?? ""
  if ["NotificationCenter","Control Center","ControlCenter","SystemUIServer","Window Server"].contains(owner) {
    print(owner, "layer:", w[kCGWindowLayer as String] ?? "", "onscreen:", w[kCGWindowIsOnscreen as String] ?? false, "bounds:", w[kCGWindowBounds as String] ?? "", "name:", w[kCGWindowName as String] ?? "")
  }
}
