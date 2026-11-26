import AppKit

/// A small pill shown under the blocked clock, e.g. "23 min left — stay focused."
///
/// Plain AppKit on purpose. A SwiftUI hosting view in this panel crashed the app (AppKit's
/// constraint-update loop check) when toasts were shown in quick succession, e.g. on a
/// double-click, and a crash drops the clock overlay until the daemon relaunches the app.
final class FocusToast {
    private var panel: NSPanel?
    private let label = NSTextField(labelWithString: "")
    private let icon = NSImageView()
    private var hideTask: Task<Void, Never>?

    private static let padding = NSEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
    private static let iconSpacing: CGFloat = 6

    func show(_ message: String, below anchor: CGRect) {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        label.stringValue = message
        let textSize = label.fittingSize
        let iconSize = CGSize(width: 14, height: 14)
        let size = CGSize(
            width: ceil(Self.padding.left + iconSize.width + Self.iconSpacing + textSize.width + Self.padding.right),
            height: ceil(Self.padding.top + max(iconSize.height, textSize.height) + Self.padding.bottom)
        )
        // Right-aligned with the clock, just under the menu bar.
        let x = max(anchor.maxX - size.width - 4, anchor.minX - size.width)
        panel.setFrame(CGRect(x: x, y: anchor.minY - size.height - 6, width: size.width, height: size.height), display: false)

        // Manual frames only: no constraints, so no constraint passes to trip over.
        icon.frame = CGRect(x: Self.padding.left, y: (size.height - iconSize.height) / 2, width: iconSize.width, height: iconSize.height)
        label.frame = CGRect(x: icon.frame.maxX + Self.iconSpacing, y: (size.height - textSize.height) / 2,
                             width: textSize.width, height: textSize.height)
        panel.contentView?.layer?.cornerRadius = size.height / 2

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
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.masksToBounds = true
        background.translatesAutoresizingMaskIntoConstraints = true
        background.autoresizingMask = [.width, .height]

        icon.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: 12, weight: .semibold)
        icon.contentTintColor = .labelColor
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        label.textColor = .labelColor
        for view in [icon, label] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = true
            background.addSubview(view)
        }
        panel.contentView = background
        return panel
    }
}
