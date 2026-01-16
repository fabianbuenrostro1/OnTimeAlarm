import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            AlarmListView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            PreferencesView()
                .tabItem {
                    Label("Preferences", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Departure.self, Preferences.self, SavedPlace.self], inMemory: true)
        .environment(LocationManager())
}
