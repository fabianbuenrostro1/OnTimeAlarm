import SwiftUI
import MapKit
import CoreLocation

struct InlineLocationField: View {
    // External bindings
    @Binding var coordinate: CLLocationCoordinate2D?
    @Binding var locationName: String
    @Binding var locationAddress: String?

    // Configuration
    let placeholder: String
    let icon: String
    let iconColor: Color
    var showUseMyLocation: Bool = false

    // Internal state
    @State private var searchService = LocationSearchService()
    @State private var searchText: String = ""
    @State private var isExpanded: Bool = false
    @State private var isReverseGeocoding: Bool = false
    @FocusState private var isFocused: Bool

    // Environment
    @Environment(LocationManager.self) private var locationManager

    private var hasSelection: Bool {
        coordinate != nil && !locationName.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            mainFieldContent

            if isExpanded {
                dropdownContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onChange(of: isFocused) { _, focused in
            if focused {
                isExpanded = true
            } else {
                // Delay closing to allow button taps to register
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if !isFocused {
                        isExpanded = false
                    }
                }
            }
        }
    }

    // MARK: - Main Field

    @ViewBuilder
    private var mainFieldContent: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            if hasSelection && !isFocused {
                // Display mode - show selected location
                VStack(alignment: .leading, spacing: 2) {
                    Text(locationName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let address = locationAddress, !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    searchText = ""
                    isFocused = true
                }
            } else {
                // Edit mode - show text field
                TextField(placeholder, text: $searchText)
                    .font(.headline)
                    .focused($isFocused)
                    .onChange(of: searchText) { _, newValue in
                        searchService.search(newValue)
                    }
                    .submitLabel(.search)
            }

            Spacer()

            // Clear button when has selection (and not focused)
            if hasSelection && !isFocused {
                Button {
                    clearSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Dropdown

    @ViewBuilder
    private var dropdownContent: some View {
        VStack(spacing: 0) {
            // "Use my location" option (origin only)
            if showUseMyLocation {
                Button {
                    useMyLocation()
                } label: {
                    HStack {
                        if isReverseGeocoding {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.blue)
                        }
                        Text("Use my location")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
                .disabled(isReverseGeocoding)

                if !searchService.results.isEmpty {
                    Divider()
                        .padding(.leading, 16)
                }
            }

            // Search results
            if !searchService.results.isEmpty {
                ForEach(searchService.results.prefix(5), id: \.self) { result in
                    Button {
                        selectSearchResult(result)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)

                    if result != searchService.results.prefix(5).last {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            } else if !searchText.isEmpty && !searchService.isSearching {
                // No results state
                HStack {
                    Image(systemName: "mappin.slash")
                        .foregroundStyle(.tertiary)
                    Text("No results found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
            } else if searchService.isSearching {
                // Loading state
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        )
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func selectSearchResult(_ result: MKLocalSearchCompletion) {
        Task {
            if let (coord, name, address) = await searchService.getCoordinates(for: result) {
                await MainActor.run {
                    coordinate = coord
                    locationName = name
                    locationAddress = address
                    searchText = ""
                    searchService.cancelSearch()
                    isFocused = false
                    isExpanded = false
                }
            }
        }
    }

    private func useMyLocation() {
        guard let userLocation = locationManager.userLocation else { return }

        isReverseGeocoding = true

        Task {
            if let (name, address) = await searchService.reverseGeocode(coordinate: userLocation) {
                await MainActor.run {
                    coordinate = userLocation
                    locationName = name
                    locationAddress = address
                    searchText = ""
                    searchService.cancelSearch()
                    isFocused = false
                    isExpanded = false
                    isReverseGeocoding = false
                }
            } else {
                await MainActor.run {
                    isReverseGeocoding = false
                }
            }
        }
    }

    private func clearSelection() {
        coordinate = nil
        locationName = ""
        locationAddress = nil
        searchText = ""
        searchService.cancelSearch()
    }
}

#Preview {
    VStack(spacing: 20) {
        InlineLocationField(
            coordinate: .constant(nil),
            locationName: .constant(""),
            locationAddress: .constant(nil),
            placeholder: "Starting location",
            icon: "location.fill",
            iconColor: .blue,
            showUseMyLocation: true
        )

        InlineLocationField(
            coordinate: .constant(CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)),
            locationName: .constant("123 Main St"),
            locationAddress: .constant("San Francisco, CA 94102"),
            placeholder: "Destination",
            icon: "mappin.circle.fill",
            iconColor: .red
        )
    }
    .padding()
    .environment(LocationManager())
}
