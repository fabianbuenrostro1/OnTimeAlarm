import SwiftUI

#if DEBUG
/// Debug menu for testing AlarmKit functionality
struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var alarmKitManager = AlarmKitManager.shared

    @State private var logs: [LogEntry] = []
    @State private var isScheduling = false

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let isError: Bool

        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: timestamp)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Status Section
                Section("AlarmKit Status") {
                    HStack {
                        Text("iOS 26+ Available")
                        Spacer()
                        Text(alarmKitManager.isAlarmKitAvailable ? "Yes" : "No")
                            .foregroundStyle(alarmKitManager.isAlarmKitAvailable ? .green : .red)
                    }

                    HStack {
                        Text("Authorization")
                        Spacer()
                        Text(alarmKitManager.getAuthorizationStatusString())
                            .foregroundStyle(authStatusColor)
                    }

                    HStack {
                        Text("Test Alarms Scheduled")
                        Spacer()
                        Text("\(alarmKitManager.testAlarmIds.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                // Quick Tests Section
                Section("Quick Tests") {
                    Button {
                        Task {
                            await scheduleTestAlarm(seconds: 10)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "alarm")
                            Text("Schedule Test Alarm (10 sec)")
                        }
                    }
                    .disabled(isScheduling || !alarmKitManager.isAlarmKitAvailable)

                    Button {
                        Task {
                            await scheduleTestAlarm(seconds: 60)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "alarm")
                            Text("Schedule Test Alarm (1 min)")
                        }
                    }
                    .disabled(isScheduling || !alarmKitManager.isAlarmKitAvailable)

                    Button(role: .destructive) {
                        Task {
                            await cancelAllTestAlarms()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Cancel All Test Alarms")
                        }
                    }
                    .disabled(alarmKitManager.testAlarmIds.isEmpty)

                    Button {
                        Task {
                            await requestAuthorization()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "lock.open")
                            Text("Request Authorization")
                        }
                    }
                }

                // Log Output Section
                Section("Log Output") {
                    if logs.isEmpty {
                        Text("No logs yet. Run a test to see output.")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(logs) { log in
                            HStack(alignment: .top) {
                                Text(log.formattedTime)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Text(log.message)
                                    .font(.caption)
                                    .foregroundStyle(log.isError ? .red : .primary)
                            }
                        }

                        Button("Clear Logs") {
                            logs.removeAll()
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("AlarmKit Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var authStatusColor: Color {
        switch alarmKitManager.getAuthorizationStatusString() {
        case "Authorized":
            return .green
        case "Denied":
            return .red
        default:
            return .orange
        }
    }

    private func addLog(_ message: String, isError: Bool = false) {
        logs.insert(LogEntry(timestamp: Date(), message: message, isError: isError), at: 0)
    }

    private func scheduleTestAlarm(seconds: TimeInterval) async {
        isScheduling = true
        addLog("Scheduling test alarm for \(Int(seconds)) seconds from now...")

        do {
            let alarmId = try await alarmKitManager.scheduleTestAlarm(inSeconds: seconds)
            let fireTime = Date().addingTimeInterval(seconds)
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            addLog("Scheduled alarm \(alarmId.uuidString.prefix(8))... fires at \(formatter.string(from: fireTime))")
        } catch {
            addLog("Failed to schedule: \(error.localizedDescription)", isError: true)
        }

        isScheduling = false
    }

    private func cancelAllTestAlarms() async {
        let count = alarmKitManager.testAlarmIds.count
        addLog("Cancelling \(count) test alarm(s)...")
        await alarmKitManager.cancelAllTestAlarms()
        addLog("Cancelled all test alarms")
    }

    private func requestAuthorization() async {
        addLog("Requesting AlarmKit authorization...")

        do {
            let authorized = try await alarmKitManager.requestAuthorization()
            addLog("Authorization result: \(authorized ? "Granted" : "Denied")")
        } catch {
            addLog("Authorization error: \(error.localizedDescription)", isError: true)
        }
    }
}

#Preview {
    DebugMenuView()
}
#endif
