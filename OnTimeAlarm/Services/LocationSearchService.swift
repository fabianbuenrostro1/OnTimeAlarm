import Foundation
import MapKit

@Observable
final class LocationSearchService: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    
    var searchQuery: String = "" {
        didSet {
            if searchQuery.isEmpty {
                results = []
            } else {
                completer.queryFragment = searchQuery
            }
        }
    }
    
    var results: [MKLocalSearchCompletion] = []
    var isSearching = false
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    // MARK: - MKLocalSearchCompleterDelegate
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
        isSearching = false
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
        isSearching = false
    }
    
    // MARK: - Get Coordinates from Completion
    
    func getCoordinates(for completion: MKLocalSearchCompletion) async -> (coordinate: CLLocationCoordinate2D, name: String)? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            if let mapItem = response.mapItems.first {
                return (mapItem.placemark.coordinate, mapItem.name ?? completion.title)
            }
        } catch {
            print("Local search error: \(error.localizedDescription)")
        }
        return nil
    }
}
