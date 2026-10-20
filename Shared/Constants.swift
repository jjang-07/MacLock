import Foundation

/// Identifiers shared by the app and the daemon.
nonisolated enum MacLockID {
    static let app = "com.maclock.app"
    /// Also the daemon's launchd label and XPC Mach service name.
    static let daemon = "com.maclock.daemon"
    static let agent = "com.maclock.agent"
}
