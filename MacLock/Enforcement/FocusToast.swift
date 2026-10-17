import AppKit
import SwiftUI

/// A small pill shown under the blocked clock, e.g. "23 min left — stay focused."
final class FocusToast {
    private var panel: NSPanel?
    /// Created once and never allowed to resize its window: a hosting view that drives its
    /// window's size can trip AppKit's constraint-update loop check and crash the app.
    private let host: NSHostingView<ToastView> = {
        let host = NSHostingView(rootView: ToastView(message: ""))
        host.sizingOptions = []
        return host
    }()
    private var hideTask: Task<Void, Never>?

    func show(_ message: String, below anchor: CGRect) {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let view = ToastView(message: message)
        host.rootView = view
        // With sizingOptions = [] the hosting view reports a zero fitting size, so measure the
        // content separately (a controller that isn't in any window can't trip the layout loop).
        let size = NSHostingController(rootView: view).sizeThatFits(in: CGSize(width: 1000, height: 200))
        // Right-aligned with the clock, just under the menu bar, kept on the anchor's screen.
        let x = max(anchor.maxX - size.width - 4, anchor.minX - size.width)
        panel.setFrame(CGRect(x: x, y: anchor.minY - size.height - 6, width: size.width, height: size.height), display: true)

        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            }
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        hideTask?.cancel()
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.contentView = host
        return panel
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "lock.fill")
            .font(.callout.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .padding(4)
    }
}
