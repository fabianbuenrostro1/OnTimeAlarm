import SwiftUI
import SwiftData

@main
struct OnTimeAlarmApp: App {
    
    init() {
        NotificationManager.shared.requestAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            DepartureListView()
        }
        .modelContainer(for: [Departure.self, Preferences.self])
    }
}

