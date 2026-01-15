import SwiftUI
import MapKit

/// The main "Mission Control" card - Map First Design
struct DepartureCardView: View {
    @Bindable var departure: Departure
    @Environment(LocationManager.self) private var locationManager
    
    @State private var currentTravelTime: TimeInterval?
    @State private var trafficStatus: TrafficStatus = .unknown
    
    // Debug / Info
    @State private var showingDebugInfo = false
    
    enum TrafficStatus {
        case clear, moderate, heavy, unknown
        
        var color: Color {
            switch self {
            case .clear: return .green
            case .moderate: return .yellow
            case .heavy: return .red
            case .unknown: return .secondary
            }
        }
        
        var icon: String {
            switch self {
            case .clear: return "checkmark.circle.fill"
            case .moderate: return "exclamationmark.circle.fill"
            case .heavy: return "exclamationmark.triangle.fill"
            case .unknown: return "questionmark.circle"
            }
        }
        
        var label: String {
            switch self {
            case .clear: return "Traffic Clear"
            case .moderate: return "Moderate Traffic"
            case .heavy: return "Heavy Traffic"
            case .unknown: return "Checking..."
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var transportModeType: MKDirectionsTransportType {
        switch departure.transportType {
        case "automobile": return .automobile
        case "walking": return .walking
        default: return .automobile
        }
    }
    
    private var originCoordinate: CLLocationCoordinate2D? {
        if let lat = departure.originLat, let lon = departure.originLong {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }
    
    private var destinationCoordinate: CLLocationCoordinate2D? {
        guard let lat = departure.destinationLat, let lon = departure.destinationLong else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    private var originDisplayName: String {
        departure.originName ?? "Origin"
    }
    
    private var destinationDisplayName: String {
        departure.destinationName ?? departure.label
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Map Hero (Top)
            ZStack(alignment: .bottomTrailing) {
                MapPreviewView(
                    originCoordinate: originCoordinate,
                    destinationCoordinate: destinationCoordinate,
                    transportType: transportModeType,
                    onTap: openInMaps
                )
                .frame(height: 220) // Taller hero map
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24))
                
                // Traffic Badge Overlay
                HStack(spacing: 4) {
                    Image(systemName: trafficStatus.icon)
                    Text(trafficStatus.label)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundStyle(trafficStatus.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .padding(12)
                
                // Debug / Info Button (Top Right)
                Button(action: { showingDebugInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(.regularMaterial, in: Circle())
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            
            // 2. Timeline Flow (Middle)
            VStack(spacing: 12) {
                // Compact Locations (Now at Top)
                CompactLocationFooterView(
                    originName: originDisplayName,
                    destinationName: destinationDisplayName
                )
                
                Divider()
                
                TimelineFlowView(
                    wakeTime: departure.wakeUpTime,
                    prepDuration: departure.prepDuration,
                    leaveTime: departure.departureTime,
                    travelTime: departure.effectiveTravelTime,
                    arrivalTime: departure.targetArrivalTime,
                    isHeavyTraffic: trafficStatus == .heavy,
                    alarmCount: departure.totalBarrageAlarms > 0 ? departure.totalBarrageAlarms : 1,
                    isBarrageEnabled: departure.isBarrageEnabled
                )
            }
            .padding(16)
            
            // 3. Alarm Status Footer (Bottom)
            AlarmStatusFooter(
                alarmCount: departure.totalBarrageAlarms > 0 ? departure.totalBarrageAlarms : 1,
                isBarrageEnabled: departure.isBarrageEnabled,
                isEnabled: $departure.isEnabled,
                targetTime: departure.targetArrivalTime,
                destinationName: destinationDisplayName
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .onChange(of: departure.isEnabled) { _, isEnabled in
            if isEnabled {
                NotificationManager.shared.scheduleNotifications(for: departure)
            } else {
                NotificationManager.shared.cancelNotifications(for: departure)
            }
        }
        .task {
            await refreshTravelTime()
        }
        .sheet(isPresented: $showingDebugInfo) {
            DebugInfoSheet(departure: departure)
        }
    }
    
    // MARK: - Actions
    
    private func openInMaps() {
        guard let destCoord = destinationCoordinate else { return }
        
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: destCoord))
        destination.name = destinationDisplayName
        
        var launchOptions: [String: Any] = [:]
        switch departure.transportType {
        case "automobile":
            launchOptions[MKLaunchOptionsDirectionsModeKey] = MKLaunchOptionsDirectionsModeDriving
        case "walking":
            launchOptions[MKLaunchOptionsDirectionsModeKey] = MKLaunchOptionsDirectionsModeWalking
        default:
            launchOptions[MKLaunchOptionsDirectionsModeKey] = MKLaunchOptionsDirectionsModeDriving
        }
        
        destination.openInMaps(launchOptions: launchOptions)
    }
    
    private func refreshTravelTime() async {
        guard let origin = originCoordinate, let dest = destinationCoordinate else { return }
        
        // Update local state and departure model
        let mode: TravelTimeService.TransportMode = {
            switch departure.transportType {
            case "automobile": return .automobile
            case "cycling": return .cycling
            case "walking": return .walking
            default: return .automobile
            }
        }()
        
        if let time = await TravelTimeService.calculateTravelTime(from: origin, to: dest, transportMode: mode) {
            currentTravelTime = time
            departure.liveTravelTime = time
            
            // Determine traffic status
            let ratio = time / departure.staticTravelTime
            if ratio < 1.1 {
                trafficStatus = .clear
            } else if ratio < 1.3 {
                trafficStatus = .moderate
            } else {
                trafficStatus = .heavy
            }
        } else {
            trafficStatus = .unknown
        }
    }
}

// MARK: - Debug Sheet
struct DebugInfoSheet: View {
    let departure: Departure
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Times") {
                    LabeledContent("Wake Up", value: departure.wakeUpTime.formatted(date: .omitted, time: .standard))
                    LabeledContent("Prep", value: TimeCalculator.formatDuration(departure.prepDuration))
                    LabeledContent("Leave", value: departure.departureTime.formatted(date: .omitted, time: .standard))
                    LabeledContent("Travel", value: TimeCalculator.formatDuration(departure.effectiveTravelTime))
                    LabeledContent("Arrive", value: departure.targetArrivalTime.formatted(date: .omitted, time: .standard))
                }
                
                Section("Settings") {
                    LabeledContent("Barrage Mode", value: departure.isBarrageEnabled ? "On" : "Off")
                    if departure.isBarrageEnabled {
                        LabeledContent("Pre-Wake Alarms", value: "\(departure.preWakeAlarms)")
                        LabeledContent("Post-Wake Alarms", value: "\(departure.postWakeAlarms)")
                        LabeledContent("Total Alarms", value: "\(departure.totalBarrageAlarms)")
                    }
                    LabeledContent("Origin", value: departure.originName ?? "Unknown")
                    LabeledContent("Destination", value: departure.destinationName ?? "Unknown")
                }
                
                Section("Actions") {
                    Button("Test Notification (5s)") {
                        scheduleTestNotification()
                    }
                }
            }
            .navigationTitle("Diagnostic Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
    
    private func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Alarm"
        content.body = "This is a test notification from Diagnostics."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}

#Preview {
    let departure = Departure(
        label: "Gym",
        targetArrivalTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!,
        prepDuration: 2700, // 45m
        staticTravelTime: 2700 // 45m
    )
    departure.destinationLat = 37.8044
    departure.destinationLong = -122.2712
    departure.destinationName = "Club One"
    departure.originName = "Home"
    departure.isBarrageEnabled = true
    departure.preWakeAlarms = 2
    departure.postWakeAlarms = 3
    
    return DepartureCardView(departure: departure)
        .padding()
        .background(Color(.systemGroupedBackground))
        .environment(LocationManager())
}
