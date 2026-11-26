import SwiftUI

/// Recurring lock windows. Schedules that are running or start within 10 minutes are locked:
/// the daemon refuses changes to them, and the UI disables their controls.
struct SchedulesSettingsView: View {
    @Environment(SessionStore.self) private var store
    @State private var editing: Schedule?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MacLock starts a session automatically during these times. A schedule can't be changed while it's running or in the 10 minutes before it starts.")
                .font(.callout)
                .foregroundStyle(.secondary)

            List {
                // Re-evaluate locks every few seconds as times pass.
                TimelineView(.periodic(from: .now, by: 5)) { context in
                    ForEach(store.config.schedules) { schedule in
                        ScheduleRow(schedule: schedule, locked: schedule.isLocked(at: context.date)) {
                            editing = schedule
                        } onToggle: { enabled in
                            change { config in
                                if let i = config.schedules.firstIndex(where: { $0.id == schedule.id }) {
                                    config.schedules[i].enabled = enabled
                                }
                            }
                        } onDelete: {
                            change { $0.schedules.removeAll { $0.id == schedule.id } }
                        }
                    }
                }
            }
            .listStyle(.bordered)
            .overlay {
                if store.config.schedules.isEmpty {
                    Text("No schedules yet").foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Add Schedule…", systemImage: "plus") {
                    editing = Schedule(name: "Focus", weekdays: [2, 3, 4, 5, 6], start: 9 * 60, end: 12 * 60)
                }
                Spacer()
                if let message {
                    Text(message).font(.callout).foregroundStyle(.red)
                }
            }
        }
        .padding()
        .disabled(store.helperStatus != .ready)
        .sheet(item: $editing) { schedule in
            ScheduleEditor(schedule: schedule) { saved in
                change { config in
                    if let i = config.schedules.firstIndex(where: { $0.id == saved.id }) {
                        config.schedules[i] = saved
                    } else {
                        config.schedules.append(saved)
                    }
                }
            }
        }
    }

    private func change(_ edit: (inout BlockConfig) -> Void) {
        var proposed = store.config
        edit(&proposed)
        message = nil
        Task { message = await store.updateConfig(proposed) }
    }
}

private struct ScheduleRow: View {
    let schedule: Schedule
    let locked: Bool
    let onEdit: () -> Void
    let onToggle: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { schedule.enabled }, set: onToggle))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(schedule.name).fontWeight(.medium)
                    if locked { Image(systemName: "lock.fill").font(.caption).foregroundStyle(.orange) }
                }
                Text("\(ScheduleFormat.days(schedule.weekdays)) · \(ScheduleFormat.time(schedule.start))–\(ScheduleFormat.time(schedule.end))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit", action: onEdit)
                .buttonStyle(.borderless)
            Button("Delete", systemImage: "trash", action: onDelete)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .disabled(locked)
        .help(locked ? "Running or starting soon, so it can't be changed right now" : "")
    }
}

private struct ScheduleEditor: View {
    @State var schedule: Schedule
    let onSave: (Schedule) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Name", text: $schedule.name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Days").font(.headline)
                HStack(spacing: 4) {
                    // Monday first; Calendar weekdays are 1 = Sunday … 7 = Saturday.
                    ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                        Toggle(ScheduleFormat.shortDay(day), isOn: Binding(
                            get: { schedule.weekdays.contains(day) },
                            set: { on in if on { schedule.weekdays.insert(day) } else { schedule.weekdays.remove(day) } }
                        ))
                        .toggleStyle(.button)
                    }
                }
            }

            HStack(spacing: 16) {
                DatePicker("From", selection: minutes(\.start), displayedComponents: .hourAndMinute)
                DatePicker("To", selection: minutes(\.end), displayedComponents: .hourAndMinute)
            }
            if schedule.end <= schedule.start {
                Text("Ends the next day (\(schedule.durationMinutes / 60)h \(schedule.durationMinutes % 60)m).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") {
                    onSave(schedule)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(schedule.weekdays.isEmpty || schedule.start == schedule.end
                          || schedule.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    /// Binds a minutes-after-midnight field to a DatePicker.
    private func minutes(_ keyPath: WritableKeyPath<Schedule, Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(schedule[keyPath: keyPath] * 60)) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                schedule[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

enum ScheduleFormat {
    static func time(_ minutes: Int) -> String {
        let date = Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(minutes * 60))
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func shortDay(_ weekday: Int) -> String {
        Calendar.current.veryShortWeekdaySymbols[weekday - 1]
    }

    static func days(_ weekdays: Set<Int>) -> String {
        switch weekdays {
        case Set(1...7): return "Every day"
        case [2, 3, 4, 5, 6]: return "Weekdays"
        case [1, 7]: return "Weekends"
        default:
            let symbols = Calendar.current.shortWeekdaySymbols
            return [2, 3, 4, 5, 6, 7, 1].filter(weekdays.contains).map { symbols[$0 - 1] }.joined(separator: ", ")
        }
    }
}
