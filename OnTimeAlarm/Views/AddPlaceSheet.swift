import SwiftUI
import CoreLocation
import SwiftData
import MapKit

struct AddPlaceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "📍" // Default to Pin
    @State private var address: String = ""
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var showingSearch = false
    
    // Map camera position
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && coordinate != nil
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let cardHeight: CGFloat = 380 // Approximate card height
                let visibleMapHeight = geometry.size.height - cardHeight
                let mapCenterY = visibleMapHeight / 2
                
                ZStack(alignment: .bottom) {
                    // MARK: - Hero Map (Top)
                    Map(position: $cameraPosition) {
                        if let coord = coordinate {
                            Annotation("", coordinate: coord) {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 44, height: 44)
                                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                                    Text(selectedIcon)
                                        .font(.title)
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .mapControls {
                        MapCompass()
                    }
                    .ignoresSafeArea(edges: .top)
                    // Apply bottom padding to shift the map's effective center upward
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: cardHeight)
                    }
                    
                    // MARK: - Details Card (Bottom)
                    VStack(spacing: 0) {
                        // Drag indicator
                        Capsule()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 36, height: 5)
                            .padding(.top, 10)
                            .padding(.bottom, 12)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // MARK: Search Row (Always Visible)
                            Button {
                                showingSearch = true
                            } label: {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(.blue)
                                    
                                    if let _ = coordinate {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(address.isEmpty ? "Selected Location" : address)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            Text("Tap to change")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text("Search for a location")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                            
                            // Label Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Label")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                TextField("Name this place (required)", text: $name)
                                    .font(.title3)
                                    .textFieldStyle(.plain)
                            }
                            
                            Divider()
                            
                            // Icon Selector - Native Emoji Picker
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Icon")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                HStack {
                                    Spacer()
                                    EmojiPickerButton(selectedEmoji: $selectedIcon)
                                    Spacer()
                                }
                            }
                            
                            // Save Button
                            Button {
                                savePlace()
                            } label: {
                                Text("Save Place")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(isFormValid ? Color.blue : Color.gray.opacity(0.3))
                                    .foregroundStyle(isFormValid ? .white : .secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(!isFormValid)
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.background)
                            .shadow(color: .black.opacity(0.12), radius: 20, y: -5)
                    )
                }
            }
            .navigationTitle("New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSearch) {
                LocationSearchSheet { coord, locationName, formattedAddress in
                    coordinate = coord
                    address = formattedAddress
                    
                    // Fly to the new location
                    withAnimation(.easeInOut(duration: 0.5)) {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        ))
                    }
                }
            }
        }
    }
    
    private func savePlace() {
        guard let coord = coordinate else { return }
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

