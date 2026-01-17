import SwiftUI
import SwiftData

@main
struct OnTimeAlarmApp: App {
    @State private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(locationManager)
                .task {
                    // Request location permission
                    locationManager.requestPermission()

                    // Request AlarmKit authorization
                    do {
                        try await AlarmKitManager.shared.requestAuthorization()
                    } catch {
                        print("AlarmKit authorization failed: \(error)")
                    }
                }
        }
        .modelContainer(for: [Departure.self, Preferences.self, SavedPlace.self])
    }
}
