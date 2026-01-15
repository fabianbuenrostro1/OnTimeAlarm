import SwiftUI
import SwiftData
import MapKit
import CoreLocation

enum LocationSelectionType {
    case origin
    case destination
}

struct LocationSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationManager.self) private var locationManager
    
    @Query(sort: \SavedPlace.createdAt) private var savedPlaces: [SavedPlace]
    
    let type: LocationSelectionType
    
    @Binding var coordinate: CLLocationCoordinate2D?
    @Binding var locationName: String
    @Binding var locationAddress: String?
    
    // For origin only
    var onUseCurrentLocation: (() -> Void)? = nil
    
    @State private var showingSearch = false
    @State private var showingAddPlace = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let cardHeight: CGFloat = 320
                
                ZStack(alignment: .bottom) {
                    // MARK: - Map Background
                    Map(position: $cameraPosition) {
                        if let coord = coordinate {
                            Annotation("", coordinate: coord) {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 40, height: 40)
                                        .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                                    
                                    Image(systemName: type == .origin ? "location.fill" : "mappin.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(type == .origin ? .blue : .red)
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .ignoresSafeArea(edges: .top)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: cardHeight)
                    }
                    
                    // MARK: - Bottom Card
                    VStack(spacing: 0) {
                        // Drag indicator
                        Capsule()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 36, height: 5)
                            .padding(.top, 10)
                            .padding(.bottom, 16)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // MARK: Search Row
                            Button {
                                showingSearch = true
                            } label: {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(.blue)
                                    
                                    if let _ = coordinate {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(locationName)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            if let addr = locationAddress, !addr.isEmpty {
                                                Text(addr)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
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
                            
                            // MARK: Saved Places Row
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Saved Places")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(savedPlaces) { place in
                                            Button {
                                                selectPlace(place)
                                            } label: {
                                                VStack(spacing: 6) {
                                                    Circle()
                                                        .strokeBorder(Color.blue, lineWidth: 2)
                                                        .frame(width: 50, height: 50)
                                                        .background(Circle().fill(Color(.systemBackground)))
                                                        .overlay {
                                                            Text(place.icon)
                                                                .font(.title2)
                                                        }
                                                        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
                                                    
                                                    Text(place.name)
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                        .foregroundStyle(.primary)
                                                        .lineLimit(2)
                                                        .multilineTextAlignment(.center)
                                                        .frame(width: 70)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        // Add New Button
                                        Button {
                                            showingAddPlace = true
                                        } label: {
                                            VStack(spacing: 6) {
                                                Circle()
                                                    .strokeBorder(Color.blue.opacity(0.5), lineWidth: 2)
                                                    .frame(width: 50, height: 50)
                                                    .background(Circle().fill(Color(.systemBackground)))
                                                    .overlay {
                                                        Image(systemName: "plus")
                                                            .font(.title3)
                                                            .foregroundStyle(.blue)
                                                    }
                                                
                                                Text("Add")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(.primary)
                                                    .frame(width: 70)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            // MARK: Current Location (Origin Only)
                            if type == .origin {
                                Button {
                                    useCurrentLocation()
                                } label: {
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .foregroundStyle(.blue)
                                        Text("Use Current Location")
                                            .fontWeight(.medium)
                                        Spacer()
                                    }
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 14)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Done Button
                            Button {
                                dismiss()
                            } label: {
                                Text("Done")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(coordinate != nil ? Color.blue : Color.gray.opacity(0.3))
                                    .foregroundStyle(coordinate != nil ? .white : .secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(coordinate == nil)
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
            .navigationTitle(type == .origin ? "From" : "To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSearch) {
                LocationSearchSheet { coord, name, address in
                    coordinate = coord
                    locationName = name
                    locationAddress = address
                    
                    withAnimation(.easeInOut(duration: 0.5)) {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                }
            }
            .sheet(isPresented: $showingAddPlace) {
                AddPlaceSheet()
            }
            .onAppear {
                if let coord = coordinate {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
        }
    }
    
    private func selectPlace(_ place: SavedPlace) {
        coordinate = place.coordinate
        locationName = place.name
        locationAddress = place.address
        
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: place.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
    
    private func useCurrentLocation() {
        if let userLoc = locationManager.userLocation {
            coordinate = userLoc
            locationName = "Current Location"
            locationAddress = nil
            onUseCurrentLocation?()
            
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: userLoc,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
    }
}

#Preview {
    LocationSelectionSheet(
        type: .origin,
        coordinate: .constant(nil),
        locationName: .constant(""),
        locationAddress: .constant(nil)
    )
    .environment(LocationManager())
    .modelContainer(for: SavedPlace.self, inMemory: true)
}
