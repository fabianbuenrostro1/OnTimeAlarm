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

    private var contextualTimingPhrase: String {
        let calendar = Calendar.current
        let alertTime = departure.wakeUpTime

        // Day relationship
        let dayPhrase: String
        if calendar.isDateInToday(alertTime) {
            dayPhrase = "This"
        } else if calendar.isDateInTomorrow(alertTime) {
            dayPhrase = "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            dayPhrase = formatter.string(from: alertTime)
        }

        // Time of day based on alert hour
        let hour = calendar.component(.hour, from: alertTime)
        let timeOfDay: String
        switch hour {
        case 0..<6:   timeOfDay = "night"
        case 6..<12:  timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<21: timeOfDay = "evening"
        default:      timeOfDay = "night"
        }

        return "\(dayPhrase) \(timeOfDay)"
    }

    private var transportVerb: String {
        switch departure.transportType {
        case "automobile", "Drive": return "drive"
        case "cycling", "Bike": return "bike"
        case "walking", "Walk": return "walk"
        default: return "travel"
        }
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Contextual timing phrase
                Text(contextualTimingPhrase)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                // Alert time
                narrativeBlock(
                    phrase: "you'll be alerted at",
                    emphasis: timeFormatter.string(from: departure.wakeUpTime),
                    isTime: true
                )

                // Prep duration
                Text("with \(TimeCalculator.formatDurationReadable(departure.prepDuration)) to get ready")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Leave time
                narrativeBlock(
                    phrase: "then leave by",
                    emphasis: timeFormatter.string(from: departure.departureTime),
                    isTime: true
                )

                // Destination
                narrativeBlock(
                    phrase: "to \(transportVerb) to",
                    emphasis: destinationDisplayName
                )

                // Arrival time
                narrativeBlock(
                    phrase: "and arrive by",
                    emphasis: timeFormatter.string(from: departure.targetArrivalTime),
                    isTime: true
                )

                // Map Preview (smaller, supporting role)
                MapPreviewView(
                    originCoordinate: originCoordinate,
                    destinationCoordinate: destinationCoordinate,
                    transportType: transportModeType,
                    onTap: openInMaps,
                    showOpenMapsHint: false
                )
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Open in Maps button
                Button {
                    openInMaps()
                } label: {
                    Label("Open in Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .navigationTitle(departure.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Toggle("", isOn: $departure.isEnabled)
                        .labelsHidden()
                        .tint(.orange)

                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "pencil")
                    }
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
            Task {
                if isEnabled {
                    try? await AlarmKitManager.shared.scheduleAlarms(for: departure)
                } else {
                    await AlarmKitManager.shared.cancelAlarms(for: departure)
                }
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func narrativeBlock(phrase: String, emphasis: String, isTime: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(phrase)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isTime {
                Text(emphasis)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            } else {
                Text(emphasis)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
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

        // Use stored origin if available and not "Current Location", otherwise use device's current location
        if let originCoord = originCoordinate,
           departure.originName != "Current Location" {
            let origin = MKMapItem(placemark: MKPlacemark(coordinate: originCoord))
            origin.name = originDisplayName
            MKMapItem.openMaps(with: [origin, destination], launchOptions: launchOptions)
        } else {
            MKMapItem.openMaps(with: [MKMapItem.forCurrentLocation(), destination], launchOptions: launchOptions)
        }
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
    departure.hasPreWakeAlarm = true

    return NavigationStack {
        DepartureDetailView(departure: departure)
    }
    .environment(LocationManager())
}
