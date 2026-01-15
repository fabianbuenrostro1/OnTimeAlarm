import SwiftUI
import SwiftData

struct DepartureListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Departure.targetArrivalTime) private var departures: [Departure]
    
    @State private var showingEditor = false
    @State private var selectedDeparture: Departure?
    
    var body: some View {
        NavigationStack {
            Group {
                if departures.isEmpty {
                    EmptyStateView(onAddTapped: { showingEditor = true })
                } else {
                    List {
                        ForEach(departures) { departure in
                            DepartureListRow(departure: departure)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedDeparture = departure
                                }
                        }
                        .onDelete(perform: deleteDepartures)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Departures")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !departures.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingEditor = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                DepartureEditorView()
            }
            .sheet(item: $selectedDeparture) { departure in
                DepartureEditorView(departure: departure)
            }
        }
    }
    
    private func deleteDepartures(at offsets: IndexSet) {
        for index in offsets {
            let departure = departures[index]
            NotificationManager.shared.cancelNotifications(for: departure)
            modelContext.delete(departure)
        }
    }
}

#Preview {
    DepartureListView()
        .modelContainer(for: [Departure.self, Preferences.self], inMemory: true)
}
