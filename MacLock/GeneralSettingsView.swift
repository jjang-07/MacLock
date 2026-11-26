import ApplicationServices
import SwiftUI

/// What MacLock needs from the Mac, and whether it has it.
struct GeneralSettingsView: View {
    @Environment(SessionStore.self) private var store
    @State private var accessibility = AXIsProcessTrusted()
    @State private var shortcutsReady: Bool?

    var body: some View {
        Form {
            Section("Needed for a hard lock") {
                StatusRow(
                    title: "Background helper",
                    detail: "Owns the session, so quitting MacLock can't end it, and blocks websites.",
                    ok: store.helperStatus == .ready,
                    actionTitle: "Open Login Items"
                ) { store.openHelperSettings() }
                StatusRow(
                    title: "Accessibility",
                    detail: "Blocks the 🌐/fn + N shortcut and closes Notification Center instantly.",
                    ok: accessibility,
                    actionTitle: "Open Settings"
                ) { openAccessibility() }
            }
            Section("Optional") {
                StatusRow(
                    title: "Do Not Disturb shortcuts",
                    detail: "Shortcuts named \"\(FocusController.onShortcut)\" and \"\(FocusController.offShortcut)\" turn on Do Not Disturb during sessions.",
                    ok: shortcutsReady,
                    actionTitle: "Open Shortcuts"
                ) { openShortcuts() }
            }
        }
        .formStyle(.grouped)
        .task {
            // Permissions can change while this tab is open.
            while !Task.isCancelled {
                accessibility = AXIsProcessTrusted()
                shortcutsReady = await FocusController.shortcutsInstalled()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func openShortcuts() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
    }
}

private struct StatusRow: View {
    let title: String
    let detail: String
    /// nil = still checking.
    let ok: Bool?
    /// Shown only while something is missing.
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                switch ok {
                case true?: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case false?: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                case nil: ProgressView().controlSize(.small)
                }
            }
            .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if ok == false {
                Button(actionTitle, action: action)
            }
        }
    }
}
