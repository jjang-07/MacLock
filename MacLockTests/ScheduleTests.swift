import Foundation
import Testing

struct ScheduleTests {
    /// Fixed calendar so tests don't depend on the machine's time zone.
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    /// 2026-11-23 is a Monday.
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    let weekdayMornings = Schedule(name: "Mornings", weekdays: [2, 3, 4, 5, 6], start: 9 * 60, end: 12 * 60)

    @Test func activeInsideWindowOnAScheduledDay() {
        let window = weekdayMornings.activeWindow(at: date(23, 10), calendar: calendar)
        #expect(window == DateInterval(start: date(23, 9), end: date(23, 12)))
    }

    @Test func inactiveOutsideWindowOrOnOtherDays() {
        #expect(weekdayMornings.activeWindow(at: date(23, 8, 59), calendar: calendar) == nil)
        #expect(weekdayMornings.activeWindow(at: date(23, 12), calendar: calendar) == nil)   // end is exclusive
        #expect(weekdayMornings.activeWindow(at: date(22, 10), calendar: calendar) == nil)   // Sunday
    }

    @Test func disabledOrEmptyNeverActive() {
        var off = weekdayMornings; off.enabled = false
        var noDays = weekdayMornings; noDays.weekdays = []
        #expect(off.activeWindow(at: date(23, 10), calendar: calendar) == nil)
        #expect(noDays.activeWindow(at: date(23, 10), calendar: calendar) == nil)
    }

    @Test func overnightWindowBelongsToTheDayItStarts() {
        // Friday nights 22:00–01:00 (Friday = 6).
        let lateNight = Schedule(name: "Late", weekdays: [6], start: 22 * 60, end: 60)
        #expect(lateNight.durationMinutes == 180)
        let expected = DateInterval(start: date(27, 22), end: date(28, 1))
        #expect(lateNight.activeWindow(at: date(27, 23), calendar: calendar) == expected)
        #expect(lateNight.activeWindow(at: date(28, 0, 30), calendar: calendar) == expected)   // Saturday 00:30
        #expect(lateNight.activeWindow(at: date(28, 22, 30), calendar: calendar) == nil)        // Saturday night
    }

    @Test func nextWindowSkipsUnscheduledDays() {
        // Friday 13:00 → next is Monday 9:00.
        let next = weekdayMornings.nextWindow(after: date(27, 13), calendar: calendar)
        #expect(next?.start == date(30, 9))
    }

    @Test func lockedWhileRunningAndJustBefore() {
        #expect(weekdayMornings.isLocked(at: date(23, 10), calendar: calendar))
        #expect(weekdayMornings.isLocked(at: date(23, 8, 55), calendar: calendar))     // 5 min before
        #expect(!weekdayMornings.isLocked(at: date(23, 8, 45), calendar: calendar))    // 15 min before
        #expect(!weekdayMornings.isLocked(at: date(23, 13), calendar: calendar))
    }

    @Test func overlappingSchedulesCoverUntilTheLatestEnd() {
        let lunch = Schedule(name: "Lunch", weekdays: [2], start: 11 * 60, end: 13 * 60)
        let window = [weekdayMornings, lunch].activeWindow(at: date(23, 11, 30), calendar: calendar)
        #expect(window == DateInterval(start: date(23, 9), end: date(23, 13)))
    }
}
