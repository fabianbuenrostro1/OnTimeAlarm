import SwiftUI
import MapKit

struct LocationSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchService = LocationSearchService()
    @FocusState private var isFocused: Bool
    
    var onLocationSelected: (CLLocationCoordinate2D, String, String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Search Header
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        
                        TextField("Address or place name", text: $searchService.searchQuery)
                            .focused($isFocused)
                            .submitLabel(.search)
                        
                        if !searchService.searchQuery.isEmpty {
                            Button {
                                searchService.searchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Dismiss Button (X)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6).opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
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
            .navigationBarHidden(true)
            .onAppear {
                isFocused = true
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


