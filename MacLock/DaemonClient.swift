import Foundation
import os
import ServiceManagement

/// Talks to the root daemon over XPC and manages its registration with launchd.
final class DaemonClient {
    enum Status: Equatable {
        case ready
        /// Registered, but the user hasn't allowed it in System Settings → General → Login Items.
        case needsApproval
        case unavailable(String)
    }

    private static let log = Logger(subsystem: MacLockID.app, category: "DaemonClient")
    private let service = SMAppService.daemon(plistName: DaemonPaths.plistName)
    private var connection: NSXPCConnection?

    /// Registers the daemon if needed and reports whether it can be used.
    func ensureRegistered() -> Status {
        switch service.status {
        case .enabled:
            return .ready
        case .requiresApproval:
            return .needsApproval
        case .notRegistered, .notFound:
            do {
                try service.register()
                Self.log.info("Registered daemon")
                return service.status == .enabled ? .ready : .needsApproval
            } catch {
                Self.log.error("Couldn't register daemon: \(error.localizedDescription, privacy: .public)")
                return service.status == .requiresApproval ? .needsApproval : .unavailable(error.localizedDescription)
            }
        @unknown default:
            return .unavailable("Unknown helper status")
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: Calls

    func startSession(seconds: Int) async -> Session? {
        await call { proxy, reply in proxy.startSession(seconds: seconds) { reply(Self.decode($0)) } } ?? nil
    }

    func currentSession() async -> Session?? {
        await call { proxy, reply in proxy.currentSession { reply(Self.decode($0)) } }
    }

    func debugEndSession() async -> Bool {
        await call { proxy, reply in proxy.debugEndSession { reply($0) } } ?? false
    }

    /// Runs one XPC call. Returns nil if the daemon couldn't be reached.
    private func call<T: Sendable>(_ body: (MacLockDaemonProtocol, @escaping @Sendable (T) -> Void) -> Void) async -> T? {
        let connection = connect()
        return await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                Self.log.error("XPC error: \(error.localizedDescription, privacy: .public)")
                once.resume(nil)
            } as? MacLockDaemonProtocol
            guard let proxy else { return once.resume(nil) }
            body(proxy) { once.resume($0) }
        }
    }

    private func connect() -> NSXPCConnection {
        if let connection { return connection }
        let connection = NSXPCConnection(machServiceName: MacLockID.daemon, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: MacLockDaemonProtocol.self)
        connection.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        connection.resume()
        self.connection = connection
        return connection
    }

    nonisolated private static func decode(_ data: Data?) -> Session? {
        data.flatMap { try? JSONDecoder().decode(Session.self, from: $0) }
    }
}

/// XPC can call both the reply and the error handler; resume the continuation only once.
nonisolated private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T?, Never>?

    init(_ continuation: CheckedContinuation<T?, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: T?) {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume(returning: value)
    }
}
