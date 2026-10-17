import AppKit
import SwiftUI
struct V: View { var body: some View { Label("Messages is blocked — 2 min left", systemImage: "lock.fill").padding(.horizontal, 14).padding(.vertical, 8).padding(4) } }
let _ = NSApplication.shared
let a = NSHostingView(rootView: V()); a.sizingOptions = []
print("fittingSize with sizingOptions=[]:", a.fittingSize)
print("NSHostingController.sizeThatFits:", NSHostingController(rootView: V()).sizeThatFits(in: CGSize(width: 10000, height: 10000)))
