import Foundation
import MapKit

struct TravelTimeService {
    
    enum TransportMode: String, CaseIterable {
        case automobile = "Drive"
        case cycling = "Bike"
        case walking = "Walk"
        
        var mapKitType: MKDirectionsTransportType {
            switch self {
            case .automobile: return .automobile
            case .cycling: return .walking // MapKit doesn't have cycling, use walking as approximation
            case .walking: return .walking
            }
        }
        
        var icon: String {
            switch self {
            case .automobile: return "car.fill"
            case .cycling: return "bicycle"
            case .walking: return "figure.walk"
            }
        }
        
        /// Speed multiplier for cycling (compared to walking)
        var speedMultiplier: Double {
            switch self {
            case .automobile: return 1.0
            case .cycling: return 0.33 // Cycling is ~3x faster than walking
            case .walking: return 1.0
            }
        }
    }
    
    /// Calculate travel time between two coordinates
    static func calculateTravelTime(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportMode: TransportMode = .automobile
    ) async -> TimeInterval? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportMode.mapKitType
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            if let travelTime = response.routes.first?.expectedTravelTime {
                // Apply speed multiplier for cycling
                return travelTime * transportMode.speedMultiplier
            }
            return nil
        } catch {
            print("Directions error: \(error.localizedDescription)")
            return nil
        }
    }
}
