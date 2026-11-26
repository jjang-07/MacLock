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
