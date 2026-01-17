import SwiftUI

struct AlarmSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var hasPreWakeAlarm: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $hasPreWakeAlarm) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(hasPreWakeAlarm ? .blue : .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pre-Wake Reminder")
                                    .fontWeight(.medium)
                                Text("5 minutes before wake up")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(.blue)
                } header: {
                    Text("Alarm Strategy")
                } footer: {
                    Text("A gentle reminder helps you transition out of deep sleep before the main alarm.")
                }

                Section("Your Alarms") {
                    AlarmSequencePreview(hasPreWakeAlarm: hasPreWakeAlarm)
                        .padding(.vertical, 8)
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        AlarmTypeRow(
                            icon: "bell",
                            iconColor: .blue,
                            title: "Pre-Wake",
                            description: "Gentle reminder 5 min before",
                            isEnabled: hasPreWakeAlarm
                        )

                        AlarmTypeRow(
                            icon: "bell.fill",
                            iconColor: .orange,
                            title: "Wake Up",
                            description: "Main alarm with snooze button",
                            isEnabled: true
                        )

                        AlarmTypeRow(
                            icon: "car.fill",
                            iconColor: .blue,
                            title: "Leave",
                            description: "Time to head out",
                            isEnabled: true
                        )
                    }
                } header: {
                    Text("Alarm Sequence")
                } footer: {
                    Text("The wake-up and leave alarms include a snooze button. Tap snooze to get 5 more minutes.")
                }
            }
            .navigationTitle("Alarm Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct AlarmSequencePreview: View {
    let hasPreWakeAlarm: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Pre-wake dot
            if hasPreWakeAlarm {
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: 12, height: 12)
                    Text("Pre")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Connecting line
            if hasPreWakeAlarm {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 20, height: 2)
            }

            // Main wake alarm
            VStack(spacing: 4) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 20, height: 20)
                    .overlay {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                    }
                Text("Wake")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Connecting line
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 20, height: 2)

            // Leave alarm
            VStack(spacing: 4) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 16, height: 16)
                    .overlay {
                        Image(systemName: "car.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.white)
                    }
                Text("Leave")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct AlarmTypeRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isEnabled ? iconColor : .gray)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.gray.opacity(0.5))
            }
        }
    }
}

#Preview {
    AlarmSettingsSheet(hasPreWakeAlarm: .constant(true))
}
