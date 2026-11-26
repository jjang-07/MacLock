import Foundation

/// Which apps get closed during a session.
nonisolated enum AppBlocklist {
    static var defaults: [String] { BlockConfig.defaults.apps.map(\.bundleID) }

    /// Never blocked, even if added by mistake: blocking these would break the Mac or MacLock itself.
    static let protected: Set<String> = [
        MacLockID.app,
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.controlcenter",
        "com.apple.loginwindow",
        "com.apple.systempreferences",
        "com.apple.Terminal",
        "com.apple.dt.Xcode",
    ]

    static func shouldBlock(_ bundleID: String?, blocklist: some Sequence<String>) -> Bool {
        guard let bundleID, !protected.contains(bundleID) else { return false }
        return blocklist.contains(bundleID)
    }
}
