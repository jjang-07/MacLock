import Foundation

/// Recognizes an open Notification Center panel from window-list entries. See Spikes/RESULTS.md.
nonisolated enum NotificationCenterDetector {
    struct WindowInfo: Equatable, Sendable {
        let owner: String
        let layer: Int
    }

    /// Open panel = a "Notification Center" window at layer 21 (it covers the whole screen).
    /// Desktop widgets belong to the same process but sit at large negative layers.
    static let panelLayer = 21

    static func isOpen(_ windows: [WindowInfo]) -> Bool {
        windows.contains { $0.owner == "Notification Center" && $0.layer == panelLayer }
    }
}
