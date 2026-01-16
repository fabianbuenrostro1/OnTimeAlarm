import SwiftUI
import SwiftData

@main
struct OnTimeAlarmApp: App {
    @State private var locationManager = LocationManager()
    
    init() {
        NotificationManager.shared.requestAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            AlarmListView()
                .environment(locationManager)
                .onAppear {
                    locationManager.requestPermission()
                }
        }
        .modelContainer(for: [Departure.self, Preferences.self, SavedPlace.self])
    }
}
