import SwiftUI
import SwiftData
import CoreLocation

struct PlacesRow: View {
    @Query(sort: \SavedPlace.createdAt) private var savedPlaces: [SavedPlace]
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var selectedName: String?
    @Binding var selectedAddress: String?
    
    // Actions
    var onSelectCurrentLocation: (() -> Void)? = nil // Optional for destination use
    var onAddNew: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // 1. Current Location Badge (only shown if callback provided)
                if let onSelectCurrentLocation = onSelectCurrentLocation {
                    Button(action: onSelectCurrentLocation) {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 50, height: 50)
                                .overlay {
                                    Image(systemName: "location.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                }
                                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                            
                            Text("Current")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // 2. Saved Places
                ForEach(savedPlaces) { place in
                    Button {
                        selectedCoordinate = place.coordinate
                        selectedName = place.name
                        selectedAddress = place.address
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color.blue) // Standard Maps blue
                                .frame(width: 50, height: 50)
                                .overlay {
                                    if place.icon.contains(".") {
                                        // Legacy SF Symbol support
                                        Image(systemName: place.icon)
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                    } else {
                                        // Emoji
                                        Text(place.icon)
                                            .font(.title2)
                                    }
                                }
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            Text(place.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .frame(maxWidth: 60)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // 3. Add New Badge
                Button(action: onAddNew) {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 50, height: 50)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                        
                        Text("Add")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8) // Space for shadow
        }
    }
}

#Preview {
    PlacesRow(
        selectedCoordinate: .constant(nil),
        selectedName: .constant(nil),
        selectedAddress: .constant(nil),
        onSelectCurrentLocation: {},
        onAddNew: {}
    )
    .modelContainer(for: SavedPlace.self, inMemory: true)
}
