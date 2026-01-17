import SwiftUI
import SwiftData
import MapKit
import CoreLocation

enum LocationSelectionType {
    case origin
    case destination
}

enum LocationTab: String, CaseIterable {
    case search = "Search"
    case saved = "Saved"
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
    var onCustomLocationSelected: (() -> Void)? = nil

    // Tab state
    @State private var selectedTab: LocationTab = .search

    // Search state (inline, no separate sheet)
    @State private var searchService = LocationSearchService()
    @FocusState private var isSearchFocused: Bool

    // Add place sheet
    @State private var showingAddPlace = false

    // Map state
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var titleText: String {
        type == .origin ? "From" : "To"
    }

    var body: some View {
        GeometryReader { geometry in
            let cardHeight: CGFloat = 420

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
                .ignoresSafeArea()
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
                        .padding(.bottom, 8)

                    // Custom header row
                    HStack {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.blue)
                        Spacer()
                        Text(titleText)
                            .font(.headline)
                        Spacer()
                        // Invisible balance element
                        Text("Cancel").opacity(0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    // MARK: - Liquid Glass Tab Bar
                    HStack(spacing: 4) {
                        ForEach(LocationTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: tab == .search ? "magnifyingglass" : "bookmark.fill")
                                        .font(.subheadline)
                                    Text(tab.rawValue)
                                        .font(.subheadline.weight(.medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedTab == tab ? Color(.systemBackground) : Color.clear)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        }
                    }
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // MARK: - Tab Content
                    Group {
                        switch selectedTab {
                        case .search:
                            searchTabContent
                        case .saved:
                            savedTabContent
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.12), radius: 20, y: -5)
                )
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

    // MARK: - Search Tab Content
    @ViewBuilder
    private var searchTabContent: some View {
        VStack(spacing: 12) {
            // Always-visible search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18, weight: .medium))

                TextField("Address or place name", text: $searchService.searchQuery)
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                if !searchService.searchQuery.isEmpty {
                    Button {
                        searchService.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: searchService.searchQuery.isEmpty)

            // Results area
            if searchService.searchQuery.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("Search for a place")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else if searchService.results.isEmpty {
                // No results
                VStack(spacing: 8) {
                    Image(systemName: "mappin.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No results found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                // Results list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchService.results, id: \.self) { result in
                            Button {
                                selectSearchResult(result)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            if result != searchService.results.last {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 160)
            }

            // Current Location (origin only)
            if type == .origin {
                Button {
                    useCurrentLocationAndDismiss()
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
        }
    }

    // MARK: - Saved Tab Content
    @ViewBuilder
    private var savedTabContent: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Add New Place card
                Button {
                    showingAddPlace = true
                } label: {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .frame(width: 56, height: 56)
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        Text("Add Place")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                // Saved places as cards
                ForEach(savedPlaces) { place in
                    Button {
                        selectPlaceAndDismiss(place)
                    } label: {
                        VStack(spacing: 8) {
                            Text(place.icon)
                                .font(.system(size: 36))

                            Text(place.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(place.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 280)
    }

    // MARK: - Actions

    private func selectSearchResult(_ result: MKLocalSearchCompletion) {
        Task {
            if let (coord, name, address) = await searchService.getCoordinates(for: result) {
                await MainActor.run {
                    coordinate = coord
                    locationName = name
                    locationAddress = address
                    onCustomLocationSelected?()
                    dismiss()
                }
            }
        }
    }

    private func selectPlaceAndDismiss(_ place: SavedPlace) {
        coordinate = place.coordinate
        locationName = place.name
        locationAddress = place.address
        onCustomLocationSelected?()
        dismiss()
    }

    private func useCurrentLocationAndDismiss() {
        if let userLoc = locationManager.userLocation {
            coordinate = userLoc
            locationName = "Current Location"
            locationAddress = nil
            onUseCurrentLocation?()
            dismiss()
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
