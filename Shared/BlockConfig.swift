import Foundation

/// What a session blocks. Stored by the daemon (root-owned file); the app edits it over XPC.
nonisolated struct BlockConfig: Codable, Equatable, Sendable {
    struct App: Codable, Equatable, Hashable, Sendable {
        var bundleID: String
        var name: String
    }

    var apps: [App]
    var websites: [String]

    static let defaults = BlockConfig(
        apps: [
            App(bundleID: "com.apple.MobileSMS", name: "Messages"),
            App(bundleID: "com.apple.FaceTime", name: "FaceTime"),
            App(bundleID: "com.hnc.Discord", name: "Discord"),
        ],
        websites: WebsiteBlocklist.defaults
    )

    var appBundleIDs: Set<String> { Set(apps.map(\.bundleID)) }

    enum ChangeError: Error, Equatable, LocalizedError {
        case removalDuringSession(apps: [String], websites: [String])

        var errorDescription: String? {
            switch self {
            case let .removalDuringSession(apps, websites):
                let items = (apps + websites).joined(separator: ", ")
                return "You can't unblock anything during a session (\(items)). You can still add more."
            }
        }
    }

    /// Cleans up a proposed config: websites normalized and de-duplicated (junk dropped), apps
    /// de-duplicated, protected system apps dropped.
    func sanitized() -> BlockConfig {
        var seenApps = Set<String>()
        let apps = apps.filter { app in
            !app.bundleID.isEmpty && !AppBlocklist.protected.contains(app.bundleID) && seenApps.insert(app.bundleID).inserted
        }
        var seenSites = Set<String>()
        let websites = websites.compactMap(HostsFile.normalize).filter { seenSites.insert($0).inserted }
        return BlockConfig(apps: apps, websites: websites)
    }

    /// The config to store if `proposed` replaces `self`. During a session the lock can only get
    /// stricter: anything that would unblock an app or website is refused.
    func applying(_ proposed: BlockConfig, sessionActive: Bool) -> Result<BlockConfig, ChangeError> {
        let next = proposed.sanitized()
        guard sessionActive else { return .success(next) }

        let removedApps = apps.filter { !next.appBundleIDs.contains($0.bundleID) }.map(\.name)
        let removedSites = websites.filter { !next.websites.contains($0) }
        guard removedApps.isEmpty, removedSites.isEmpty else {
            return .failure(.removalDuringSession(apps: removedApps, websites: removedSites))
        }
        return .success(next)
    }
}
