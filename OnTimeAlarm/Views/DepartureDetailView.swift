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
    @State private var weatherInfo: WeatherService.WeatherInfo?
    @State private var isLoadingWeather: Bool = false
    @State private var weatherError: String?
    @State private var isEditingLabel = false
    @FocusState private var labelFieldFocused: Bool

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
            VStack(alignment: .leading, spacing: 24) {

                // Hero header with integrated toggle
                HStack(alignment: .center) {
                    if isEditingLabel {
                        TextField("Alarm", text: $departure.label)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .italic()
                            .textFieldStyle(.plain)
                            .focused($labelFieldFocused)
                            .onSubmit {
                                isEditingLabel = false
                            }
                            .onChange(of: labelFieldFocused) { _, focused in
                                if !focused {
                                    isEditingLabel = false
                                }
                            }
                    } else {
                        Text(departure.label.isEmpty ? "Alarm" : departure.label)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .italic()
                            .underline(color: .secondary.opacity(0.4))
                            .onTapGesture {
                                isEditingLabel = true
                                labelFieldFocused = true
                            }
                    }
                    Spacer()
                    Toggle("", isOn: $departure.isEnabled)
                        .labelsHidden()
                        .tint(.orange)
                }

                // Content group with grayscale when disabled
                Group {
                    // First paragraph - Wake up
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "bell.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("You'll wake up at \(timeFormatter.string(from: departure.wakeUpTime))")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("with \(TimeCalculator.formatDurationReadable(departure.prepDuration)) to get ready.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Second paragraph - Leave and arrive
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: transportModeIcon)
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Leave by \(timeFormatter.string(from: departure.departureTime))")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("to arrive at \(destinationDisplayName) by \(timeFormatter.string(from: departure.targetArrivalTime)).")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

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

                    // Weather paragraph
                    weatherParagraph

                    // Traffic paragraph
                    trafficParagraph

                    // Positivity paragraph
                    positivityParagraph

                    // Open in Maps button (moved to bottom)
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
                .saturation(departure.isEnabled ? 1.0 : 0.0)
                .opacity(departure.isEnabled ? 1.0 : 0.6)
                .animation(.easeInOut(duration: 0.3), value: departure.isEnabled)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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
            await refreshWeather()
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

    private func refreshWeather() async {
        guard let destCoord = destinationCoordinate else {
            weatherError = "No destination coordinates"
            return
        }

        isLoadingWeather = true
        weatherError = nil

        let result = await WeatherService.fetchWeatherWithError(
            for: destCoord,
            at: departure.targetArrivalTime
        )

        switch result {
        case .success(let info):
            weatherInfo = info
        case .failure(let error):
            weatherInfo = nil
            weatherError = error
        }

        isLoadingWeather = false
    }

    // MARK: - Info Paragraphs

    @ViewBuilder
    private var weatherParagraph: some View {
        if let weather = weatherInfo {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: weather.symbolName)
                    .font(.title2)
                    .foregroundStyle(weather.condition.color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Expect \(weather.formattedTemperature) and \(weather.conditionDescription.lowercased()) at \(timeFormatter.string(from: departure.targetArrivalTime))")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let suggestion = weather.suggestion {
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else if isLoadingWeather {
            HStack(alignment: .top, spacing: 14) {
                ProgressView()
                    .frame(width: 28)

                Text("Loading weather...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if let error = weatherError {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Weather unavailable")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var trafficParagraph: some View {
        if trafficStatus != .unknown {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: trafficStatus.icon)
                    .font(.title2)
                    .foregroundStyle(trafficStatus.color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(trafficStatus.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(trafficStatus.subtitle(
                        travelTime: departure.effectiveTravelTime,
                        transportVerb: transportVerb
                    ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var positivityParagraph: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("Have a great day!")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("You're all set for an on-time arrival.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
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
