import SwiftUI
import MapKit

/// Full-screen detail view for a departure - shows map, timeline, and controls
struct DepartureDetailView: View {
    @Bindable var departure: Departure
    @Environment(LocationManager.self) private var locationManager
    @Environment(\.modelContext) private var modelContext

    @State private var showingEditor = false
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
        ScrollView {
            VStack(spacing: 0) {
                // 1. Map Hero (Full Width)
                ZStack(alignment: .topLeading) {
                    MapPreviewView(
                        originCoordinate: originCoordinate,
                        destinationCoordinate: destinationCoordinate,
                        transportType: transportModeType,
                        onTap: openInMaps
                    )
                    .frame(height: 260)

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
                }

                // 2. Content Section
                VStack(spacing: 12) {
                    // Location Bar
                    CompactLocationFooterView(
                        originName: originDisplayName,
                        destinationName: destinationDisplayName
                    )

                    Divider()

                    // 3. Timeline Flow
                    TimelineFlowView(
                        wakeTime: departure.wakeUpTime,
                        prepDuration: departure.prepDuration,
                        leaveTime: departure.departureTime,
                        travelTime: departure.effectiveTravelTime,
                        arrivalTime: departure.targetArrivalTime,
                        isHeavyTraffic: trafficStatus == .heavy,
                        alarmCount: departure.totalBarrageAlarms > 0 ? departure.totalBarrageAlarms : 1,
                        isBarrageEnabled: departure.isBarrageEnabled,
                        preWakeAlarms: departure.preWakeAlarms,
                        postWakeAlarms: departure.postWakeAlarms,
                        barrageInterval: departure.barrageInterval
                    )
                }
                .padding(16)
                .background(Color(.systemBackground))

                Spacer(minLength: 20)

                // 4. Footer with Toggle
                AlarmStatusFooter(
                    alarmCount: departure.totalBarrageAlarms > 0 ? departure.totalBarrageAlarms : 1,
                    isBarrageEnabled: departure.isBarrageEnabled,
                    isEnabled: $departure.isEnabled,
                    targetTime: departure.targetArrivalTime,
                    destinationName: destinationDisplayName,
                    preWakeAlarms: departure.preWakeAlarms,
                    postWakeAlarms: departure.postWakeAlarms
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(departure.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditor = true
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            DepartureWizardView(departure: departure)
        }
        .task {
            await refreshTravelTime()
        }
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
        label: "Work",
        targetArrivalTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!,
        prepDuration: 2700,
        staticTravelTime: 1800
    )
    departure.destinationLat = 37.8044
    departure.destinationLong = -122.2712
    departure.destinationName = "Office"
    departure.originName = "Home"
    departure.isBarrageEnabled = true
    departure.preWakeAlarms = 2
    departure.postWakeAlarms = 3

    return NavigationStack {
        DepartureDetailView(departure: departure)
    }
    .environment(LocationManager())
}
