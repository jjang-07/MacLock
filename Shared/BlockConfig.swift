import Foundation

/// What a session blocks. Stored by the daemon (root-owned file); the app edits it over XPC.
nonisolated struct BlockConfig: Codable, Equatable, Sendable {
    struct App: Codable, Equatable, Hashable, Sendable {
        var bundleID: String
        var name: String
    }

    var apps: [App]
    var websites: [String]
    var schedules: [Schedule] = []

    init(apps: [App], websites: [String], schedules: [Schedule] = []) {
        self.apps = apps
        self.websites = websites
        self.schedules = schedules
    }

    /// Config files from before schedules existed have no "schedules" key.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        apps = try c.decode([App].self, forKey: .apps)
        websites = try c.decode([String].self, forKey: .websites)
        schedules = try c.decodeIfPresent([Schedule].self, forKey: .schedules) ?? []
    }

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
        case lockedSchedule(names: [String])

        var errorDescription: String? {
            switch self {
            case let .removalDuringSession(apps, websites):
                let items = (apps + websites).joined(separator: ", ")
                return "You can't unblock anything during a session (\(items)). You can still add more."
            case let .lockedSchedule(names):
                return "\(names.joined(separator: ", ")) is running or starts within 10 minutes, so it can't be changed or removed right now."
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
        var seenSchedules = Set<UUID>()
        let schedules = schedules.filter { schedule in
            (0..<24 * 60).contains(schedule.start) && (0..<24 * 60).contains(schedule.end)
                && schedule.weekdays.isSubset(of: 1...7) && seenSchedules.insert(schedule.id).inserted
        }
        return BlockConfig(apps: apps, websites: websites, schedules: schedules)
    }

    /// The config to store if `proposed` replaces `self`. During a session the lock can only get
    /// stricter: anything that would unblock an app or website is refused.
    /// Schedules that are running or about to start can't be changed or removed, session or not.
    func applying(_ proposed: BlockConfig, sessionActive: Bool, now: Date = Date(),
                  calendar: Calendar = .current) -> Result<BlockConfig, ChangeError> {
        let next = proposed.sanitized()

        let lockedChanged = schedules.filter { old in
            old.isLocked(at: now, calendar: calendar) && !next.schedules.contains(old)
        }
        guard lockedChanged.isEmpty else { return .failure(.lockedSchedule(names: lockedChanged.map(\.name))) }

        guard sessionActive else { return .success(next) }

        let removedApps = apps.filter { !next.appBundleIDs.contains($0.bundleID) }.map(\.name)
        let removedSites = websites.filter { !next.websites.contains($0) }
        guard removedApps.isEmpty, removedSites.isEmpty else {
            return .failure(.removalDuringSession(apps: removedApps, websites: removedSites))
        }
        return .success(next)
    }
}
