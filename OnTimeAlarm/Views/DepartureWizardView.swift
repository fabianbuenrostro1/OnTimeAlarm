import SwiftUI
import SwiftData
import MapKit
import CoreLocation

enum WizardSearchType {
    case origin
    case destination
}

struct DepartureWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationManager.self) private var locationManager
    
    @Query private var savedPlaces: [SavedPlace]
    
    let departure: Departure?
    
    init(departure: Departure? = nil) {
        self.departure = departure
    }
    
    // MARK: - State
    @State private var label: String = ""
    
    // Locations
    @State private var fromName: String = "Current Location"
    @State private var fromAddress: String?
    @State private var fromCoordinate: CLLocationCoordinate2D?
    @State private var isUsingCurrentLocation: Bool = true
    
    @State private var toName: String?
    @State private var toAddress: String?
    @State private var toCoordinate: CLLocationCoordinate2D?
    
    // Timing
    @State private var arrivalTime: Date = {
        // Default to tomorrow at 9 AM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day! += 1
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components) ?? Date()
    }()
    
    @State private var prepDuration: TimeInterval = 1800 // 30 min default
    
    // Travel
    @State private var travelTime: TimeInterval = 0
    @State private var transportMode: TravelTimeService.TransportMode = .automobile
    @State private var isLoadingTravel: Bool = false
    
    // Barrage Mode
    @State private var isBarrageEnabled: Bool = true
    @State private var preWakeAlarms: Int = 2
    @State private var postWakeAlarms: Int = 5
    @State private var barrageInterval: TimeInterval = 120
    
    // Sheets
    @State private var showingFromPicker: Bool = false
    @State private var showingToPicker: Bool = false
    @State private var showingTimePicker: Bool = false
    @State private var showingLocationSearch: Bool = false
    @State private var showingAlarmSettings: Bool = false
    @State private var activeSearchType: WizardSearchType = .destination
    
    private var isEditing: Bool { departure != nil }
    
    // MARK: - Calculations
    private var wakeUpTime: Date {
        TimeCalculator.wakeUpTime(
            arrivalTime: arrivalTime,
            prepDuration: prepDuration,
            travelTime: travelTime
        )
    }
    
    private var leaveTime: Date {
        TimeCalculator.departureTime(
            arrivalTime: arrivalTime,
            travelTime: travelTime
        )
    }
    
    private var canSave: Bool {
        toCoordinate != nil && (fromCoordinate != nil || isUsingCurrentLocation)
    }
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    madLibsSection
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    resultHeroSection
                    
                    alarmSentenceSection
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle(isEditing ? "Edit Alarm" : "New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingFromPicker) {
                fromPickerSheet
            }
            .sheet(isPresented: $showingToPicker) {
                toPickerSheet
            }
            .sheet(isPresented: $showingTimePicker) {
                timePickerSheet
            }
            .sheet(isPresented: $showingLocationSearch) {
                LocationSearchSheet { coordinate, name, address in
                    switch activeSearchType {
                    case .origin:
                        isUsingCurrentLocation = false
                        fromName = name
                        fromAddress = address
                        fromCoordinate = coordinate
                    case .destination:
                        toName = name
                        toAddress = address
                        toCoordinate = coordinate
                        if label.isEmpty {
                            label = name
                        }
                    }
                    calculateTravelTime()
                }
            }
            .sheet(isPresented: $showingAlarmSettings) {
                AlarmSettingsSheet(
                    isBarrageEnabled: $isBarrageEnabled,
                    preWakeAlarms: $preWakeAlarms,
                    postWakeAlarms: $postWakeAlarms,
                    barrageInterval: $barrageInterval
                )
            }
            .onChange(of: toName) { _, _ in
                calculateTravelTime()
            }
            .onChange(of: fromName) { _, _ in
                calculateTravelTime()
            }
            .onChange(of: transportMode) { _, _ in
                calculateTravelTime()
            }
            .onAppear {
                loadExistingDeparture()
                setupCurrentLocation()
            }
        }
    }
    
    // MARK: - Mad Libs Section
    @ViewBuilder
    private var madLibsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("I need to get from")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            chipButton(
                icon: isUsingCurrentLocation ? "location.fill" : "mappin.circle.fill",
                iconColor: .blue,
                title: fromName,
                subtitle: fromAddress,
                action: { showingFromPicker = true }
            )
            
            Text("to")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            chipButton(
                icon: "mappin.circle.fill",
                iconColor: toCoordinate != nil ? .red : .gray,
                title: toName ?? "Choose destination",
                subtitle: toAddress,
                isPlaceholder: toCoordinate == nil,
                action: { showingToPicker = true }
            )
            
            Text("by")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            chipButton(
                icon: "clock.fill",
                iconColor: .orange,
                title: timeFormatter.string(from: arrivalTime),
                subtitle: formattedDate(arrivalTime),
                action: { showingTimePicker = true }
            )
            
            prepDurationRow
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    @ViewBuilder
    private var prepDurationRow: some View {
        HStack(spacing: 8) {
            Text("I need")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Picker("", selection: $prepDuration) {
                Text("15").tag(TimeInterval(900))
                Text("30").tag(TimeInterval(1800))
                Text("45").tag(TimeInterval(2700))
                Text("60").tag(TimeInterval(3600))
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            
            Text("min to get ready")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Result Hero Section
    @ViewBuilder
    private var resultHeroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Wake Up")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(timeFormatter.string(from: wakeUpTime))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
            }
            
            HStack(spacing: 20) {
                resultItem(label: "Leave", time: leaveTime, color: .orange)
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)
                
                resultItem(label: "Arrive", time: arrivalTime, color: .green)
            }
            
            travelTimeLabel
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var travelTimeLabel: some View {
        if travelTime > 0 {
            Text("\(Int(travelTime / 60)) min \(transportModeLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
        } else if isLoadingTravel {
            ProgressView()
                .scaleEffect(0.8)
        }
    }
    
    // MARK: - Alarm Sentence Section
    @ViewBuilder
    private var alarmSentenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("And I need")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            chipButton(
                icon: isBarrageEnabled ? "bell.badge.waveform.fill" : "bell.fill",
                iconColor: isBarrageEnabled ? .orange : .gray,
                title: alarmSummaryTitle,
                subtitle: alarmSummarySubtitle,
                action: { showingAlarmSettings = true }
            )
            
            Text("to ensure I'm up.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    private var alarmSummaryTitle: String {
        if isBarrageEnabled {
            if preWakeAlarms > 0 && postWakeAlarms > 0 {
                return "\(preWakeAlarms) alarms before & \(postWakeAlarms) after"
            } else if preWakeAlarms > 0 {
                return "\(preWakeAlarms) alarms before wake up"
            } else if postWakeAlarms > 0 {
                return "\(postWakeAlarms) safety alarms after"
            } else {
                return "Multiple alarms"
            }
        } else {
            return "Just one alarm"
        }
    }
    
    private var alarmSummarySubtitle: String? {
        if isBarrageEnabled {
            return "Active at wake up"
        } else {
            return "Standard mode"
        }
    }
    
    // MARK: - Chip Button
    @ViewBuilder
    private func chipButton(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        isPlaceholder: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isPlaceholder ? .secondary : .primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Result Item
    @ViewBuilder
    private func resultItem(label: String, time: Date, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(timeFormatter.string(from: time))
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
        }
    }
    
    private var transportModeLabel: String {
        switch transportMode {
        case .automobile: return "driving"
        case .walking: return "walking"
        case .cycling: return "biking"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    // MARK: - Sheets
    @ViewBuilder
    private var fromPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isUsingCurrentLocation = true
                        fromName = "Current Location"
                        fromAddress = nil
                        fromCoordinate = locationManager.userLocation
                        showingFromPicker = false
                    } label: {
                        Label("Current Location", systemImage: "location.fill")
                    }
                }
                
                if !savedPlaces.isEmpty {
                    Section("Saved Places") {
                        ForEach(savedPlaces) { place in
                            Button {
                                isUsingCurrentLocation = false
                                fromName = place.name
                                fromAddress = place.address
                                fromCoordinate = place.coordinate
                                showingFromPicker = false
                            } label: {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text(place.name)
                                        Text(place.address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Text(place.icon)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        showingFromPicker = false
                        activeSearchType = .origin
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingLocationSearch = true
                        }
                    } label: {
                        Label("Search for a location", systemImage: "magnifyingglass")
                    }
                }
            }
            .navigationTitle("From")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingFromPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    @ViewBuilder
    private var toPickerSheet: some View {
        NavigationStack {
            List {
                if !savedPlaces.isEmpty {
                    Section("Saved Places") {
                        ForEach(savedPlaces) { place in
                            Button {
                                toName = place.name
                                toAddress = place.address
                                toCoordinate = place.coordinate
                                if label.isEmpty {
                                    label = place.name
                                }
                                showingToPicker = false
                            } label: {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text(place.name)
                                        Text(place.address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Text(place.icon)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        showingToPicker = false
                        activeSearchType = .destination
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingLocationSearch = true
                        }
                    } label: {
                        Label("Search for a location", systemImage: "magnifyingglass")
                    }
                }
            }
            .navigationTitle("To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingToPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    @ViewBuilder
    private var timePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Arrival Time",
                    selection: $arrivalTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Arrive By")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingTimePicker = false }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Logic
    private func setupCurrentLocation() {
        if isUsingCurrentLocation {
            fromCoordinate = locationManager.userLocation
        }
    }
    
    private func loadExistingDeparture() {
        guard let departure = departure else { return }
        
        label = departure.label
        arrivalTime = departure.targetArrivalTime
        prepDuration = departure.prepDuration
        travelTime = departure.staticTravelTime
        
        isBarrageEnabled = departure.isBarrageEnabled
        preWakeAlarms = departure.preWakeAlarms
        postWakeAlarms = departure.postWakeAlarms
        barrageInterval = departure.barrageInterval
        
        if let destName = departure.destinationName {
            toName = destName
            toAddress = departure.destinationAddress
            if let lat = departure.destinationLat, let lon = departure.destinationLong {
                toCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        
        if let originName = departure.originName {
            fromName = originName
            fromAddress = departure.originAddress
            isUsingCurrentLocation = false
            if let lat = departure.originLat, let lon = departure.originLong {
                fromCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
    }
    
    private func calculateTravelTime() {
        guard let to = toCoordinate else { return }
        
        let from: CLLocationCoordinate2D
        if isUsingCurrentLocation {
            guard let current = locationManager.userLocation else { return }
            from = current
        } else {
            guard let origin = fromCoordinate else { return }
            from = origin
        }
        
        // Guard against same origin/destination
        if abs(from.latitude - to.latitude) < 0.0001 && abs(from.longitude - to.longitude) < 0.0001 {
            travelTime = 0
            return
        }
        
        isLoadingTravel = true
        
        Task {
            if let time = await TravelTimeService.calculateTravelTime(
                from: from,
                to: to,
                transportMode: transportMode
            ) {
                await MainActor.run {
                    isLoadingTravel = false
                    travelTime = time
                }
            } else {
                await MainActor.run {
                    isLoadingTravel = false
                    travelTime = 1200 // 20 min fallback
                }
            }
        }
    }
    
    private func save() {
        let dep = departure ?? Departure(
            label: label.isEmpty ? (toName ?? "Alarm") : label,
            targetArrivalTime: arrivalTime,
            prepDuration: prepDuration,
            staticTravelTime: travelTime
        )
        
        if departure == nil {
            modelContext.insert(dep)
        }
        
        dep.label = label.isEmpty ? (toName ?? "Alarm") : label
        dep.targetArrivalTime = arrivalTime
        dep.prepDuration = prepDuration
        dep.staticTravelTime = travelTime
        
        dep.destinationName = toName
        dep.destinationAddress = toAddress
        dep.destinationLat = toCoordinate?.latitude
        dep.destinationLong = toCoordinate?.longitude
        
        if isUsingCurrentLocation {
            dep.originName = "Current Location"
            dep.originAddress = nil
            dep.originLat = fromCoordinate?.latitude
            dep.originLong = fromCoordinate?.longitude
        } else {
            dep.originName = fromName
            dep.originAddress = fromAddress
            dep.originLat = fromCoordinate?.latitude
            dep.originLong = fromCoordinate?.longitude
        }
        
        dep.isBarrageEnabled = isBarrageEnabled
        dep.preWakeAlarms = preWakeAlarms
        dep.postWakeAlarms = postWakeAlarms
        dep.barrageInterval = barrageInterval
        
        dismiss()
    }
}

#Preview {
    DepartureWizardView()
        .environment(LocationManager())
}
