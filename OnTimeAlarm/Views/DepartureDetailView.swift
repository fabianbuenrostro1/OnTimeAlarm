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

    // MARK: - Computed Properties

    private var transportModeType: MKDirectionsTransportType {
        switch departure.transportType {
        case "automobile", "Drive": return .automobile
        case "walking", "Walk": return .walking
        default: return .automobile
        }
    }

    private var transportModeIcon: String {
        switch departure.transportType {
        case "automobile", "Drive": return "car.fill"
        case "cycling", "Bike": return "bicycle"
        case "walking", "Walk": return "figure.walk"
        default: return "car.fill"
        }
    }

    private var transportModeLabel: String {
        switch departure.transportType {
        case "automobile", "Drive": return "Drive"
        case "cycling", "Bike": return "Bike"
        case "walking", "Walk": return "Walk"
        default: return "Drive"
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
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Layer 1: Full-bleed map background
                VStack(spacing: 0) {
                    MapPreviewView(
                        originCoordinate: originCoordinate,
                        destinationCoordinate: destinationCoordinate,
                        transportType: transportModeType,
                        onTap: openInMaps,
                        showOpenMapsHint: false
                    )
                    .frame(height: geometry.size.height * 0.50)

                    Spacer()
                }
                .ignoresSafeArea(edges: .top)

                // Layer 2: Scrollable floating card
                ScrollView {
                    VStack(spacing: 0) {
                        // Spacer to push card below map
                        Color.clear
                            .frame(height: geometry.size.height * 0.28)

                        // Floating Card
                        VStack(spacing: 0) {
                            // Drag indicator
                            Capsule()
                                .fill(Color(.systemGray4))
                                .frame(width: 36, height: 5)
                                .padding(.top, 8)
                                .padding(.bottom, 12)

                            // Card Content
                            VStack(spacing: 12) {
                                // Card Header: Title + Toggle
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(departure.label)
                                            .font(.title2)
                                            .fontWeight(.bold)

                                        HStack(spacing: 4) {
                                            Image(systemName: transportModeIcon)
                                                .font(.caption)
                                            Text(transportModeLabel)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $departure.isEnabled)
                                        .labelsHidden()
                                        .tint(departure.isBarrageEnabled ? .orange : .green)
                                }

                                Divider()

                                // Route Section
                                VStack(alignment: .leading, spacing: 8) {
                                    sectionHeader("Route")
                                    CompactLocationFooterView(
                                        originName: originDisplayName,
                                        destinationName: destinationDisplayName
                                    )
                                }

                                Divider()

                                // Schedule Section
                                VStack(alignment: .leading, spacing: 8) {
                                    sectionHeader("Schedule")
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
                                        barrageInterval: departure.barrageInterval,
                                        trafficStatus: trafficStatus
                                    )
                                }

                                // Action Button
                                Button {
                                    openInMaps()
                                } label: {
                                    Label("Open in Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .tint(.blue)
                                .padding(.top, 8)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        }
                        .background(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 24,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 24
                            )
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.15), radius: 12, y: -4)
                        )
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "pencil")
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

    // MARK: - Helper Views

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
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
