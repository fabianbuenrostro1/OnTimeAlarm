import SwiftUI
import SwiftData

struct DepartureEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Existing departure (nil for new)
    let departure: Departure?
    
    init(departure: Departure? = nil) {
        self.departure = departure
    }
    
    // Form state
    @State private var label: String = ""
    @State private var targetArrivalTime: Date = Date()
    @State private var prepDuration: TimeInterval = 1800 // 30 mins
    @State private var staticTravelTime: TimeInterval = 1200 // 20 mins
    
    private var isEditing: Bool { departure != nil }
    
    private var prepDurationOptions: [(String, TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200)
    ]
    
    private var travelTimeOptions: [(String, TimeInterval)] = [
        ("5 min", 300),
        ("10 min", 600),
        ("15 min", 900),
        ("20 min", 1200),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hour", 3600)
    ]
    
    // Computed preview
    private var calculatedWakeUpTime: Date {
        TimeCalculator.wakeUpTime(
            arrivalTime: targetArrivalTime,
            prepDuration: prepDuration,
            travelTime: staticTravelTime
        )
    }
    
    private var calculatedDepartureTime: Date {
        TimeCalculator.departureTime(
            arrivalTime: targetArrivalTime,
            travelTime: staticTravelTime
        )
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Label
                Section("Destination") {
                    TextField("Label (e.g., Gym, Work)", text: $label)
                }
                
                // Section 2: Timing
                Section("Timing") {
                    DatePicker(
                        "Arrival Time",
                        selection: $targetArrivalTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    
                    Picker("Prep Duration", selection: $prepDuration) {
                        ForEach(prepDurationOptions, id: \.1) { option in
                            Text(option.0).tag(option.1)
                        }
                    }
                }
                
                // Section 3: Travel
                Section("Travel") {
                    Picker("Travel Time", selection: $staticTravelTime) {
                        ForEach(travelTimeOptions, id: \.1) { option in
                            Text(option.0).tag(option.1)
                        }
                    }
                }
                
                // Section 4: Calculated Preview
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Wake Up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(timeFormatter.string(from: calculatedWakeUpTime))
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        VStack(alignment: .center) {
                            Text("Leave")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(timeFormatter.string(from: calculatedDepartureTime))
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Arrive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(timeFormatter.string(from: targetArrivalTime))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Your Schedule")
                }
            }
            .navigationTitle(isEditing ? "Edit Departure" : "New Departure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let departure = departure {
                    label = departure.label
                    targetArrivalTime = departure.targetArrivalTime
                    prepDuration = departure.prepDuration
                    staticTravelTime = departure.staticTravelTime
                }
            }
        }
    }
    
    private func save() {
        if let departure = departure {
            // Update existing
            departure.label = label
            departure.targetArrivalTime = targetArrivalTime
            departure.prepDuration = prepDuration
            departure.staticTravelTime = staticTravelTime
            
            // Reschedule notifications
            NotificationManager.shared.scheduleNotifications(for: departure)
        } else {
            // Create new
            let newDeparture = Departure(
                label: label,
                targetArrivalTime: targetArrivalTime,
                prepDuration: prepDuration,
                staticTravelTime: staticTravelTime
            )
            modelContext.insert(newDeparture)
            
            // Schedule notifications
            NotificationManager.shared.scheduleNotifications(for: newDeparture)
        }
        
        dismiss()
    }
}

#Preview {
    DepartureEditorView()
        .modelContainer(for: [Departure.self], inMemory: true)
}
