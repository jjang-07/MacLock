import Foundation
import Testing

struct ClockGuardTests {
    @Test func noJumpWhenClocksAgree() {
        #expect(ClockGuard.jump(wallElapsed: 1.0, monotonicElapsed: 1.0) == 0)
        #expect(ClockGuard.jump(wallElapsed: 1.4, monotonicElapsed: 1.0) == 0)   // jitter
    }

    @Test func detectsClockMovedForward() {
        // User set the date a day ahead between two 1-second ticks.
        #expect(ClockGuard.jump(wallElapsed: 86_401, monotonicElapsed: 1) == 86_400)
    }

    @Test func detectsClockMovedBack() {
        #expect(ClockGuard.jump(wallElapsed: -3599, monotonicElapsed: 1) == -3600)
    }

    @Test func shiftingKeepsTimeRemaining() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let session = Session(start: start, duration: .seconds(1500))
        let now = start.addingTimeInterval(500)
        let jump: TimeInterval = 86_400

        let shifted = session.shifted(by: jump)
        #expect(shifted.id == session.id)
        #expect(shifted.remaining(at: now.addingTimeInterval(jump)) == session.remaining(at: now))
        #expect(shifted.totalSeconds == session.totalSeconds)
    }
}
