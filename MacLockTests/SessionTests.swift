import Foundation
import Testing

struct SessionTests {
    let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func endIsStartPlusDuration() {
        let s = Session(start: start, duration: .seconds(25 * 60))
        #expect(s.end == start.addingTimeInterval(1500))
        #expect(s.totalSeconds == 1500)
    }

    @Test func activeOnlyBetweenStartAndEnd() {
        let s = Session(start: start, duration: .seconds(60))
        #expect(!s.isActive(at: start.addingTimeInterval(-1)))
        #expect(s.isActive(at: start))
        #expect(s.isActive(at: start.addingTimeInterval(59.9)))
        #expect(!s.isActive(at: start.addingTimeInterval(60)))
    }

    @Test func remainingNeverNegative() {
        let s = Session(start: start, duration: .seconds(60))
        #expect(s.remaining(at: start.addingTimeInterval(20)) == 40)
        #expect(s.remaining(at: start.addingTimeInterval(500)) == 0)
    }

    @Test func progressIsClamped() {
        let s = Session(start: start, duration: .seconds(100))
        #expect(s.progress(at: start.addingTimeInterval(-10)) == 0)
        #expect(s.progress(at: start.addingTimeInterval(25)) == 0.25)
        #expect(s.progress(at: start.addingTimeInterval(1000)) == 1)
    }

    @Test(arguments: [
        (0.0, "0:00"),
        (0.2, "0:01"),        // rounds up while active
        (59.0, "0:59"),
        (1421.0, "23:41"),
        (3599.5, "1:00:00"),
        (3909.0, "1:05:09"),
    ])
    func countdownFormat(seconds: Double, expected: String) {
        #expect(Countdown.format(seconds) == expected)
    }
}
