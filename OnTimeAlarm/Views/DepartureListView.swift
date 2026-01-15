import SwiftUI
import SwiftData

struct DepartureListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationManager.self) private var locationManager
    @Query(sort: \Departure.targetArrivalTime) private var departures: [Departure]
    
    @State private var showingEditor = false
    @State private var selectedDeparture: Departure?
    
    /// The next upcoming active departure
    private var activeDeparture: Departure? {
        departures.first { $0.isEnabled }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if departures.isEmpty {
                        // Empty state
                        EmptyStateView(onAddTapped: { showingEditor = true })
                            .padding(.top, 60)
                    } else {
                        // Main departure card
                        if let departure = activeDeparture {
                            DepartureCardView(departure: departure)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .onTapGesture {
                                    selectedDeparture = departure
                                }
                        }
                        
                        // Additional departures (if any)
                        let otherDepartures = departures.filter { $0.id != activeDeparture?.id }
                        if !otherDepartures.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Later")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 20)
                                
                                ForEach(otherDepartures) { departure in
                                    CompactDepartureRow(departure: departure)
                                        .padding(.horizontal, 16)
                                        .onTapGesture {
                                            selectedDeparture = departure
                                        }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mission Control")
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
                DepartureWizardView()
            }
            .sheet(item: $selectedDeparture) { departure in
                DepartureWizardView(departure: departure)
            }
        }
        .onAppear {
            // Request location on appear
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
            NotificationManager.shared.cancelNotifications(for: departure)
            modelContext.delete(departure)
        }
    }
}

/// Compact row for secondary departures
struct CompactDepartureRow: View {
    @Bindable var departure: Departure
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(timeFormatter.string(from: departure.departureTime))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(departure.isEnabled ? .primary : .secondary)
                
                Text(departure.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $departure.isEnabled)
                .labelsHidden()
                .tint(.green)
                .onChange(of: departure.isEnabled) { _, isEnabled in
                    if isEnabled {
                        NotificationManager.shared.scheduleNotifications(for: departure)
                    } else {
                        NotificationManager.shared.cancelNotifications(for: departure)
                    }
                }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DepartureListView()
        .modelContainer(for: [Departure.self, Preferences.self], inMemory: true)
        .environment(LocationManager())
}
