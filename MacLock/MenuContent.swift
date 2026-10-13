import SwiftUI

struct MenuContent: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.isActive {
                ActiveSessionView()
            } else {
                StartSessionView()
            }

            Divider()

            HStack {
                Button("Settings…") { openSettings() }
                Spacer()
                // No quitting your way out of a session.
                if !store.isActive {
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                }
            }
        }
        .padding()
        .frame(width: 280)
    }

    private func openSettings() {
        dismiss()   // close the popover
        openWindow(id: WindowID.settings)
        // Menu bar apps aren't active by default, so the window would open behind others.
        NSApp.activate()
    }
}

private struct StartSessionView: View {
    @Environment(SessionStore.self) private var store
    @AppStorage("customMinutes") private var customMinutes = 45

    private static var presets: [Int] {
        #if DEBUG
        [1, 25, 50, 90]   // 1-minute preset for testing
        #else
        [25, 50, 90]
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start a focus session")
                .font(.headline)

            HStack {
                ForEach(Self.presets, id: \.self) { minutes in
                    Button("\(minutes)m") { store.start(duration: .seconds(minutes * 60)) }
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)

            HStack {
                Stepper(value: $customMinutes, in: 5...480, step: 5) {
                    Text(Self.label(minutes: customMinutes))
                        .monospacedDigit()
                }
                Spacer()
                Button("Start") { store.start(duration: .seconds(customMinutes * 60)) }
                    .buttonStyle(.borderedProminent)
            }

            Text("Once started, a session can't be stopped early.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private static func label(minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : "\(minutes / 60)h \(minutes % 60)m"
    }
}

private struct ActiveSessionView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Locked in")
                .font(.headline)

            Text(Countdown.format(store.remaining))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: Int(store.remaining))

            ProgressView(value: store.progress)

            if let end = store.session?.end {
                Text("Ends at \(end.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            #if DEBUG
            Button("End session (debug only)", role: .destructive) { store.debugEnd() }
                .font(.caption)
            #endif
        }
    }
}
