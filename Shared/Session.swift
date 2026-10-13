import Foundation

/// A single lock session. Times are wall-clock; tamper-resistant timing arrives with the daemon (M8).
struct Session: Codable, Equatable, Sendable, Identifiable {
    enum Source: String, Codable, Sendable {
        case manual
        case schedule
    }

    let id: UUID
    let start: Date
    let end: Date
    let source: Source

    init(id: UUID = UUID(), start: Date, duration: Duration, source: Source = .manual) {
        self.id = id
        self.start = start
        self.end = start.addingTimeInterval(TimeInterval(duration.components.seconds))
        self.source = source
    }

    var totalSeconds: TimeInterval { end.timeIntervalSince(start) }

    func remaining(at now: Date) -> TimeInterval { max(0, end.timeIntervalSince(now)) }

    func isActive(at now: Date) -> Bool { now >= start && now < end }

    /// 0 at start, 1 at end.
    func progress(at now: Date) -> Double {
        guard totalSeconds > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / totalSeconds))
    }
}

enum Countdown {
    /// "23:41" under an hour, "1:05:09" at or above. Rounds up so it never shows 0:00 while active.
    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
