import SwiftUI
import SwiftData
import MapKit
import CoreLocation

enum LocationSearchType {
    case origin
    case destination
}

struct DepartureEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationManager.self) private var locationManager
    
    let departure: Departure?
    
    init(departure: Departure? = nil) {
        self.departure = departure
    }
    
    // Form state
    @State private var label: String = ""
    @State private var targetArrivalTime: Date = Date()
    @State private var prepDuration: TimeInterval = 1800
    @State private var staticTravelTime: TimeInterval = 1200
    
    // Origin (departure from) location - Snapshot based
    @State private var originName: String?
    @State private var originCoordinate: CLLocationCoordinate2D?
    
    // Barrage Mode
    @State private var isBarrageEnabled: Bool = false
    @State private var preWakeAlarms: Int = 2
    @State private var postWakeAlarms: Int = 5
    @State private var barrageInterval: TimeInterval = 120
    
    // Destination location
    @State private var destinationName: String?
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    
    // Travel state
    @State private var liveTravelTime: TimeInterval?
    @State private var selectedTransportMode: TravelTimeService.TransportMode = .automobile
    @State private var isLoadingTravelTime = false
    
    // Sheets
    @State private var showingLocationSearch = false
    @State private var searchType: LocationSearchType = .destination
    
    private var isEditing: Bool { departure != nil }
    
    private var prepDurationOptions: [(String, TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200)
    ]
    
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
                // Section 1: Locations
                Section("Route") {
                    // Origin - Snapshot Location
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("From")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let name = originName {
                                Text(name)
                                    .foregroundStyle(.primary)
                            } else {
                                Text("Not set")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            snapshotCurrentLocation()
                        } label: {
                            Text("Use Current")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        
                        Button {
                            searchType = .origin
                            showingLocationSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Destination (Going To)
                    Button {
                        searchType = .destination
                        showingLocationSearch = true
                    } label: {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("To")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let name = destinationName {
                                    Text(name)
                                        .foregroundStyle(.primary)
                                } else {
                                    Text("Set destination...")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if destinationName != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    
                    // Label
                    TextField("Label (e.g., Gym, Work)", text: $label)
                    
                    // Transport + Travel Time (show when both locations set)
                    if originCoordinate != nil && destinationCoordinate != nil {
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
                
                // Section 3: Barrage Mode
                Section {
                    Toggle(isOn: $isBarrageEnabled) {
                        HStack {
                            Image(systemName: "bell.badge.waveform.fill")
                                .foregroundStyle(.orange)
                            Text("Barrage Mode")
                        }
                    }
                    .tint(.orange)
                    
                    if isBarrageEnabled {
                        Stepper(value: $preWakeAlarms, in: 0...5) {
                            HStack {
                                Text("Ramp Up")
                                Spacer()
                                Text("\(preWakeAlarms) alarms before")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Stepper(value: $postWakeAlarms, in: 0...30) {
                            HStack {
                                Text("Safety Net")
                                Spacer()
                                Text("\(postWakeAlarms) alarms after")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Picker("Interval", selection: $barrageInterval) {
                            Text("1 min").tag(TimeInterval(60))
                            Text("2 min").tag(TimeInterval(120))
                            Text("5 min").tag(TimeInterval(300))
                            Text("10 min").tag(TimeInterval(600))
                        }
                        
                        // Barrage Timeline Visualizer
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            barrageTimelineView
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Alarm Mode")
                } footer: {
                    if isBarrageEnabled {
                        Text("Fires \(preWakeAlarms + 1 + postWakeAlarms) alarms total: \(preWakeAlarms) before, 1 at wake up, \(postWakeAlarms) after.")
                    }
                }
                
                // Section 4: Schedule Preview
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingLocationSearch) {
                LocationSearchSheet { coordinate, name in
                    if searchType == .origin {
                        originCoordinate = coordinate
                        originName = name
                    } else {
                        destinationCoordinate = coordinate
                        destinationName = name
                        if label.isEmpty {
                            label = name
                        }
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
                    
                    // Load origin
                    originName = departure.originName
                    if let lat = departure.originLat, let long = departure.originLong {
                        originCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                    }
                    
                    // Load destination
                    destinationName = departure.destinationName
                    if let lat = departure.destinationLat, let long = departure.destinationLong {
                        destinationCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                    }
                    liveTravelTime = departure.liveTravelTime
                    
                    // Load transport mode
                    if let mode = TravelTimeService.TransportMode.allCases.first(where: { $0.rawValue == departure.transportType }) {
                        selectedTransportMode = mode
                    }
                    
                    // Load barrage settings
                    isBarrageEnabled = departure.isBarrageEnabled
                    preWakeAlarms = departure.preWakeAlarms
                    postWakeAlarms = departure.postWakeAlarms
                    barrageInterval = departure.barrageInterval
                } else {
                    // New departure: snapshot current location by default
                    snapshotCurrentLocation()
                }
            }
        }
    }
    
    private func calculateLiveTravelTime() {
        guard let origin = originCoordinate,
              let destination = destinationCoordinate else { return }
        
        isLoadingTravelTime = true
        
        Task {
            let travelTime = await TravelTimeService.calculateTravelTime(
                from: origin,
                to: destination,
                transportMode: selectedTransportMode
            )
            
            await MainActor.run {
                liveTravelTime = travelTime
                isLoadingTravelTime = false
            }
        }
    }
    
    private func snapshotCurrentLocation() {
        if let userLoc = locationManager.userLocation {
            originCoordinate = userLoc
            originName = "Current Location"
            calculateLiveTravelTime()
        }
    }
    
    private var barrageTimelineView: some View {
        HStack(spacing: 4) {
            // Pre-wake dots
            ForEach(0..<preWakeAlarms, id: \.self) { _ in
                Circle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 8, height: 8)
            }
            
            // Main wake dot
            Circle()
                .fill(Color.orange)
                .frame(width: 14, height: 14)
                .overlay {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.white)
                }
            
            // Post-wake dots
            ForEach(0..<min(postWakeAlarms, 10), id: \.self) { i in
                Circle()
                    .fill(Color.red.opacity(0.3 + Double(i) * 0.07))
                    .frame(width: 8, height: 8)
            }
            
            if postWakeAlarms > 10 {
                Text("+\(postWakeAlarms - 10)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func save() {
        if let departure = departure {
            departure.label = label
            departure.targetArrivalTime = targetArrivalTime
            departure.prepDuration = prepDuration
            departure.staticTravelTime = staticTravelTime
            
            // Save origin (snapshot)
            departure.originName = originName
            departure.originLat = originCoordinate?.latitude
            departure.originLong = originCoordinate?.longitude
            
            // Save destination
            departure.destinationName = destinationName
            departure.destinationLat = destinationCoordinate?.latitude
            departure.destinationLong = destinationCoordinate?.longitude
            departure.liveTravelTime = liveTravelTime
            departure.transportType = selectedTransportMode.rawValue
            
            // Save barrage settings
            departure.isBarrageEnabled = isBarrageEnabled
            departure.preWakeAlarms = preWakeAlarms
            departure.postWakeAlarms = postWakeAlarms
            departure.barrageInterval = barrageInterval
            
            NotificationManager.shared.scheduleNotifications(for: departure)
        } else {
            let newDeparture = Departure(
                label: label,
                targetArrivalTime: targetArrivalTime,
                prepDuration: prepDuration,
                staticTravelTime: staticTravelTime
            )
            
            // Save origin (snapshot)
            newDeparture.originName = originName
            newDeparture.originLat = originCoordinate?.latitude
            newDeparture.originLong = originCoordinate?.longitude
            
            // Save destination
            newDeparture.destinationName = destinationName
            newDeparture.destinationLat = destinationCoordinate?.latitude
            newDeparture.destinationLong = destinationCoordinate?.longitude
            newDeparture.liveTravelTime = liveTravelTime
            newDeparture.transportType = selectedTransportMode.rawValue
            
            // Save barrage settings
            newDeparture.isBarrageEnabled = isBarrageEnabled
            newDeparture.preWakeAlarms = preWakeAlarms
            newDeparture.postWakeAlarms = postWakeAlarms
            newDeparture.barrageInterval = barrageInterval
            
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
