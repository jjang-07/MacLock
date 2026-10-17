import Testing

struct AppBlocklistTests {
    @Test func blocksListedApps() {
        #expect(AppBlocklist.shouldBlock("com.apple.MobileSMS", blocklist: AppBlocklist.defaults))
        #expect(AppBlocklist.shouldBlock("com.hnc.Discord", blocklist: AppBlocklist.defaults))
    }

    @Test func allowsUnlistedApps() {
        #expect(!AppBlocklist.shouldBlock("com.apple.Safari", blocklist: AppBlocklist.defaults))
    }

    @Test func neverBlocksProtectedApps() {
        let careless = ["com.apple.finder", MacLockID.app, "com.apple.systempreferences"]
        for id in careless {
            #expect(!AppBlocklist.shouldBlock(id, blocklist: careless))
        }
    }

    @Test func ignoresAppsWithoutBundleID() {
        #expect(!AppBlocklist.shouldBlock(nil, blocklist: AppBlocklist.defaults))
    }
}
