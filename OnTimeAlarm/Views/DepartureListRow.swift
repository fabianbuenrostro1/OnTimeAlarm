import SwiftUI

struct DepartureListRow: View {
    @Bindable var departure: Departure
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack {
            // Leading: Times and labels
            VStack(alignment: .leading, spacing: 4) {
                // Wake-up time (large, prominent)
                Text(timeFormatter.string(from: departure.wakeUpTime))
                    .font(.system(size: 42, weight: .light, design: .default))
                    .foregroundStyle(departure.isEnabled ? .primary : .secondary)
                
                // Label
                Text(departure.label)
                    .font(.headline)
                    .foregroundStyle(departure.isEnabled ? .primary : .secondary)
                
                // Sublabel: Arrival time and prep duration
                Text("Arrive by \(timeFormatter.string(from: departure.targetArrivalTime)) • \(TimeCalculator.formatDuration(departure.prepDuration)) Prep")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Trailing: Toggle
            Toggle("", isOn: $departure.isEnabled)
                .labelsHidden()
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
        targetArrivalTime: Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date())!,
        prepDuration: 900,
        staticTravelTime: 900
    )
    return DepartureListRow(departure: departure)
        .padding()
}
