import Foundation

/// Detects changes to the system clock by comparing wall-clock time with a monotonic clock the
/// user can't change. A session is shifted by the jump, so changing the date doesn't change how
/// much time is left.
nonisolated enum ClockGuard {
    /// Normal timer jitter and NTP corrections stay under this.
    static let tolerance: TimeInterval = 2

    /// How far the wall clock jumped between two ticks (positive = moved forward), or 0.
    static func jump(wallElapsed: TimeInterval, monotonicElapsed: TimeInterval) -> TimeInterval {
        let drift = wallElapsed - monotonicElapsed
        return abs(drift) > tolerance ? drift : 0
    }
}
