import Foundation
import CoreLocation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var userLocation: CLLocationCoordinate2D?
    var isLoading = false
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
        
        #if DEBUG
        setMockLocation()
        #endif
    }
    
    // MARK: - Public Methods
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        isLoading = true
        manager.requestLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isLoading = false
        if let coordinate = locations.first?.coordinate {
            print("LocationManager: Updated location to \(coordinate)")
            userLocation = coordinate
        }
    }
    
    // Fallback for Simulator/Preview
    func setMockLocation() {
        #if DEBUG
        // Apple Park
        userLocation = CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090)
        #endif
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        print("Location error: \(error.localizedDescription)")
    }
}
