import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Blocking", systemImage: "nosign") { placeholder("Blocked apps and websites") }
            Tab("Schedules", systemImage: "calendar") { placeholder("Scheduled lock sessions") }
            Tab("Stats", systemImage: "chart.bar") { placeholder("Focus time and streaks") }
            Tab("General", systemImage: "gearshape") { placeholder("Permissions and helper status") }
        }
        .frame(width: 520, height: 360)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
