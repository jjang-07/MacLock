import Foundation
import Testing

struct BlockConfigTests {
    typealias App = BlockConfig.App
    let base = BlockConfig(apps: [App(bundleID: "com.apple.MobileSMS", name: "Messages")], websites: ["youtube.com"])

    @Test func outsideSessionAnythingGoes() throws {
        let emptied = try base.applying(BlockConfig(apps: [], websites: []), sessionActive: false).get()
        #expect(emptied.apps.isEmpty && emptied.websites.isEmpty)
    }

    @Test func duringSessionAddingIsAllowed() throws {
        var more = base
        more.apps.append(App(bundleID: "com.hnc.Discord", name: "Discord"))
        more.websites.append("reddit.com")
        let result = try base.applying(more, sessionActive: true).get()
        #expect(result.appBundleIDs == ["com.apple.MobileSMS", "com.hnc.Discord"])
        #expect(result.websites == ["youtube.com", "reddit.com"])
    }

    @Test func duringSessionRemovingAnAppIsRefused() {
        var fewer = base
        fewer.apps = []
        #expect(base.applying(fewer, sessionActive: true) == .failure(.removalDuringSession(apps: ["Messages"], websites: [])))
    }

    @Test func duringSessionRemovingAWebsiteIsRefused() {
        var fewer = base
        fewer.websites = []
        #expect(base.applying(fewer, sessionActive: true) == .failure(.removalDuringSession(apps: [], websites: ["youtube.com"])))
    }

    @Test func rewritingAWebsiteIntoTheSameDomainIsNotARemoval() throws {
        var same = base
        same.websites = ["https://www.YouTube.com/"]
        #expect(try base.applying(same, sessionActive: true).get().websites == ["youtube.com"])
    }

    @Test func sanitizeDropsJunkDuplicatesAndProtectedApps() {
        let messy = BlockConfig(
            apps: [App(bundleID: "com.apple.finder", name: "Finder"), App(bundleID: "x", name: "X"), App(bundleID: "x", name: "X again")],
            websites: ["YouTube.com", "www.youtube.com", "not a domain", "evil.com\n0.0.0.0 apple.com"]
        ).sanitized()
        #expect(messy.apps == [App(bundleID: "x", name: "X")])
        #expect(messy.websites == ["youtube.com"])
    }

    @Test func defaultsAreAlreadyClean() {
        #expect(BlockConfig.defaults.sanitized() == BlockConfig.defaults)
    }
}

struct BlockConfigScheduleTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }
    let mornings = Schedule(name: "Mornings", weekdays: [2, 3, 4, 5, 6], start: 9 * 60, end: 12 * 60)
    var config: BlockConfig { BlockConfig(apps: [], websites: [], schedules: [mornings]) }

    @Test func unlockedScheduleCanBeRemovedOrEdited() throws {
        var removed = config; removed.schedules = []
        #expect(try config.applying(removed, sessionActive: false, now: date(23, 14), calendar: calendar).get().schedules.isEmpty)
        var edited = config; edited.schedules[0].end = 11 * 60
        #expect(try config.applying(edited, sessionActive: false, now: date(23, 14), calendar: calendar).get().schedules[0].end == 11 * 60)
    }

    @Test func runningScheduleCantBeRemovedDisabledOrEdited() {
        let monday10 = date(23, 10)
        var removed = config; removed.schedules = []
        var disabled = config; disabled.schedules[0].enabled = false
        var shortened = config; shortened.schedules[0].end = 10 * 60
        for change in [removed, disabled, shortened] {
            #expect(config.applying(change, sessionActive: true, now: monday10, calendar: calendar)
                == .failure(.lockedSchedule(names: ["Mornings"])))
        }
    }

    @Test func aboutToStartScheduleIsLocked() {
        var removed = config; removed.schedules = []
        #expect(config.applying(removed, sessionActive: false, now: date(23, 8, 55), calendar: calendar)
            == .failure(.lockedSchedule(names: ["Mornings"])))
    }

    @Test func addingAScheduleIsAlwaysAllowed() throws {
        var more = config
        more.schedules.append(Schedule(name: "Evenings", weekdays: [2], start: 19 * 60, end: 21 * 60))
        #expect(try config.applying(more, sessionActive: true, now: date(23, 10), calendar: calendar).get().schedules.count == 2)
    }

    @Test func invalidSchedulesAreDropped() {
        let bad = BlockConfig(apps: [], websites: [], schedules: [
            Schedule(name: "Bad time", weekdays: [2], start: 25 * 60, end: 60),
            Schedule(name: "Bad day", weekdays: [9], start: 60, end: 120),
        ]).sanitized()
        #expect(bad.schedules.isEmpty)
    }

    @Test func oldConfigFilesWithoutSchedulesStillLoad() throws {
        let json = #"{"apps":[{"bundleID":"com.apple.MobileSMS","name":"Messages"}],"websites":["youtube.com"]}"#
        let decoded = try JSONDecoder().decode(BlockConfig.self, from: Data(json.utf8))
        #expect(decoded.schedules.isEmpty && decoded.websites == ["youtube.com"])
    }
}
