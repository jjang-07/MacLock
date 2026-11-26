import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Blocking", systemImage: "nosign") { BlockingSettingsView() }
            Tab("Schedules", systemImage: "calendar") { SchedulesSettingsView() }
            Tab("Stats", systemImage: "chart.bar") { placeholder("Focus time and streaks") }
            Tab("General", systemImage: "gearshape") { GeneralSettingsView() }
        }
        .frame(width: 560, height: 460)
        .environment(SessionStore.shared)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
