import Foundation
import MapKit

struct TravelTimeService {
    
    enum TransportMode: String, CaseIterable {
        case automobile = "Driving"
        case walking = "Walking"
        case transit = "Transit"
        
        var mapKitType: MKDirectionsTransportType {
            switch self {
            case .automobile: return .automobile
            case .walking: return .walking
            case .transit: return .transit
            }
        }
        
        var icon: String {
            switch self {
            case .automobile: return "car.fill"
            case .walking: return "figure.walk"
            case .transit: return "bus.fill"
            }
        }
    }
    
    /// Calculate travel time between two coordinates
    static func calculateTravelTime(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType = .automobile
    ) async -> TimeInterval? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportType
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            return response.routes.first?.expectedTravelTime
        } catch {
            print("Directions error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Calculate travel time using user's current location
    static func calculateTravelTime(
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType = .automobile
    ) async -> TimeInterval? {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportType
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            return response.routes.first?.expectedTravelTime
        } catch {
            print("Directions error: \(error.localizedDescription)")
            return nil
        }
    }
}
