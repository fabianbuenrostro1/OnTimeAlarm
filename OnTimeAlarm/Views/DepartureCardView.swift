import SwiftUI
import MapKit

/// The main "Mission Control" card showing map, from/to, and timing
struct DepartureCardView: View {
    @Bindable var departure: Departure
    @Environment(LocationManager.self) private var locationManager
    
    @State private var currentTravelTime: TimeInterval?
    @State private var trafficStatus: TrafficStatus = .unknown
    
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
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var transportModeType: MKDirectionsTransportType {
        switch departure.transportType {
        case "automobile": return .automobile
        case "walking": return .walking
        default: return .automobile
        }
    }
    
    private var transportIcon: String {
        switch departure.transportType {
        case "automobile": return "car.fill"
        case "cycling": return "bicycle"
        case "walking": return "figure.walk"
        default: return "car.fill"
        }
    }
    
    /// Origin coordinate: fixed address from snapshot
    private var originCoordinate: CLLocationCoordinate2D? {
        if let lat = departure.originLat, let lon = departure.originLong {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }
    
    /// Destination coordinate
    private var destinationCoordinate: CLLocationCoordinate2D? {
        guard let lat = departure.destinationLat, let lon = departure.destinationLong else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// Origin display name
    private var originDisplayName: String {
        departure.originName ?? "Origin"
    }
    
    /// Destination display name
    private var destinationDisplayName: String {
        departure.destinationName ?? departure.label
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with status
            headerSection
            
            // Map Preview
            MapPreviewView(
                originCoordinate: originCoordinate,
                destinationCoordinate: destinationCoordinate,
                transportType: transportModeType,
                onTap: openInMaps
            )
            .frame(height: 180)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // From / To Section
            fromToSection
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Timing Section
            timingSection
                .padding(16)
            
            // Alarm Toggle
            alarmToggle
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .task {
            await refreshTravelTime()
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT DEPARTURE")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(departure.label)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // Traffic status badge
            HStack(spacing: 4) {
                Image(systemName: trafficStatus.icon)
                Text(trafficStatus.label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(trafficStatus.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(trafficStatus.color.opacity(0.15), in: Capsule())
        }
        .padding(16)
    }
    
    private var fromToSection: some View {
        VStack(spacing: 8) {
            // FROM
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.blue)
                        .frame(width: 28, height: 28)
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("FROM")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(originDisplayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                if departure.originName == "Current Location" {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            // Connector line
            HStack {
                Rectangle()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 2, height: 16)
                    .padding(.leading, 13)
                Spacer()
            }
            
            // TO
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TO")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(destinationDisplayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
        }
    }
    
    private var timingSection: some View {
        HStack {
            // Leave At
            VStack(spacing: 4) {
                Text("LEAVE AT")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(timeFormatter.string(from: departure.departureTime))
                    .font(.title)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Arrow with travel info
            VStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: transportIcon)
                        .font(.caption)
                    Text(TimeCalculator.formatDuration(departure.effectiveTravelTime))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Arrive By
            VStack(spacing: 4) {
                Text("ARRIVE BY")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(timeFormatter.string(from: departure.targetArrivalTime))
                    .font(.title)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        }
    }
    
    private var alarmToggle: some View {
        Toggle(isOn: $departure.isEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Alarm")
                    .font(.headline)
                Text(departure.isEnabled ? "Monitoring traffic" : "Off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.green)
        .padding(.vertical, 4)
        .onChange(of: departure.isEnabled) { _, isEnabled in
            if isEnabled {
                NotificationManager.shared.scheduleNotifications(for: departure)
            } else {
                NotificationManager.shared.cancelNotifications(for: departure)
            }
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
            
            // Determine traffic status by comparing to static time
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

#Preview {
    let departure = Departure(
        label: "Brenda Athletic Clubs",
        targetArrivalTime: Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date())!,
        prepDuration: 900,
        staticTravelTime: 1320
    )
    departure.destinationLat = 37.8044
    departure.destinationLong = -122.2712
    departure.destinationName = "Brenda Athletic Clubs"
    
    return DepartureCardView(departure: departure)
        .padding()
        .background(Color(.systemGroupedBackground))
        .environment(LocationManager())
}
