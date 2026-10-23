import Foundation

/// Pure text logic for the MacLock block in /etc/hosts. Everything outside the markers is left
/// byte-for-byte unchanged.
nonisolated enum HostsFile {
    static let beginMarker = "# >>> MacLock (managed during focus sessions; do not edit)"
    static let endMarker = "# <<< MacLock"

    /// `contents` with any existing MacLock block replaced by one for `domains`
    /// (or removed entirely when `domains` is empty).
    static func applying(domains: [String], to contents: String) -> String {
        let base = removingBlock(from: contents)
        guard !domains.isEmpty else { return base }
        let hosts = domains.flatMap(variants(of:))
        var block = [beginMarker]
        for host in hosts {
            block.append("0.0.0.0 \(host)")
            block.append(":: \(host)")
        }
        block.append(endMarker)
        let separator = base.isEmpty || base.hasSuffix("\n") ? "" : "\n"
        return base + separator + block.joined(separator: "\n") + "\n"
    }

    /// `contents` without the MacLock block (and without the newline that preceded it).
    static func removingBlock(from contents: String) -> String {
        guard let begin = contents.range(of: beginMarker) else { return contents }
        let afterBegin = contents[begin.upperBound...]
        // A missing end marker (truncated file) means the block runs to the end.
        let blockEnd: String.Index
        if let end = afterBegin.range(of: endMarker) {
            blockEnd = contents[end.upperBound...].first == "\n"
                ? contents.index(after: end.upperBound) : end.upperBound
        } else {
            blockEnd = contents.endIndex
        }
        return String(contents[..<begin.lowerBound]) + String(contents[blockEnd...])
    }

    /// The hostnames blocked for one site: itself plus the common www/mobile names.
    static func variants(of domain: String) -> [String] {
        [domain, "www.\(domain)", "m.\(domain)"]
    }

    /// Turns user input ("https://www.YouTube.com/watch?v=1") into a bare domain ("youtube.com").
    /// Returns nil for anything that isn't a plausible domain, so junk never reaches /etc/hosts.
    static func normalize(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let scheme = text.range(of: "://") { text = String(text[scheme.upperBound...]) }
        text = String(text.prefix { $0 != "/" && $0 != "?" && $0 != "#" && $0 != ":" })
        while text.hasPrefix("www.") || text.hasPrefix("m.") {
            text = String(text.drop(while: { $0 != "." }).dropFirst())
        }
        let labels = text.split(separator: ".", omittingEmptySubsequences: false)
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        guard labels.count >= 2, text.count <= 253,
              labels.allSatisfy({ !$0.isEmpty && $0.count <= 63 && $0.allSatisfy(allowed.contains)
                  && !$0.hasPrefix("-") && !$0.hasSuffix("-") }),
              text != "localhost"
        else { return nil }
        return text
    }
}

nonisolated enum WebsiteBlocklist {
    static let defaults = ["youtube.com", "reddit.com", "instagram.com", "tiktok.com", "x.com", "twitter.com", "facebook.com"]
}
