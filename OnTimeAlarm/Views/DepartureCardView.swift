import SwiftUI
import MapKit

/// The main "Mission Control" card showing chronological timeline
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
            // 1. Header (Arrive By + Toggle)
            TimelineHeaderView(
                targetTime: departure.targetArrivalTime,
                isEnabled: $departure.isEnabled
            )
            .padding(16)
            
            Divider()
                .padding(.horizontal, 16)
            
            // 2. Timeline Flow (Wake -> Prep -> Leave)
            TimelineFlowView(
                wakeTime: departure.wakeUpTime,
                prepDuration: departure.prepDuration,
                leaveTime: departure.departureTime,
                travelTime: departure.effectiveTravelTime,
                arrivalTime: departure.targetArrivalTime,
                isHeavyTraffic: trafficStatus == .heavy
            )
            .padding(16)
            
            // 3. Map Preview
            MapPreviewView(
                originCoordinate: originCoordinate,
                destinationCoordinate: destinationCoordinate,
                transportType: transportModeType,
                onTap: openInMaps
            )
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // 4. Footer (Locations + Traffic)
            CompactLocationFooterView(
                originName: originDisplayName,
                destinationName: destinationDisplayName,
                trafficStatus: trafficStatus
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
    
    return DepartureCardView(departure: departure)
        .padding()
        .background(Color(.systemGroupedBackground))
        .environment(LocationManager())
}
