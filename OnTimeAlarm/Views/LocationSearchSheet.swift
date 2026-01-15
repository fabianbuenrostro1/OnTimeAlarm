import SwiftUI
import MapKit

struct LocationSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchService = LocationSearchService()
    @State private var isSearchActive = false
    
    var onLocationSelected: (CLLocationCoordinate2D, String, String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search results
                if searchService.searchQuery.isEmpty {
                    ContentUnavailableView(
                        "Search for a Place",
                        systemImage: "magnifyingglass",
                        description: Text("Enter an address or place name above")
                    )
                } else if searchService.results.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "mappin.slash",
                        description: Text("Try a different search term")
                    )
                } else {
                    List(searchService.results, id: \.self) { result in
                        Button {
                            selectLocation(result)
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
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search Location")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchService.searchQuery,
                isPresented: $isSearchActive,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Address or place name"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Activate search (and keyboard) when sheet appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isSearchActive = true
                }
            }
            .onChange(of: isSearchActive) { oldValue, newValue in
                // When X is pressed, isSearchActive becomes false - dismiss the sheet
                if oldValue == true && newValue == false {
                    dismiss()
                }
            }
        }
    }
    
    private func selectLocation(_ completion: MKLocalSearchCompletion) {
        Task {
            if let result = await searchService.getCoordinates(for: completion) {
                await MainActor.run {
                    onLocationSelected(result.coordinate, result.name, result.formattedAddress)
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    LocationSearchSheet { coordinate, name, address in
        print("Selected: \(name) at \(coordinate), Address: \(address)")
    }
}


