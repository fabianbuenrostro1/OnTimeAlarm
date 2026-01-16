import SwiftUI

/// Arrival-first row for the On Time Alarm list
struct AlarmRowView: View {
    @Bindable var departure: Departure

    /// Convert stored transport type to verb for display
    private var transportVerb: String {
        switch departure.transportType {
        case "Drive": return "drive"
        case "Walk": return "walk"
        case "Bike": return "bike"
        default: return "travel"
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // Line 1: Arrival time - PROMINENT
                Text(departure.targetArrivalTime, format: .dateTime.hour().minute())
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(departure.isEnabled ? .primary : .secondary)

                // Line 1.5: Destination name subtitle - "Robin" to the time's "Batman"
                if let destinationName = departure.destinationName, !destinationName.isEmpty {
                    Text(destinationName)
                        .font(.title3)
                        .fontWeight(.light)
                        .foregroundStyle(departure.isEnabled ? .primary : .secondary)
                }

                // Line 2: The math - Wake time + breakdown
                Text("Wake \(departure.wakeUpTime.formatted(.dateTime.hour().minute())) · \(TimeCalculator.formatDuration(departure.prepDuration)) prep · \(TimeCalculator.formatDuration(departure.effectiveTravelTime)) \(transportVerb)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Line 3: Address (if present)
                if let address = departure.destinationAddress, !address.isEmpty {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Toggle switch
            Toggle("", isOn: $departure.isEnabled)
                .labelsHidden()
                .tint(.green)
                .onChange(of: departure.isEnabled) { _, isEnabled in
                    if isEnabled {
                        NotificationManager.shared.scheduleNotifications(for: departure)
                    } else {
                        NotificationManager.shared.cancelNotifications(for: departure)
                    }
                }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let departure = Departure(
        label: "Gym",
        targetArrivalTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!,
        prepDuration: 1800,  // 30 min
        staticTravelTime: 900  // 15 min
    )
    departure.destinationAddress = "13549 W Harding Rd"

    return List {
        AlarmRowView(departure: departure)
    }
    .modelContainer(for: Departure.self, inMemory: true)
}
