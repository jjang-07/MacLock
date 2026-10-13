import SwiftUI

struct MenuContent: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MacLock")
                .font(.headline)
            Text("No active session")
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Button("Settings…") { openSettings() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 260)
    }

    private func openSettings() {
        dismiss()   // close the popover
        openWindow(id: WindowID.settings)
        // Menu bar apps aren't active by default, so the window would open behind others.
        NSApp.activate()
    }
}
