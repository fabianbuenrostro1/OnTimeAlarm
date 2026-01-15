import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct DepartureEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationManager.self) private var locationManager
    
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
    
    // Location state
    @State private var destinationName: String?
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var liveTravelTime: TimeInterval?
    @State private var selectedTransportMode: TravelTimeService.TransportMode = .automobile
    @State private var isLoadingTravelTime = false
    @State private var showingLocationSearch = false
    
    private var isEditing: Bool { departure != nil }
    
    private var prepDurationOptions: [(String, TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200)
    ]
    
    // Use live travel time if available
    private var effectiveTravelTime: TimeInterval {
        liveTravelTime ?? staticTravelTime
    }
    
    private var calculatedWakeUpTime: Date {
        TimeCalculator.wakeUpTime(
            arrivalTime: targetArrivalTime,
            prepDuration: prepDuration,
            travelTime: effectiveTravelTime
        )
    }
    
    private var calculatedDepartureTime: Date {
        TimeCalculator.departureTime(
            arrivalTime: targetArrivalTime,
            travelTime: effectiveTravelTime
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
                // Section 1: Destination (merged with Travel)
                Section("Destination") {
                    // Location search button
                    Button {
                        showingLocationSearch = true
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            
                            if let name = destinationName {
                                Text(name)
                                    .foregroundStyle(.primary)
                            } else {
                                Text("Search for a place...")
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if destinationName != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    
                    // Label field
                    TextField("Label (e.g., Gym, Work)", text: $label)
                    
                    // Transport mode picker (only show if destination selected)
                    if destinationCoordinate != nil {
                        Picker("Transport", selection: $selectedTransportMode) {
                            ForEach(TravelTimeService.TransportMode.allCases, id: \.self) { mode in
                                Label(mode.rawValue, systemImage: mode.icon)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedTransportMode) { _, _ in
                            calculateLiveTravelTime()
                        }
                        
                        // Travel time display
                        HStack {
                            Text("Travel Time")
                            Spacer()
                            if isLoadingTravelTime {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if let liveTime = liveTravelTime {
                                HStack(spacing: 4) {
                                    Text(TimeCalculator.formatDuration(liveTime))
                                        .fontWeight(.medium)
                                    Image(systemName: "bolt.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            } else {
                                Text(TimeCalculator.formatDuration(staticTravelTime))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
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
                
                // Section 3: Calculated Preview
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
            .sheet(isPresented: $showingLocationSearch) {
                LocationSearchSheet { coordinate, name in
                    destinationCoordinate = coordinate
                    destinationName = name
                    if label.isEmpty {
                        label = name
                    }
                    calculateLiveTravelTime()
                }
            }
            .onAppear {
                if let departure = departure {
                    label = departure.label
                    targetArrivalTime = departure.targetArrivalTime
                    prepDuration = departure.prepDuration
                    staticTravelTime = departure.staticTravelTime
                    destinationName = departure.destinationName
                    if let lat = departure.destinationLat, let long = departure.destinationLong {
                        destinationCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                    }
                    liveTravelTime = departure.liveTravelTime
                }
            }
        }
    }
    
    private func calculateLiveTravelTime() {
        guard let destination = destinationCoordinate else { return }
        guard let userLocation = locationManager.userLocation else {
            print("No user location available")
            return
        }
        
        isLoadingTravelTime = true
        
        Task {
            let travelTime = await TravelTimeService.calculateTravelTime(
                from: userLocation,
                to: destination,
                transportMode: selectedTransportMode
            )
            
            await MainActor.run {
                liveTravelTime = travelTime
                isLoadingTravelTime = false
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
            departure.destinationName = destinationName
            departure.destinationLat = destinationCoordinate?.latitude
            departure.destinationLong = destinationCoordinate?.longitude
            departure.liveTravelTime = liveTravelTime
            departure.transportType = selectedTransportMode.rawValue
            
            NotificationManager.shared.scheduleNotifications(for: departure)
        } else {
            // Create new
            let newDeparture = Departure(
                label: label,
                targetArrivalTime: targetArrivalTime,
                prepDuration: prepDuration,
                staticTravelTime: staticTravelTime
            )
            newDeparture.destinationName = destinationName
            newDeparture.destinationLat = destinationCoordinate?.latitude
            newDeparture.destinationLong = destinationCoordinate?.longitude
            newDeparture.liveTravelTime = liveTravelTime
            newDeparture.transportType = selectedTransportMode.rawValue
            
            modelContext.insert(newDeparture)
            NotificationManager.shared.scheduleNotifications(for: newDeparture)
        }
        
        dismiss()
    }
}

#Preview {
    DepartureEditorView()
        .modelContainer(for: [Departure.self], inMemory: true)
        .environment(LocationManager())
}
