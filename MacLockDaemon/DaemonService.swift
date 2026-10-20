import Foundation
import os
import Security

/// Accepts XPC connections from the MacLock app only, and serves the session authority.
final class DaemonService: NSObject, NSXPCListenerDelegate, MacLockDaemonProtocol, @unchecked Sendable {
    private let authority: SessionAuthority
    private let log = Logger(subsystem: MacLockID.daemon, category: "XPC")

    init(authority: SessionAuthority) {
        self.authority = authority
    }

    /// Only processes signed as the MacLock app, by the same team that signed this daemon, may connect.
    static func clientRequirement() -> String {
        if let team = ownTeamID() {
            return "identifier \"\(MacLockID.app)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(team)\""
        }
        #if DEBUG
        // Ad-hoc signed development build: there's no team to check against.
        return "identifier \"\(MacLockID.app)\""
        #else
        fatalError("Release daemon must be signed with a team ID")
        #endif
    }

    private static func ownTeamID() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any]
        else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }

    // MARK: NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // The listener-wide code-signing requirement has already rejected anything else.
        connection.exportedInterface = NSXPCInterface(with: MacLockDaemonProtocol.self)
        connection.exportedObject = self
        connection.resume()
        log.info("Accepted connection from pid \(connection.processIdentifier)")
        return true
    }

    // MARK: MacLockDaemonProtocol

    func startSession(seconds: Int, reply: @escaping @Sendable (Data?) -> Void) {
        reply(Self.encode(authority.start(seconds: seconds)))
    }

    func currentSession(reply: @escaping @Sendable (Data?) -> Void) {
        reply(Self.encode(authority.current()))
    }

    func debugEndSession(reply: @escaping @Sendable (Bool) -> Void) {
        #if DEBUG
        authority.end()
        reply(true)
        #else
        reply(false)
        #endif
    }

    private static func encode(_ session: Session?) -> Data? {
        session.flatMap { try? JSONEncoder().encode($0) }
    }
}
