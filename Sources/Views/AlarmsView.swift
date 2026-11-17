import SwiftUI

struct AlarmsView: View {
    @Environment(LyrionService.self) private var service
    @State private var alarms: [Alarm] = []
    @State private var isLoading = false
    @State private var showAdd = false

    var body: some View {
        Group {
            if isLoading && alarms.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(alarms) { alarm in
                        AlarmRow(alarm: alarm)
                    }
                    .onDelete { indexSet in
                        for i in indexSet { deleteAlarm(alarms[i]) }
                        alarms.remove(atOffsets: indexSet)
                    }
                }
            }
        }
        .navigationTitle("Alarms")
        .toolbar {
            Button { showAdd = true } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAlarmView { time in
                service.addAlarm(time: time)
                Task { await loadAlarms() }
            }
        }
        .task { await loadAlarms() }
    }

    private func loadAlarms() async {
        isLoading = true
        alarms = (try? await service.fetchAlarms()) ?? []
        isLoading = false
    }

    private func deleteAlarm(_ alarm: Alarm) {
        service.deleteAlarm(id: alarm.id)
    }
}

struct AlarmRow: View {
    @Environment(LyrionService.self) private var service
    let alarm: Alarm

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeString)
                    .font(.title3).bold()
                Text(daysString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { alarm.enabled },
                set: { service.enableAlarm(id: alarm.id, enabled: $0) }
            ))
            .labelsHidden()
        }
    }

    private var daysString: String {
        guard alarm.repeat_ else { return "Once" }
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        if alarm.dow.isEmpty { return "Every day" }
        return alarm.dow.sorted().map { dayNames[$0 % 7] }.joined(separator: ", ")
    }
}

struct AddAlarmView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var time = Date()
    let onAdd: (Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
            .navigationTitle("Add Alarm")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                        let seconds = (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60
                        onAdd(seconds)
                        dismiss()
                    }
                }
            }
        }
    }
}
