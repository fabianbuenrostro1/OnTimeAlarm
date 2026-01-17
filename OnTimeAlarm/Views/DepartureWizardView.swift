import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct DepartureWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationManager.self) private var locationManager

    let departure: Departure?
    
    init(departure: Departure? = nil) {
        self.departure = departure
    }
    
    // MARK: - State
    @State private var label: String = ""
    
    // Locations
    @State private var fromName: String = ""
    @State private var fromAddress: String?
    @State private var fromCoordinate: CLLocationCoordinate2D?

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
    
    // Alarm Settings
    @State private var hasPreWakeAlarm: Bool = true
    
    // Repeat Days (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
    @State private var repeatDays: Set<Int> = []
    
    // Sheets
    @State private var showingAlarmSettings: Bool = false
    @State private var showingRepeatSelection: Bool = false
    @State private var showingPrepSelection: Bool = false
    @State private var showingTimePicker: Bool = false
    
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
        toCoordinate != nil && fromCoordinate != nil
    }
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }
    
    private var repeatSummary: String {
        if repeatDays.isEmpty {
            return "Just once"
        } else if repeatDays.count == 7 {
            return "Every day"
        } else if repeatDays == [1, 7] {
            return "Weekends"
        } else if repeatDays == [2, 3, 4, 5, 6] {
            return "Weekdays"
        } else {
            let calendar = Calendar.current
            let weekdays = calendar.shortWeekdaySymbols
            let sortedDays = repeatDays.sorted().map { weekdays[$0 - 1] }
            return sortedDays.joined(separator: ", ")
        }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    madLibsSection

                    alarmSentenceSection
                    
                    Spacer(minLength: 100)
                }
            }
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
            .sheet(isPresented: $showingAlarmSettings) {
                AlarmSettingsSheet(hasPreWakeAlarm: $hasPreWakeAlarm)
            }
            .sheet(isPresented: $showingRepeatSelection) {
                repeatSettingsSheet
                .presentationDetents([.fraction(0.3)])
            }
            .sheet(isPresented: $showingPrepSelection) {
                prepSettingsSheet
                .presentationDetents([.fraction(0.5)])
            }
            .sheet(isPresented: $showingTimePicker) {
                timePickerSheet
                .presentationDetents([.fraction(0.4)])
            }
            .onChange(of: fromCoordinate?.latitude) { _, _ in
                calculateTravelTime()
            }
            .onChange(of: toCoordinate?.latitude) { _, _ in
                calculateTravelTime()
            }
            .onChange(of: transportMode) { _, _ in
                calculateTravelTime()
            }
            .onAppear {
                loadExistingDeparture()
            }
        }
    }
    
    // MARK: - Mad Libs Section
    @ViewBuilder
    private var madLibsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Label/title field - pill style input
            TextField("This trip is for...", text: $label)
                .font(.title2)
                .fontWeight(.semibold)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("I need to")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Transport mode picker - chip style
            HStack(spacing: 12) {
                Image(systemName: transportMode.icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32)

                HStack(spacing: 0) {
                    ForEach(TravelTimeService.TransportMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.snappy) { transportMode = mode }
                        } label: {
                            Text(mode.rawValue)
                                .font(.subheadline.weight(transportMode == mode ? .semibold : .regular))
                                .foregroundStyle(transportMode == mode ? .white : .primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(transportMode == mode ? Color.blue : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("from")
                .font(.title3)
                .foregroundStyle(.secondary)

            InlineLocationField(
                coordinate: $fromCoordinate,
                locationName: $fromName,
                locationAddress: $fromAddress,
                placeholder: "Starting location",
                icon: "circle.fill",
                iconColor: .blue,
                showUseMyLocation: true
            )
            .zIndex(2) // Ensure dropdown appears above other content

            Text("to")
                .font(.title3)
                .foregroundStyle(.secondary)

            InlineLocationField(
                coordinate: $toCoordinate,
                locationName: Binding(
                    get: { toName ?? "" },
                    set: { toName = $0.isEmpty ? nil : $0 }
                ),
                locationAddress: $toAddress,
                placeholder: "Destination location",
                icon: "circle.fill",
                iconColor: .red
            )
            .zIndex(1) // Ensure dropdown appears above other content
            .onChange(of: toName) { _, newValue in
                if let name = newValue, label.isEmpty {
                    label = name
                }
            }
            
            Text("arriving")
                .font(.title3)
                .foregroundStyle(.secondary)

            chipButton(
                icon: "clock.fill",
                iconColor: .orange,
                title: timeFormatter.string(from: arrivalTime),
                action: { showingTimePicker = true }
            )

            Text("repeating")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            chipButton(
                icon: "repeat",
                iconColor: repeatDays.isEmpty ? .gray : .orange,
                title: repeatSummary,
                action: { showingRepeatSelection = true }
            )
            
            Text("with")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            chipButton(
                icon: "clock.badge.checkmark.fill",
                iconColor: .orange,
                title: "\(Int(prepDuration / 60)) min to get ready",
                action: { showingPrepSelection = true }
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    @ViewBuilder
    private var repeatSettingsSheet: some View {
        VStack(spacing: 24) {
            Text("Repeat")
                .font(.headline)
                .padding(.top, 24)
            
            repeatDaysStrip
            
            Spacer()
            
            Button("Done") {
                showingRepeatSelection = false
            }
            .font(.headline)
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    @ViewBuilder
    private var prepSettingsSheet: some View {
        VStack(spacing: 24) {
            Text("Prep Time")
                .font(.headline)
                .padding(.top, 24)

            prepDurationBubbles

            Spacer()

            Button("Done") {
                showingPrepSelection = false
            }
            .font(.headline)
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    @ViewBuilder
    private var timePickerSheet: some View {
        VStack(spacing: 24) {
            Text("Arrival Time")
                .font(.headline)
                .padding(.top, 24)

            DatePicker(
                "",
                selection: $arrivalTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()

            Spacer()

            Button("Done") {
                showingTimePicker = false
            }
            .font(.headline)
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    @ViewBuilder
    private var prepDurationBubbles: some View {
        let steps = Array(stride(from: 10, through: 60, by: 5)) + [75, 90]
        
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 50), spacing: 12)], spacing: 12) {
            ForEach(steps, id: \.self) { minutes in
                let duration = TimeInterval(minutes * 60)
                let isSelected = prepDuration == duration
                
                Button {
                    withAnimation(.snappy) {
                        prepDuration = duration
                    }
                } label: {
                    Text("\(minutes)")
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .frame(width: 48, height: 48)
                        .background(isSelected ? Color.orange : Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private var prepDurationRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("I need")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text("\(Int(prepDuration / 60)) min")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text("to get ready")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 10 to 60 in steps of 5, then 75 and 90
                    let steps = Array(stride(from: 10, through: 60, by: 5)) + [75, 90]
                    
                    ForEach(steps, id: \.self) { minutes in
                        let duration = TimeInterval(minutes * 60)
                        let isSelected = prepDuration == duration
                        
                        Button {
                            withAnimation(.snappy) {
                                prepDuration = duration
                            }
                        } label: {
                            Text("\(minutes)")
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .frame(width: 44, height: 44)
                                .background(isSelected ? Color.orange : Color(.systemGray6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    @ViewBuilder
    private var repeatDaysStrip: some View {
        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
        
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                let isSelected = repeatDays.contains(day)
                
                Button {
                    withAnimation(.snappy) {
                        if isSelected {
                            repeatDays.remove(day)
                        } else {
                            repeatDays.insert(day)
                        }
                    }
                } label: {
                    Text(dayLabels[day - 1])
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .frame(width: 40, height: 40)
                        .background(isSelected ? Color.orange : Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
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
                icon: hasPreWakeAlarm ? "bell.badge" : "bell.fill",
                iconColor: .orange,
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
        if hasPreWakeAlarm {
            return "3 alarms with snooze"
        } else {
            return "2 alarms with snooze"
        }
    }

    private var alarmSummarySubtitle: String? {
        if hasPreWakeAlarm {
            return "Pre-wake, wake up, and leave"
        } else {
            return "Wake up and leave"
        }
    }
    
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
    
    // MARK: - Logic
    
    private func loadExistingDeparture() {
        guard let departure = departure else { return }

        label = departure.label
        arrivalTime = departure.targetArrivalTime
        prepDuration = departure.prepDuration
        travelTime = departure.staticTravelTime

        hasPreWakeAlarm = departure.hasPreWakeAlarm

        // Load transport mode
        if let mode = TravelTimeService.TransportMode.allCases.first(where: { $0.rawValue == departure.transportType }) {
            transportMode = mode
        }

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
            if let lat = departure.originLat, let lon = departure.originLong {
                fromCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
    }
    
    private func calculateTravelTime() {
        guard let to = toCoordinate, let from = fromCoordinate else { return }
        
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
        
        print("----- DEBUG: SAVING DEPARTURE -----")
        dump(dep)
        print("-----------------------------------")
        
        dep.label = label.isEmpty ? (toName ?? "Alarm") : label
        dep.targetArrivalTime = arrivalTime
        dep.prepDuration = prepDuration
        dep.staticTravelTime = travelTime
        
        dep.destinationName = toName
        dep.destinationAddress = toAddress
        dep.destinationLat = toCoordinate?.latitude
        dep.destinationLong = toCoordinate?.longitude

        dep.originName = fromName
        dep.originAddress = fromAddress
        dep.originLat = fromCoordinate?.latitude
        dep.originLong = fromCoordinate?.longitude

        dep.hasPreWakeAlarm = hasPreWakeAlarm
        dep.transportType = transportMode.rawValue

        // Schedule alarms with AlarmKit
        Task {
            do {
                try await AlarmKitManager.shared.scheduleAlarms(for: dep)
            } catch {
                print("Failed to schedule alarms: \(error)")
            }
        }

        dismiss()
    }
}

#Preview {
    DepartureWizardView()
        .environment(LocationManager())
}
