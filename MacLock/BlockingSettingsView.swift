import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Edits the blocklists. Every change goes to the daemon, which refuses removals during a session.
struct BlockingSettingsView: View {
    @Environment(SessionStore.self) private var store
    @State private var newWebsite = ""
    @State private var message: String?
    @State private var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.isActive {
                Label("A session is running: you can add to these lists, but not remove anything until it ends.",
                      systemImage: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            HStack(alignment: .top, spacing: 16) {
                appsSection
                websitesSection
            }

            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
            } else if let note {
                Label(note, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .disabled(store.helperStatus != .ready)
    }

    // MARK: Apps

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apps").font(.headline)
            List {
                ForEach(store.config.apps, id: \.bundleID) { app in
                    HStack {
                        AppIcon(bundleID: app.bundleID)
                        Text(app.name)
                        Spacer()
                        removeButton { $0.apps.removeAll { $0.bundleID == app.bundleID } }
                    }
                }
            }
            .listStyle(.bordered)
            .overlay { if store.config.apps.isEmpty { emptyLabel("No blocked apps") } }

            Button("Add App…", systemImage: "plus", action: pickApps)
        }
        .frame(maxWidth: .infinity)
    }

    private func pickApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Block"
        NSApp.activate()
        guard panel.runModal() == .OK else { return }

        let picked = panel.urls.compactMap { url -> BlockConfig.App? in
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            return .init(bundleID: id, name: name)
        }
        let protected = picked.filter { AppBlocklist.protected.contains($0.bundleID) }.map(\.name)
        change { $0.apps += picked }
        if !protected.isEmpty {
            message = "\(protected.joined(separator: ", ")) can't be blocked: MacLock or your Mac needs it."
        }
    }

    // MARK: Websites

    private var websitesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Websites").font(.headline)
            List {
                ForEach(store.config.websites, id: \.self) { site in
                    HStack {
                        Image(systemName: "globe").foregroundStyle(.secondary)
                        Text(site)
                        Spacer()
                        removeButton { $0.websites.removeAll { $0 == site } }
                    }
                }
            }
            .listStyle(.bordered)
            .overlay { if store.config.websites.isEmpty { emptyLabel("No blocked websites") } }

            HStack {
                TextField("example.com", text: $newWebsite)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addWebsite)
                Button("Add", action: addWebsite)
                    .disabled(newWebsite.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Also blocks www. and m. versions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func addWebsite() {
        guard let domain = HostsFile.normalize(newWebsite) else {
            message = "\"\(newWebsite)\" doesn't look like a website. Try something like reddit.com."
            return
        }
        newWebsite = ""
        change { $0.websites.append(domain) }
        // Browsers (Chromium-based ones especially) keep their own DNS cache and open connections,
        // so a site that's already open keeps working until the browser restarts.
        note = store.isActive
            ? "\(domain) is blocked now. Tabs that are already open may keep loading until you quit and reopen your browser."
            : nil
    }

    // MARK: Helpers

    private func removeButton(_ edit: @escaping (inout BlockConfig) -> Void) -> some View {
        Button("Remove", systemImage: "minus.circle.fill") { change(edit) }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(store.isActive)
            .help(store.isActive ? "Can't unblock during a session" : "Remove")
    }

    private func change(_ edit: (inout BlockConfig) -> Void) {
        var proposed = store.config
        edit(&proposed)
        message = nil
        Task { message = await store.updateConfig(proposed) }
    }

    private func emptyLabel(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).font(.callout)
    }
}

private struct AppIcon: View {
    let bundleID: String

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "app.dashed")
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
                .help("Not installed")
        }
    }
}
