import Foundation

/// Something that locks down part of the Mac while a session is active.
protocol Enforcer: AnyObject {
    func activate(session: Session)
    func deactivate()
}
