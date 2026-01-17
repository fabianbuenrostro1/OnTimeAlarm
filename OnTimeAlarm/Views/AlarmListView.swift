import SwiftUI
import SwiftData

/// iOS Alarm-style list view - the new home screen
struct AlarmListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationManager.self) private var locationManager
    @Query(sort: \Departure.targetArrivalTime) private var departures: [Departure]

    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            Group {
                if departures.isEmpty {
                    EmptyStateView(onAddTapped: { showingEditor = true })
                } else {
                    List {
                        ForEach(departures) { departure in
                            NavigationLink(value: departure) {
                                AlarmRowView(departure: departure)
                            }
                        }
                        .onDelete(perform: deleteDepartures)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(departures.count == 1 ? "Arrival Alarm" : "Arrival Alarms")
            .navigationDestination(for: Departure.self) { departure in
                DepartureDetailView(departure: departure)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingEditor = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                DepartureWizardView()
            }
        }
        .onAppear {
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            } else {
                locationManager.requestLocation()
            }
        }
    }

    private func deleteDepartures(at offsets: IndexSet) {
        for index in offsets {
            let departure = departures[index]
            Task {
                await AlarmKitManager.shared.cancelAlarms(for: departure)
            }
            modelContext.delete(departure)
        }
    }
}

#Preview {
    AlarmListView()
        .modelContainer(for: [Departure.self, Preferences.self], inMemory: true)
        .environment(LocationManager())
}
