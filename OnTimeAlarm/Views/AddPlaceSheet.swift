import SwiftUI
import CoreLocation
import SwiftData

struct AddPlaceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "📍" // Default to Pin
    @State private var address: String = ""
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var showingSearch = false
    
    // Smart Presets
    let presets: [(String, String)] = [
        ("Home", "🏠"),
        ("Work", "💼"),
        ("Gym", "💪"),
        ("School", "🎓"),
        ("Partner", "❤️"),
        ("Cafe", "☕️"),
        ("Shop", "🛒")
    ]
    
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && coordinate != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Location (Reverse order - Location first)
                Section("Location") {
                    if let coord = coordinate {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(address)
                                    .fontWeight(.medium)
                                Text("\(coord.latitude), \(coord.longitude)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Change", systemImage: "magnifyingglass") {
                                showingSearch = true
                            }
                        }
                    } else {
                        Button {
                            showingSearch = true
                        } label: {
                            Label("Search for Address", systemImage: "magnifyingglass")
                        }
                    }
                }
                
                // Section 2: Label (Below location)
                Section("Label") {
                    TextField("Name (Required)", text: $name)
                    
                    // Presets for quick filling
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.0) { preset in
                                Button {
                                    name = preset.0
                                    selectedIcon = preset.1
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(preset.1)
                                        Text(preset.0)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(SavedPlace.icons, id: \.self) { icon in
                                Text(icon)
                                    .font(.title)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.blue.opacity(0.15) : Color.clear)
                                    .clipShape(Circle())
                                    .overlay {
                                        if selectedIcon == icon {
                                            Circle().stroke(Color.blue, lineWidth: 2)
                                        }
                                    }
                                    .onTapGesture {
                                        selectedIcon = icon
                                    }
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .navigationTitle("New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePlace()
                    }
                    .disabled(!isFormValid)
                }
            }
            .sheet(isPresented: $showingSearch) {
                LocationSearchSheet { coord, locationName, formattedAddress in
                    coordinate = coord
                    address = formattedAddress
                    // Note: intentionally NOT auto-filling name to force user input
                }
            }
        }
    }
    
    private func savePlace() {
        guard let coord = coordinate else { return }
        
        // Ensure we don't save with empty name despite UI disable
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let newPlace = SavedPlace(
            name: name,
            icon: selectedIcon,
            address: address,
            latitude: coord.latitude,
            longitude: coord.longitude
        )
        
        modelContext.insert(newPlace)
        dismiss()
    }
}

#Preview {
    AddPlaceSheet()
}
