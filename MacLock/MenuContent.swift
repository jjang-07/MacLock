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
                if store.helperStatus != .ready { HelperStatusView() }
                StartSessionView()
                    .disabled(store.helperStatus != .ready || store.isStarting)
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

/// Shown until the root helper is approved; sessions can't start without it.
private struct HelperStatusView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch store.helperStatus {
            case .needsApproval:
                Label("Allow MacLock's helper to start sessions", systemImage: "exclamationmark.shield")
                    .font(.callout.weight(.medium))
                Text("System Settings → General → Login Items & Extensions → turn on MacLock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open Login Items") { store.openHelperSettings() }
            case .unavailable(let reason):
                Label("MacLock's helper isn't available", systemImage: "exclamationmark.triangle")
                    .font(.callout.weight(.medium))
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Try Again") { store.checkHelper() }
            case .ready:
                EmptyView()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: .rect(cornerRadius: 8))
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
