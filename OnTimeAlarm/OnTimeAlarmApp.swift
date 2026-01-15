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
            TabView {
                DepartureListView()
                    .tabItem {
                        Label("Mission Control", systemImage: "location.circle.fill")
                    }
                
                DebugView()
                    .tabItem {
                        Label("Debug", systemImage: "ant.fill")
                    }
            }
            .environment(locationManager)
            .onAppear {
                locationManager.requestPermission()
            }
        }
        .modelContainer(for: [Departure.self, Preferences.self, SavedPlace.self])
    }
}
