import Testing

struct HostsFileTests {
    let stock = """
        ##
        # Host Database
        ##
        127.0.0.1\tlocalhost
        255.255.255.255\tbroadcasthost
        ::1             localhost

        """

    @Test func addsBlockAfterExistingContent() {
        let result = HostsFile.applying(domains: ["youtube.com"], to: stock)
        #expect(result.hasPrefix(stock))
        #expect(result.contains("0.0.0.0 youtube.com\n:: youtube.com\n"))
        #expect(result.contains("0.0.0.0 www.youtube.com"))
        #expect(result.contains("0.0.0.0 m.youtube.com"))
        #expect(result.hasSuffix(HostsFile.endMarker + "\n"))
    }

    @Test func removingRestoresOriginalExactly() {
        let blocked = HostsFile.applying(domains: ["youtube.com", "reddit.com"], to: stock)
        #expect(HostsFile.removingBlock(from: blocked) == stock)
        #expect(HostsFile.applying(domains: [], to: blocked) == stock)
    }

    @Test func reapplyingReplacesBlockInsteadOfDuplicating() {
        let once = HostsFile.applying(domains: ["youtube.com"], to: stock)
        let twice = HostsFile.applying(domains: ["youtube.com"], to: once)
        #expect(once == twice)
        let changed = HostsFile.applying(domains: ["reddit.com"], to: once)
        #expect(!changed.contains("youtube.com"))
        #expect(changed.contains("0.0.0.0 reddit.com"))
    }

    @Test func keepsUserEntriesAfterTheBlock() {
        let blocked = HostsFile.applying(domains: ["youtube.com"], to: stock)
        let edited = blocked + "10.0.0.5 nas.local\n"
        #expect(HostsFile.removingBlock(from: edited) == stock + "10.0.0.5 nas.local\n")
    }

    @Test func handlesFileWithoutTrailingNewline() {
        let noNewline = "127.0.0.1 localhost"
        let blocked = HostsFile.applying(domains: ["x.com"], to: noNewline)
        #expect(blocked.hasPrefix("127.0.0.1 localhost\n" + HostsFile.beginMarker))
    }

    @Test func truncatedBlockIsRemovedToTheEnd() {
        let truncated = stock + HostsFile.beginMarker + "\n0.0.0.0 youtube.com\n"
        #expect(HostsFile.removingBlock(from: truncated) == stock)
    }

    @Test func noBlockMeansNoChange() {
        #expect(HostsFile.removingBlock(from: stock) == stock)
    }

    @Test(arguments: [
        ("youtube.com", "youtube.com"),
        ("  YouTube.COM ", "youtube.com"),
        ("https://www.youtube.com/watch?v=abc", "youtube.com"),
        ("http://m.facebook.com:443/home", "facebook.com"),
        ("old.reddit.com", "old.reddit.com"),
    ])
    func normalizesInput(input: String, expected: String) {
        #expect(HostsFile.normalize(input) == expected)
    }

    @Test(arguments: ["", "youtube", "localhost", "you tube.com", "a..com", "-bad.com", "evil.com\n0.0.0.0 apple.com", "#.com"])
    func rejectsJunk(input: String) {
        #expect(HostsFile.normalize(input) == nil)
    }
}
