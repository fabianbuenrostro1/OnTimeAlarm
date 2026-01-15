import SwiftUI
import SwiftData
import MapKit

struct DebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var departures: [Departure]
    
    var body: some View {
        NavigationStack {
            List {
                Section("Quick Add") {
                    Button("Add 'Home -> Work'") {
                        addMockDeparture(
                            label: "Work",
                            origin: "Home",
                            destination: "Apple Park",
                            lat: 37.3346,
                            long: -122.0090,
                            wakeHour: 6,
                            wakeMinute: 30
                        )
                    }
                    
                    Button("Add 'Home -> Gym'") {
                        addMockDeparture(
                            label: "Gym",
                            origin: "Home",
                            destination: "Equinox",
                            lat: 37.7897,
                            long: -122.4013,
                            wakeHour: 5,
                            wakeMinute: 0
                        )
                    }
                    
                    Button("Add 'School -> Work'") {
                        addMockDeparture(
                            label: "Pickup",
                            origin: "School",
                            destination: "Work",
                            lat: 37.4275,
                            long: -122.1697,
                            wakeHour: 14,
                            wakeMinute: 30
                        )
                    }
                }
                

                
                Section("Latest Departure Inspector") {
                    if let latest = departures.sorted(by: { $0.createdDate > $1.createdDate }).first {
                        LabeledContent("Label", value: latest.label)
                        LabeledContent("Origin", value: latest.originName ?? "N/A")
                        LabeledContent("Destination", value: latest.destinationName ?? "N/A")
                        
                        LabeledContent("Target Arrival") {
                            Text(latest.targetArrivalTime, style: .time)
                        }
                        
                        LabeledContent("Prep Duration", value: "\(Int(latest.prepDuration / 60)) min")
                        LabeledContent("Travel Time (Static)", value: "\(Int(latest.staticTravelTime / 60)) min")
                        
                        if let live = latest.liveTravelTime {
                             LabeledContent("Travel Time (Live)", value: "\(Int(live / 60)) min")
                        }
                        
                        LabeledContent("Barrage Enabled", value: latest.isBarrageEnabled ? "Yes" : "No")
                        if latest.isBarrageEnabled {
                            LabeledContent("Pre-Wake Alarms", value: "\(latest.preWakeAlarms)")
                            LabeledContent("Post-Wake Alarms", value: "\(latest.postWakeAlarms)")
                        }
                        
                        LabeledContent("Coordinates (Dest)") {
                            if let lat = latest.destinationLat, let long = latest.destinationLong {
                                Text("\(lat, specifier: "%.4f"), \(long, specifier: "%.4f")")
                                    .font(.caption)
                                    .monospaced()
                            } else {
                                Text("Missing")
                            }
                        }
                    } else {
                        Text("No departures found")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Data Management") {
                    Button("Clear All Departures", role: .destructive) {
                        do {
                            try modelContext.delete(model: Departure.self)
                        } catch {
                            print("Failed to delete departures: \(error)")
                        }
                    }
                    
                    HStack {
                        Text("Total Departures")
                        Spacer()
                        Text("\(departures.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Diagnostics") {
                    LabeledContent("Pending Notifications") {
                        // Placeholder for async counts
                        Text("Check Console")
                    }
                    
                    Button("Log Pending Notifications") {
                        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                            print("--- Pending Notifications ---")
                            for request in requests {
                                print("ID: \(request.identifier), Trigger: \(String(describing: request.trigger))")
                            }
                            print("-----------------------------")
                        }
                    }
                }
            }
            .navigationTitle("Debug Tools")
        }
    }
    
    private func addMockDeparture(label: String, origin: String, destination: String, lat: Double, long: Double, wakeHour: Int, wakeMinute: Int) {
        // Create an arrival time (e.g., +2 hours from wake)
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = calendar.component(.year, from: Date())
        components.month = calendar.component(.month, from: Date())
        components.day = calendar.component(.day, from: Date()) + 1 // Tomorrow
        components.hour = wakeHour + 2
        components.minute = wakeMinute
        
        let arrivalTime = calendar.date(from: components) ?? Date()
        
        let departure = Departure(
            label: label,
            targetArrivalTime: arrivalTime,
            prepDuration: 2700, // 45m
            staticTravelTime: 1800 // 30m
        )
        
        departure.destinationName = destination
        departure.destinationLat = lat
        departure.destinationLong = long
        departure.originName = origin
        departure.isBarrageEnabled = true
        departure.preWakeAlarms = 3
        
        modelContext.insert(departure)
    }
}

#Preview {
    DebugView()
        .modelContainer(for: Departure.self, inMemory: true)
}
