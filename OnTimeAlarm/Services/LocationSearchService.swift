import Foundation
import MapKit
import Combine
import CoreLocation

@Observable
final class LocationSearchService: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    var searchQuery: String = ""
    var results: [MKLocalSearchCompletion] = []
    var isSearching = false

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]

        // Debounce search queries by 300ms
        searchSubject
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.performSearch(query)
            }
            .store(in: &cancellables)
    }

    /// Public method for debounced search
    func search(_ query: String) {
        searchQuery = query
        if query.isEmpty {
            results = []
            isSearching = false
        } else {
            isSearching = true
            searchSubject.send(query)
        }
    }

    /// Internal method that triggers the completer
    private func performSearch(_ query: String) {
        completer.queryFragment = query
    }

    /// Cancel any pending search
    func cancelSearch() {
        results = []
        isSearching = false
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

    // MARK: - Reverse Geocoding

    /// Reverse geocode coordinates to get the street address
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> (name: String, address: String)? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
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
                let name = street.isEmpty ? (placemark.name ?? formattedAddress) : street

                return (name, formattedAddress)
            }
        } catch {
            print("Reverse geocode error: \(error.localizedDescription)")
        }
        return nil
    }
}
