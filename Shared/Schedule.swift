import Foundation

/// A recurring lock window, e.g. weekdays 9:00–12:00. The daemon starts (or extends) a session
/// to cover it. Windows may cross midnight (22:00–01:00 belongs to the day it starts).
nonisolated struct Schedule: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id = UUID()
    var name: String
    /// Calendar weekdays: 1 = Sunday … 7 = Saturday.
    var weekdays: Set<Int>
    /// Minutes after midnight.
    var start: Int
    var end: Int
    var enabled = true

    /// Can't be edited, disabled or deleted this long before it starts.
    static let lockLead: TimeInterval = 10 * 60

    var durationMinutes: Int { end > start ? end - start : end + 24 * 60 - start }

    /// The window covering `date`, if any.
    func activeWindow(at date: Date, calendar: Calendar = .current) -> DateInterval? {
        guard enabled, start != end, !weekdays.isEmpty else { return nil }
        // A window that started yesterday may still be running (crosses midnight).
        for dayOffset in [0, -1] {
            guard let window = window(onDayOf: date, offsetDays: dayOffset, calendar: calendar) else { continue }
            if window.start <= date && date < window.end { return window }
        }
        return nil
    }

    /// The next window that starts after `date`, looking a week ahead.
    func nextWindow(after date: Date, calendar: Calendar = .current) -> DateInterval? {
        guard enabled, start != end, !weekdays.isEmpty else { return nil }
        return (0...7).lazy
            .compactMap { window(onDayOf: date, offsetDays: $0, calendar: calendar) }
            .first { $0.start > date }
    }

    /// True while the window runs or is about to start: then it can't be changed or removed.
    func isLocked(at date: Date, calendar: Calendar = .current) -> Bool {
        if activeWindow(at: date, calendar: calendar) != nil { return true }
        guard let next = nextWindow(after: date, calendar: calendar) else { return false }
        return next.start.timeIntervalSince(date) <= Self.lockLead
    }

    private func window(onDayOf date: Date, offsetDays: Int, calendar: Calendar) -> DateInterval? {
        guard let day = calendar.date(byAdding: .day, value: offsetDays, to: calendar.startOfDay(for: date)),
              weekdays.contains(calendar.component(.weekday, from: day)),
              let startDate = calendar.date(byAdding: .minute, value: start, to: day),
              let endDate = calendar.date(byAdding: .minute, value: start + durationMinutes, to: day)
        else { return nil }
        return DateInterval(start: startDate, end: endDate)
    }
}

extension Array where Element == Schedule {
    /// The window to cover now: if several overlap, until the latest end among them.
    nonisolated func activeWindow(at date: Date, calendar: Calendar = .current) -> DateInterval? {
        let windows = compactMap { $0.activeWindow(at: date, calendar: calendar) }
        guard let first = windows.first else { return nil }
        return windows.dropFirst().reduce(first) { DateInterval(start: Swift.min($0.start, $1.start), end: Swift.max($0.end, $1.end)) }
    }
}
