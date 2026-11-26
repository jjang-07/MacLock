import Foundation
import os
import Synchronization

/// The blocklists, persisted in a root-owned file (mode 644: the app can read it, only root can
/// change it). Changes come from the app over XPC and go through `BlockConfig.applying`.
final class ConfigStore: Sendable {
    private static let url = DaemonPaths.stateDirectory.appendingPathComponent("config.json")
    private let config: Mutex<BlockConfig>
    private let log = Logger(subsystem: MacLockID.daemon, category: "Config")

    init() {
        let loaded = (try? Data(contentsOf: Self.url)).flatMap { try? JSONDecoder().decode(BlockConfig.self, from: $0) }
        config = Mutex(loaded?.sanitized() ?? .defaults)
    }

    var current: BlockConfig { config.withLock { $0 } }

    func update(to proposed: BlockConfig, sessionActive: Bool) -> Result<BlockConfig, BlockConfig.ChangeError> {
        config.withLock { config in
            let result = config.applying(proposed, sessionActive: sessionActive)
            if case .success(let next) = result, next != config {
                config = next
                save(next)
                log.notice("Blocklists updated: \(next.apps.count) apps, \(next.websites.count) websites")
            }
            if case .failure(let error) = result {
                log.notice("Refused change: \(error.localizedDescription, privacy: .public)")
            }
            return result
        }
    }

    private func save(_ config: BlockConfig) {
        do {
            try FileManager.default.createDirectory(at: DaemonPaths.stateDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(config).write(to: Self.url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: Self.url.path)
        } catch {
            log.error("Couldn't save config: \(error.localizedDescription, privacy: .public)")
        }
    }
}
