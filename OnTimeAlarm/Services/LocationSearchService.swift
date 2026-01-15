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
    
    func getCoordinates(for completion: MKLocalSearchCompletion) async -> (coordinate: CLLocationCoordinate2D, name: String, formattedAddress: String)? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            if let mapItem = response.mapItems.first {
                // Construct full address
                let placemark = mapItem.placemark
                var addressComponents: [String] = []
                
                // Street
                let streetNumber = placemark.subThoroughfare ?? ""
                let streetName = placemark.thoroughfare ?? ""
                let street = "\(streetNumber) \(streetName)".trimmingCharacters(in: .whitespaces)
                if !street.isEmpty { addressComponents.append(street) }
                
                // City
                if let city = placemark.locality {
                    addressComponents.append(city)
                }
                
                // State & Zip
                if let state = placemark.administrativeArea, let zip = placemark.postalCode {
                    addressComponents.append("\(state) \(zip)")
                } else if let state = placemark.administrativeArea {
                    addressComponents.append(state)
                }
                
                let formattedAddress = addressComponents.joined(separator: ", ")
                let name = mapItem.name ?? completion.title
                
                // If the name IS the address (e.g. searching for a street address), 
                // formattedAddress might be duplicate. But safe to return both.
                
                return (mapItem.placemark.coordinate, name, formattedAddress)
            }
        } catch {
            print("Local search error: \(error.localizedDescription)")
        }
        return nil
    }
}
