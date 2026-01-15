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
    
    // Origin (departure from) location // Locations
    @State private var originName: String?
    @State private var originAddress: String?
    @State private var originCoordinate: CLLocationCoordinate2D?
    
    // Barrage Mode
    @State private var isBarrageEnabled: Bool = false
    @State private var preWakeAlarms: Int = 2
    @State private var postWakeAlarms: Int = 5
    @State private var barrageInterval: TimeInterval = 120
    
    // Destination location
    @State private var destinationName: String?
    @State private var destinationAddress: String?
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    
    // Travel state
    @State private var liveTravelTime: TimeInterval?
    @State private var selectedTransportMode: TravelTimeService.TransportMode = .automobile
    @State private var isLoadingTravelTime = false
    
    // Sheets
    @State private var showingLocationSearch = false
    @State private var showingAddPlace = false
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
                // Header Section: Schedule Hero + Label
                Section {
                    VStack(spacing: 16) {
                        // 1. Wake Up Time - The Hero
                        VStack(spacing: 4) {
                            Text("Wake Up")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(timeFormatter.string(from: calculatedWakeUpTime))
                                .font(.system(size: 56, weight: .bold, design: .rounded)) // Slightly larger
                                .foregroundStyle(.primary)
                        }
                        .padding(.top, 8)
                        
                        // 2. Timeline: Wake → Leave → Arrive
                        HStack {
                            VStack(spacing: 4) {
                                Image(systemName: "bed.double.fill")
                                    .foregroundStyle(.blue)
                                Text(timeFormatter.string(from: calculatedWakeUpTime))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 2)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 4) {
                                Image(systemName: "car.fill")
                                    .foregroundStyle(.orange)
                                Text(timeFormatter.string(from: calculatedDepartureTime))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 2)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.green)
                                Text(timeFormatter.string(from: targetArrivalTime))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        Divider()
                        
                        // 3. Name it (Label) - Integrated at bottom of card
                        TextField("Name this departure (e.g., Gym)", text: $label)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 4)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Section 3: Where are you going?
                Section {
                    // Origin
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
                                    .fontWeight(.medium)
                                if let addr = originAddress {
                                    Text(addr)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            } else {
                                Text("Not set")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            searchType = .origin
                            showingLocationSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Origin Places Row
                    PlacesRow(
                        selectedCoordinate: $originCoordinate,
                        selectedName: $originName,
                        selectedAddress: $originAddress,
                        onSelectCurrentLocation: {
                            snapshotCurrentLocation()
                        },
                        onAddNew: {
                            showingAddPlace = true
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                    
                    // Destination
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
                                    .fontWeight(.medium)
                                if let addr = destinationAddress {
                                    Text(addr)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            } else {
                                Text("Not set")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            searchType = .destination
                            showingLocationSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Destination Places Row
                    PlacesRow(
                        selectedCoordinate: $destinationCoordinate,
                        selectedName: $destinationName,
                        selectedAddress: $destinationAddress,
                        onAddNew: {
                            showingAddPlace = true
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                    .onChange(of: destinationName) { oldValue, newValue in
                        if oldValue != newValue, newValue != nil, destinationCoordinate != nil {
                            calculateLiveTravelTime()
                            if label.isEmpty, let name = newValue {
                                label = name
                            }
                        }
                    }
                    
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
                } header: {
                    Text("Where are you going?")
                }
                
                // Section 4: When do you need to arrive?
                Section {
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
                } header: {
                    Text("When do you need to arrive?")
                }
                
                // Section 5: Alarm Mode
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
                    Text("Alarm Settings")
                } footer: {
                    if isBarrageEnabled {
                        Text("Fires \(preWakeAlarms + 1 + postWakeAlarms) alarms total: \(preWakeAlarms) before, 1 at wake up, \(postWakeAlarms) after.")
                    }
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
                LocationSearchSheet { coordinate, name, formattedAddress in
                    if searchType == .origin {
                        originCoordinate = coordinate
                        originName = name
                        originAddress = formattedAddress
                    } else {
                        destinationCoordinate = coordinate
                        destinationName = name
                        destinationAddress = formattedAddress
                        
                        // Auto-fill label only if empty AND name doesn't look like an address
                        // Simple heuristic: if name starts with a number, maybe it's an address?
                        // But user might want to name it "Work".
                        // Let's NOT auto-fill label if it's identical to name, to avoid redundancy.
                        if label.isEmpty {
                            // If name is NOT same as formattedAddress (meaning it's a POI name), use it.
                            if name != formattedAddress {
                                label = name
                            }
                        }
                    }
                    calculateLiveTravelTime()
                }
            }
            .sheet(isPresented: $showingAddPlace) {
                AddPlaceSheet()
            }
            .onAppear {
                if let departure = departure {
                    label = departure.label
                    targetArrivalTime = departure.targetArrivalTime
                    prepDuration = departure.prepDuration
                    staticTravelTime = departure.staticTravelTime
                    
                    // Load origin
                    originName = departure.originName
                    originAddress = departure.originAddress
                    if let lat = departure.originLat, let long = departure.originLong {
                        originCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                    }
                    
                    // Load destination
                    destinationName = departure.destinationName
                    destinationAddress = departure.destinationAddress
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
                    // New departure: snapshot current location by default (if available)
                    if locationManager.userLocation != nil {
                        snapshotCurrentLocation()
                    }
                    // If not available, the .onChange below will handle it
                }
            }
            .onChange(of: locationManager.isLoading) { wasLoading, isLoading in
                // Auto-snapshot for new departures when location request finishes
                if wasLoading && !isLoading,
                   departure == nil,
                   originCoordinate == nil,
                   locationManager.userLocation != nil {
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
            originName = originName ?? "Current Location"
            
            // Reverse geocode for Smart Subtitle
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)) { placemarks, error in
                if let placemark = placemarks?.first {
                    // Smart Title: The Address (e.g. 323 Lander Ave)
                    let streetNumber = placemark.subThoroughfare ?? ""
                    let streetName = placemark.thoroughfare ?? ""
                    let fullAddress = "\(streetNumber) \(streetName)".trimmingCharacters(in: .whitespaces)
                    
                    if !fullAddress.isEmpty {
                        originName = fullAddress
                    } else {
                        originName = placemark.name ?? "Current Location"
                    }
                    
                    // Smart Subtitle: City, State Zip (e.g. San Francisco, CA 94108)
                    let city = placemark.locality ?? ""
                    let state = placemark.administrativeArea ?? ""
                    let zip = placemark.postalCode ?? ""
                    
                    var parts: [String] = []
                    if !city.isEmpty { parts.append(city) }
                    if !state.isEmpty { parts.append(state) }
                    let locationStr = parts.joined(separator: ", ")
                    
                    if !locationStr.isEmpty && !zip.isEmpty {
                        originAddress = "\(locationStr) \(zip)"
                    } else if !locationStr.isEmpty {
                        originAddress = locationStr
                    } else {
                        // Fallback
                        let timeStr = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
                        originAddress = "Snapshot • \(timeStr)"
                    }
                    
                } else {
                    originName = "Current Location"
                    originAddress = "Snapshot: \(userLoc.latitude.formatted(.number.precision(.fractionLength(4)))), \(userLoc.longitude.formatted(.number.precision(.fractionLength(4))))"
                }
            }
            
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
            departure.originAddress = originAddress
            departure.originLat = originCoordinate?.latitude
            departure.originLong = originCoordinate?.longitude
            
            // Save destination
            departure.destinationName = destinationName
            departure.destinationAddress = destinationAddress
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
            newDeparture.originAddress = originAddress
            newDeparture.originLat = originCoordinate?.latitude
            newDeparture.originLong = originCoordinate?.longitude
            
            // Save destination
            newDeparture.destinationName = destinationName
            newDeparture.destinationAddress = destinationAddress
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
