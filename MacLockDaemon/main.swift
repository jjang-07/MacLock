import Foundation
import os

// Root LaunchDaemon (registered by the app via SMAppService). Owns the session so that quitting
// or killing the app can't end it.

let log = Logger(subsystem: MacLockID.daemon, category: "Main")
let service = DaemonService(authority: SessionAuthority())

let listener = NSXPCListener(machServiceName: MacLockID.daemon)
listener.setConnectionCodeSigningRequirement(DaemonService.clientRequirement())
listener.delegate = service
listener.resume()
log.info("Daemon started (uid \(getuid()))")

RunLoop.main.run()
